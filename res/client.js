(function ($hx_exports, $global) { "use strict";
$hx_exports["client"] = $hx_exports["client"] || {};
$hx_exports["client"]["JsApi"] = $hx_exports["client"]["JsApi"] || {};
var $estr = function() { return js_Boot.__string_rec(this,''); },$hxEnums = $hxEnums || {},$_;
function $extend(from, fields) {
	var proto = Object.create(from);
	for (var name in fields) proto[name] = fields[name];
	if( fields.toString !== Object.prototype.toString ) proto.toString = fields.toString;
	return proto;
}
var ClientGroup = $hxEnums["ClientGroup"] = { __ename__:true,__constructs__:null
	,Banned: {_hx_name:"Banned",_hx_index:0,__enum__:"ClientGroup",toString:$estr}
	,User: {_hx_name:"User",_hx_index:1,__enum__:"ClientGroup",toString:$estr}
	,Leader: {_hx_name:"Leader",_hx_index:2,__enum__:"ClientGroup",toString:$estr}
	,Admin: {_hx_name:"Admin",_hx_index:3,__enum__:"ClientGroup",toString:$estr}
};
ClientGroup.__constructs__ = [ClientGroup.Banned,ClientGroup.User,ClientGroup.Leader,ClientGroup.Admin];
var Client = function(name,group) {
	this.name = name;
	var i = group;
	if(group == null) {
		i = 0;
	}
	this.group = i;
};
Client.__name__ = true;
Client.fromData = function(data) {
	return new Client(data.name,data.group);
};
Client.prototype = {
	hasPermission: function(permission,permissions) {
		if((this.group & 1) != 0) {
			return permissions.banned.indexOf(permission) != -1;
		}
		if((this.group & 8) != 0) {
			return permissions.admin.indexOf(permission) != -1;
		}
		if((this.group & 4) != 0) {
			return permissions.leader.indexOf(permission) != -1;
		}
		if((this.group & 2) != 0) {
			return permissions.user.indexOf(permission) != -1;
		}
		return permissions.guest.indexOf(permission) != -1;
	}
	,setGroupFlag: function(type,flag) {
		if(flag) {
			this.group |= 1 << type._hx_index;
		} else {
			this.group &= -1 - (1 << type._hx_index);
		}
		return flag;
	}
};
var ClientTools = function() { };
ClientTools.__name__ = true;
ClientTools.setLeader = function(clients,name) {
	var _g = 0;
	while(_g < clients.length) {
		var client = clients[_g];
		++_g;
		if(client.name == name) {
			client.setGroupFlag(ClientGroup.Leader,true);
		} else if((client.group & 4) != 0) {
			client.setGroupFlag(ClientGroup.Leader,false);
		}
	}
};
ClientTools.hasLeader = function(clients) {
	var _g = 0;
	while(_g < clients.length) if((clients[_g++].group & 4) != 0) {
		return true;
	}
	return false;
};
ClientTools.getByName = function(clients,name,def) {
	var _g = 0;
	while(_g < clients.length) {
		var client = clients[_g];
		++_g;
		if(client.name == name) {
			return client;
		}
	}
	return def;
};
var EReg = function(r,opt) {
	this.r = new RegExp(r,opt.split("u").join(""));
};
EReg.__name__ = true;
EReg.prototype = {
	match: function(s) {
		if(this.r.global) {
			this.r.lastIndex = 0;
		}
		this.r.m = this.r.exec(s);
		this.r.s = s;
		return this.r.m != null;
	}
	,matched: function(n) {
		if(this.r.m != null && n >= 0 && n < this.r.m.length) {
			return this.r.m[n];
		} else {
			throw haxe_Exception.thrown("EReg::matched");
		}
	}
	,split: function(s) {
		return s.replace(this.r,"#__delim__#").split("#__delim__#");
	}
};
var HxOverrides = function() { };
HxOverrides.__name__ = true;
HxOverrides.dateStr = function(date) {
	var m = date.getMonth() + 1;
	var d = date.getDate();
	var h = date.getHours();
	var mi = date.getMinutes();
	var s = date.getSeconds();
	return date.getFullYear() + "-" + (m < 10 ? "0" + m : "" + m) + "-" + (d < 10 ? "0" + d : "" + d) + " " + (h < 10 ? "0" + h : "" + h) + ":" + (mi < 10 ? "0" + mi : "" + mi) + ":" + (s < 10 ? "0" + s : "" + s);
};
HxOverrides.strDate = function(s) {
	switch(s.length) {
	case 8:
		var k = s.split(":");
		var d = new Date();
		d["setTime"](0);
		d["setUTCHours"](k[0]);
		d["setUTCMinutes"](k[1]);
		d["setUTCSeconds"](k[2]);
		return d;
	case 10:
		var k = s.split("-");
		return new Date(k[0],k[1] - 1,k[2],0,0,0);
	case 19:
		var k = s.split(" ");
		var y = k[0].split("-");
		var t = k[1].split(":");
		return new Date(y[0],y[1] - 1,y[2],t[0],t[1],t[2]);
	default:
		throw haxe_Exception.thrown("Invalid date format : " + s);
	}
};
HxOverrides.cca = function(s,index) {
	var x = s.charCodeAt(index);
	if(x != x) {
		return undefined;
	}
	return x;
};
HxOverrides.substr = function(s,pos,len) {
	if(len == null) {
		len = s.length;
	} else if(len < 0) {
		if(pos == 0) {
			len = s.length + len;
		} else {
			return "";
		}
	}
	return s.substr(pos,len);
};
HxOverrides.remove = function(a,obj) {
	var i = a.indexOf(obj);
	if(i == -1) {
		return false;
	}
	a.splice(i,1);
	return true;
};
HxOverrides.now = function() {
	return Date.now();
};
var Lambda = function() { };
Lambda.__name__ = true;
Lambda.exists = function(it,f) {
	var x = $getIterator(it);
	while(x.hasNext()) if(f(x.next())) {
		return true;
	}
	return false;
};
Lambda.find = function(it,f) {
	var v = $getIterator(it);
	while(v.hasNext()) {
		var v1 = v.next();
		if(f(v1)) {
			return v1;
		}
	}
	return null;
};
var haxe_ds_StringMap = function() {
	this.h = Object.create(null);
};
haxe_ds_StringMap.__name__ = true;
var Lang = function() { };
Lang.__name__ = true;
Lang.request = function(path,callback) {
	var http = new haxe_http_HttpJs(path);
	http.onData = callback;
	http.request();
};
Lang.init = function(folderPath,callback) {
	var _this = Lang.ids;
	var _g = [];
	var _g1 = 0;
	while(_g1 < _this.length) {
		var v = _this[_g1];
		++_g1;
		if(v == Lang.lang || v == "en") {
			_g.push(v);
		}
	}
	Lang.ids = _g;
	Lang.langs.h = Object.create(null);
	var count = 0;
	var _g = 0;
	var _g1 = Lang.ids;
	while(_g < _g1.length) {
		var name = [_g1[_g]];
		++_g;
		Lang.request("" + folderPath + "/" + name[0] + ".json",(function(name) {
			return function(data) {
				var data1 = JSON.parse(data);
				var lang = new haxe_ds_StringMap();
				var _g = 0;
				var _g1 = Reflect.fields(data1);
				while(_g < _g1.length) {
					var key = _g1[_g];
					++_g;
					lang.h[key] = Reflect.field(data1,key);
				}
				var id = haxe_io_Path.withoutExtension(name[0]);
				Lang.langs.h[id] = lang;
				count += 1;
				if(count == Lang.ids.length && callback != null) {
					callback();
				}
			};
		})(name));
	}
};
Lang.get = function(key) {
	if(Lang.langs.h[Lang.lang] == null) {
		Lang.lang = "en";
	}
	var text = Lang.langs.h[Lang.lang].h[key];
	if(text == null) {
		return key;
	} else {
		return text;
	}
};
Math.__name__ = true;
var PathTools = function() { };
PathTools.__name__ = true;
PathTools.urlExtension = function(url) {
	return StringTools.trim(haxe_io_Path.extension(new EReg("[#?]","").split(url)[0])).toLowerCase();
};
var Reflect = function() { };
Reflect.__name__ = true;
Reflect.field = function(o,field) {
	try {
		return o[field];
	} catch( _g ) {
		return null;
	}
};
Reflect.fields = function(o) {
	var a = [];
	if(o != null) {
		var hasOwnProperty = Object.prototype.hasOwnProperty;
		for( var f in o ) {
		if(f != "__id__" && f != "hx__closures__" && hasOwnProperty.call(o,f)) {
			a.push(f);
		}
		}
	}
	return a;
};
Reflect.isFunction = function(f) {
	if(typeof(f) == "function") {
		return !(f.__name__ || f.__ename__);
	} else {
		return false;
	}
};
Reflect.compareMethods = function(f1,f2) {
	if(f1 == f2) {
		return true;
	}
	if(!Reflect.isFunction(f1) || !Reflect.isFunction(f2)) {
		return false;
	}
	if(f1.scope == f2.scope && f1.method == f2.method) {
		return f1.method != null;
	} else {
		return false;
	}
};
Reflect.copy = function(o) {
	if(o == null) {
		return null;
	}
	var o2 = { };
	var _g = 0;
	var _g1 = Reflect.fields(o);
	while(_g < _g1.length) {
		var f = _g1[_g];
		++_g;
		o2[f] = Reflect.field(o,f);
	}
	return o2;
};
var Std = function() { };
Std.__name__ = true;
Std.string = function(s) {
	return js_Boot.__string_rec(s,"");
};
Std.parseInt = function(x) {
	if(x != null) {
		var _g = 0;
		var _g1 = x.length;
		while(_g < _g1) {
			var i = _g++;
			var c = x.charCodeAt(i);
			if(c <= 8 || c >= 14 && c != 32 && c != 45) {
				var nc = x.charCodeAt(i + 1);
				var v = parseInt(x,nc == 120 || nc == 88 ? 16 : 10);
				if(isNaN(v)) {
					return null;
				} else {
					return v;
				}
			}
		}
	}
	return null;
};
var StringTools = function() { };
StringTools.__name__ = true;
StringTools.htmlEscape = function(s,quotes) {
	var buf_b = "";
	var _g_offset = 0;
	var _g_s = s;
	while(_g_offset < _g_s.length) {
		var s = _g_s;
		var index = _g_offset++;
		var c = s.charCodeAt(index);
		if(c >= 55296 && c <= 56319) {
			c = c - 55232 << 10 | s.charCodeAt(index + 1) & 1023;
		}
		var c1 = c;
		if(c1 >= 65536) {
			++_g_offset;
		}
		var code = c1;
		switch(code) {
		case 34:
			if(quotes) {
				buf_b += "&quot;";
			} else {
				buf_b += String.fromCodePoint(code);
			}
			break;
		case 38:
			buf_b += "&amp;";
			break;
		case 39:
			if(quotes) {
				buf_b += "&#039;";
			} else {
				buf_b += String.fromCodePoint(code);
			}
			break;
		case 60:
			buf_b += "&lt;";
			break;
		case 62:
			buf_b += "&gt;";
			break;
		default:
			buf_b += String.fromCodePoint(code);
		}
	}
	return buf_b;
};
StringTools.startsWith = function(s,start) {
	if(s.length >= start.length) {
		return s.lastIndexOf(start,0) == 0;
	} else {
		return false;
	}
};
StringTools.endsWith = function(s,end) {
	var elen = end.length;
	var slen = s.length;
	if(slen >= elen) {
		return s.indexOf(end,slen - elen) == slen - elen;
	} else {
		return false;
	}
};
StringTools.isSpace = function(s,pos) {
	var c = HxOverrides.cca(s,pos);
	if(!(c > 8 && c < 14)) {
		return c == 32;
	} else {
		return true;
	}
};
StringTools.ltrim = function(s) {
	var l = s.length;
	var r = 0;
	while(r < l && StringTools.isSpace(s,r)) ++r;
	if(r > 0) {
		return HxOverrides.substr(s,r,l - r);
	} else {
		return s;
	}
};
StringTools.rtrim = function(s) {
	var l = s.length;
	var r = 0;
	while(r < l && StringTools.isSpace(s,l - r - 1)) ++r;
	if(r > 0) {
		return HxOverrides.substr(s,0,l - r);
	} else {
		return s;
	}
};
StringTools.trim = function(s) {
	return StringTools.ltrim(StringTools.rtrim(s));
};
StringTools.lpad = function(s,c,l) {
	if(c.length <= 0) {
		return s;
	}
	var buf_b = "";
	l -= s.length;
	while(buf_b.length < l) buf_b += c == null ? "null" : "" + c;
	buf_b += s == null ? "null" : "" + s;
	return buf_b;
};
StringTools.replace = function(s,sub,by) {
	return s.split(sub).join(by);
};
StringTools.hex = function(n,digits) {
	var s = "";
	while(true) {
		s = "0123456789ABCDEF".charAt(n & 15) + s;
		n >>>= 4;
		if(!(n > 0)) {
			break;
		}
	}
	if(digits != null) {
		while(s.length < digits) s = "0" + s;
	}
	return s;
};
var VideoList = function() {
	this.items = [];
	this.pos = 0;
};
VideoList.__name__ = true;
VideoList.prototype = {
	setPos: function(i) {
		if(i < 0 || i > this.items.length - 1) {
			i = 0;
		}
		this.pos = i;
	}
	,findIndex: function(f) {
		var i = 0;
		var _g = 0;
		var _g1 = this.items;
		while(_g < _g1.length) {
			if(f(_g1[_g++])) {
				return i;
			}
			++i;
		}
		return -1;
	}
	,addItem: function(item,atEnd) {
		if(atEnd) {
			this.items.push(item);
		} else {
			this.items.splice(this.pos + 1,0,item);
		}
	}
	,setNextItem: function(nextPos) {
		var next = this.items[nextPos];
		HxOverrides.remove(this.items,next);
		if(nextPos < this.pos) {
			this.pos--;
		}
		this.items.splice(this.pos + 1,0,next);
	}
	,toggleItemType: function(pos) {
		this.items[pos].isTemp = !this.items[pos].isTemp;
	}
	,removeItem: function(index) {
		if(index < this.pos) {
			this.pos--;
		}
		HxOverrides.remove(this.items,this.items[index]);
		if(this.pos >= this.items.length) {
			this.pos = 0;
		}
	}
	,skipItem: function() {
		var item = this.items[this.pos];
		if(!item.isTemp) {
			this.pos++;
		} else {
			HxOverrides.remove(this.items,item);
		}
		if(this.pos >= this.items.length) {
			this.pos = 0;
		}
	}
};
var client_Buttons = function() { };
client_Buttons.__name__ = true;
client_Buttons.init = function(main) {
	client_Buttons.settings = main.settings;
	if(client_Buttons.settings.isSwapped) {
		client_Buttons.swapPlayerAndChat();
	}
	client_Buttons.initSplit();
	client_Buttons.setSplitSize(client_Buttons.settings.chatSize);
	client_Buttons.initChatInput(main);
	var passIcon = window.document.querySelector("#guestpass_icon");
	passIcon.onclick = function(e) {
		var icon = passIcon.firstElementChild;
		var isOpen = icon.getAttribute("name") == "eye-off";
		var pass = window.document.querySelector("#guestpass");
		if(isOpen) {
			pass.type = "password";
			icon.setAttribute("name","eye");
		} else {
			pass.type = "text";
			icon.setAttribute("name","eye-off");
		}
	};
	var smilesBtn = window.document.querySelector("#smilesbtn");
	smilesBtn.onclick = function(e) {
		var smilesWrap = window.document.querySelector("#smileswrap");
		if(smilesWrap.children.length == 0) {
			return;
		}
		if(smilesBtn.classList.toggle("active")) {
			smilesWrap.style.display = "grid";
		} else {
			smilesWrap.style.display = "none";
		}
		if(smilesWrap.firstElementChild.dataset.src == null) {
			return;
		}
		var _g = 0;
		var _g1 = smilesWrap.children;
		while(_g < _g1.length) {
			var child = _g1[_g];
			++_g;
			child.src = child.dataset.src;
			child.removeAttribute("data-src");
		}
	};
	window.document.querySelector("#clearchatbtn").onclick = function(e) {
		if((main.personal.group & 8) != 0) {
			main.send({ type : "ClearChat"});
		}
	};
	var userList = window.document.querySelector("#userlist");
	userList.onclick = function(e) {
		if((main.personal.group & 8) == 0) {
			return;
		}
		var el = e.target;
		if(userList == el) {
			return;
		}
		if(!el.classList.contains("userlist_item")) {
			el = el.parentElement;
		}
		var name = "";
		if(el.children.length == 1) {
			name = el.lastElementChild.innerText;
		}
		main.send({ type : "SetLeader", setLeader : { clientName : name}});
	};
	var userlistToggle = window.document.querySelector("#userlisttoggle");
	userlistToggle.onclick = function(e) {
		var icon = userlistToggle.firstElementChild;
		var isHidden = icon.getAttribute("name") == "chevron-forward";
		var style = window.document.querySelector("#userlist").style;
		if(isHidden) {
			style.display = "block";
			icon.setAttribute("name","chevron-down");
		} else {
			style.display = "none";
			icon.setAttribute("name","chevron-forward");
		}
		client_Buttons.settings.isUserListHidden = !isHidden;
		client_Settings.write(client_Buttons.settings);
	};
	window.document.querySelector("#usercount").onclick = userlistToggle.onclick;
	if(client_Buttons.settings.isUserListHidden) {
		userlistToggle.onclick();
	}
	var toggleSynch = window.document.querySelector("#togglesynch");
	toggleSynch.onclick = function(e) {
		var icon = toggleSynch.firstElementChild;
		if(main.isSyncActive) {
			if(!window.confirm(Lang.get("toggleSynchConfirm"))) {
				return;
			}
			main.isSyncActive = false;
			icon.style.color = "rgba(238, 72, 67, 0.75)";
			icon.setAttribute("name","pause");
		} else {
			main.isSyncActive = true;
			icon.style.color = "";
			icon.setAttribute("name","play");
			main.send({ type : "UpdatePlaylist"});
		}
	};
	window.document.querySelector("#mediarefresh").onclick = function(e) {
		main.refreshPlayer();
	};
	window.document.querySelector("#fullscreenbtn").onclick = function(e) {
		if((client_Utils.isTouch() || main.isVerbose()) && !client_Utils.hasFullscreen()) {
			return client_Utils.requestFullscreen(window.document.documentElement);
		} else {
			return client_Utils.requestFullscreen(window.document.querySelector("#ytapiplayer"));
		}
	};
	client_Buttons.initPageFullscreen();
	var getPlaylist = window.document.querySelector("#getplaylist");
	getPlaylist.onclick = function(e) {
		client_Utils.copyToClipboard(main.getPlaylistLinks().join(","));
		var icon = getPlaylist.firstElementChild;
		icon.setAttribute("name","checkmark");
		return haxe_Timer.delay(function() {
			icon.setAttribute("name","link");
		},2000);
	};
	window.document.querySelector("#clearplaylist").onclick = function(e) {
		if(!window.confirm(Lang.get("clearPlaylistConfirm"))) {
			return;
		}
		main.send({ type : "ClearPlaylist"});
	};
	window.document.querySelector("#shuffleplaylist").onclick = function(e) {
		if(!window.confirm(Lang.get("shufflePlaylistConfirm"))) {
			return;
		}
		main.send({ type : "ShufflePlaylist"});
	};
	window.document.querySelector("#lockplaylist").onclick = function(e) {
		if(!main.hasPermission("lockPlaylist")) {
			return;
		}
		if(main.isPlaylistOpen) {
			if(!window.confirm(Lang.get("lockPlaylistConfirm"))) {
				return;
			}
		}
		main.send({ type : "TogglePlaylistLock"});
	};
	var showMediaUrl = window.document.querySelector("#showmediaurl");
	showMediaUrl.onclick = function(e) {
		client_Buttons.showPlayerGroup(showMediaUrl);
	};
	var showCustomEmbed = window.document.querySelector("#showcustomembed");
	showCustomEmbed.onclick = function(e) {
		client_Buttons.showPlayerGroup(showCustomEmbed);
	};
	var mediaUrl = window.document.querySelector("#mediaurl");
	mediaUrl.oninput = function() {
		var value = mediaUrl.value;
		var isRawSingleVideo = value != "" && main.isRawPlayerLink(value) && main.isSingleVideoLink(value);
		window.document.querySelector("#mediatitleblock").style.display = isRawSingleVideo ? "" : "none";
		return window.document.querySelector("#subsurlblock").style.display = isRawSingleVideo ? "" : "none";
	};
	mediaUrl.onfocus = mediaUrl.oninput;
	window.document.querySelector("#insert_template").onclick = function(e) {
		mediaUrl.value = main.getTemplateUrl();
		mediaUrl.focus();
	};
	var showOptions = window.document.querySelector("#showoptions");
	showOptions.onclick = function(e) {
		return client_Buttons.toggleGroup(showOptions);
	};
	window.document.querySelector("#exitBtn").onclick = function(e) {
		if((main.personal.group & 2) != 0) {
			main.send({ type : "Logout"});
		} else {
			window.document.querySelector("#guestname").focus();
		}
		return client_Buttons.toggleGroup(showOptions);
	};
	window.document.querySelector("#swapLayoutBtn").onclick = function(e) {
		client_Buttons.swapPlayerAndChat();
		client_Settings.write(client_Buttons.settings);
	};
};
client_Buttons.showPlayerGroup = function(el) {
	var groups = window.document.querySelectorAll("[data-target]");
	var _g = 0;
	while(_g < groups.length) {
		var group = groups[_g];
		++_g;
		if(el == group) {
			continue;
		}
		if(group.classList.contains("collapsed")) {
			continue;
		}
		client_Buttons.toggleGroup(group);
	}
	client_Buttons.toggleGroup(el);
};
client_Buttons.toggleGroup = function(el) {
	el.classList.toggle("collapsed");
	var id = el.dataset.target;
	window.document.querySelector(id).classList.toggle("collapse");
	return el.classList.toggle("active");
};
client_Buttons.swapPlayerAndChat = function() {
	client_Buttons.settings.isSwapped = window.document.querySelector("body").classList.toggle("swap");
	var sizes = window.document.body.style.gridTemplateColumns.split(" ");
	sizes.reverse();
	window.document.body.style.gridTemplateColumns = sizes.join(" ");
};
client_Buttons.initSplit = function() {
	if(client_Buttons.split != null) {
		client_Buttons.split.destroy();
	}
	client_Buttons.split = new Split({ columnGutters : [{ element : window.document.querySelector(".gutter"), track : 1}], minSize : 200, snapOffset : 0, onDragEnd : client_Buttons.saveSplitSize});
};
client_Buttons.setSplitSize = function(chatSize) {
	if(chatSize < 200) {
		return;
	}
	var sizes = window.document.body.style.gridTemplateColumns.split(" ");
	sizes[client_Buttons.settings.isSwapped ? 0 : sizes.length - 1] = "" + chatSize + "px";
	window.document.body.style.gridTemplateColumns = sizes.join(" ");
};
client_Buttons.saveSplitSize = function() {
	var sizes = window.document.body.style.gridTemplateColumns.split(" ");
	if(client_Buttons.settings.isSwapped) {
		sizes.reverse();
	}
	var tmp = parseFloat(sizes[sizes.length - 1]);
	client_Buttons.settings.chatSize = tmp;
	client_Settings.write(client_Buttons.settings);
};
client_Buttons.initTextButtons = function(main) {
	window.document.querySelector("#synchThresholdBtn").onclick = function(e) {
		var secs = client_Buttons.settings.synchThreshold + 1;
		if(secs > 5) {
			secs = 1;
		}
		main.setSynchThreshold(secs);
		client_Buttons.updateSynchThresholdBtn();
	};
	client_Buttons.updateSynchThresholdBtn();
	window.document.querySelector("#hotkeysBtn").onclick = function(e) {
		client_Buttons.settings.hotkeysEnabled = !client_Buttons.settings.hotkeysEnabled;
		client_Settings.write(client_Buttons.settings);
		client_Buttons.updateHotkeysBtn();
	};
	client_Buttons.updateHotkeysBtn();
	var removeBtn = window.document.querySelector("#removeVideoBtn");
	removeBtn.onclick = function(e) {
		if(main.toggleVideoElement() || main.isListEmpty()) {
			return removeBtn.innerText = Lang.get("removeVideo");
		} else {
			return removeBtn.innerText = Lang.get("addVideo");
		}
	};
	window.document.querySelector("#setVideoUrlBtn").onclick = function(e) {
		var src = window.prompt(Lang.get("setVideoUrlPrompt"));
		if(StringTools.trim(src) == "") {
			main.refreshPlayer();
			return;
		}
		client_JsApi.setVideoSrc(src);
	};
	window.document.querySelector("#selectLocalVideoBtn").onclick = function(e) {
		client_Utils.browseFileUrl(function(url,name) {
			client_JsApi.setVideoSrc(url);
		});
	};
};
client_Buttons.initHotkeys = function(main,player) {
	window.document.querySelector("#mediarefresh").title += " (Alt-R)";
	window.document.querySelector("#voteskip").title += " (Alt-S)";
	window.document.querySelector("#getplaylist").title += " (Alt-C)";
	window.document.querySelector("#fullscreenbtn").title += " (Alt-F)";
	window.document.querySelector("#leader_btn").title += " (Alt-L)";
	window.onkeydown = function(e) {
		if(!client_Buttons.settings.hotkeysEnabled) {
			return;
		}
		if(client_Buttons.isElementEditable(e.target)) {
			return;
		}
		var key = e.keyCode;
		if(key == 8) {
			e.preventDefault();
		}
		if(!e.altKey) {
			return;
		}
		switch(key) {
		case 67:
			window.document.querySelector("#getplaylist").onclick();
			break;
		case 70:
			window.document.querySelector("#fullscreenbtn").onclick();
			break;
		case 76:
			main.toggleLeader();
			break;
		case 80:
			if((main.personal.group & 4) == 0) {
				client_JsApi.once("SetLeader",function(event) {
					if(event.setLeader.clientName == main.personal.name) {
						player.pause();
					}
				});
			}
			main.toggleLeader();
			break;
		case 82:
			window.document.querySelector("#mediarefresh").onclick();
			break;
		case 83:
			window.document.querySelector("#voteskip").onclick();
			break;
		default:
			return;
		}
		e.preventDefault();
	};
};
client_Buttons.isElementEditable = function(target) {
	if(target == null) {
		return false;
	}
	if(target.isContentEditable) {
		return true;
	}
	var tagName = target.tagName;
	if(tagName == "INPUT" || tagName == "TEXTAREA") {
		return true;
	}
	return false;
};
client_Buttons.updateSynchThresholdBtn = function() {
	var tmp = "" + Lang.get("synchThreshold") + ": " + client_Buttons.settings.synchThreshold;
	window.document.querySelector("#synchThresholdBtn").innerText = tmp + "s";
};
client_Buttons.updateHotkeysBtn = function() {
	var text = Lang.get("hotkeys");
	var state = client_Buttons.settings.hotkeysEnabled ? Lang.get("on") : Lang.get("off");
	window.document.querySelector("#hotkeysBtn").innerText = "" + text + ": " + state;
};
client_Buttons.initChatInput = function(main) {
	var guestName = window.document.querySelector("#guestname");
	guestName.onkeydown = function(e) {
		if(e.keyCode == 13) {
			main.guestLogin(guestName.value);
			if(client_Utils.isTouch()) {
				guestName.blur();
			}
		}
	};
	var guestPass = window.document.querySelector("#guestpass");
	guestPass.onkeydown = function(e) {
		if(e.keyCode == 13) {
			main.userLogin(guestName.value,guestPass.value);
			guestPass.value = "";
			if(client_Utils.isTouch()) {
				guestPass.blur();
			}
		}
	};
	if(client_Utils.isIOS()) {
		window.document.ontouchmove = function(e) {
			return e.preventDefault();
		};
		window.document.body.style.height = "-webkit-fill-available";
		window.document.querySelector("#chat").style.height = "-webkit-fill-available";
	}
	var chatline = window.document.querySelector("#chatline");
	chatline.onfocus = function(e) {
		if(client_Utils.isIOS()) {
			var startY = window.scrollY;
			haxe_Timer.delay(function() {
				window.scrollBy(0,-(window.scrollY - startY));
				window.document.querySelector("#video").scrollTop = 0;
				main.scrollChatToEnd();
				if(window.visualViewport == null) {
					var tmp = "" + Std.string(window.innerHeight);
					window.document.querySelector("#chat").style.height = tmp + "px";
				}
			},100);
		} else if(client_Utils.isTouch()) {
			main.scrollChatToEnd();
		}
	};
	if(client_Utils.isIOS() && window.visualViewport != null) {
		window.visualViewport.addEventListener("resize",function(e) {
			var tmp = "" + Std.string(window.innerHeight);
			return window.document.querySelector("#chat").style.height = tmp + "px";
		});
	}
	chatline.onblur = function(e) {
		if(client_Utils.isIOS() && window.visualViewport == null) {
			window.document.querySelector("#chat").style.height = "-webkit-fill-available";
		}
	};
	new client_InputWithHistory(chatline,null,50,function(value) {
		if(main.handleCommands(value)) {
			return true;
		}
		main.send({ type : "Message", message : { clientName : "", text : value}});
		if(client_Utils.isTouch()) {
			chatline.blur();
		}
		return true;
	});
};
client_Buttons.initPageFullscreen = function() {
	window.document.onfullscreenchange = function(e) {
		var el = window.document.documentElement;
		if(client_Utils.hasFullscreen()) {
			if(e.target == el) {
				el.classList.add("mobile-view");
			}
		} else {
			el.classList.remove("mobile-view");
		}
	};
};
var client_InputWithHistory = function(element,history,maxItems,onEnter) {
	this.historyId = -1;
	this.element = element;
	if(history != null) {
		this.history = history;
	} else {
		this.history = [];
	}
	this.maxItems = maxItems;
	this.onEnter = onEnter;
	element.onkeydown = $bind(this,this.onKeyDown);
};
client_InputWithHistory.__name__ = true;
client_InputWithHistory.pushIfNotLast = function(arr,item) {
	var len = arr.length;
	if(len == 0 || arr[len - 1] != item) {
		arr.push(item);
	}
};
client_InputWithHistory.prototype = {
	onKeyDown: function(e) {
		switch(e.keyCode) {
		case 13:
			var value = this.element.value;
			if(value.length == 0) {
				return;
			}
			if(this.onEnter(value)) {
				client_InputWithHistory.pushIfNotLast(this.history,value);
			}
			if(this.history.length > this.maxItems) {
				this.history.shift();
			}
			this.historyId = -1;
			this.element.value = "";
			this.onInput();
			break;
		case 38:
			this.historyId--;
			if(this.historyId == -2) {
				this.historyId = this.history.length - 1;
				if(this.historyId == -1) {
					return;
				}
			} else if(this.historyId == -1) {
				this.historyId++;
			}
			this.element.value = this.history[this.historyId];
			this.onInput();
			break;
		case 40:
			if(this.historyId == -1) {
				return;
			}
			this.historyId++;
			if(this.historyId > this.history.length - 1) {
				this.historyId = -1;
				this.element.value = "";
			} else {
				this.element.value = this.history[this.historyId];
			}
			this.onInput();
			break;
		default:
		}
	}
	,onInput: function() {
		if(this.element.oninput != null) {
			this.element.oninput();
		}
	}
};
var client_JsApi = function() { };
client_JsApi.__name__ = true;
client_JsApi.init = function(main,player) {
	client_JsApi.main = main;
	client_JsApi.player = player;
	client_JsApi.initPluginsSpace();
};
client_JsApi.initPluginsSpace = function() {
	var w = window;
	if(w.synctube == null) {
		w.synctube = { };
	}
};
client_JsApi.addPlugin = $hx_exports["client"]["JsApi"]["addPlugin"] = function(id,onLoaded) {
	client_JsApi.addScriptToHead("/plugins/" + id + "/index.js",function() {
		var obj = { api : client.JsApi, id : id, path : "/plugins/" + id};
		if(window.synctube[id] == null) {
			window.console.error("Plugin \"" + id + "\" not found");
		} else {
			new synctube[id](obj);
			if(onLoaded != null) {
				onLoaded();
			}
		}
	});
};
client_JsApi.addScriptToHead = $hx_exports["client"]["JsApi"]["addScriptToHead"] = function(url,onLoaded) {
	var script = window.document.createElement("script");
	script.type = "text/javascript";
	script.onload = onLoaded;
	script.src = url;
	window.document.head.appendChild(script);
};
client_JsApi.hasScriptInHead = $hx_exports["client"]["JsApi"]["hasScriptInHead"] = function(url) {
	var _g = 0;
	var _g1 = window.document.getElementsByTagName("head")[0].children;
	while(_g < _g1.length) if(_g1[_g++].src == url) {
		return true;
	}
	return false;
};
client_JsApi.getVideoItems = $hx_exports["client"]["JsApi"]["getVideoItems"] = function() {
	var items = client_JsApi.player.getItems();
	var _g = [];
	var _g1 = 0;
	while(_g1 < items.length) _g.push(Reflect.copy(items[_g1++]));
	return _g;
};
client_JsApi.addVideoItem = $hx_exports["client"]["JsApi"]["addVideoItem"] = function(url,atEnd,isTemp,callback) {
	client_JsApi.main.addVideo(url,atEnd,isTemp,callback);
};
client_JsApi.removeVideoItem = $hx_exports["client"]["JsApi"]["removeVideoItem"] = function(url) {
	client_JsApi.main.removeVideoItem(url);
};
client_JsApi.getTime = $hx_exports["client"]["JsApi"]["getTime"] = function() {
	return client_JsApi.player.getTime();
};
client_JsApi.setTime = $hx_exports["client"]["JsApi"]["setTime"] = function(time) {
	client_JsApi.player.setTime(time);
};
client_JsApi.isLeader = $hx_exports["client"]["JsApi"]["isLeader"] = function() {
	return (client_JsApi.main.personal.group & 4) != 0;
};
client_JsApi.forceSyncNextTick = $hx_exports["client"]["JsApi"]["forceSyncNextTick"] = function(flag) {
	client_JsApi.main.forceSyncNextTick = flag;
};
client_JsApi.setVideoSrc = $hx_exports["client"]["JsApi"]["setVideoSrc"] = function(src) {
	client_JsApi.player.changeVideoSrc(src);
};
client_JsApi.getLocalIp = $hx_exports["client"]["JsApi"]["getLocalIp"] = function() {
	return client_JsApi.main.host;
};
client_JsApi.getGlobalIp = $hx_exports["client"]["JsApi"]["getGlobalIp"] = function() {
	return client_JsApi.main.globalIp;
};
client_JsApi.addSubtitleSupport = $hx_exports["client"]["JsApi"]["addSubtitleSupport"] = function(format) {
	format = StringTools.trim(format).toLowerCase();
	if(client_JsApi.subtitleFormats.indexOf(format) != -1) {
		return;
	}
	client_JsApi.subtitleFormats.push(format);
};
client_JsApi.hasSubtitleSupport = $hx_exports["client"]["JsApi"]["hasSubtitleSupport"] = function(format) {
	if(format == null) {
		return client_JsApi.subtitleFormats.length > 0;
	}
	return client_JsApi.subtitleFormats.indexOf(format) != -1;
};
client_JsApi.once = $hx_exports["client"]["JsApi"]["once"] = function(type,func) {
	client_JsApi.onceListeners.push({ type : type, func : func});
};
client_JsApi.fireOnceEvent = function(event) {
	var i = 0;
	while(i < client_JsApi.onceListeners.length) {
		var listener = client_JsApi.onceListeners[i];
		if(listener.type == event.type) {
			listener.func(event);
			HxOverrides.remove(client_JsApi.onceListeners,listener);
			continue;
		}
		++i;
	}
};
client_JsApi.notifyOnVideoChange = $hx_exports["client"]["JsApi"]["notifyOnVideoChange"] = function(func) {
	client_JsApi.videoChange.push(func);
};
client_JsApi.removeFromVideoChange = $hx_exports["client"]["JsApi"]["removeFromVideoChange"] = function(func) {
	HxOverrides.remove(client_JsApi.videoChange,func);
};
client_JsApi.fireVideoChangeEvents = function(item) {
	var _g = 0;
	var _g1 = client_JsApi.videoChange;
	while(_g < _g1.length) _g1[_g++](item);
};
client_JsApi.notifyOnVideoRemove = $hx_exports["client"]["JsApi"]["notifyOnVideoRemove"] = function(func) {
	client_JsApi.videoRemove.push(func);
};
client_JsApi.removeFromVideoRemove = $hx_exports["client"]["JsApi"]["removeFromVideoRemove"] = function(func) {
	HxOverrides.remove(client_JsApi.videoRemove,func);
};
client_JsApi.fireVideoRemoveEvents = function(item) {
	var _g = 0;
	var _g1 = client_JsApi.videoRemove;
	while(_g < _g1.length) _g1[_g++](item);
};
var client_Main = function() {
	this.matchSimpleDate = new EReg("^-?([0-9]+d)?([0-9]+h)?([0-9]+m)?([0-9]+s?)?$","");
	this.mask = new EReg("\\${([0-9]+)-([0-9]+)}","g");
	this.disabledReconnection = false;
	this.isConnected = false;
	this.personal = new Client("Unknown",0);
	this.filters = [];
	this.pageTitle = window.document.title;
	this.clients = [];
	this.isPlaylistOpen = true;
	this.globalIp = "";
	this.forceSyncNextTick = false;
	this.isSyncActive = true;
	var _gthis = this;
	this.player = new client_Player(this);
	this.host = $global.location.hostname;
	if(this.host == "") {
		this.host = "localhost";
	}
	client_Settings.init({ version : 3, name : "", hash : "", isExtendedPlayer : false, playerSize : 1, chatSize : 300, synchThreshold : 2, isSwapped : false, isUserListHidden : true, latestLinks : [], latestSubs : [], hotkeysEnabled : true},$bind(this,this.settingsPatcher));
	this.settings = client_Settings.read();
	this.initListeners();
	this.onTimeGet = new haxe_Timer(this.settings.synchThreshold * 1000);
	this.onTimeGet.run = $bind(this,this.requestTime);
	window.document.onvisibilitychange = function() {
		if(!window.document.hidden && _gthis.onBlinkTab != null) {
			window.document.title = _gthis.getPageTitle();
			_gthis.onBlinkTab.stop();
			_gthis.onBlinkTab = null;
		}
	};
	Lang.init("langs",function() {
		client_Buttons.initTextButtons(_gthis);
		client_Buttons.initHotkeys(_gthis,_gthis.player);
		_gthis.openWebSocket();
	});
	client_JsApi.init(this,this.player);
};
client_Main.__name__ = true;
client_Main.main = function() {
	new client_Main();
};
client_Main.serverMessage = function(type,text,isText) {
	if(isText == null) {
		isText = true;
	}
	var msgBuf = window.document.querySelector("#messagebuffer");
	var div = window.document.createElement("div");
	var time = HxOverrides.dateStr(new Date()).split(" ")[1];
	switch(type) {
	case 1:
		div.className = "server-msg-reconnect";
		div.textContent = Lang.get("msgConnected");
		break;
	case 2:
		div.className = "server-msg-disconnect";
		div.textContent = Lang.get("msgDisconnected");
		break;
	case 3:
		div.className = "server-whisper";
		div.textContent = time + text + " " + Lang.get("entered");
		break;
	case 4:
		div.className = "server-whisper";
		div.innerHTML = "<div class=\"head\">\n\t\t\t\t\t<div class=\"server-whisper\"></div>\n\t\t\t\t\t<span class=\"timestamp\">" + time + "</span>\n\t\t\t\t</div>";
		var textDiv = div.querySelector(".server-whisper");
		if(isText) {
			textDiv.textContent = text;
		} else {
			textDiv.innerHTML = text;
		}
		break;
	default:
	}
	msgBuf.appendChild(div);
	msgBuf.scrollTop = msgBuf.scrollHeight;
};
client_Main.prototype = {
	settingsPatcher: function(data,version) {
		switch(version) {
		case 1:
			data.hotkeysEnabled = true;
			break;
		case 2:
			data.latestSubs = [];
			break;
		case 3:
			throw haxe_Exception.thrown("skipped version " + version);
		default:
			throw haxe_Exception.thrown("skipped version " + version);
		}
		return data;
	}
	,requestTime: function() {
		if(!this.isSyncActive) {
			return;
		}
		if(this.player.isListEmpty()) {
			return;
		}
		this.send({ type : "GetTime"});
	}
	,openWebSocket: function() {
		var _gthis = this;
		var protocol = "ws:";
		if($global.location.protocol == "https:") {
			protocol = "wss:";
		}
		var port = $global.location.port;
		var colonPort = port.length > 0 ? ":" + port : port;
		var path = $global.location.pathname;
		this.ws = new WebSocket("" + protocol + "//" + this.host + colonPort + path);
		this.ws.onmessage = $bind(this,this.onMessage);
		this.ws.onopen = function() {
			client_Main.serverMessage(1);
			return _gthis.isConnected = true;
		};
		this.ws.onclose = function() {
			if(_gthis.isConnected) {
				client_Main.serverMessage(2);
			}
			_gthis.isConnected = false;
			_gthis.player.pause();
			if(_gthis.disabledReconnection) {
				return;
			}
			haxe_Timer.delay($bind(_gthis,_gthis.openWebSocket),2000);
		};
	}
	,initListeners: function() {
		var _gthis = this;
		client_Buttons.init(this);
		window.document.querySelector("#leader_btn").onclick = $bind(this,this.toggleLeader);
		window.document.querySelector("#voteskip").onclick = function(e) {
			if(client_Utils.isTouch() && !window.confirm(Lang.get("skipItemConfirm"))) {
				return;
			}
			if(_gthis.player.isListEmpty()) {
				return;
			}
			var items = _gthis.player.getItems();
			var pos = _gthis.player.getItemPos();
			_gthis.send({ type : "SkipVideo", skipVideo : { url : items[pos].url}});
		};
		window.document.querySelector("#queue_next").onclick = function(e) {
			_gthis.addVideoUrl(false);
		};
		window.document.querySelector("#queue_end").onclick = function(e) {
			_gthis.addVideoUrl(true);
		};
		new client_InputWithHistory(window.document.querySelector("#mediaurl"),this.settings.latestLinks,10,function(value) {
			_gthis.addVideoUrl(true);
			return false;
		});
		window.document.querySelector("#mediatitle").onkeydown = function(e) {
			if(e.keyCode == 13) {
				_gthis.addVideoUrl(true);
			}
		};
		new client_InputWithHistory(window.document.querySelector("#subsurl"),this.settings.latestSubs,10,function(value) {
			_gthis.addVideoUrl(true);
			return false;
		});
		window.document.querySelector("#ce_queue_next").onclick = function(e) {
			_gthis.addIframe(false);
		};
		window.document.querySelector("#ce_queue_end").onclick = function(e) {
			_gthis.addIframe(true);
		};
		window.document.querySelector("#customembed-title").onkeydown = function(e) {
			if(e.keyCode == 13) {
				_gthis.addIframe(true);
				e.preventDefault();
			}
		};
		window.document.querySelector("#customembed-content").onkeydown = window.document.querySelector("#customembed-title").onkeydown;
	}
	,hasPermission: function(permission) {
		return this.personal.hasPermission(permission,this.config.permissions);
	}
	,handleUrlMasks: function(links) {
		var _g = 0;
		while(_g < links.length) {
			var link = links[_g];
			++_g;
			if(!this.mask.match(link)) {
				continue;
			}
			var start = Std.parseInt(this.mask.matched(1));
			var end = Std.parseInt(this.mask.matched(2));
			if(Math.abs(start - end) > 100) {
				continue;
			}
			var step = end > start ? -1 : 1;
			var i = links.indexOf(link);
			HxOverrides.remove(links,link);
			while(end != start + step) {
				var x = link.replace(this.mask.r,"" + end);
				links.splice(i,0,x);
				end += step;
			}
		}
	}
	,addVideoUrl: function(atEnd) {
		var mediaUrl = window.document.querySelector("#mediaurl");
		var subsUrl = window.document.querySelector("#subsurl");
		var isTemp = window.document.querySelector("#addfromurl").querySelector(".add-temp").checked;
		var url = mediaUrl.value;
		var subs = subsUrl.value;
		if(url.length == 0) {
			return;
		}
		mediaUrl.value = "";
		client_InputWithHistory.pushIfNotLast(this.settings.latestLinks,url);
		if(subs.length != 0) {
			client_InputWithHistory.pushIfNotLast(this.settings.latestSubs,subs);
		}
		client_Settings.write(this.settings);
		var _this_r = new RegExp(", ?(https?)","g".split("u").join(""));
		var links = url.replace(_this_r,"|$1").split("|");
		this.handleUrlMasks(links);
		if(!atEnd) {
			this.sortItemsForQueueNext(links);
		}
		this.addVideoArray(links,atEnd,isTemp);
	}
	,isRawPlayerLink: function(url) {
		return this.player.isRawPlayerLink(url);
	}
	,isSingleVideoLink: function(url) {
		if(new EReg(", ?(https?)","g").match(url)) {
			return false;
		}
		if(this.mask.match(url)) {
			return false;
		}
		return true;
	}
	,sortItemsForQueueNext: function(items) {
		if(items.length == 0) {
			return;
		}
		var first = null;
		if(this.player.isListEmpty()) {
			first = items.shift();
		}
		items.reverse();
		if(first != null) {
			items.unshift(first);
		}
	}
	,addVideoArray: function(links,atEnd,isTemp) {
		var _gthis = this;
		if(links.length == 0) {
			return;
		}
		this.addVideo(links.shift(),atEnd,isTemp,function() {
			_gthis.addVideoArray(links,atEnd,isTemp);
		});
	}
	,addVideo: function(url,atEnd,isTemp,callback) {
		var _gthis = this;
		var protocol = $global.location.protocol;
		if(StringTools.startsWith(url,"/")) {
			url = "" + protocol + "//" + $global.location.hostname + ":" + $global.location.port + url;
		}
		if(!StringTools.startsWith(url,"http")) {
			url = "" + protocol + "//" + url;
		}
		this.player.getVideoData({ url : url, atEnd : atEnd},function(data) {
			if(data.duration == 0) {
				client_Main.serverMessage(4,Lang.get("addVideoError"));
				return;
			}
			if(data.title == null) {
				data.title = Lang.get("rawVideo");
			}
			if(data.url == null) {
				data.url = url;
			}
			_gthis.send({ type : "AddVideo", addVideo : { item : { url : data.url, title : data.title, author : _gthis.personal.name, duration : data.duration, isTemp : isTemp, subs : data.subs, isIframe : data.isIframe == true}, atEnd : atEnd}});
			if(callback != null) {
				callback();
			}
		});
	}
	,addIframe: function(atEnd) {
		var _gthis = this;
		var iframeCode = window.document.querySelector("#customembed-content");
		var iframe = iframeCode.value;
		if(iframe.length == 0) {
			return;
		}
		iframeCode.value = "";
		var mediaTitle = window.document.querySelector("#customembed-title");
		var title = mediaTitle.value;
		mediaTitle.value = "";
		var isTemp = window.document.querySelector("#customembed").querySelector(".add-temp").checked;
		this.player.getIframeData({ url : iframe, atEnd : atEnd},function(data) {
			if(data.duration == 0) {
				client_Main.serverMessage(4,Lang.get("addVideoError"));
				return;
			}
			if(title.length > 0) {
				data.title = title;
			}
			if(data.title == null) {
				data.title = "Custom Media";
			}
			if(data.url == null) {
				data.url = iframe;
			}
			_gthis.send({ type : "AddVideo", addVideo : { item : { url : data.url, title : data.title, author : _gthis.personal.name, duration : data.duration, isTemp : isTemp, isIframe : true}, atEnd : atEnd}});
		});
	}
	,removeVideoItem: function(url) {
		this.send({ type : "RemoveVideo", removeVideo : { url : url}});
	}
	,toggleVideoElement: function() {
		if(this.player.hasVideo()) {
			this.player.removeVideo();
		} else if(!this.player.isListEmpty()) {
			this.player.setVideo(this.player.getItemPos());
		}
		return this.player.hasVideo();
	}
	,isListEmpty: function() {
		return this.player.isListEmpty();
	}
	,refreshPlayer: function() {
		this.player.refresh();
	}
	,getPlaylistLinks: function() {
		var items = this.player.getItems();
		var _g = [];
		var _g1 = 0;
		while(_g1 < items.length) _g.push(items[_g1++].url);
		return _g;
	}
	,tryLocalIp: function(url) {
		if(this.host == this.globalIp) {
			return url;
		}
		return StringTools.replace(url,this.globalIp,this.host);
	}
	,onMessage: function(e) {
		var data = JSON.parse(e.data);
		if(this.config != null && this.config.isVerbose) {
			var t = data.type;
			haxe_Log.trace("Event: " + data.type,{ fileName : "src/client/Main.hx", lineNumber : 384, className : "client.Main", methodName : "onMessage", customParams : [Reflect.field(data,t.charAt(0).toLowerCase() + HxOverrides.substr(t,1,null))]});
		}
		client_JsApi.fireOnceEvent(data);
		switch(data.type) {
		case "AddVideo":
			this.player.addVideoItem(data.addVideo.item,data.addVideo.atEnd);
			if(this.player.itemsLength() == 1) {
				this.player.setVideo(0);
			}
			break;
		case "BanClient":
			break;
		case "ClearChat":
			this.clearChat();
			break;
		case "ClearPlaylist":
			this.player.clearItems();
			if(this.player.isListEmpty()) {
				this.player.pause();
			}
			break;
		case "Connected":
			this.onConnected(data);
			this.onTimeGet.run();
			break;
		case "Disconnected":
			break;
		case "Dump":
			client_Utils.saveFile("dump.json","application/json",data.dump.data);
			break;
		case "Flashback":
			break;
		case "GetTime":
			if(data.getTime.paused == null) {
				data.getTime.paused = false;
			}
			if(data.getTime.rate == null) {
				data.getTime.rate = 1;
			}
			if(this.player.getPlaybackRate() != data.getTime.rate) {
				this.player.setPlaybackRate(data.getTime.rate);
			}
			var synchThreshold = this.settings.synchThreshold;
			var newTime = data.getTime.time;
			var time = this.player.getTime();
			if((this.personal.group & 4) != 0 && !this.forceSyncNextTick) {
				if(Math.abs(time - newTime) < synchThreshold) {
					return;
				}
				this.player.setTime(time,false);
				return;
			}
			if(this.player.isVideoLoaded()) {
				this.forceSyncNextTick = false;
			}
			if(this.player.getDuration() <= this.player.getTime() + synchThreshold) {
				return;
			}
			if(!data.getTime.paused) {
				this.player.play();
			} else {
				this.player.pause();
			}
			this.player.setPauseIndicator(!data.getTime.paused);
			if(Math.abs(time - newTime) < synchThreshold) {
				return;
			}
			if(!data.getTime.paused) {
				this.player.setTime(newTime + 0.5);
			} else {
				this.player.setTime(newTime);
			}
			break;
		case "KickClient":
			this.disabledReconnection = true;
			this.ws.close();
			break;
		case "Login":
			this.onLogin(data.login.clients,data.login.clientName);
			break;
		case "LoginError":
			this.settings.name = "";
			this.settings.hash = "";
			client_Settings.write(this.settings);
			this.showGuestLoginPanel();
			break;
		case "Logout":
			this.updateClients(data.logout.clients);
			this.personal = new Client(data.logout.clientName,0);
			this.onUserGroupChanged();
			this.showGuestLoginPanel();
			this.settings.name = "";
			this.settings.hash = "";
			client_Settings.write(this.settings);
			break;
		case "Message":
			this.addMessage(data.message.clientName,data.message.text);
			break;
		case "PasswordRequest":
			this.showGuestPasswordPanel();
			break;
		case "Pause":
			this.player.setPauseIndicator(false);
			if((this.personal.group & 4) != 0) {
				return;
			}
			this.player.pause();
			this.player.setTime(data.pause.time);
			break;
		case "Play":
			this.player.setPauseIndicator(true);
			if((this.personal.group & 4) != 0) {
				return;
			}
			var synchThreshold = this.settings.synchThreshold;
			var newTime = data.play.time;
			if(Math.abs(this.player.getTime() - newTime) >= synchThreshold) {
				this.player.setTime(newTime);
			}
			this.player.play();
			break;
		case "PlayItem":
			this.player.setVideo(data.playItem.pos);
			break;
		case "RemoveVideo":
			this.player.removeItem(data.removeVideo.url);
			if(this.player.isListEmpty()) {
				this.player.pause();
			}
			break;
		case "Rewind":
			this.player.setTime(data.rewind.time + 0.5);
			break;
		case "ServerMessage":
			var id = data.serverMessage.textId;
			client_Main.serverMessage(4,id == "usernameError" ? StringTools.replace(Lang.get(id),"$MAX","" + this.config.maxLoginLength) : Lang.get(id));
			break;
		case "SetLeader":
			ClientTools.setLeader(this.clients,data.setLeader.clientName);
			this.updateUserList();
			this.setLeaderButton((this.personal.group & 4) != 0);
			if((this.personal.group & 4) != 0) {
				this.player.onSetTime();
			}
			break;
		case "SetNextItem":
			this.player.setNextItem(data.setNextItem.pos);
			break;
		case "SetRate":
			if((this.personal.group & 4) != 0) {
				return;
			}
			this.player.setPlaybackRate(data.setRate.rate);
			break;
		case "SetTime":
			var synchThreshold = this.settings.synchThreshold;
			var newTime = data.setTime.time;
			if(Math.abs(this.player.getTime() - newTime) < synchThreshold) {
				return;
			}
			this.player.setTime(newTime);
			break;
		case "ShufflePlaylist":
			break;
		case "SkipVideo":
			this.player.skipItem(data.skipVideo.url);
			if(this.player.isListEmpty()) {
				this.player.pause();
			}
			break;
		case "ToggleItemType":
			this.player.toggleItemType(data.toggleItemType.pos);
			break;
		case "TogglePlaylistLock":
			this.setPlaylistLock(data.togglePlaylistLock.isOpen);
			break;
		case "UpdateClients":
			this.updateClients(data.updateClients.clients);
			var oldGroup = this.personal.group;
			this.personal = ClientTools.getByName(this.clients,this.personal.name,this.personal);
			if(this.personal.group != oldGroup) {
				this.onUserGroupChanged();
			}
			break;
		case "UpdatePlaylist":
			this.player.setItems(data.updatePlaylist.videoList);
			break;
		case "VideoLoaded":
			this.player.setTime(0);
			this.player.play();
			if((this.personal.group & 4) != 0 && !this.player.isVideoLoaded()) {
				this.forceSyncNextTick = true;
			}
			break;
		}
	}
	,onConnected: function(data) {
		var connected = data.connected;
		this.globalIp = connected.globalIp;
		this.setConfig(connected.config);
		if(connected.isUnknownClient) {
			this.updateClients(connected.clients);
			this.personal = ClientTools.getByName(this.clients,connected.clientName,this.personal);
			this.showGuestLoginPanel();
		} else {
			this.onLogin(connected.clients,connected.clientName);
		}
		var guestName = window.document.querySelector("#guestname");
		var name = this.settings.name;
		if(name.length == 0) {
			name = guestName.value;
		}
		var hash = this.settings.hash;
		if(hash.length > 0) {
			this.loginRequest(name,hash);
		} else {
			this.guestLogin(name);
		}
		this.setLeaderButton((this.personal.group & 4) != 0);
		this.setPlaylistLock(connected.isPlaylistOpen);
		this.clearChat();
		client_Main.serverMessage(1);
		var _g = 0;
		var _g1 = connected.history;
		while(_g < _g1.length) {
			var message = _g1[_g];
			++_g;
			this.addMessage(message.name,message.text,message.time);
		}
		this.player.setItems(connected.videoList,connected.itemPos);
		this.onUserGroupChanged();
	}
	,onUserGroupChanged: function() {
		var button = window.document.querySelector("#queue_next");
		if(this.personal.hasPermission("changeOrder",this.config.permissions)) {
			button.disabled = false;
		} else {
			button.disabled = true;
		}
		var adminMenu = window.document.querySelector("#adminMenu");
		if((this.personal.group & 8) != 0) {
			adminMenu.style.display = "block";
		} else {
			adminMenu.style.display = "none";
		}
	}
	,guestLogin: function(name) {
		if(name.length == 0) {
			return;
		}
		this.send({ type : "Login", login : { clientName : name}});
		this.settings.name = name;
		client_Settings.write(this.settings);
	}
	,userLogin: function(name,password) {
		if(this.config.salt == null) {
			return;
		}
		if(password.length == 0) {
			return;
		}
		if(name.length == 0) {
			return;
		}
		var hash = haxe_crypto_Sha256.encode(password + this.config.salt);
		this.loginRequest(name,hash);
		this.settings.hash = hash;
		client_Settings.write(this.settings);
	}
	,loginRequest: function(name,hash) {
		this.send({ type : "Login", login : { clientName : name, passHash : hash}});
	}
	,setConfig: function(config) {
		this.config = config;
		if(client_Utils.isTouch()) {
			config.requestLeaderOnPause = false;
		}
		this.pageTitle = config.channelName;
		window.document.querySelector("#guestname").maxLength = config.maxLoginLength;
		window.document.querySelector("#chatline").maxLength = config.maxMessageLength;
		this.filters.length = 0;
		var _g = 0;
		var _g1 = config.filters;
		while(_g < _g1.length) {
			var filter = _g1[_g];
			++_g;
			this.filters.push({ regex : new EReg(filter.regex,filter.flags), replace : filter.replace});
		}
		var _g = 0;
		var _g1 = config.emotes;
		while(_g < _g1.length) {
			var emote = _g1[_g];
			++_g;
			var tag = StringTools.endsWith(emote.image,"mp4") ? "video autoplay=\"\" loop=\"\" muted=\"\"" : "img";
			this.filters.push({ regex : new EReg("(^| )" + this.escapeRegExp(emote.name) + "(?!\\S)","g"), replace : "$1<" + tag + " class=\"channel-emote\" src=\"" + emote.image + "\" title=\"" + emote.name + "\"/>"});
		}
		window.document.querySelector("#smilesbtn").classList.remove("active");
		var smilesWrap = window.document.querySelector("#smileswrap");
		smilesWrap.style.display = "none";
		smilesWrap.onclick = function(e) {
			var el = e.target;
			if(el == smilesWrap) {
				return;
			}
			var form = window.document.querySelector("#chatline");
			form.value += " " + el.title;
			form.focus();
		};
		smilesWrap.textContent = "";
		var _g = 0;
		var _g1 = config.emotes;
		while(_g < _g1.length) {
			var emote = _g1[_g];
			++_g;
			var tag = StringTools.endsWith(emote.image,"mp4") ? "video" : "img";
			var el = window.document.createElement(tag);
			el.className = "smile-preview";
			el.dataset.src = emote.image;
			el.title = emote.name;
			smilesWrap.appendChild(el);
		}
	}
	,onLogin: function(data,clientName) {
		this.updateClients(data);
		var newPersonal = ClientTools.getByName(this.clients,clientName);
		if(newPersonal == null) {
			return;
		}
		this.personal = newPersonal;
		this.onUserGroupChanged();
		this.hideGuestLoginPanel();
	}
	,showGuestLoginPanel: function() {
		window.document.querySelector("#guestlogin").style.display = "flex";
		window.document.querySelector("#guestpassword").style.display = "none";
		window.document.querySelector("#chatbox").style.display = "none";
		window.document.querySelector("#exitBtn").textContent = Lang.get("login");
	}
	,hideGuestLoginPanel: function() {
		window.document.querySelector("#guestlogin").style.display = "none";
		window.document.querySelector("#guestpassword").style.display = "none";
		window.document.querySelector("#chatbox").style.display = "flex";
		window.document.querySelector("#exitBtn").textContent = Lang.get("exit");
	}
	,showGuestPasswordPanel: function() {
		window.document.querySelector("#guestlogin").style.display = "none";
		window.document.querySelector("#chatbox").style.display = "none";
		window.document.querySelector("#guestpassword").style.display = "flex";
		window.document.querySelector("#guestpass").type = "password";
		window.document.querySelector("#guestpass_icon").setAttribute("name","eye");
	}
	,updateClients: function(newClients) {
		this.clients.length = 0;
		var _g = 0;
		while(_g < newClients.length) this.clients.push(Client.fromData(newClients[_g++]));
		this.updateUserList();
	}
	,send: function(data) {
		if(!this.isConnected) {
			return;
		}
		this.ws.send(JSON.stringify(data));
	}
	,updateUserList: function() {
		window.document.querySelector("#usercount").textContent = this.clients.length + " " + Lang.get("online");
		window.document.title = this.getPageTitle();
		var list_b = "";
		var _g = 0;
		var _g1 = this.clients;
		while(_g < _g1.length) {
			var client = _g1[_g];
			++_g;
			list_b += "<div class=\"userlist_item\">";
			if((client.group & 4) != 0) {
				list_b += "<ion-icon name=\"play\"></ion-icon>";
			}
			var klass = (client.group & 1) != 0 ? "userlist_banned" : "";
			if((client.group & 8) != 0) {
				klass += " userlist_owner";
			}
			list_b += Std.string("<span class=\"" + klass + "\">" + client.name + "</span></div>");
		}
		window.document.querySelector("#userlist").innerHTML = list_b;
	}
	,getPageTitle: function() {
		return "" + this.pageTitle + " (" + this.clients.length + ")";
	}
	,clearChat: function() {
		window.document.querySelector("#messagebuffer").textContent = "";
	}
	,getLocalDateFromUtc: function(utcDate) {
		var date = HxOverrides.strDate(utcDate);
		return HxOverrides.dateStr(new Date(date.getTime() - date.getTimezoneOffset() * 60 * 1000));
	}
	,addMessage: function(name,text,date) {
		var msgBuf = window.document.querySelector("#messagebuffer");
		var userDiv = window.document.createElement("div");
		userDiv.className = "chat-msg-" + name;
		var headDiv = window.document.createElement("div");
		headDiv.className = "head";
		var tstamp = window.document.createElement("span");
		tstamp.className = "timestamp";
		if(date == null) {
			date = HxOverrides.dateStr(new Date());
		} else {
			date = this.getLocalDateFromUtc(date);
		}
		var time = date.split(" ")[1];
		tstamp.textContent = time == null ? date : time;
		tstamp.title = date;
		var nameDiv = window.document.createElement("strong");
		nameDiv.className = "username";
		nameDiv.textContent = name;
		var textDiv = window.document.createElement("div");
		textDiv.className = "text";
		text = StringTools.htmlEscape(text);
		var _g = 0;
		var _g1 = this.filters;
		while(_g < _g1.length) {
			var filter = _g1[_g];
			++_g;
			text = text.replace(filter.regex.r,filter.replace);
		}
		textDiv.innerHTML = text;
		var isInChatEnd = msgBuf.scrollTop + msgBuf.clientHeight >= msgBuf.scrollHeight - 1;
		if(isInChatEnd) {
			var _g = 0;
			var _g1 = textDiv.getElementsByTagName("img");
			while(_g < _g1.length) _g1[_g++].onload = $bind(this,this.onChatImageLoaded);
			var _g = 0;
			var _g1 = textDiv.getElementsByTagName("video");
			while(_g < _g1.length) _g1[_g++].onloadedmetadata = $bind(this,this.onChatVideoLoaded);
		}
		userDiv.appendChild(headDiv);
		headDiv.appendChild(nameDiv);
		headDiv.appendChild(tstamp);
		userDiv.appendChild(textDiv);
		msgBuf.appendChild(userDiv);
		if(isInChatEnd) {
			while(msgBuf.children.length > 200) msgBuf.removeChild(msgBuf.firstChild);
			msgBuf.scrollTop = msgBuf.scrollHeight;
		}
		if(name == this.personal.name) {
			msgBuf.scrollTop = msgBuf.scrollHeight;
		}
		if(this.onBlinkTab == null) {
			this.blinkTabWithTitle("*Chat*");
		}
	}
	,onChatImageLoaded: function(e) {
		this.scrollChatToEnd();
		e.target.onload = null;
	}
	,onChatVideoLoaded: function(e) {
		var el = e.target;
		if(this.emoteMaxSize == null) {
			this.emoteMaxSize = Std.parseInt(window.getComputedStyle(el).getPropertyValue("max-width"));
		}
		var max = this.emoteMaxSize;
		var ratio = Math.min(max / el.videoWidth,max / el.videoHeight);
		el.style.width = "" + el.videoWidth * ratio + "px";
		el.style.height = "" + el.videoHeight * ratio + "px";
		this.scrollChatToEnd();
		el.onloadedmetadata = null;
	}
	,scrollChatToEnd: function() {
		var msgBuf = window.document.querySelector("#messagebuffer");
		msgBuf.scrollTop = msgBuf.scrollHeight;
	}
	,handleCommands: function(command) {
		if(!StringTools.startsWith(command,"/")) {
			return false;
		}
		var args = StringTools.trim(command).split(" ");
		command = HxOverrides.substr(args.shift(),1,null);
		if(command.length == 0) {
			return false;
		}
		switch(command) {
		case "ban":
			this.mergeRedundantArgs(args,0,2);
			var name = args[0];
			var time = this.parseSimpleDate(args[1]);
			if(time < 0) {
				return true;
			}
			this.send({ type : "BanClient", banClient : { name : name, time : time}});
			return true;
		case "clear":
			this.send({ type : "ClearChat"});
			return true;
		case "dump":
			this.send({ type : "Dump"});
			return true;
		case "fb":case "flashback":
			this.send({ type : "Flashback"});
			return false;
		case "kick":
			this.mergeRedundantArgs(args,0,1);
			this.send({ type : "KickClient", kickClient : { name : args[0]}});
			return true;
		case "removeBan":case "unban":
			this.mergeRedundantArgs(args,0,1);
			this.send({ type : "BanClient", banClient : { name : args[0], time : 0}});
			return true;
		}
		if(this.matchSimpleDate.match(command)) {
			this.send({ type : "Rewind", rewind : { time : this.parseSimpleDate(command)}});
			return false;
		}
		return false;
	}
	,parseSimpleDate: function(text) {
		if(text == null) {
			return 0;
		}
		if(!this.matchSimpleDate.match(text)) {
			return 0;
		}
		var matches = [];
		var length = client_Utils.matchedNum(this.matchSimpleDate);
		var _g = 1;
		while(_g < length) {
			var group = this.matchSimpleDate.matched(_g++);
			if(group == null) {
				continue;
			}
			matches.push(group);
		}
		var seconds = 0;
		var _g = 0;
		while(_g < matches.length) seconds += this.parseSimpleDateBlock(matches[_g++]);
		if(StringTools.startsWith(text,"-")) {
			seconds = -seconds;
		}
		return seconds;
	}
	,parseSimpleDateBlock: function(block) {
		if(StringTools.endsWith(block,"s")) {
			return Std.parseInt(HxOverrides.substr(block,0,block.length - 1));
		} else if(StringTools.endsWith(block,"m")) {
			return Std.parseInt(HxOverrides.substr(block,0,block.length - 1)) * 60;
		} else if(StringTools.endsWith(block,"h")) {
			return Std.parseInt(HxOverrides.substr(block,0,block.length - 1)) * 60 * 60;
		} else if(StringTools.endsWith(block,"d")) {
			return Std.parseInt(HxOverrides.substr(block,0,block.length - 1)) * 60 * 60 * 24;
		}
		return Std.parseInt(block);
	}
	,mergeRedundantArgs: function(args,pos,newLength) {
		var count = args.length - (newLength - 1);
		if(count < 2) {
			return;
		}
		var x = args.splice(pos,count).join(" ");
		args.splice(pos,0,x);
	}
	,blinkTabWithTitle: function(title) {
		var _gthis = this;
		if(!window.document.hidden) {
			return;
		}
		if(this.onBlinkTab != null) {
			this.onBlinkTab.stop();
		}
		this.onBlinkTab = new haxe_Timer(1000);
		this.onBlinkTab.run = function() {
			if(StringTools.startsWith(window.document.title,_gthis.pageTitle)) {
				window.document.title = title;
			} else {
				window.document.title = _gthis.getPageTitle();
			}
		};
		this.onBlinkTab.run();
	}
	,setLeaderButton: function(flag) {
		var leaderBtn = window.document.querySelector("#leader_btn");
		if(flag) {
			leaderBtn.classList.add("success-bg");
		} else {
			leaderBtn.classList.remove("success-bg");
		}
	}
	,setPlaylistLock: function(isOpen) {
		this.isPlaylistOpen = isOpen;
		var lockPlaylist = window.document.querySelector("#lockplaylist");
		var icon = lockPlaylist.firstElementChild;
		if(isOpen) {
			lockPlaylist.title = Lang.get("playlistOpen");
			lockPlaylist.classList.add("btn-success");
			lockPlaylist.classList.add("success");
			lockPlaylist.classList.remove("danger");
			icon.setAttribute("name","lock-open");
		} else {
			lockPlaylist.title = Lang.get("playlistLocked");
			lockPlaylist.classList.add("btn-danger");
			lockPlaylist.classList.add("danger");
			lockPlaylist.classList.remove("success");
			icon.setAttribute("name","lock-closed");
		}
	}
	,setSynchThreshold: function(s) {
		this.onTimeGet.stop();
		this.onTimeGet = new haxe_Timer(s * 1000);
		this.onTimeGet.run = $bind(this,this.requestTime);
		this.settings.synchThreshold = s;
		client_Settings.write(this.settings);
	}
	,toggleLeader: function() {
		this.setLeaderButton((this.personal.group & 4) == 0);
		this.send({ type : "SetLeader", setLeader : { clientName : (this.personal.group & 4) != 0 ? "" : this.personal.name}});
	}
	,hasLeader: function() {
		return ClientTools.hasLeader(this.clients);
	}
	,hasLeaderOnPauseRequest: function() {
		return this.config.requestLeaderOnPause;
	}
	,getTemplateUrl: function() {
		return this.config.templateUrl;
	}
	,getYoutubeApiKey: function() {
		return this.config.youtubeApiKey;
	}
	,getYoutubePlaylistLimit: function() {
		return this.config.youtubePlaylistLimit;
	}
	,isVerbose: function() {
		return this.config.isVerbose;
	}
	,escapeRegExp: function(regex) {
		var _this_r = new RegExp("([.*+?^${}()|[\\]\\\\])","g".split("u").join(""));
		return regex.replace(_this_r,"\\$1");
	}
};
var client_Player = function(main) {
	this.skipSetRate = false;
	this.skipSetTime = false;
	this.isLoaded = false;
	this.playerEl = window.document.querySelector("#ytapiplayer");
	this.videoItemsEl = window.document.querySelector("#queue");
	this.videoList = new VideoList();
	this.main = main;
	this.players = [new client_players_Youtube(main,this)];
	this.iframePlayer = new client_players_Iframe(main,this);
	this.rawPlayer = new client_players_Raw(main,this);
	this.initItemButtons();
};
client_Player.__name__ = true;
client_Player.prototype = {
	initItemButtons: function() {
		var _gthis = this;
		window.document.querySelector("#queue").onclick = function(e) {
			var btn = e.target;
			var item = btn.parentElement.parentElement;
			var i = client_Utils.getIndex(item.parentElement,item);
			if(btn.classList.contains("qbtn-play")) {
				_gthis.main.send({ type : "PlayItem", playItem : { pos : i}});
			}
			if(btn.classList.contains("qbtn-next")) {
				_gthis.main.send({ type : "SetNextItem", setNextItem : { pos : i}});
			}
			if(btn.classList.contains("qbtn-tmp")) {
				_gthis.main.send({ type : "ToggleItemType", toggleItemType : { pos : i}});
			}
			if(btn.classList.contains("qbtn-delete")) {
				_gthis.main.removeVideoItem(item.querySelector(".qe_title").getAttribute("href"));
			}
		};
	}
	,setNextItem: function(pos) {
		this.videoList.setNextItem(pos);
		var next = this.videoItemsEl.children[pos];
		this.videoItemsEl.removeChild(next);
		client_Utils.insertAtIndex(this.videoItemsEl,next,this.videoList.pos + 1);
	}
	,toggleItemType: function(pos) {
		this.videoList.toggleItemType(pos);
		this.setItemElementType(this.videoItemsEl.children[pos],this.videoList.items[pos].isTemp);
	}
	,setPlayer: function(newPlayer) {
		if(this.player != newPlayer) {
			if(this.player != null) {
				var _this = this.videoList;
				client_JsApi.fireVideoRemoveEvents(_this.items[_this.pos]);
				this.player.removeVideo();
			}
			this.main.blinkTabWithTitle("*Video*");
		}
		this.player = newPlayer;
	}
	,getVideoData: function(data,callback) {
		var player = Lambda.find(this.players,function(player) {
			return player.isSupportedLink(data.url);
		});
		if(player == null) {
			player = this.rawPlayer;
		}
		player.getVideoData(data,callback);
	}
	,isRawPlayerLink: function(url) {
		return !Lambda.exists(this.players,function(player) {
			return player.isSupportedLink(url);
		});
	}
	,getIframeData: function(data,callback) {
		this.iframePlayer.getVideoData(data,callback);
	}
	,setVideo: function(i) {
		if(!this.main.isSyncActive) {
			return;
		}
		var item = this.videoList.items[i];
		var currentPlayer = Lambda.find(this.players,function(p) {
			return p.isSupportedLink(item.url);
		});
		if(currentPlayer != null) {
			this.setPlayer(currentPlayer);
		} else if(item.isIframe) {
			this.setPlayer(this.iframePlayer);
		} else {
			this.setPlayer(this.rawPlayer);
		}
		this.removeActiveLabel(this.videoList.pos);
		this.videoList.setPos(i);
		this.addActiveLabel(this.videoList.pos);
		this.isLoaded = false;
		this.player.loadVideo(item);
		client_JsApi.fireVideoChangeEvents(item);
		window.document.querySelector("#currenttitle").textContent = item.title;
	}
	,changeVideoSrc: function(src) {
		if(this.player == null) {
			return;
		}
		var _this = this.videoList;
		var item = _this.items[_this.pos];
		if(item == null) {
			return;
		}
		this.player.loadVideo({ url : src, title : item.title, author : item.author, duration : item.duration, subs : item.subs, isTemp : item.isTemp, isIframe : item.isIframe});
	}
	,removeVideo: function() {
		var _this = this.videoList;
		client_JsApi.fireVideoRemoveEvents(_this.items[_this.pos]);
		this.player.removeVideo();
		window.document.querySelector("#currenttitle").textContent = Lang.get("nothingPlaying");
		this.setPauseIndicator(true);
	}
	,setPauseIndicator: function(flag) {
		if(!this.main.isSyncActive) {
			return;
		}
		var state = flag ? "play" : "pause";
		var el = window.document.querySelector("#pause-indicator");
		if(el.getAttribute("name") == state) {
			return;
		}
		el.setAttribute("name",state);
	}
	,onCanBePlayed: function() {
		if(!this.isLoaded) {
			this.main.send({ type : "VideoLoaded"});
		}
		this.isLoaded = true;
	}
	,onPlay: function() {
		if((this.main.personal.group & 4) == 0) {
			return;
		}
		this.main.send({ type : "Play", play : { time : this.getTime()}});
		if(this.main.hasLeaderOnPauseRequest() && this.videoList.items.length > 0) {
			if(this.main.hasPermission("requestLeader")) {
				this.main.toggleLeader();
			}
		}
	}
	,onPause: function() {
		var _gthis = this;
		if(this.main.hasLeaderOnPauseRequest() && this.videoList.items.length > 0 && this.getTime() > 1 && !this.main.hasLeader()) {
			client_JsApi.once("SetLeader",function(event) {
				if(event.setLeader.clientName != _gthis.main.personal.name) {
					return;
				}
				_gthis.main.send({ type : "Pause", pause : { time : _gthis.getTime()}});
				_gthis.player.pause();
			});
			this.main.toggleLeader();
			return;
		}
		if((this.main.personal.group & 4) == 0) {
			return;
		}
		this.main.send({ type : "Pause", pause : { time : this.getTime()}});
	}
	,onSetTime: function() {
		if(this.skipSetTime) {
			this.skipSetTime = false;
			return;
		}
		if((this.main.personal.group & 4) == 0) {
			return;
		}
		this.main.send({ type : "SetTime", setTime : { time : this.getTime()}});
	}
	,onRateChange: function() {
		if(this.skipSetRate) {
			this.skipSetRate = false;
			return;
		}
		if((this.main.personal.group & 4) == 0) {
			return;
		}
		this.main.send({ type : "SetRate", setRate : { rate : this.getPlaybackRate()}});
	}
	,addVideoItem: function(item,atEnd) {
		var url = StringTools.htmlEscape(item.url,true);
		var duration = item.isIframe ? "" : this.duration(item.duration);
		var itemEl = client_Utils.nodeFromString("<li class=\"queue_entry info\" title=\"" + Lang.get("addedBy") + ": " + item.author + "\">\n\t\t\t\t<header>\n\t\t\t\t\t<span class=\"qe_time\">" + duration + "</span>\n\t\t\t\t\t<h4><a class=\"qe_title\" href=\"" + url + "\" target=\"_blank\">" + StringTools.htmlEscape(item.title) + "</a></h4>\n\t\t\t\t</header>\n\t\t\t\t<span class=\"controls\">\n\t\t\t\t\t<button class=\"qbtn-play\" title=\"" + Lang.get("play") + "\"><ion-icon name=\"play\"></ion-icon></button>\n\t\t\t\t\t<button class=\"qbtn-next\" title=\"" + Lang.get("setNext") + "\"><ion-icon name=\"arrow-up\"></ion-icon></button>\n\t\t\t\t\t<button class=\"qbtn-tmp\"><ion-icon></ion-icon></button>\n\t\t\t\t\t<button class=\"qbtn-delete\" title=\"" + Lang.get("delete") + "\"><ion-icon name=\"close\"></ion-icon></button>\n\t\t\t\t</span>\n\t\t\t</li>");
		this.videoList.addItem(item,atEnd);
		this.setItemElementType(itemEl,item.isTemp);
		if(atEnd) {
			this.videoItemsEl.appendChild(itemEl);
		} else {
			client_Utils.insertAtIndex(this.videoItemsEl,itemEl,this.videoList.pos + 1);
		}
		this.updateCounters();
	}
	,setItemElementType: function(item,isTemp) {
		var btn = item.querySelector(".qbtn-tmp");
		btn.title = isTemp ? Lang.get("makePermanent") : Lang.get("makeTemporary");
		btn.firstElementChild.setAttribute("name",isTemp ? "lock-open" : "lock-closed");
		if(isTemp) {
			item.classList.add("queue_temp");
		} else {
			item.classList.remove("queue_temp");
		}
	}
	,removeItem: function(url) {
		this.removeElementItem(url);
		var index = this.videoList.findIndex(function(item) {
			return item.url == url;
		});
		if(index == -1) {
			return;
		}
		var _this = this.videoList;
		var isCurrent = _this.items[_this.pos].url == url;
		this.videoList.removeItem(index);
		this.updateCounters();
		if(isCurrent && this.videoList.items.length > 0) {
			this.setVideo(this.videoList.pos);
		}
	}
	,removeElementItem: function(url) {
		var _g = 0;
		var _g1 = this.videoItemsEl.children;
		while(_g < _g1.length) {
			var child = _g1[_g];
			++_g;
			if(child.querySelector(".qe_title").getAttribute("href") == url) {
				this.videoItemsEl.removeChild(child);
				break;
			}
		}
	}
	,skipItem: function(url) {
		var pos = this.videoList.findIndex(function(item) {
			return item.url == url;
		});
		if(pos == -1) {
			return;
		}
		this.removeActiveLabel(this.videoList.pos);
		this.videoList.setPos(pos);
		var _this = this.videoList;
		if(_this.items[_this.pos].isTemp) {
			this.removeElementItem(url);
		}
		this.videoList.skipItem();
		this.updateCounters();
		if(this.videoList.items.length == 0) {
			return;
		}
		this.setVideo(this.videoList.pos);
	}
	,addActiveLabel: function(pos) {
		var childs = this.videoItemsEl.children;
		if(childs[this.videoList.pos] != null) {
			childs[this.videoList.pos].classList.add("queue_active");
		}
	}
	,removeActiveLabel: function(pos) {
		var childs = this.videoItemsEl.children;
		if(childs[this.videoList.pos] != null) {
			childs[this.videoList.pos].classList.remove("queue_active");
		}
	}
	,updateCounters: function() {
		var tmp = "" + this.videoList.items.length + " ";
		var tmp1 = Lang.get("videos");
		window.document.querySelector("#plcount").textContent = tmp + tmp1;
		window.document.querySelector("#pllength").textContent = this.totalDuration();
	}
	,getItems: function() {
		return this.videoList.items;
	}
	,setItems: function(list,pos) {
		var currentUrl;
		if(this.videoList.pos >= this.videoList.items.length) {
			currentUrl = "";
		} else {
			var _this = this.videoList;
			currentUrl = _this.items[_this.pos].url;
		}
		this.clearItems();
		if(list.length == 0) {
			return;
		}
		var _g = 0;
		while(_g < list.length) this.addVideoItem(list[_g++],true);
		if(pos != null) {
			this.videoList.setPos(pos);
		}
		var _this = this.videoList;
		if(currentUrl != _this.items[_this.pos].url) {
			this.setVideo(this.videoList.pos);
		} else {
			this.addActiveLabel(this.videoList.pos);
		}
	}
	,clearItems: function() {
		var _this = this.videoList;
		_this.items.length = 0;
		_this.pos = 0;
		this.videoItemsEl.textContent = "";
		this.updateCounters();
	}
	,refresh: function() {
		if(this.videoList.items.length == 0) {
			return;
		}
		var time = this.getTime();
		this.removeVideo();
		this.setVideo(this.videoList.pos);
		if((this.main.personal.group & 4) != 0) {
			this.setTime(time);
			this.main.forceSyncNextTick = true;
		}
	}
	,duration: function(time) {
		var h = time / 60 / 60 | 0;
		var m = (time / 60 | 0) - h * 60;
		var s = time % 60 | 0;
		var time = "" + m + ":";
		if(m < 10) {
			time = "0" + time;
		}
		if(h > 0) {
			time = "" + h + ":" + time;
		}
		if(s < 10) {
			time += "0";
		}
		time += s;
		return time;
	}
	,totalDuration: function() {
		var time = 0.0;
		var _g = 0;
		var _g1 = this.videoList.items;
		while(_g < _g1.length) {
			var item = _g1[_g];
			++_g;
			if(item.isIframe) {
				continue;
			}
			time += item.duration;
		}
		return this.duration(time);
	}
	,isListEmpty: function() {
		return this.videoList.items.length == 0;
	}
	,itemsLength: function() {
		return this.videoList.items.length;
	}
	,getItemPos: function() {
		return this.videoList.pos;
	}
	,hasVideo: function() {
		return this.playerEl.children.length != 0;
	}
	,getDuration: function() {
		if(this.videoList.pos >= this.videoList.items.length) {
			return 0;
		}
		var _this = this.videoList;
		return _this.items[_this.pos].duration;
	}
	,isVideoLoaded: function() {
		return this.player.isVideoLoaded();
	}
	,play: function() {
		if(!this.main.isSyncActive) {
			return;
		}
		if(this.player == null) {
			return;
		}
		if(!this.player.isVideoLoaded()) {
			return;
		}
		this.player.play();
	}
	,pause: function() {
		if(!this.main.isSyncActive) {
			return;
		}
		if(this.player == null) {
			return;
		}
		if(!this.player.isVideoLoaded()) {
			return;
		}
		this.player.pause();
	}
	,getTime: function() {
		if(this.player == null) {
			return 0;
		}
		if(!this.player.isVideoLoaded()) {
			return 0;
		}
		return this.player.getTime();
	}
	,setTime: function(time,isLocal) {
		if(isLocal == null) {
			isLocal = true;
		}
		if(!this.main.isSyncActive) {
			return;
		}
		if(this.player == null) {
			return;
		}
		if(!this.player.isVideoLoaded()) {
			return;
		}
		this.skipSetTime = isLocal;
		this.player.setTime(time);
	}
	,getPlaybackRate: function() {
		if(this.player == null) {
			return 1;
		}
		if(!this.player.isVideoLoaded()) {
			return 1;
		}
		return this.player.getPlaybackRate();
	}
	,setPlaybackRate: function(rate,isLocal) {
		if(isLocal == null) {
			isLocal = true;
		}
		if(!this.main.isSyncActive) {
			return;
		}
		if(this.player == null) {
			return;
		}
		if(!this.player.isVideoLoaded()) {
			return;
		}
		this.skipSetRate = isLocal;
		this.player.setPlaybackRate(rate);
	}
};
var client_Settings = function() { };
client_Settings.__name__ = true;
client_Settings.init = function(def,upd) {
	client_Settings.storage = js_Browser.getLocalStorage();
	client_Settings.isSupported = client_Settings.storage != null;
	client_Settings.defaults = def;
	client_Settings.updater = upd;
};
client_Settings.read = function() {
	if(!client_Settings.isSupported) {
		return client_Settings.defaults;
	}
	return client_Settings.checkData(JSON.parse(client_Settings.storage.getItem("data")));
};
client_Settings.checkData = function(data) {
	if(client_Settings.defaults == null) {
		throw haxe_Exception.thrown("read: default data is null");
	}
	if(data == null) {
		return client_Settings.defaults;
	}
	if(data.version == client_Settings.defaults.version) {
		return data;
	}
	if(data.version > client_Settings.defaults.version) {
		throw haxe_Exception.thrown("read: current data version is larger than default data version");
	}
	if(client_Settings.updater == null) {
		throw haxe_Exception.thrown("read: updater function is null");
	}
	while(data.version < client_Settings.defaults.version) {
		data = client_Settings.updater(data,data.version);
		data.version++;
	}
	client_Settings.write(data);
	return data;
};
client_Settings.write = function(data) {
	if(!client_Settings.isSupported) {
		return;
	}
	client_Settings.storage.setItem("data",JSON.stringify(data));
};
var client_Utils = function() { };
client_Utils.__name__ = true;
client_Utils.isTouch = function() {
	return 'ontouchstart' in window;
};
client_Utils.isIOS = function() {
	if(!new EReg("^(iPhone|iPad|iPod)","").match($global.navigator.platform)) {
		if(new EReg("^Mac","").match($global.navigator.platform)) {
			return $global.navigator.maxTouchPoints > 4;
		} else {
			return false;
		}
	} else {
		return true;
	}
};
client_Utils.nodeFromString = function(div) {
	var wrapper = window.document.createElement("div");
	wrapper.innerHTML = div;
	return wrapper.firstElementChild;
};
client_Utils.prepend = function(parent,child) {
	if(parent.firstChild == null) {
		parent.appendChild(child);
	} else {
		parent.insertBefore(child,parent.firstChild);
	}
};
client_Utils.insertAtIndex = function(parent,child,i) {
	if(i >= parent.children.length) {
		parent.appendChild(child);
	} else {
		parent.insertBefore(child,parent.children[i]);
	}
};
client_Utils.getIndex = function(parent,child) {
	var i = 0;
	var _g = 0;
	var _g1 = parent.children;
	while(_g < _g1.length) {
		if(_g1[_g++] == child) {
			break;
		}
		++i;
	}
	return i;
};
client_Utils.hasFullscreen = function() {
	var doc = window.document;
	if(!(window.document.fullscreenElement != null || doc.mozFullScreenElement != null)) {
		return doc.webkitFullscreenElement != null;
	} else {
		return true;
	}
};
client_Utils.requestFullscreen = function(el) {
	var el2 = el;
	if(el.requestFullscreen != null) {
		el.requestFullscreen();
	} else if(el2.mozRequestFullScreen != null) {
		el2.mozRequestFullScreen();
	} else if(el2.webkitRequestFullscreen != null) {
		el2.webkitRequestFullscreen(HTMLElement.ALLOW_KEYBOARD_INPUT);
	} else {
		return false;
	}
	return true;
};
client_Utils.copyToClipboard = function(text) {
	var clipboardData = window.clipboardData;
	if(clipboardData != null && clipboardData.setData != null) {
		clipboardData.setData("Text",text);
		return;
	} else if(window.document.queryCommandSupported != null) {
		var textarea = window.document.createElement("textarea");
		textarea.textContent = text;
		textarea.style.position = "fixed";
		window.document.body.appendChild(textarea);
		textarea.select();
		window.document.execCommand("copy");
		window.document.body.removeChild(textarea);
	}
};
client_Utils.matchedNum = function(ereg) {
	return ereg.r.m.length;
};
client_Utils.browseFileUrl = function(onFileLoad,isBinary,revoke) {
	if(revoke == null) {
		revoke = false;
	}
	if(isBinary == null) {
		isBinary = true;
	}
	var input = window.document.createElement("input");
	input.style.visibility = "hidden";
	input.setAttribute("type","file");
	input.id = "browse";
	input.onclick = function(e) {
		e.cancelBubble = true;
		e.stopPropagation();
	};
	input.onchange = function() {
		var file = input.files[0];
		var url = URL.createObjectURL(file);
		onFileLoad(url,file.name);
		window.document.body.removeChild(input);
		if(revoke) {
			URL.revokeObjectURL(url);
		}
	};
	window.document.body.appendChild(input);
	input.click();
};
client_Utils.saveFile = function(name,mime,data) {
	var blob = new Blob([data],{ type : mime});
	var url = URL.createObjectURL(blob);
	var a = window.document.createElement("a");
	a.download = name;
	a.href = url;
	a.onclick = function(e) {
		e.cancelBubble = true;
		e.stopPropagation();
	};
	window.document.body.appendChild(a);
	a.click();
	window.document.body.removeChild(a);
	URL.revokeObjectURL(url);
};
var client_players_Iframe = function(main,player) {
	this.playerEl = window.document.querySelector("#ytapiplayer");
	this.main = main;
	this.player = player;
};
client_players_Iframe.__name__ = true;
client_players_Iframe.prototype = {
	isSupportedLink: function(url) {
		return true;
	}
	,getVideoData: function(data,callback) {
		var iframe = window.document.createElement("div");
		iframe.innerHTML = data.url;
		if(this.isValidIframe(iframe)) {
			callback({ duration : 356400});
		} else {
			callback({ duration : 0});
		}
	}
	,isValidIframe: function(iframe) {
		if(iframe.children.length != 1) {
			return false;
		}
		if(iframe.firstChild.nodeName != "IFRAME") {
			return iframe.firstChild.nodeName == "OBJECT";
		} else {
			return true;
		}
	}
	,loadVideo: function(item) {
		this.removeVideo();
		this.video = window.document.createElement("div");
		this.video.id = "videoplayer";
		this.video.innerHTML = item.url;
		if(!this.isValidIframe(this.video)) {
			this.video = null;
			return;
		}
		if(this.video.firstChild.nodeName == "IFRAME") {
			this.video.setAttribute("sandbox","allow-scripts");
		}
		this.playerEl.appendChild(this.video);
	}
	,removeVideo: function() {
		if(this.video == null) {
			return;
		}
		this.playerEl.removeChild(this.video);
		this.video = null;
	}
	,isVideoLoaded: function() {
		return this.video != null;
	}
	,play: function() {
	}
	,pause: function() {
	}
	,getTime: function() {
		return 0;
	}
	,setTime: function(time) {
	}
	,getPlaybackRate: function() {
		return 1;
	}
	,setPlaybackRate: function(rate) {
	}
};
var client_players_Raw = function(main,player) {
	this.isHlsLoaded = false;
	this.playAllowed = true;
	this.matchName = new EReg("^(.+)\\.(.+)","");
	this.subsInput = window.document.querySelector("#subsurl");
	this.titleInput = window.document.querySelector("#mediatitle");
	this.playerEl = window.document.querySelector("#ytapiplayer");
	this.main = main;
	this.player = player;
};
client_players_Raw.__name__ = true;
client_players_Raw.prototype = {
	isSupportedLink: function(url) {
		return true;
	}
	,getVideoData: function(data,callback) {
		var _gthis = this;
		var url = data.url;
		var decodedUrl = decodeURIComponent(url.split("+").join(" "));
		var optTitle = StringTools.trim(this.titleInput.value);
		var title = HxOverrides.substr(decodedUrl,decodedUrl.lastIndexOf("/") + 1,null);
		var isNameMatched = this.matchName.match(title);
		if(optTitle != "") {
			title = optTitle;
		} else if(isNameMatched) {
			title = this.matchName.matched(1);
		} else {
			title = Lang.get("rawVideo");
		}
		var isHls = false;
		if(isNameMatched) {
			isHls = this.matchName.matched(2).indexOf("m3u8") != -1;
		} else {
			isHls = StringTools.endsWith(title,"m3u8");
		}
		if(isHls && !this.isHlsLoaded) {
			this.loadHlsPlugin(function() {
				_gthis.getVideoData(data,callback);
			});
			return;
		}
		this.titleInput.value = "";
		var subs = StringTools.trim(this.subsInput.value);
		this.subsInput.value = "";
		var video = window.document.createElement("video");
		video.src = url;
		video.onerror = function(e) {
			if(_gthis.playerEl.contains(video)) {
				_gthis.playerEl.removeChild(video);
			}
			callback({ duration : 0});
		};
		video.onloadedmetadata = function() {
			if(_gthis.playerEl.contains(video)) {
				_gthis.playerEl.removeChild(video);
			}
			callback({ duration : video.duration, title : title, subs : subs});
		};
		client_Utils.prepend(this.playerEl,video);
		if(isHls) {
			this.initHlsSource(video,url);
		}
	}
	,loadHlsPlugin: function(callback) {
		var _gthis = this;
		client_JsApi.addScriptToHead("https://cdn.jsdelivr.net/npm/hls.js@latest",function() {
			_gthis.isHlsLoaded = true;
			callback();
		});
	}
	,initHlsSource: function(video,url) {
		if(!Hls.isSupported()) {
			return;
		}
		var hls = new Hls();
		hls.loadSource(url);
		hls.attachMedia(video);
	}
	,loadVideo: function(item) {
		var _gthis = this;
		var url = this.main.tryLocalIp(item.url);
		var isHls = item.url.indexOf("m3u8") != -1 || StringTools.endsWith(item.title,"m3u8");
		if(isHls && !this.isHlsLoaded) {
			this.loadHlsPlugin(function() {
				_gthis.loadVideo(item);
			});
			return;
		}
		if(this.video != null) {
			this.video.src = url;
			var _g = 0;
			var _g1 = this.video.children;
			while(_g < _g1.length) {
				var element = _g1[_g];
				++_g;
				if(element.nodeName != "TRACK") {
					continue;
				}
				element.remove();
			}
		} else {
			this.video = window.document.createElement("video");
			this.video.id = "videoplayer";
			this.video.setAttribute("playsinline","");
			this.video.src = url;
			this.video.oncanplaythrough = ($_=this.player,$bind($_,$_.onCanBePlayed));
			this.video.onseeking = ($_=this.player,$bind($_,$_.onSetTime));
			this.video.onplay = function(e) {
				_gthis.playAllowed = true;
				_gthis.player.onPlay();
			};
			this.video.onpause = ($_=this.player,$bind($_,$_.onPause));
			this.video.onratechange = ($_=this.player,$bind($_,$_.onRateChange));
			this.playerEl.appendChild(this.video);
		}
		if(isHls) {
			this.initHlsSource(this.video,url);
		}
		this.restartControlsHider();
		client_players_RawSubs.loadSubs(item,this.video);
	}
	,restartControlsHider: function() {
		var _gthis = this;
		this.video.controls = true;
		if(client_Utils.isTouch()) {
			return;
		}
		if(this.controlsHider != null) {
			this.controlsHider.stop();
		}
		this.controlsHider = haxe_Timer.delay(function() {
			if(_gthis.video == null) {
				return;
			}
			_gthis.video.controls = false;
		},3000);
		this.video.onmousemove = function(e) {
			if(_gthis.controlsHider != null) {
				_gthis.controlsHider.stop();
			}
			_gthis.video.controls = true;
			return _gthis.video.onmousemove = null;
		};
	}
	,removeVideo: function() {
		if(this.video == null) {
			return;
		}
		this.video.pause();
		this.video.removeAttribute("src");
		this.video.load();
		this.playerEl.removeChild(this.video);
		this.video = null;
	}
	,isVideoLoaded: function() {
		return this.video != null;
	}
	,play: function() {
		var _gthis = this;
		if(!this.playAllowed) {
			return;
		}
		var promise = this.video.play();
		if(promise == null) {
			return;
		}
		promise.catch(function(error) {
			return _gthis.playAllowed = false;
		});
	}
	,pause: function() {
		this.video.pause();
	}
	,getTime: function() {
		return this.video.currentTime;
	}
	,setTime: function(time) {
		this.video.currentTime = time;
	}
	,getPlaybackRate: function() {
		return this.video.playbackRate;
	}
	,setPlaybackRate: function(rate) {
		this.video.playbackRate = rate;
	}
};
var client_players_RawSubs = function() { };
client_players_RawSubs.__name__ = true;
client_players_RawSubs.loadSubs = function(item,video) {
	if(item.subs == null || item.subs.length == 0) {
		return;
	}
	var ext = PathTools.urlExtension(item.subs);
	if(client_JsApi.hasSubtitleSupport(ext)) {
		return;
	}
	var url = encodeURI(item.subs);
	if(!StringTools.startsWith(url,"/")) {
		var protocol = $global.location.protocol;
		if(!StringTools.startsWith(url,"http")) {
			url = "" + protocol + "//" + url;
		}
		url = "/proxy?url=" + url;
	}
	switch(ext) {
	case "ass":
		client_players_RawSubs.parseAss(video,url);
		break;
	case "srt":
		client_players_RawSubs.parseSrt(video,url);
		break;
	case "vtt":
		client_players_RawSubs.onParsed(video,"VTT subtitles",url);
		break;
	}
};
client_players_RawSubs.parseSrt = function(video,url) {
	window.fetch(url).then(function(response) {
		return response.text();
	}).then(function(text) {
		if(client_players_RawSubs.isProxyError(text)) {
			return;
		}
		var subs = [];
		var blocks = StringTools.replace(text,"\r\n","\n").split("\n\n");
		var _g = 0;
		while(_g < blocks.length) {
			var lines = blocks[_g++].split("\n");
			if(lines.length < 3) {
				continue;
			}
			var _g1 = [];
			var _g2 = 2;
			var _g3 = lines.length;
			while(_g2 < _g3) _g1.push(lines[_g2++]);
			subs.push({ counter : lines[0], time : StringTools.replace(lines[1],",","."), text : _g1.join("\n")});
		}
		var data = "WEBVTT\n\n";
		var _g = 0;
		while(_g < subs.length) {
			var sub = subs[_g];
			++_g;
			data += "" + sub.counter + "\n";
			data += "" + sub.time + "\n";
			data += "" + sub.text + "\n\n";
		}
		var url = "data:text/plain;base64," + haxe_crypto_Base64.encode(haxe_io_Bytes.ofString(data));
		client_players_RawSubs.onParsed(video,"SRT subtitles",url);
	});
};
client_players_RawSubs.parseAss = function(video,url) {
	window.fetch(url).then(function(response) {
		return response.text();
	}).then(function(text) {
		if(client_players_RawSubs.isProxyError(text)) {
			return;
		}
		var subs = [];
		var lines = StringTools.replace(text,"\r\n","\n").split("\n");
		var matchFormat = new EReg("^Format:","");
		var matchDialogue = new EReg("^Dialogue:","");
		var blockTags_r = new RegExp("\\{\\\\[^}]*\\}","g".split("u").join(""));
		var spaceTags_r = new RegExp("\\\\(n|h)","g".split("u").join(""));
		var newLineTag_r = new RegExp("\\\\N","g".split("u").join(""));
		var manyNewLineTags_r = new RegExp("\\\\N(\\\\N)+","g".split("u").join(""));
		var drawingMode = new EReg("\\\\p[124]","");
		var eventStart = false;
		var formatFound = false;
		var ids_h = Object.create(null);
		var subsCounter = 1;
		var _g = 0;
		while(_g < lines.length) {
			var line = StringTools.trim(lines[_g++]);
			if(!eventStart) {
				eventStart = StringTools.startsWith(line,"[Events]");
				continue;
			}
			if(!formatFound) {
				formatFound = matchFormat.match(line);
				if(!formatFound) {
					continue;
				}
				var list = line.replace(matchFormat.r,"").split(",");
				var _g1 = 0;
				var _g2 = list.length;
				while(_g1 < _g2) {
					var i = _g1++;
					ids_h[StringTools.trim(list[i])] = i;
				}
				ids_h["_length"] = list.length;
			}
			if(!matchDialogue.match(line)) {
				continue;
			}
			var list1 = line.replace(matchDialogue.r,"").split(",");
			while(list1.length > ids_h["_length"]) {
				var el = list1.pop();
				list1[list1.length - 1] += el;
			}
			var result = new Array(list1.length);
			var _g3 = 0;
			var _g11 = list1.length;
			while(_g3 < _g11) {
				var i1 = _g3++;
				result[i1] = StringTools.trim(list1[i1]);
			}
			list1 = result;
			var text = result[ids_h["Text"]];
			if(drawingMode.match(text)) {
				text = "";
			}
			text = text.replace(blockTags_r,"");
			text = text.replace(spaceTags_r," ");
			text = text.replace(manyNewLineTags_r,"\\N");
			if(StringTools.startsWith(text,"\\N")) {
				text = HxOverrides.substr(text,"\\N".length,null);
			}
			if(StringTools.endsWith(text,"\\N")) {
				text = HxOverrides.substr(text,0,text.length - 2);
			}
			text = text.replace(newLineTag_r,"\n");
			subs.push({ counter : subsCounter, start : client_players_RawSubs.convertAssTime(result[ids_h["Start"]]), end : client_players_RawSubs.convertAssTime(result[ids_h["End"]]), text : text});
			++subsCounter;
		}
		var data = "WEBVTT\n\n";
		var _g = 0;
		while(_g < subs.length) {
			var sub = subs[_g];
			++_g;
			data += "" + sub.counter + "\n";
			data += "" + sub.start + " --> " + sub.end + "\n";
			data += "" + sub.text + "\n\n";
		}
		var url = "data:text/plain;base64," + haxe_crypto_Base64.encode(haxe_io_Bytes.ofString(data));
		client_players_RawSubs.onParsed(video,"ASS subtitles",url);
	});
};
client_players_RawSubs.convertAssTime = function(time) {
	if(!client_players_RawSubs.assTimeStamp.match(time)) {
		return "" + StringTools.lpad("" + 0,"0",2) + ":" + StringTools.lpad("" + 0,"0",2) + ":" + StringTools.lpad("" + 0,"0",2) + "." + HxOverrides.substr(StringTools.lpad("" + 0,"0",3),0,3);
	}
	var h = Std.parseInt(client_players_RawSubs.assTimeStamp.matched(1));
	var m = Std.parseInt(client_players_RawSubs.assTimeStamp.matched(2));
	var s = Std.parseInt(client_players_RawSubs.assTimeStamp.matched(3));
	var ms = Std.parseInt(client_players_RawSubs.assTimeStamp.matched(4)) * 10;
	return "" + StringTools.lpad("" + h,"0",2) + ":" + StringTools.lpad("" + m,"0",2) + ":" + StringTools.lpad("" + s,"0",2) + "." + HxOverrides.substr(StringTools.lpad("" + ms,"0",3),0,3);
};
client_players_RawSubs.isProxyError = function(text) {
	if(StringTools.startsWith(text,"Proxy error:")) {
		client_Main.serverMessage(4,"Failed to add subs: proxy error");
		haxe_Log.trace("Failed to add subs: " + text,{ fileName : "src/client/players/RawSubs.hx", lineNumber : 191, className : "client.players.RawSubs", methodName : "isProxyError"});
		return true;
	}
	return false;
};
client_players_RawSubs.onParsed = function(video,name,dataUrl) {
	var trackEl = window.document.createElement("track");
	trackEl.kind = "captions";
	trackEl.label = name;
	trackEl.srclang = "en";
	trackEl.src = dataUrl;
	video.appendChild(trackEl);
	trackEl.track.mode = "showing";
};
var client_players_Youtube = function(main,player) {
	this.matchSeconds = new EReg("([0-9]+)S","");
	this.matchMinutes = new EReg("([0-9]+)M","");
	this.matchHours = new EReg("([0-9]+)H","");
	this.isLoaded = false;
	this.playerEl = window.document.querySelector("#ytapiplayer");
	this.urlVideoId = "?part=snippet&fields=nextPageToken,items(snippet/resourceId/videoId)";
	this.urlTitleDuration = "?part=snippet,contentDetails&fields=items(snippet/title,contentDetails/duration)";
	this.playlistUrl = "https://www.googleapis.com/youtube/v3/playlistItems";
	this.videosUrl = "https://www.googleapis.com/youtube/v3/videos";
	this.matchPlaylist = new EReg("youtube\\.com.*list=([A-z0-9_-]+)","");
	this.matchEmbed = new EReg("youtube\\.com/embed/([A-z0-9_-]+)","");
	this.matchShort = new EReg("youtu\\.be/([A-z0-9_-]+)","");
	this.matchId = new EReg("youtube\\.com.*v=([A-z0-9_-]+)","");
	this.main = main;
	this.player = player;
};
client_players_Youtube.__name__ = true;
client_players_Youtube.prototype = {
	isSupportedLink: function(url) {
		if(this.extractVideoId(url) == "") {
			return this.extractPlaylistId(url) != "";
		} else {
			return true;
		}
	}
	,extractVideoId: function(url) {
		if(this.matchId.match(url)) {
			return this.matchId.matched(1);
		}
		if(this.matchShort.match(url)) {
			return this.matchShort.matched(1);
		}
		if(this.matchEmbed.match(url)) {
			return this.matchEmbed.matched(1);
		}
		return "";
	}
	,extractPlaylistId: function(url) {
		if(!this.matchPlaylist.match(url)) {
			return "";
		}
		return this.matchPlaylist.matched(1);
	}
	,convertTime: function(duration) {
		var total = 0;
		var hours = this.matchHours.match(duration);
		var minutes = this.matchMinutes.match(duration);
		var seconds = this.matchSeconds.match(duration);
		if(hours) {
			total = Std.parseInt(this.matchHours.matched(1)) * 3600;
		}
		if(minutes) {
			total += Std.parseInt(this.matchMinutes.matched(1)) * 60;
		}
		if(seconds) {
			total += Std.parseInt(this.matchSeconds.matched(1));
		}
		return total;
	}
	,getVideoData: function(data,callback) {
		var _gthis = this;
		var url = data.url;
		if(this.apiKey == null) {
			this.apiKey = this.main.getYoutubeApiKey();
		}
		var id = this.extractVideoId(url);
		if(id == "") {
			this.getPlaylistVideoData(data,callback);
			return;
		}
		var http = new haxe_http_HttpJs("" + this.videosUrl + this.urlTitleDuration + "&id=" + id + "&key=" + this.apiKey);
		http.onData = function(text) {
			var json = JSON.parse(text);
			if(json.error != null) {
				_gthis.youtubeApiError(json.error);
				_gthis.getRemoteDataFallback(url,callback);
				return;
			}
			var items = json.items;
			if(items == null || items.length == 0) {
				callback({ duration : 0});
				return;
			}
			var _g = 0;
			while(_g < items.length) {
				var item = items[_g];
				++_g;
				var title = item.snippet.title;
				var duration = _gthis.convertTime(item.contentDetails.duration);
				if(duration == 0) {
					callback({ duration : 356400, title : title, url : "<iframe src=\"https://www.youtube.com/embed/" + id + "\" frameborder=\"0\"\n\t\t\t\t\t\t\tallow=\"accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture\"\n\t\t\t\t\t\t\tallowfullscreen></iframe>", isIframe : true});
					continue;
				}
				callback({ duration : duration, title : title, url : url});
			}
		};
		http.onError = function(msg) {
			_gthis.getRemoteDataFallback(url,callback);
		};
		http.request();
	}
	,getPlaylistVideoData: function(data,callback) {
		var _gthis = this;
		var id = this.extractPlaylistId(data.url);
		var maxResults = this.main.getYoutubePlaylistLimit();
		var dataUrl = "" + this.playlistUrl + this.urlVideoId + "&maxResults=" + maxResults + "&playlistId=" + id + "&key=" + this.apiKey;
		var loadJson = null;
		loadJson = function(url) {
			var http = new haxe_http_HttpJs(url);
			http.onData = function(text) {
				var json = JSON.parse(text);
				if(json.error != null) {
					_gthis.youtubeApiError(json.error);
					callback({ duration : 0});
					return;
				}
				var items = json.items;
				if(items == null || items.length == 0) {
					callback({ duration : 0});
					return;
				}
				if(!data.atEnd) {
					_gthis.main.sortItemsForQueueNext(items);
				}
				var loadNextItem = null;
				loadNextItem = function() {
					var obj = { url : "https://youtu.be/" + items.shift().snippet.resourceId.videoId, atEnd : data.atEnd};
					_gthis.getVideoData(obj,function(data) {
						callback(data);
						maxResults -= 1;
						if(maxResults <= 0) {
							return;
						}
						if(items.length > 0) {
							loadNextItem();
						} else if(json.nextPageToken != null) {
							loadJson("" + dataUrl + "&pageToken=" + json.nextPageToken);
						}
					});
				};
				loadNextItem();
			};
			http.onError = function(msg) {
				callback({ duration : 0});
			};
			http.request();
		};
		loadJson(dataUrl);
	}
	,youtubeApiError: function(error) {
		client_Main.serverMessage(4,"Error " + error.code + ": " + error.message,false);
	}
	,getRemoteDataFallback: function(url,callback) {
		var _gthis = this;
		if(!js_youtube_Youtube.isLoadedAPI) {
			js_youtube_Youtube.init(function() {
				_gthis.getRemoteDataFallback(url,callback);
			});
			return;
		}
		var video = window.document.createElement("div");
		video.id = "temp-videoplayer";
		client_Utils.prepend(this.playerEl,video);
		this.tempYoutube = new YT.Player(video.id,{ videoId : this.extractVideoId(url), playerVars : { modestbranding : 1, rel : 0, showinfo : 0}, events : { onReady : function(e) {
			if(_gthis.playerEl.contains(video)) {
				_gthis.playerEl.removeChild(video);
			}
			callback({ duration : _gthis.tempYoutube.getDuration()});
		}, onError : function(e) {
			haxe_Log.trace("Error " + e.data,{ fileName : "src/client/players/Youtube.hx", lineNumber : 201, className : "client.players.Youtube", methodName : "getRemoteDataFallback"});
			if(_gthis.playerEl.contains(video)) {
				_gthis.playerEl.removeChild(video);
			}
			callback({ duration : 0});
		}}});
	}
	,loadVideo: function(item) {
		var _gthis = this;
		if(!js_youtube_Youtube.isLoadedAPI) {
			js_youtube_Youtube.init(function() {
				_gthis.loadVideo(item);
			});
			return;
		}
		if(this.youtube != null) {
			this.youtube.loadVideoById({ videoId : this.extractVideoId(item.url)});
			return;
		}
		this.isLoaded = false;
		this.video = window.document.createElement("div");
		this.video.id = "videoplayer";
		this.playerEl.appendChild(this.video);
		this.youtube = new YT.Player(this.video.id,{ videoId : this.extractVideoId(item.url), playerVars : { autoplay : 1, playsinline : 1, modestbranding : 1, rel : 0, showinfo : 0}, events : { onReady : function(e) {
			_gthis.isLoaded = true;
			_gthis.youtube.pauseVideo();
		}, onStateChange : function(e) {
			switch(e.data) {
			case -1:
				_gthis.player.onCanBePlayed();
				break;
			case 0:
				break;
			case 1:
				_gthis.player.onPlay();
				break;
			case 2:
				_gthis.player.onPause();
				break;
			case 3:
				_gthis.player.onSetTime();
				break;
			case 5:
				break;
			}
		}, onPlaybackRateChange : function(e) {
			_gthis.player.onRateChange();
		}}});
	}
	,removeVideo: function() {
		if(this.video == null) {
			return;
		}
		this.isLoaded = false;
		this.youtube.destroy();
		this.youtube = null;
		if(this.playerEl.contains(this.video)) {
			this.playerEl.removeChild(this.video);
		}
		this.video = null;
	}
	,isVideoLoaded: function() {
		return this.isLoaded;
	}
	,play: function() {
		this.youtube.playVideo();
	}
	,pause: function() {
		this.youtube.pauseVideo();
	}
	,getTime: function() {
		return this.youtube.getCurrentTime();
	}
	,setTime: function(time) {
		this.youtube.seekTo(time,true);
	}
	,getPlaybackRate: function() {
		return this.youtube.getPlaybackRate();
	}
	,setPlaybackRate: function(rate) {
		this.youtube.setPlaybackRate(rate);
	}
};
var haxe_Exception = function(message,previous,native) {
	Error.call(this,message);
	this.message = message;
	this.__previousException = previous;
	this.__nativeException = native != null ? native : this;
};
haxe_Exception.__name__ = true;
haxe_Exception.caught = function(value) {
	if(((value) instanceof haxe_Exception)) {
		return value;
	} else if(((value) instanceof Error)) {
		return new haxe_Exception(value.message,null,value);
	} else {
		return new haxe_ValueException(value,null,value);
	}
};
haxe_Exception.thrown = function(value) {
	if(((value) instanceof haxe_Exception)) {
		return value.get_native();
	} else if(((value) instanceof Error)) {
		return value;
	} else {
		var e = new haxe_ValueException(value);
		return e;
	}
};
haxe_Exception.__super__ = Error;
haxe_Exception.prototype = $extend(Error.prototype,{
	unwrap: function() {
		return this.__nativeException;
	}
	,get_native: function() {
		return this.__nativeException;
	}
});
var haxe_Log = function() { };
haxe_Log.__name__ = true;
haxe_Log.formatOutput = function(v,infos) {
	var str = Std.string(v);
	if(infos == null) {
		return str;
	}
	var pstr = infos.fileName + ":" + infos.lineNumber;
	if(infos.customParams != null) {
		var _g = 0;
		var _g1 = infos.customParams;
		while(_g < _g1.length) str += ", " + Std.string(_g1[_g++]);
	}
	return pstr + ": " + str;
};
haxe_Log.trace = function(v,infos) {
	var str = haxe_Log.formatOutput(v,infos);
	if(typeof(console) != "undefined" && console.log != null) {
		console.log(str);
	}
};
var haxe_Timer = function(time_ms) {
	var me = this;
	this.id = setInterval(function() {
		me.run();
	},time_ms);
};
haxe_Timer.__name__ = true;
haxe_Timer.delay = function(f,time_ms) {
	var t = new haxe_Timer(time_ms);
	t.run = function() {
		t.stop();
		f();
	};
	return t;
};
haxe_Timer.prototype = {
	stop: function() {
		if(this.id == null) {
			return;
		}
		clearInterval(this.id);
		this.id = null;
	}
	,run: function() {
	}
};
var haxe_ValueException = function(value,previous,native) {
	haxe_Exception.call(this,String(value),previous,native);
	this.value = value;
};
haxe_ValueException.__name__ = true;
haxe_ValueException.__super__ = haxe_Exception;
haxe_ValueException.prototype = $extend(haxe_Exception.prototype,{
	unwrap: function() {
		return this.value;
	}
});
var haxe_io_Bytes = function(data) {
	this.length = data.byteLength;
	this.b = new Uint8Array(data);
	this.b.bufferValue = data;
	data.hxBytes = this;
	data.bytes = this.b;
};
haxe_io_Bytes.__name__ = true;
haxe_io_Bytes.ofString = function(s,encoding) {
	if(encoding == haxe_io_Encoding.RawNative) {
		var buf = new Uint8Array(s.length << 1);
		var _g = 0;
		var _g1 = s.length;
		while(_g < _g1) {
			var i = _g++;
			var c = s.charCodeAt(i);
			buf[i << 1] = c & 255;
			buf[i << 1 | 1] = c >> 8;
		}
		return new haxe_io_Bytes(buf.buffer);
	}
	var a = [];
	var i = 0;
	while(i < s.length) {
		var c = s.charCodeAt(i++);
		if(55296 <= c && c <= 56319) {
			c = c - 55232 << 10 | s.charCodeAt(i++) & 1023;
		}
		if(c <= 127) {
			a.push(c);
		} else if(c <= 2047) {
			a.push(192 | c >> 6);
			a.push(128 | c & 63);
		} else if(c <= 65535) {
			a.push(224 | c >> 12);
			a.push(128 | c >> 6 & 63);
			a.push(128 | c & 63);
		} else {
			a.push(240 | c >> 18);
			a.push(128 | c >> 12 & 63);
			a.push(128 | c >> 6 & 63);
			a.push(128 | c & 63);
		}
	}
	return new haxe_io_Bytes(new Uint8Array(a).buffer);
};
haxe_io_Bytes.ofData = function(b) {
	var hb = b.hxBytes;
	if(hb != null) {
		return hb;
	}
	return new haxe_io_Bytes(b);
};
haxe_io_Bytes.prototype = {
	getString: function(pos,len,encoding) {
		if(pos < 0 || len < 0 || pos + len > this.length) {
			throw haxe_Exception.thrown(haxe_io_Error.OutsideBounds);
		}
		if(encoding == null) {
			encoding = haxe_io_Encoding.UTF8;
		}
		var s = "";
		var b = this.b;
		var i = pos;
		var max = pos + len;
		switch(encoding._hx_index) {
		case 0:
			while(i < max) {
				var c = b[i++];
				if(c < 128) {
					if(c == 0) {
						break;
					}
					s += String.fromCodePoint(c);
				} else if(c < 224) {
					var code = (c & 63) << 6 | b[i++] & 127;
					s += String.fromCodePoint(code);
				} else if(c < 240) {
					var code1 = (c & 31) << 12 | (b[i++] & 127) << 6 | b[i++] & 127;
					s += String.fromCodePoint(code1);
				} else {
					var u = (c & 15) << 18 | (b[i++] & 127) << 12 | (b[i++] & 127) << 6 | b[i++] & 127;
					s += String.fromCodePoint(u);
				}
			}
			break;
		case 1:
			while(i < max) {
				var c = b[i++] | b[i++] << 8;
				s += String.fromCodePoint(c);
			}
			break;
		}
		return s;
	}
	,toString: function() {
		return this.getString(0,this.length);
	}
};
var haxe_io_Encoding = $hxEnums["haxe.io.Encoding"] = { __ename__:true,__constructs__:null
	,UTF8: {_hx_name:"UTF8",_hx_index:0,__enum__:"haxe.io.Encoding",toString:$estr}
	,RawNative: {_hx_name:"RawNative",_hx_index:1,__enum__:"haxe.io.Encoding",toString:$estr}
};
haxe_io_Encoding.__constructs__ = [haxe_io_Encoding.UTF8,haxe_io_Encoding.RawNative];
var haxe_crypto_Base64 = function() { };
haxe_crypto_Base64.__name__ = true;
haxe_crypto_Base64.encode = function(bytes,complement) {
	if(complement == null) {
		complement = true;
	}
	var str = new haxe_crypto_BaseCode(haxe_crypto_Base64.BYTES).encodeBytes(bytes).toString();
	if(complement) {
		switch(bytes.length % 3) {
		case 1:
			str += "==";
			break;
		case 2:
			str += "=";
			break;
		default:
		}
	}
	return str;
};
var haxe_crypto_BaseCode = function(base) {
	var len = base.length;
	var nbits = 1;
	while(len > 1 << nbits) ++nbits;
	if(nbits > 8 || len != 1 << nbits) {
		throw haxe_Exception.thrown("BaseCode : base length must be a power of two.");
	}
	this.base = base;
	this.nbits = nbits;
};
haxe_crypto_BaseCode.__name__ = true;
haxe_crypto_BaseCode.prototype = {
	encodeBytes: function(b) {
		var nbits = this.nbits;
		var base = this.base;
		var size = b.length * 8 / nbits | 0;
		var out = new haxe_io_Bytes(new ArrayBuffer(size + (b.length * 8 % nbits == 0 ? 0 : 1)));
		var buf = 0;
		var curbits = 0;
		var mask = (1 << nbits) - 1;
		var pin = 0;
		var pout = 0;
		while(pout < size) {
			while(curbits < nbits) {
				curbits += 8;
				buf <<= 8;
				buf |= b.b[pin++];
			}
			curbits -= nbits;
			out.b[pout++] = base.b[buf >> curbits & mask];
		}
		if(curbits > 0) {
			out.b[pout++] = base.b[buf << nbits - curbits & mask];
		}
		return out;
	}
};
var haxe_crypto_Sha256 = function() {
};
haxe_crypto_Sha256.__name__ = true;
haxe_crypto_Sha256.encode = function(s) {
	var sh = new haxe_crypto_Sha256();
	return sh.hex(sh.doEncode(haxe_crypto_Sha256.str2blks(s),s.length * 8));
};
haxe_crypto_Sha256.str2blks = function(s) {
	var s1 = haxe_io_Bytes.ofString(s);
	var nblk = (s1.length + 8 >> 6) + 1;
	var blks = [];
	var _g = 0;
	var _g1 = nblk * 16;
	while(_g < _g1) blks[_g++] = 0;
	var _g = 0;
	var _g1 = s1.length;
	while(_g < _g1) {
		var i = _g++;
		blks[i >> 2] |= s1.b[i] << 24 - ((i & 3) << 3);
	}
	var i = s1.length;
	blks[i >> 2] |= 128 << 24 - ((i & 3) << 3);
	blks[nblk * 16 - 1] = s1.length * 8;
	return blks;
};
haxe_crypto_Sha256.prototype = {
	doEncode: function(m,l) {
		var K = [1116352408,1899447441,-1245643825,-373957723,961987163,1508970993,-1841331548,-1424204075,-670586216,310598401,607225278,1426881987,1925078388,-2132889090,-1680079193,-1046744716,-459576895,-272742522,264347078,604807628,770255983,1249150122,1555081692,1996064986,-1740746414,-1473132947,-1341970488,-1084653625,-958395405,-710438585,113926993,338241895,666307205,773529912,1294757372,1396182291,1695183700,1986661051,-2117940946,-1838011259,-1564481375,-1474664885,-1035236496,-949202525,-778901479,-694614492,-200395387,275423344,430227734,506948616,659060556,883997877,958139571,1322822218,1537002063,1747873779,1955562222,2024104815,-2067236844,-1933114872,-1866530822,-1538233109,-1090935817,-965641998];
		var HASH = [1779033703,-1150833019,1013904242,-1521486534,1359893119,-1694144372,528734635,1541459225];
		var W = [];
		W[64] = 0;
		var a;
		var b;
		var c;
		var d;
		var e;
		var f;
		var g;
		var h;
		var T1;
		var T2;
		m[l >> 5] |= 128 << 24 - l % 32;
		m[(l + 64 >> 9 << 4) + 15] = l;
		var i = 0;
		while(i < m.length) {
			a = HASH[0];
			b = HASH[1];
			c = HASH[2];
			d = HASH[3];
			e = HASH[4];
			f = HASH[5];
			g = HASH[6];
			h = HASH[7];
			var _g = 0;
			while(_g < 64) {
				var j = _g++;
				if(j < 16) {
					W[j] = m[j + i];
				} else {
					var x = W[j - 2];
					var x1 = (x >>> 17 | x << 15) ^ (x >>> 19 | x << 13) ^ x >>> 10;
					var y = W[j - 7];
					var lsw = (x1 & 65535) + (y & 65535);
					var x2 = (x1 >> 16) + (y >> 16) + (lsw >> 16) << 16 | lsw & 65535;
					var x3 = W[j - 15];
					var y1 = (x3 >>> 7 | x3 << 25) ^ (x3 >>> 18 | x3 << 14) ^ x3 >>> 3;
					var lsw1 = (x2 & 65535) + (y1 & 65535);
					var x4 = (x2 >> 16) + (y1 >> 16) + (lsw1 >> 16) << 16 | lsw1 & 65535;
					var y2 = W[j - 16];
					var lsw2 = (x4 & 65535) + (y2 & 65535);
					W[j] = (x4 >> 16) + (y2 >> 16) + (lsw2 >> 16) << 16 | lsw2 & 65535;
				}
				var y3 = (e >>> 6 | e << 26) ^ (e >>> 11 | e << 21) ^ (e >>> 25 | e << 7);
				var lsw3 = (h & 65535) + (y3 & 65535);
				var x5 = (h >> 16) + (y3 >> 16) + (lsw3 >> 16) << 16 | lsw3 & 65535;
				var y4 = e & f ^ ~e & g;
				var lsw4 = (x5 & 65535) + (y4 & 65535);
				var x6 = (x5 >> 16) + (y4 >> 16) + (lsw4 >> 16) << 16 | lsw4 & 65535;
				var y5 = K[j];
				var lsw5 = (x6 & 65535) + (y5 & 65535);
				var x7 = (x6 >> 16) + (y5 >> 16) + (lsw5 >> 16) << 16 | lsw5 & 65535;
				var y6 = W[j];
				var lsw6 = (x7 & 65535) + (y6 & 65535);
				T1 = (x7 >> 16) + (y6 >> 16) + (lsw6 >> 16) << 16 | lsw6 & 65535;
				var x8 = (a >>> 2 | a << 30) ^ (a >>> 13 | a << 19) ^ (a >>> 22 | a << 10);
				var y7 = a & b ^ a & c ^ b & c;
				var lsw7 = (x8 & 65535) + (y7 & 65535);
				T2 = (x8 >> 16) + (y7 >> 16) + (lsw7 >> 16) << 16 | lsw7 & 65535;
				h = g;
				g = f;
				f = e;
				var lsw8 = (d & 65535) + (T1 & 65535);
				e = (d >> 16) + (T1 >> 16) + (lsw8 >> 16) << 16 | lsw8 & 65535;
				d = c;
				c = b;
				b = a;
				var lsw9 = (T1 & 65535) + (T2 & 65535);
				a = (T1 >> 16) + (T2 >> 16) + (lsw9 >> 16) << 16 | lsw9 & 65535;
			}
			var y8 = HASH[0];
			var lsw10 = (a & 65535) + (y8 & 65535);
			HASH[0] = (a >> 16) + (y8 >> 16) + (lsw10 >> 16) << 16 | lsw10 & 65535;
			var y9 = HASH[1];
			var lsw11 = (b & 65535) + (y9 & 65535);
			HASH[1] = (b >> 16) + (y9 >> 16) + (lsw11 >> 16) << 16 | lsw11 & 65535;
			var y10 = HASH[2];
			var lsw12 = (c & 65535) + (y10 & 65535);
			HASH[2] = (c >> 16) + (y10 >> 16) + (lsw12 >> 16) << 16 | lsw12 & 65535;
			var y11 = HASH[3];
			var lsw13 = (d & 65535) + (y11 & 65535);
			HASH[3] = (d >> 16) + (y11 >> 16) + (lsw13 >> 16) << 16 | lsw13 & 65535;
			var y12 = HASH[4];
			var lsw14 = (e & 65535) + (y12 & 65535);
			HASH[4] = (e >> 16) + (y12 >> 16) + (lsw14 >> 16) << 16 | lsw14 & 65535;
			var y13 = HASH[5];
			var lsw15 = (f & 65535) + (y13 & 65535);
			HASH[5] = (f >> 16) + (y13 >> 16) + (lsw15 >> 16) << 16 | lsw15 & 65535;
			var y14 = HASH[6];
			var lsw16 = (g & 65535) + (y14 & 65535);
			HASH[6] = (g >> 16) + (y14 >> 16) + (lsw16 >> 16) << 16 | lsw16 & 65535;
			var y15 = HASH[7];
			var lsw17 = (h & 65535) + (y15 & 65535);
			HASH[7] = (h >> 16) + (y15 >> 16) + (lsw17 >> 16) << 16 | lsw17 & 65535;
			i += 16;
		}
		return HASH;
	}
	,hex: function(a) {
		var str = "";
		var _g = 0;
		while(_g < a.length) str += StringTools.hex(a[_g++],8);
		return str.toLowerCase();
	}
};
var haxe_http_HttpBase = function(url) {
	this.url = url;
	this.headers = [];
	this.params = [];
	this.emptyOnData = $bind(this,this.onData);
};
haxe_http_HttpBase.__name__ = true;
haxe_http_HttpBase.prototype = {
	onData: function(data) {
	}
	,onBytes: function(data) {
	}
	,onError: function(msg) {
	}
	,onStatus: function(status) {
	}
	,hasOnData: function() {
		return !Reflect.compareMethods($bind(this,this.onData),this.emptyOnData);
	}
	,success: function(data) {
		this.responseBytes = data;
		this.responseAsString = null;
		if(this.hasOnData()) {
			this.onData(this.get_responseData());
		}
		this.onBytes(this.responseBytes);
	}
	,get_responseData: function() {
		if(this.responseAsString == null && this.responseBytes != null) {
			this.responseAsString = this.responseBytes.getString(0,this.responseBytes.length,haxe_io_Encoding.UTF8);
		}
		return this.responseAsString;
	}
};
var haxe_http_HttpJs = function(url) {
	this.async = true;
	this.withCredentials = false;
	haxe_http_HttpBase.call(this,url);
};
haxe_http_HttpJs.__name__ = true;
haxe_http_HttpJs.__super__ = haxe_http_HttpBase;
haxe_http_HttpJs.prototype = $extend(haxe_http_HttpBase.prototype,{
	request: function(post) {
		var _gthis = this;
		this.responseAsString = null;
		this.responseBytes = null;
		var r = this.req = js_Browser.createXMLHttpRequest();
		var onreadystatechange = function(_) {
			if(r.readyState != 4) {
				return;
			}
			var s;
			try {
				s = r.status;
			} catch( _g ) {
				s = null;
			}
			if(s == 0 && js_Browser.get_supported() && $global.location != null) {
				var protocol = $global.location.protocol.toLowerCase();
				if(new EReg("^(?:about|app|app-storage|.+-extension|file|res|widget):$","").match(protocol)) {
					s = r.response != null ? 200 : 404;
				}
			}
			if(s == undefined) {
				s = null;
			}
			if(s != null) {
				_gthis.onStatus(s);
			}
			if(s != null && s >= 200 && s < 400) {
				_gthis.req = null;
				_gthis.success(haxe_io_Bytes.ofData(r.response));
			} else if(s == null || s == 0 && r.response == null) {
				_gthis.req = null;
				_gthis.onError("Failed to connect or resolve host");
			} else if(s == null) {
				_gthis.req = null;
				var onreadystatechange = r.response != null ? haxe_io_Bytes.ofData(r.response) : null;
				_gthis.responseBytes = onreadystatechange;
				_gthis.onError("Http Error #" + r.status);
			} else {
				switch(s) {
				case 12007:
					_gthis.req = null;
					_gthis.onError("Unknown host");
					break;
				case 12029:
					_gthis.req = null;
					_gthis.onError("Failed to connect to host");
					break;
				default:
					_gthis.req = null;
					var onreadystatechange = r.response != null ? haxe_io_Bytes.ofData(r.response) : null;
					_gthis.responseBytes = onreadystatechange;
					_gthis.onError("Http Error #" + r.status);
				}
			}
		};
		if(this.async) {
			r.onreadystatechange = onreadystatechange;
		}
		var _g = this.postData;
		var _g1 = this.postBytes;
		var uri = _g == null ? _g1 == null ? null : new Blob([_g1.b.bufferValue]) : _g1 == null ? _g : null;
		if(uri != null) {
			post = true;
		} else {
			var _g = 0;
			var _g1 = this.params;
			while(_g < _g1.length) {
				var p = _g1[_g];
				++_g;
				if(uri == null) {
					uri = "";
				} else {
					uri = (uri == null ? "null" : Std.string(uri)) + "&";
				}
				var s = p.name;
				var value = (uri == null ? "null" : Std.string(uri)) + encodeURIComponent(s) + "=";
				var s1 = p.value;
				uri = value + encodeURIComponent(s1);
			}
		}
		try {
			if(post) {
				r.open("POST",this.url,this.async);
			} else if(uri != null) {
				r.open("GET",this.url + (this.url.split("?").length <= 1 ? "?" : "&") + (uri == null ? "null" : Std.string(uri)),this.async);
				uri = null;
			} else {
				r.open("GET",this.url,this.async);
			}
			r.responseType = "arraybuffer";
		} catch( _g ) {
			var _g1 = haxe_Exception.caught(_g).unwrap();
			this.req = null;
			this.onError(_g1.toString());
			return;
		}
		r.withCredentials = this.withCredentials;
		if(!Lambda.exists(this.headers,function(h) {
			return h.name == "Content-Type";
		}) && post && this.postData == null) {
			r.setRequestHeader("Content-Type","application/x-www-form-urlencoded");
		}
		var _g = 0;
		var _g1 = this.headers;
		while(_g < _g1.length) {
			var h = _g1[_g];
			++_g;
			r.setRequestHeader(h.name,h.value);
		}
		r.send(uri);
		if(!this.async) {
			onreadystatechange(null);
		}
	}
});
var haxe_io_Error = $hxEnums["haxe.io.Error"] = { __ename__:true,__constructs__:null
	,Blocked: {_hx_name:"Blocked",_hx_index:0,__enum__:"haxe.io.Error",toString:$estr}
	,Overflow: {_hx_name:"Overflow",_hx_index:1,__enum__:"haxe.io.Error",toString:$estr}
	,OutsideBounds: {_hx_name:"OutsideBounds",_hx_index:2,__enum__:"haxe.io.Error",toString:$estr}
	,Custom: ($_=function(e) { return {_hx_index:3,e:e,__enum__:"haxe.io.Error",toString:$estr}; },$_._hx_name="Custom",$_.__params__ = ["e"],$_)
};
haxe_io_Error.__constructs__ = [haxe_io_Error.Blocked,haxe_io_Error.Overflow,haxe_io_Error.OutsideBounds,haxe_io_Error.Custom];
var haxe_io_Path = function(path) {
	switch(path) {
	case ".":case "..":
		this.dir = path;
		this.file = "";
		return;
	}
	var c1 = path.lastIndexOf("/");
	var c2 = path.lastIndexOf("\\");
	if(c1 < c2) {
		this.dir = HxOverrides.substr(path,0,c2);
		path = HxOverrides.substr(path,c2 + 1,null);
		this.backslash = true;
	} else if(c2 < c1) {
		this.dir = HxOverrides.substr(path,0,c1);
		path = HxOverrides.substr(path,c1 + 1,null);
	} else {
		this.dir = null;
	}
	var cp = path.lastIndexOf(".");
	if(cp != -1) {
		this.ext = HxOverrides.substr(path,cp + 1,null);
		this.file = HxOverrides.substr(path,0,cp);
	} else {
		this.ext = null;
		this.file = path;
	}
};
haxe_io_Path.__name__ = true;
haxe_io_Path.withoutExtension = function(path) {
	var s = new haxe_io_Path(path);
	s.ext = null;
	return s.toString();
};
haxe_io_Path.extension = function(path) {
	var s = new haxe_io_Path(path);
	if(s.ext == null) {
		return "";
	}
	return s.ext;
};
haxe_io_Path.prototype = {
	toString: function() {
		return (this.dir == null ? "" : this.dir + (this.backslash ? "\\" : "/")) + this.file + (this.ext == null ? "" : "." + this.ext);
	}
};
var haxe_iterators_ArrayIterator = function(array) {
	this.current = 0;
	this.array = array;
};
haxe_iterators_ArrayIterator.__name__ = true;
haxe_iterators_ArrayIterator.prototype = {
	hasNext: function() {
		return this.current < this.array.length;
	}
	,next: function() {
		return this.array[this.current++];
	}
};
var js_Boot = function() { };
js_Boot.__name__ = true;
js_Boot.__string_rec = function(o,s) {
	if(o == null) {
		return "null";
	}
	if(s.length >= 5) {
		return "<...>";
	}
	var t = typeof(o);
	if(t == "function" && (o.__name__ || o.__ename__)) {
		t = "object";
	}
	switch(t) {
	case "function":
		return "<function>";
	case "object":
		if(o.__enum__) {
			var e = $hxEnums[o.__enum__];
			var con = e.__constructs__[o._hx_index];
			var n = con._hx_name;
			if(con.__params__) {
				s = s + "\t";
				return n + "(" + ((function($this) {
					var $r;
					var _g = [];
					{
						var _g1 = 0;
						var _g2 = con.__params__;
						while(true) {
							if(!(_g1 < _g2.length)) {
								break;
							}
							var p = _g2[_g1];
							_g1 = _g1 + 1;
							_g.push(js_Boot.__string_rec(o[p],s));
						}
					}
					$r = _g;
					return $r;
				}(this))).join(",") + ")";
			} else {
				return n;
			}
		}
		if(((o) instanceof Array)) {
			var str = "[";
			s += "\t";
			var _g = 0;
			var _g1 = o.length;
			while(_g < _g1) {
				var i = _g++;
				str += (i > 0 ? "," : "") + js_Boot.__string_rec(o[i],s);
			}
			str += "]";
			return str;
		}
		var tostr;
		try {
			tostr = o.toString;
		} catch( _g ) {
			return "???";
		}
		if(tostr != null && tostr != Object.toString && typeof(tostr) == "function") {
			var s2 = o.toString();
			if(s2 != "[object Object]") {
				return s2;
			}
		}
		var str = "{\n";
		s += "\t";
		var hasp = o.hasOwnProperty != null;
		var k = null;
		for( k in o ) {
		if(hasp && !o.hasOwnProperty(k)) {
			continue;
		}
		if(k == "prototype" || k == "__class__" || k == "__super__" || k == "__interfaces__" || k == "__properties__") {
			continue;
		}
		if(str.length != 2) {
			str += ", \n";
		}
		str += s + k + " : " + js_Boot.__string_rec(o[k],s);
		}
		s = s.substring(1);
		str += "\n" + s + "}";
		return str;
	case "string":
		return o;
	default:
		return String(o);
	}
};
var js_Browser = function() { };
js_Browser.__name__ = true;
js_Browser.get_supported = function() {
	if(typeof(window) != "undefined" && typeof(window.location) != "undefined") {
		return typeof(window.location.protocol) == "string";
	} else {
		return false;
	}
};
js_Browser.getLocalStorage = function() {
	try {
		var s = window.localStorage;
		s.getItem("");
		if(s.length == 0) {
			var key = "_hx_" + Math.random();
			s.setItem(key,key);
			s.removeItem(key);
		}
		return s;
	} catch( _g ) {
		return null;
	}
};
js_Browser.createXMLHttpRequest = function() {
	if(typeof XMLHttpRequest != "undefined") {
		return new XMLHttpRequest();
	}
	if(typeof ActiveXObject != "undefined") {
		return new ActiveXObject("Microsoft.XMLHTTP");
	}
	throw haxe_Exception.thrown("Unable to create XMLHttpRequest object.");
};
var js_hlsjs_HlsConfig = function() { };
js_hlsjs_HlsConfig.__name__ = true;
var js_youtube_Youtube = function() { };
js_youtube_Youtube.__name__ = true;
js_youtube_Youtube.init = function(onAPIReady) {
	var firstElement = window.document.getElementsByTagName("script")[0];
	var script = window.document.createElement("script");
	script.src = "https://www.youtube.com/player_api";
	firstElement.parentNode.insertBefore(script,firstElement);
	window.onYouTubePlayerAPIReady = function() {
		js_youtube_Youtube.isLoadedAPI = true;
		if(onAPIReady != null) {
			onAPIReady();
		}
	};
};
function $getIterator(o) { if( o instanceof Array ) return new haxe_iterators_ArrayIterator(o); else return o.iterator(); }
function $bind(o,m) { if( m == null ) return null; if( m.__id__ == null ) m.__id__ = $global.$haxeUID++; var f; if( o.hx__closures__ == null ) o.hx__closures__ = {}; else f = o.hx__closures__[m.__id__]; if( f == null ) { f = m.bind(o); o.hx__closures__[m.__id__] = f; } return f; }
$global.$haxeUID |= 0;
if(typeof(performance) != "undefined" ? typeof(performance.now) == "function" : false) {
	HxOverrides.now = performance.now.bind(performance);
}
if( String.fromCodePoint == null ) String.fromCodePoint = function(c) { return c < 0x10000 ? String.fromCharCode(c) : String.fromCharCode((c>>10)+0xD7C0)+String.fromCharCode((c&0x3FF)+0xDC00); }
String.__name__ = true;
Array.__name__ = true;
Date.__name__ = "Date";
js_Boot.__toStr = ({ }).toString;
Lang.langs = new haxe_ds_StringMap();
Lang.ids = ["en","ru"];
Lang.lang = HxOverrides.substr($global.navigator.language,0,2).toLowerCase();
client_JsApi.subtitleFormats = [];
client_JsApi.videoChange = [];
client_JsApi.videoRemove = [];
client_JsApi.onceListeners = [];
client_Settings.isSupported = false;
client_players_RawSubs.assTimeStamp = new EReg("([0-9]+):([0-9][0-9]):([0-9][0-9]).([0-9][0-9])","");
haxe_crypto_Base64.CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
haxe_crypto_Base64.BYTES = haxe_io_Bytes.ofString(haxe_crypto_Base64.CHARS);
js_youtube_Youtube.isLoadedAPI = false;
client_Main.main();
})(typeof exports != "undefined" ? exports : typeof window != "undefined" ? window : typeof self != "undefined" ? self : this, typeof window != "undefined" ? window : typeof global != "undefined" ? global : typeof self != "undefined" ? self : this);
