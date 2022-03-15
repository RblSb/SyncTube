package;

import Types.Permission;
import Types.Permissions;

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
}
