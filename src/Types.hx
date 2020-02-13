package;

import Client.ClientData;

typedef VideoItem = {
	url:String,
	title:String,
	author:String,
	duration:Float
}

typedef WsEvent = {
	type:WsEventType,
	?connected:{
		clients:Array<ClientData>,
		isUnknownClient:Bool,
		clientName:String,
		videoList:Array<VideoItem>
	},
	?login:{
		clientName:String,
		?clients:Array<ClientData>,
		?isUnknownClient:Bool,
	},
	?logout:{
		clientName:String,
		clients:Array<ClientData>,
	},
	?message:{
		clientName:String,
		text:String
	},
	?updateClients:{
		clients:Array<ClientData>,
	},
	?addVideo:{
		item:VideoItem
	},
	?removeVideo:{
		url:String
	},
	?pause:{
		time:Float
	},
	?play:{
		time:Float
	},
	?getTime:{
		time:Float,
		paused:Bool
	},
	?setTime:{
		time:Float
	},
	?setLeader:{
		clientName:String
	}
}

enum abstract WsEventType(String) {
	var Connected;
	var Login;
	var LoginError;
	var Logout;
	var Message;
	var UpdateClients;
	// var AddClient;
	// var RemoveClient;
	var AddVideo;
	var RemoveVideo;
	var VideoLoaded;
	var Pause;
	var Play;
	var GetTime;
	var SetTime;
	var SetLeader;
}
