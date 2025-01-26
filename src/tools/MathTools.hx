package tools;

class MathTools {
	public static inline function clamp<T:Float>(v:T, min:T, max:T):T {
		return v < min ? min : v > max ? max : v;
	}

	public static inline function lerp(ratio:Float, a:Float, b:Float):Float {
		return a + ratio * (b - a);
	}

	public static inline function sign(v:Float):Int {
		if (v == 0) return 0;
		return v < 0 ? -1 : 1;
	}

	public static inline function abs<T:Float>(v:T):T {
		return cast Math.abs(v);
	}

	public static inline function pow<T:Float>(v:T, exp:T):T {
		return cast Math.pow(v, exp);
	}

	public static inline function limitMin<T:Float>(a:T, b:T):T {
		return a < b ? b : a;
	}

	public static inline function limitMax<T:Float>(a:T, b:T):T {
		return a > b ? b : a;
	}

	public static inline function wrapAround<T:Float>(v:T, min:T, max:T):T {
		if (min == max) return min;
		final range = max - min + 1;
		return min + (((v - min) % range) + range) % range;
	}

	public static function toFixed(v:Float, digits = 2):Float {
		if (digits > 8) throw 'digits is $digits, but cannot be bigger than 8 (for value $v)';
		final ratio = Math.pow(10, digits);
		return Std.int(v * ratio) / ratio;
	}

	public static function toBitString(value:Int):String {
		var result = "";
		var mask = 1;
		for (i in 0...32) { // 32-bit integer
			result = (value & mask != 0 ? "1" : "0") + result;
			mask <<= 1;
		}
		final i = result.indexOf("1");
		return i > 0 ? result.substr(i) : result;
	}
}
