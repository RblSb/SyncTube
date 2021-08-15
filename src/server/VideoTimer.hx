package server;

import haxe.Timer.stamp;

class VideoTimer {
	public var isStarted(default, null) = false;

	var startTime = 0.0;
	var pauseStartTime = 0.0;
	var rateStartTime = 0.0;
	var rate = 1.0;

	public function new() {}

	public function start():Void {
		isStarted = true;
		startTime = stamp();
		pauseStartTime = 0;
		rateStartTime = stamp();
	}

	public function stop():Void {
		isStarted = false;
		startTime = 0;
		pauseStartTime = 0;
	}

	public function pause():Void {
		startTime += rateTime() - rateTime() * this.rate;
		pauseStartTime = stamp();
		rateStartTime = 0;
	}

	public function play():Void {
		if (!isStarted) start();
		startTime += pauseTime();
		pauseStartTime = 0;
		rateStartTime = stamp();
	}

	public function getTime():Float {
		if (startTime == 0) return 0;
		final time = stamp() - startTime;
		return time - rateTime() + rateTime() * rate - pauseTime();
	}

	public function setTime(secs:Float):Void {
		startTime = stamp() - secs;
		rateStartTime = stamp();
		if (isPaused()) pause();
	}

	public function isPaused():Bool {
		return !isStarted || pauseStartTime != 0;
	}

	public function getRate():Float {
		return rate;
	}

	public function setRate(rate:Float):Void {
		if (!isPaused()) {
			startTime += rateTime() - rateTime() * this.rate;
			rateStartTime = stamp();
		}
		this.rate = rate;
	}

	function pauseTime():Float {
		if (pauseStartTime == 0) return 0;
		return stamp() - pauseStartTime;
	}

	function rateTime():Float {
		if (rateStartTime == 0) return 0;
		return stamp() - rateStartTime - pauseTime();
	}
}
