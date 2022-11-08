package;

import Client.ClientData;

typedef VideoDataRequest = {
	url:String,
	atEnd:Bool
}

typedef VideoData = {
	duration:Float,
	?title:String,
	?url:String,
	?subs:String,
	?isIframe:Bool
}

typedef Config = {
	port:Int,
	channelName:String,
	maxLoginLength:Int,
	maxMessageLength:Int,
	serverChatHistory:Int,
	totalVideoLimit:Int,
	userVideoLimit:Int,
	requestLeaderOnPause:Bool,
	localAdmins:Bool,
	allowProxyIps:Bool,
	localNetworkOnly:Bool,
	templateUrl:String,
	youtubeApiKey:String,
	youtubePlaylistLimit:Int,
	permissions:Permissions,
	emotes:Array<Emote>,
	filters:Array<Filter>,
	?isVerbose:Bool,
	?salt:String
}

typedef Permissions = {
	banned:Array<Permission>,
	guest:Array<Permission>,
	user:Array<Permission>,
	leader:Array<Permission>,
	admin:Array<Permission>
}

enum abstract Permission(String) {
	var GuestPerm = "guest";
	var UserPerm = "user";
	var LeaderPerm = "leader";
	var AdminPerm = "admin";
	var WriteChatPerm = "writeChat";
	var AddVideoPerm = "addVideo";
	var RemoveVideoPerm = "removeVideo";
	var RequestLeaderPerm = "requestLeader";
	var RewindPerm = "rewind";
	var ClearChatPerm = "clearChat";
	var SetLeaderPerm = "setLeader";
	var ChangeOrderPerm = "changeOrder";
	var ToggleItemTypePerm = "toggleItemType";
	var LockPlaylistPerm = "lockPlaylist";
	var BanClientPerm = "banClient";
}

typedef UserList = {
	admins:Array<UserField>,
	bans:Array<BanField>,
	?salt:String
}

typedef UserField = {
	name:String,
	hash:String
}

typedef BanField = {
	ip:String,
	toDate:Date
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
	?subs:String,
	isTemp:Bool,
	isIframe:Bool
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
	?serverMessage:{
		textId:String
	},
	?updateClients:{
		clients:Array<ClientData>,
	},
	?banClient:{
		name:String,
		time:Float
	},
	?kickClient:{
		name:String,
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
		?paused:Bool,
		?rate:Float
	},
	?setTime:{
		time:Float
	},
	?setRate:{
		rate:Float
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
	},
	?dump:{
		data:String
	}
}

enum abstract WsEventType(String) {
	var Connected;
	var Disconnected;
	var Login;
	var PasswordRequest;
	var LoginError;
	var Logout;
	var Message;
	var ServerMessage;
	var UpdateClients;
	// var AddClient;
	// var RemoveClient;
	var BanClient;
	var KickClient;
	var AddVideo;
	var RemoveVideo;
	var SkipVideo;
	var VideoLoaded;
	var Pause;
	var Play;
	var GetTime;
	var SetTime;
	var SetRate;
	var Rewind;
	var Flashback;
	var SetLeader;
	var PlayItem;
	var SetNextItem;
	var ToggleItemType;
	var ClearChat;
	var ClearPlaylist;
	var ShufflePlaylist;
	var UpdatePlaylist;
	var TogglePlaylistLock;
	var Dump;
}
