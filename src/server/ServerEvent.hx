package server;

import Types.WsEvent;

typedef ServerEvent = {
	time:Float,
	clientName:String,
	clientGroup:Int,
	event:WsEvent
}
