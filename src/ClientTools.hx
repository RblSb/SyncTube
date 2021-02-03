package;

import Types.Permissions;
import Types.Permission;

class ClientTools {

	public static function setLeader(clients:Array<Client>, name:String):Void {
		for (client in clients) {
			if (client.name == name) client.isLeader = true;
			else if (client.isLeader) client.isLeader = false;
		}
	}

	public static function hasLeader(clients:Array<Client>):Bool {
		for (client in clients) {
			if (client.isLeader) return true;
		}
		return false;
	}

	public static function getByName(
		clients:Array<Client>, name:String, ?def:Client
	):Null<Client> {
		for (client in clients) {
			if (client.name == name) return client;
		}
		return def;
	}

	public static function hasPermission(client:Client, permission:Permission, permissions:Permissions):Bool {
		final p = permissions;
		if (client.isAdmin) return p.admin.contains(permission);
		if (client.isLeader) return p.leader.contains(permission);
		if (client.isUser) return p.user.contains(permission);
		return p.guest.contains(permission);
	}

}
