package server;

import Types.Message;
import Types.VideoItem;

typedef ServerState = {
	videoList:Array<VideoItem>,
	isPlaylistOpen:Bool,
	itemPos:Int,
	messages:Array<Message>,
	timer:{
		time:Float, paused:Bool
	}
}
