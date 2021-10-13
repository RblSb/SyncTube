package server;

import Types.WsEvent;

typedef ServerEvent = {
	time:String,
	clientName:String,
	clientGroup:Int,
	event:WsEvent
}
