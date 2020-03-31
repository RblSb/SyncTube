package server;

import haxe.Timer;

class VideoTimer {

	public var isStarted(default, null) = false;
	var startTime = 0.0;
	var pauseStartTime = 0.0;

	public function new() {}

	public function start():Void {
		isStarted = true;
		startTime = Timer.stamp();
		pauseStartTime = 0;
	}

	public function stop():Void {
		isStarted = false;
		startTime = 0;
		pauseStartTime = 0;
	}

	public function pause():Void {
		pauseStartTime = Timer.stamp();
	}

	public function play():Void {
		if (!isStarted) start();
		startTime += pauseTime();
		pauseStartTime = 0;
	}

	public function getTime():Float {
		if (startTime == 0) return 0;
		return Timer.stamp() - startTime - pauseTime();
	}

	public function setTime(secs:Float):Void {
		startTime = Timer.stamp() - secs;
		if (isPaused()) pause();
	}

	public function isPaused():Bool {
		return !isStarted || pauseStartTime != 0;
	}

	function pauseTime():Float {
		if (pauseStartTime == 0) return 0;
		return Timer.stamp() - pauseStartTime;
	}

}
