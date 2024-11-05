package tools;

import utils.ArrayKeyValueReverseIterator;
import utils.ArrayReverseIterator;

class ArrayTools {
	public static function last<T>(arr:Array<T>):Null<T> {
		return arr[arr.length - 1];
	}

	public static function min<T:Float>(arr:Array<T>, ?maxValue:T):T {
		var min = arr[0] ?? maxValue;
		for (value in arr) if (value < min) min = value;
		return min;
	}

	public static function max<T:Float>(arr:Array<T>, ?minValue:T):T {
		var max = arr[0] ?? minValue;
		for (value in arr) if (value > max) max = value;
		return max;
	}

	public static function indexOfMax<T:Float>(arr:Array<T>, ?minValue:T):Int {
		if (arr.length == 0) return -1;
		var max = arr[0] ?? minValue;
		var maxIndex = 0;
		for (i in 1...arr.length) {
			if (arr[i] > max) {
				maxIndex = i;
				max = arr[i];
			}
		}
		return maxIndex;
	}

	public static function sum<T:Float>(arr:Array<T>):T {
		var total:T = cast 0;
		for (value in arr) total += value;
		return total;
	}

	public static function shuffle<T>(arr:Array<T>):Void {
		for (i => a in arr) {
			final n = Std.random(arr.length);
			final b = arr[n];
			arr[i] = b;
			arr[n] = a;
		}
	}

	public static inline function reversed<T>(arr:Array<T>) {
		return new ArrayReverseIterator(arr);
	}

	/** Key-value reversed array iterator **/
	public static inline function reversedKV<T>(arr:Array<T>) {
		return new ArrayKeyValueReverseIterator(arr);
	}

	public static inline function findMin<T>(
		arr:Array<T>, f:(item:T) -> Float, maxValue:Float
	):Null<T> {
		var result:Null<T> = null;
		for (item in arr) {
			final dist = f(item);
			if (dist > maxValue) continue;
			maxValue = dist;
			result = item;
		}
		return result;
	}

	extern overload public static inline function inlineFind<T>(it:Array<T>, f:(item:T) -> Bool):Null<T> {
		var result:Null<T> = null;
		for (v in it) {
			if (f(v)) {
				result = v;
				break;
			}
		}
		return result;
	}

	extern overload public static inline function inlineFind<T>(it:Iterable<T>, f:(item:T) -> Bool):Null<T> {
		var result:Null<T> = null;
		for (v in it) {
			if (f(v)) {
				result = v;
				break;
			}
		}
		return result;
	}

	extern overload public static inline function inlineExists<T>(it:Array<T>, f:(item:T) -> Bool):Bool {
		var result = false;
		for (v in it) {
			if (f(v)) {
				result = true;
				break;
			}
		}
		return result;
	}

	extern overload public static inline function inlineExists<T>(it:Iterable<T>, f:(item:T) -> Bool):Bool {
		var result = false;
		for (v in it) {
			if (f(v)) {
				result = true;
				break;
			}
		}
		return result;
	}
}
