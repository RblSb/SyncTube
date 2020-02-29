package client;

import Types.VideoData;
import Types.VideoItem;

interface IPlayer {
	function getVideoData(url:String, callback:(data:VideoData)->Void):Void;
	function loadVideo(item:VideoItem):Void;
	function removeVideo():Void;
	function play():Void;
	function pause():Void;
	function getTime():Float;
	function setTime(time:Float):Void;
}
