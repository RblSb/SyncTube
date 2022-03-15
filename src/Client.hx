package;

import Types.Permission;
import Types.Permissions;
import haxe.EnumFlags;
#if nodejs
import js.node.http.IncomingMessage;
import js.npm.ws.WebSocket;
#end

enum ClientGroup {
	Banned;
	User;
	Leader;
	Admin;
}

typedef ClientData = {
	name:String,
	group:Int
}

class Client {
	#if nodejs
	public final ws:WebSocket;
	public final req:IncomingMessage;
	public final id:Int;
	public var isAlive = true;
	#end
	public var name:String;
	public var group:EnumFlags<ClientGroup>;
	public var isBanned(get, set):Bool;
	public var isUser(get, set):Bool;
	public var isLeader(get, set):Bool;
	public var isAdmin(get, set):Bool;

	#if nodejs
	public function new(?ws:WebSocket, ?req:IncomingMessage, ?id:Int, name:String, group:Int) {
		this.ws = ws;
		this.req = req;
		this.id = id;
		this.name = name;
		this.group = new EnumFlags(group);
	}
	#else
	public function new(name:String, group:Int) {
		this.name = name;
		this.group = new EnumFlags(group);
	}
	#end

	public function hasPermission(permission:Permission, permissions:Permissions):Bool {
		final p = permissions;
		if (isBanned) return p.banned.contains(permission);
		if (isAdmin) return p.admin.contains(permission);
		if (isLeader) return p.leader.contains(permission);
		if (isUser) return p.user.contains(permission);
		return p.guest.contains(permission);
	}

	inline function get_isBanned():Bool {
		return group.has(Banned);
	}

	inline function set_isBanned(flag:Bool):Bool {
		return setGroupFlag(Banned, flag);
	}

	inline function get_isUser():Bool {
		return group.has(User);
	}

	inline function set_isUser(flag:Bool):Bool {
		return setGroupFlag(User, flag);
	}

	inline function get_isLeader():Bool {
		return group.has(Leader);
	}

	inline function set_isLeader(flag:Bool):Bool {
		return setGroupFlag(Leader, flag);
	}

	inline function get_isAdmin():Bool {
		return group.has(Admin);
	}

	inline function set_isAdmin(flag:Bool):Bool {
		return setGroupFlag(Admin, flag);
	}

	function setGroupFlag(type:ClientGroup, flag:Bool):Bool {
		if (flag) group.set(type);
		else group.unset(type);
		return flag;
	}

	public function getData():ClientData {
		return {
			name: name,
			group: group.toInt()
		}
	}

	public static function fromData(data:ClientData):Client {
		return new Client(data.name, data.group);
	}
}
