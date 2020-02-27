package client;

import Types.VideoItem;

interface IPlayer {
	function loadVideo(item:VideoItem):Void;
	function removeVideo():Void;
	function play():Void;
	function pause():Void;
	function getTime():Float;
	function setTime(time:Float):Void;
}
