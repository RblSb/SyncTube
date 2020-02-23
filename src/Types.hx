package;

import Client.ClientData;

typedef Config = {
	channelName:String,
	maxLoginLength:Int,
	maxMessageLength:Int,
	serverChatHistory:Int,
	videoLimit:Int,
	leaderRequest:String,
	emotes:Array<Emote>,
	filters:Array<Filter>
};

typedef Emote = {
	name:String,
	image:String
};

typedef Filter = {
	name:String,
	regex:String,
	flags:String,
	replace:String
};

typedef Message = {
	text:String,
	name:String,
	time:String
}

typedef VideoItem = {
	url:String,
	title:String,
	author:String,
	duration:Float
}

typedef WsEvent = {
	type:WsEventType,
	?connected:{
		config:Config,
		history:Array<Message>,
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
		oldClientName:String,
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
		item:VideoItem,
		atEnd:Bool
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
	?rewind:{
		time:Float
	},
	?setLeader:{
		clientName:String
	},
	?updatePlaylist:{
		videoList:Array<VideoItem>
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
	var Rewind;
	var SetLeader;
	var ClearChat;
	var ClearPlaylist;
	var ShufflePlaylist;
	var UpdatePlaylist;
}
