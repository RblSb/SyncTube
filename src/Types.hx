package;

import Client.ClientData;

typedef VideoData = {
	duration:Float,
	?title:String
}

typedef Config = {
	channelName:String,
	maxLoginLength:Int,
	maxMessageLength:Int,
	serverChatHistory:Int,
	videoLimit:Int,
	leaderRequest:String,
	emotes:Array<Emote>,
	filters:Array<Filter>,
	?salt:String
};

typedef UserList = {
	admins:Array<UserField>,
	?salt:String
}

typedef UserField = {
	name:String,
	hash:String
}

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
	duration:Float,
	isTemp:Bool
}

typedef WsEvent = {
	type:WsEventType,
	?connected:{
		config:Config,
		history:Array<Message>,
		clients:Array<ClientData>,
		isUnknownClient:Bool,
		clientName:String,
		videoList:Array<VideoItem>,
		isPlaylistOpen:Bool,
		itemPos:Int,
		globalIp:String
	},
	?login:{
		clientName:String,
		?passHash:String,
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
	?skipVideo:{
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
	?playItem:{
		pos:Int
	},
	?setNextItem:{
		pos:Int
	},
	?toggleItemType:{
		pos:Int
	},
	?updatePlaylist:{
		videoList:Array<VideoItem>
	},
	?togglePlaylistLock:{
		isOpen:Bool
	}
}

enum abstract WsEventType(String) {
	var Connected;
	var Login;
	var PasswordRequest;
	var LoginError;
	var Logout;
	var Message;
	var UpdateClients;
	// var AddClient;
	// var RemoveClient;
	var AddVideo;
	var RemoveVideo;
	var SkipVideo;
	var VideoLoaded;
	var Pause;
	var Play;
	var GetTime;
	var SetTime;
	var Rewind;
	var SetLeader;
	var PlayItem;
	var SetNextItem;
	var ToggleItemType;
	var ClearChat;
	var ClearPlaylist;
	var ShufflePlaylist;
	var UpdatePlaylist;
	var TogglePlaylistLock;
}
