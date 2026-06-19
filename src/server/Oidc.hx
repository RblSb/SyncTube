package server;

import Types.OidcConfig;
import haxe.Json;
import js.node.Buffer;
import js.node.Crypto;
import js.node.Http;
import js.node.Https;
import js.node.http.IncomingMessage;
import js.node.http.ServerResponse;
import js.node.url.URL;

private typedef Session = {
	name:String,
	isAdmin:Bool,
	exp:Float,
}

private typedef Pending = {
	verifier:String,
	nonce:String,
	redirectUri:String,
	createdAt:Float,
}

class Oidc {
	static inline var COOKIE = "synctube_session";
	static inline var SESSION_TTL_MS = 7 * 24 * 60 * 60 * 1000;
	static inline var PENDING_TTL_MS = 10 * 60 * 1000;
	static inline var CLOCK_LEEWAY_S = 60;

	final config:OidcConfig;
	final maxLoginLength:Int;
	final isHttps:Bool;
	final sessions:Map<String, Session> = [];
	final pending:Map<String, Pending> = [];
	var discovery:Null<Dynamic>;
	var jwks:Null<Array<Dynamic>>;

	public function new(config:OidcConfig, opts:{maxLoginLength:Int, isHttps:Bool}) {
		this.config = config;
		maxLoginLength = opts.maxLoginLength;
		isHttps = opts.isHttps;
	}

	public function beginLogin(req:IncomingMessage, res:ServerResponse):Void {
		ensureDiscovery(disc -> {
			if (disc == null) {
				showError(res, "OIDC discovery failed");
				return;
			}
			final state = randomHex(16);
			final nonce = randomHex(16);
			final verifier = base64Url((Crypto : Dynamic).randomBytes(32));
			final challenge = sha256Base64Url(verifier);
			final redirect = redirectUri(req);
			pending[state] = {
				verifier: verifier,
				nonce: nonce,
				redirectUri: redirect,
				createdAt: now(),
			};
			prunePending();
			final query = encodeQuery([
				{k: "response_type", v: "code"},
				{k: "client_id", v: config.clientId},
				{k: "redirect_uri", v: redirect},
				{k: "scope", v: scopes()},
				{k: "state", v: state},
				{k: "nonce", v: nonce},
				{k: "code_challenge", v: challenge},
				{k: "code_challenge_method", v: "S256"},
			]);
			final sep = (disc.authorization_endpoint : String).contains("?") ? "&" : "?";
			res.redirect('${disc.authorization_endpoint}$sep$query');
		});
	}

	public function handleCallback(req:IncomingMessage, res:ServerResponse):Void {
		final url = try new URL(req.url, "http://localhost") catch (e) null;
		if (url == null) {
			showError(res, "Invalid callback request");
			return;
		}
		final params = url.searchParams;
		final error = params.get("error");
		if (error != null) {
			showError(res, 'OIDC provider error: $error');
			return;
		}
		final code = params.get("code");
		final state = params.get("state");
		if (code == null || state == null) {
			showError(res, "Missing code or state");
			return;
		}
		final pend = pending[state];
		pending.remove(state);
		if (pend == null || now() - pend.createdAt > PENDING_TTL_MS) {
			showError(res, "Invalid or expired login state");
			return;
		}
		ensureDiscovery(disc -> {
			if (disc == null) {
				showError(res, "OIDC discovery failed");
				return;
			}
			final body = encodeQuery([
				{k: "grant_type", v: "authorization_code"},
				{k: "code", v: code},
				{k: "redirect_uri", v: pend.redirectUri},
				{k: "client_id", v: config.clientId},
				{k: "client_secret", v: config.clientSecret},
				{k: "code_verifier", v: pend.verifier},
			]);
			final headers = {
				"content-type": "application/x-www-form-urlencoded",
				"content-length": '${Buffer.byteLength(body)}',
				"accept": "application/json",
			};
			httpJson("POST", disc.token_endpoint, headers, body, tok -> {
				if (tok == null || tok.id_token == null) {
					showError(res, "Token exchange failed");
					return;
				}
				verifyIdToken(disc, tok.id_token, pend.nonce, claims -> {
					if (claims == null) {
						showError(res, "ID token validation failed");
						return;
					}
					maybeUserinfo(disc, tok, claims, merged -> finishLogin(merged, res));
				});
			});
		});
	}

	public function logout(req:IncomingMessage, res:ServerResponse):Void {
		final id = getCookie(req, COOKIE);
		if (id != null) sessions.remove(id);
		clearSessionCookie(res);
		res.redirect("/");
	}

	public function resolveSession(req:IncomingMessage):Null<{name:String, isAdmin:Bool}> {
		final id = getCookie(req, COOKIE);
		if (id == null) return null;
		final s = sessions[id];
		if (s == null) return null;
		if (s.exp < now()) {
			sessions.remove(id);
			return null;
		}
		return {name: s.name, isAdmin: s.isAdmin};
	}

	function finishLogin(claims:Dynamic, res:ServerResponse):Void {
		final name = pickName(claims);
		final isAdmin = isAdminFromClaims(claims);
		final sessionId = randomHex(32);
		sessions[sessionId] = {
			name: name,
			isAdmin: isAdmin,
			exp: now() + SESSION_TTL_MS,
		};
		setSessionCookie(res, sessionId);
		res.redirect("/");
	}

	function verifyIdToken(disc:Dynamic, idToken:String, nonce:String,
			cb:(claims:Null<Dynamic>) -> Void):Void {
		final parts = idToken.split(".");
		if (parts.length != 3) return cb(null);
		final header = try Json.parse(base64UrlString(parts[0])) catch (e) null;
		final payload = try Json.parse(base64UrlString(parts[1])) catch (e) null;
		if (header == null || payload == null) return cb(null);
		if (!validateClaims(disc, payload, nonce)) return cb(null);
		final alg:String = header.alg;
		if (alg == null) return cb(null);
		final signingInput = '${parts[0]}.${parts[1]}';
		final sig = Buffer.from(parts[2], "base64url");
		if (alg.startsWith("HS")) {
			return cb(verifyHmac(alg, signingInput, sig) ? payload : null);
		}
		function tryVerify(retried:Bool):Void {
			ensureJwks(disc, keys -> {
				if (keys == null) return cb(null);
				final jwk = findKey(keys, header.kid);
				if (jwk == null) {
					if (!retried) {
						jwks = null;
						tryVerify(true);
						return;
					}
					return cb(null);
				}
				cb(verifyAsymmetric(alg, jwk, signingInput, sig) ? payload : null);
			});
		}
		tryVerify(false);
	}

	function validateClaims(disc:Dynamic, payload:Dynamic, nonce:String):Bool {
		if (payload.iss != disc.issuer) return false;
		final aud:Dynamic = payload.aud;
		final audOk = if (Std.isOfType(aud, Array)) {
			(aud : Array<Dynamic>).indexOf(config.clientId) != -1;
		} else {
			aud == config.clientId;
		}
		if (!audOk) return false;
		if (payload.azp != null && payload.azp != config.clientId) return false;
		final exp:Null<Float> = payload.exp;
		if (exp == null || exp + CLOCK_LEEWAY_S < now() / 1000) return false;
		if (nonce != null && payload.nonce != nonce) return false;
		return true;
	}

	function verifyHmac(alg:String, signingInput:String, sig:Buffer):Bool {
		try {
			final hmac = (Crypto : Dynamic).createHmac('sha${alg.substr(2)}', config.clientSecret);
			hmac.update(signingInput);
			final expected:Buffer = hmac.digest();
			if (expected.length != sig.length) return false;
			return (Crypto : Dynamic).timingSafeEqual(expected, sig);
		} catch (e) {
			return false;
		}
	}

	function verifyAsymmetric(alg:String, jwk:Dynamic, signingInput:String, sig:Buffer):Bool {
		try {
			final crypto = (Crypto : Dynamic);
			final keyObj = crypto.createPublicKey({key: jwk, format: "jwk"});
			final verifier = crypto.createVerify('sha${alg.substr(2)}');
			verifier.update(signingInput);
			verifier.end();
			final key:Dynamic = if (alg.startsWith("ES")) {
				{key: keyObj, dsaEncoding: "ieee-p1363"};
			} else if (alg.startsWith("PS")) {
				{
					key: keyObj,
					padding: crypto.constants.RSA_PKCS1_PSS_PADDING,
					saltLength: crypto.constants.RSA_PSS_SALTLEN_DIGEST,
				};
			} else {
				keyObj;
			}
			return verifier.verify(key, sig);
		} catch (e) {
			return false;
		}
	}

	function findKey(keys:Array<Dynamic>, kid:Null<String>):Null<Dynamic> {
		if (kid != null) {
			for (key in keys) if (key.kid == kid) return key;
			return null;
		}
		return keys.length == 1 ? keys[0] : null;
	}

	function maybeUserinfo(disc:Dynamic, tok:Dynamic, claims:Dynamic,
			cb:(claims:Dynamic) -> Void):Void {
		final hasGroupClaim = config.groupClaim != null && config.groupClaim.length > 0;
		final needsGroup = hasGroupClaim && Reflect.field(claims, config.groupClaim) == null;
		if (disc.userinfo_endpoint == null || tok.access_token == null || !needsGroup) {
			return cb(claims);
		}
		final headers = {"authorization": 'Bearer ${tok.access_token}'};
		httpJson("GET", disc.userinfo_endpoint, headers, null, info -> {
			if (info != null) {
				for (field in Reflect.fields(info)) {
					if (Reflect.field(claims, field) == null) {
						Reflect.setField(claims, field, Reflect.field(info, field));
					}
				}
			}
			cb(claims);
		});
	}

	function pickName(claims:Dynamic):String {
		final candidates = ["preferred_username", "name", "nickname", "email", "sub"];
		if (config.usernameClaim != null && config.usernameClaim.length > 0) {
			candidates.unshift(config.usernameClaim);
		}
		for (claim in candidates) {
			final value = Reflect.field(claims, claim);
			if (value == null) continue;
			final name = sanitizeName(Std.string(value));
			if (name.length > 0) return name;
		}
		return "User";
	}

	function isAdminFromClaims(claims:Dynamic):Bool {
		if (config.groupClaim == null || config.groupClaim.length == 0) return false;
		final adminValues = config.adminValues ?? [];
		if (adminValues.length == 0) return false;
		final raw:Dynamic = Reflect.field(claims, config.groupClaim);
		if (raw == null) return false;
		final values = if (Std.isOfType(raw, Array)) {
			[for (v in (raw : Array<Dynamic>)) Std.string(v)];
		} else {
			[Std.string(raw)];
		}
		for (value in values) {
			if (adminValues.indexOf(value) != -1) return true;
		}
		return false;
	}

	final matchHtmlChars = ~/[&^<>'"]/g;

	function sanitizeName(name:String):String {
		name = matchHtmlChars.replace(name.trim(), "");
		if (name.length > maxLoginLength) name = name.substr(0, maxLoginLength);
		return name.trim();
	}

	function ensureDiscovery(cb:(disc:Null<Dynamic>) -> Void):Void {
		if (discovery != null) return cb(discovery);
		var base = config.issuer;
		if (base.endsWith("/")) base = base.substr(0, base.length - 1);
		httpJson("GET", '$base/.well-known/openid-configuration', null, null, json -> {
			if (json == null || json.authorization_endpoint == null
				|| json.token_endpoint == null || json.issuer == null) {
				return cb(null);
			}
			discovery = json;
			cb(discovery);
		});
	}

	function ensureJwks(disc:Dynamic, cb:(keys:Null<Array<Dynamic>>) -> Void):Void {
		if (jwks != null) return cb(jwks);
		if (disc.jwks_uri == null) return cb(null);
		httpJson("GET", disc.jwks_uri, null, null, json -> {
			if (json == null || json.keys == null) return cb(null);
			jwks = json.keys;
			cb(jwks);
		});
	}

	function httpJson(method:String, urlStr:String, headers:Null<Dynamic>,
			body:Null<String>, cb:(json:Null<Dynamic>) -> Void):Void {
		final url = try new URL(urlStr) catch (e) {
			cb(null);
			return;
		}
		final options:Dynamic = {
			method: method,
			hostname: url.hostname,
			path: url.pathname + url.search,
			headers: headers ?? {},
		};
		if (url.port != null && url.port != "") options.port = Std.parseInt(url.port);
		final transport:Dynamic = url.protocol == "https:" ? Https : Http;
		final request = transport.request(options, (res:Dynamic) -> {
			final chunks:Array<Buffer> = [];
			res.on("data", chunk -> chunks.push(chunk));
			res.on("end", () -> {
				final text = Buffer.concat(chunks).toString();
				if (res.statusCode >= 400) return cb(null);
				cb(try Json.parse(text) catch (e) null);
			});
		});
		request.on("error", e -> cb(null));
		if (body != null) request.write(body);
		request.end();
	}

	function redirectUri(req:IncomingMessage):String {
		if (config.redirectUri != null && config.redirectUri.length > 0) {
			return config.redirectUri;
		}
		final host = req.headers["host"];
		return '${requestProtocol(req)}://$host/auth/callback';
	}

	function requestProtocol(req:IncomingMessage):String {
		final forwarded:String = req.headers["x-forwarded-proto"];
		if (forwarded != null) return forwarded.split(",")[0].trim();
		return isHttps ? "https" : "http";
	}

	function scopes():String {
		final s = config.scopes;
		if (s == null || s.length == 0) return "openid profile";
		return s.contains("openid") ? s : 'openid $s';
	}

	function setSessionCookie(res:ServerResponse, id:String):Void {
		final maxAge = Std.int(SESSION_TTL_MS / 1000);
		var cookie = '$COOKIE=$id; Path=/; HttpOnly; SameSite=Lax; Max-Age=$maxAge';
		if (isHttps) cookie += "; Secure";
		res.setHeader("set-cookie", cookie);
	}

	function clearSessionCookie(res:ServerResponse):Void {
		var cookie = '$COOKIE=; Path=/; HttpOnly; SameSite=Lax; Max-Age=0';
		if (isHttps) cookie += "; Secure";
		res.setHeader("set-cookie", cookie);
	}

	function getCookie(req:IncomingMessage, name:String):Null<String> {
		final header:String = req.headers["cookie"];
		if (header == null) return null;
		for (part in header.split(";")) {
			final pair = part.trim();
			final i = pair.indexOf("=");
			if (i < 0) continue;
			if (pair.substr(0, i) == name) return pair.substr(i + 1);
		}
		return null;
	}

	function prunePending():Void {
		final limit = now() - PENDING_TTL_MS;
		for (state => data in pending) {
			if (data.createdAt < limit) pending.remove(state);
		}
	}

	function showError(res:ServerResponse, msg:String):Void {
		trace('OIDC: $msg');
		res.statusCode = 400;
		res.setHeader("content-type", "text/html");
		res.end('<p>${StringTools.htmlEscape(msg, true)}</p><p><a href="/">Back</a></p>');
	}

	inline function randomHex(bytes:Int):String {
		return (Crypto : Dynamic).randomBytes(bytes).toString("hex");
	}

	inline function base64Url(buf:Buffer):String {
		return buf.toString("base64url");
	}

	inline function base64UrlString(data:String):String {
		return Buffer.from(data, "base64url").toString("utf8");
	}

	inline function sha256Base64Url(data:String):String {
		return (Crypto : Dynamic).createHash("sha256").update(data).digest("base64url");
	}

	inline function encodeQuery(params:Array<{k:String, v:String}>):String {
		return params.map(p -> '${encodeURIComponent(p.k)}=${encodeURIComponent(p.v)}').join("&");
	}

	inline function encodeURIComponent(data:String):String {
		return js.Syntax.code("encodeURIComponent({0})", data);
	}

	inline function now():Float {
		return Date.now().getTime();
	}
}
