package;

#if nodejs
import js.npm.ws.WebSocket;
#elseif js
import js.html.WebSocket;
#end

typedef ClientData = {
	name:String,
	isLeader:Bool
}

class Client {

	public final ws:WebSocket;
	public var name:String;
	public var isLeader:Bool;

	public function new(?ws:WebSocket, name:String, isLeader = false) {
		this.ws = ws;
		this.name = name;
		this.isLeader = isLeader;
	}

	public function getData():ClientData {
		return {
			name: name,
			isLeader: isLeader
		}
	}

	public static function fromData(data:ClientData):Client {
		return new Client(data.name, data.isLeader);
	}

}
