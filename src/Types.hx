package;

import Client.ClientData;

enum abstract PlayerType(String) {
	var RawType;
	var YoutubeType;
	var VkType;
	var IframeType;
}

typedef VideoDataRequest = {
	final url:String;
	final atEnd:Bool;
}

typedef UploadResponse = {
	info:String,
	?url:String,
	?errorId:String,
}

typedef VideoData = {
	final duration:Float;
	var ?title:String;
	var ?url:String;
	var ?subs:String;
	var ?voiceOverTrack:String;
	var ?playerType:PlayerType;
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
	unpauseWithoutLeader:Bool,
	localAdmins:Bool,
	allowProxyIps:Bool,
	localNetworkOnly:Bool,
	sslKeyPemPath:String,
	sslCertPemPath:String,
	templateUrl:String,
	youtubeApiKey:String,
	youtubePlaylistLimit:Int,
	cacheStorageLimitGiB:Float,
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

enum abstract ProgressType(String) {
	var Caching;
	var Downloading;
	var Uploading;
	var Canceled;
}

@:using(Types.VideoItemTools)
typedef VideoItem = {
	/** Immutable, used as identifier for skipping / removing items **/
	final url:String;
	var title:String;
	var author:String;
	var duration:Float;
	var ?subs:String;
	var ?voiceOverTrack:String;
	var isTemp:Bool;
	var doCache:Bool;
	var playerType:PlayerType;
}

private class VideoItemTools {
	public static function withUrl(item:VideoItem, url:String):VideoItem {
		return {
			url: url,
			title: item.title,
			author: item.author,
			duration: item.duration,
			subs: item.subs,
			voiceOverTrack: item.voiceOverTrack,
			isTemp: item.isTemp,
			doCache: item.doCache,
			playerType: item.playerType
		};
	}
}

typedef FlashbackItem = {
	url:String,
	duration:Float,
	time:Float
}

typedef GetTimeEvent = {
	time:Float,
	?paused:Bool,
	?pausedByServer:Bool,
	?rate:Float
}

typedef WsEvent = {
	type:WsEventType,
	?connected:{
		uuid:String,
		config:Config,
		history:Array<Message>,
		clients:Array<ClientData>,
		isUnknownClient:Bool,
		clientName:String,
		videoList:Array<VideoItem>,
		isPlaylistOpen:Bool,
		itemPos:Int,
		globalIp:String,
		playersCacheSupport:Array<PlayerType>,
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
	?progress:{
		type:ProgressType,
		ratio:Float,
		?data:String
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
	?getTime:GetTimeEvent,
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
	},
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
	var Progress;
	var UpdateClients;
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
	var CrashTest;
}
