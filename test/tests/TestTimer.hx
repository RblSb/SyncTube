package test.tests;

import haxe.PosInfos;
import haxe.Timer;
import server.VideoTimer;
import utest.Assert;
import utest.Async;
import utest.Test;

class TestTimer extends Test {
	@:timeout(500)
	function testMain(async:Async) {
		final timer = new VideoTimer();
		timer.start();
		Timer.delay(() -> {
			almostEq(0.1, timer.getTime());
			timer.setTime(1);
			almostEq(1, timer.getTime());
		}, 100);
		Timer.delay(() -> {
			almostEq(1.1, timer.getTime());
			timer.setTime(0.1);
			almostEq(0.1, timer.getTime());
		}, 200);
		Timer.delay(() -> {
			almostEq(0.2, timer.getTime());
			Assert.equals(false, timer.isPaused());
			Assert.equals(true, timer.isStarted);
			timer.stop();
			Assert.equals(0, timer.getTime());
			Assert.equals(true, timer.isPaused());
			Assert.equals(false, timer.isStarted);
			timer.start();
			timer.setRate(3);
		}, 300);
		Timer.delay(() -> {
			almostEq(0.3, timer.getTime());
			timer.setTime(0.1);
			almostEq(0.1, timer.getTime());
			async.done();
		}, 400);
	}

	@:timeout(500)
	function testRate(async:Async) {
		final timer = new VideoTimer();
		timer.start();
		timer.setRate(2);
		almostEq(0, timer.getTime());
		Timer.delay(() -> {
			almostEq(0.2, timer.getTime());
			timer.setRate(1);
			almostEq(0.2, timer.getTime());
		}, 100);
		Timer.delay(() -> {
			almostEq(0.3, timer.getTime());
			timer.setRate(2);
			almostEq(0.3, timer.getTime());
		}, 200);
		Timer.delay(() -> {
			almostEq(0.5, timer.getTime());
			timer.pause();
			almostEq(0.5, timer.getTime());
			Assert.equals(true, timer.isPaused());
			Assert.equals(true, timer.isStarted);
		}, 300);
		Timer.delay(() -> {
			almostEq(0.5, timer.getTime());
			Assert.equals(true, timer.isPaused());
			Assert.equals(true, timer.isStarted);
			async.done();
		}, 400);
	}

	@:timeout(500)
	function testRatePause(async:Async) {
		final timer = new VideoTimer();
		timer.start();
		timer.setRate(2);
		timer.setTime(1);
		almostEq(1, timer.getTime());
		Timer.delay(() -> {
			almostEq(1.2, timer.getTime());
			timer.pause();
			almostEq(1.2, timer.getTime());
		}, 100);
		Timer.delay(() -> {
			almostEq(1.2, timer.getTime());
			timer.play();
			almostEq(1.2, timer.getTime());
		}, 200);
		Timer.delay(() -> {
			almostEq(1.4, timer.getTime());
			timer.pause();
			almostEq(1.4, timer.getTime());
			timer.setRate(3);
		}, 300);
		Timer.delay(() -> {
			almostEq(1.4, timer.getTime());
			timer.play();
			almostEq(1.4, timer.getTime());
			timer.setRate(1);
			almostEq(1.4, timer.getTime());
			async.done();
		}, 400);
	}

	@:timeout(500)
	function testPauseRate(async:Async) {
		final timer = new VideoTimer();
		timer.start();
		timer.setTime(100);
		timer.pause();
		Timer.delay(() -> {
			almostEq(100, timer.getTime());
			timer.setRate(2);
			almostEq(100, timer.getTime());
		}, 100);
		Timer.delay(() -> {
			almostEq(100, timer.getTime());
			timer.setRate(1);
			almostEq(100, timer.getTime());
		}, 200);
		Timer.delay(() -> {
			almostEq(100, timer.getTime());
			timer.setRate(2);
			almostEq(100, timer.getTime());
			timer.play();
			almostEq(100, timer.getTime());
		}, 300);
		Timer.delay(() -> {
			almostEq(100.2, timer.getTime());
			timer.setRate(1);
			almostEq(100.2, timer.getTime());
			async.done();
		}, 400);
	}

	@:timeout(500)
	function testBigRate(async:Async) {
		final timer = new VideoTimer();
		timer.start();
		timer.setRate(3);
		timer.setTime(10);
		almostEq(10, timer.getTime());
		Timer.delay(() -> {
			almostEq(10.3, timer.getTime());
		}, 100);
		Timer.delay(() -> {
			almostEq(10.6, timer.getTime());
			timer.pause();
			almostEq(10.6, timer.getTime());
		}, 200);
		Timer.delay(() -> {
			almostEq(10.6, timer.getTime());
			timer.play();
			almostEq(10.6, timer.getTime());
		}, 300);
		Timer.delay(() -> {
			almostEq(10.9, timer.getTime());
			timer.setRate(1);
			almostEq(10.9, timer.getTime());
			async.done();
		}, 400);
	}

	function almostEq(a:Float, b:Float, ?p:PosInfos):Void {
		if (isMacCI()) {
			Assert.isTrue(Math.abs(a - b) < 0.5);
			return;
		}
		Assert.equals(Math.round(a * 10) / 10, Math.round(b * 10) / 10, p);
	}

	function isMacCI():Bool {
		return Sys.systemName() == "Mac" && Sys.environment()["CI"] == "true";
	}
}
