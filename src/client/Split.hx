package client;

@:native("Split")
extern class Split {
	function new(divs:Array<String>, opts:Dynamic):Void;
	function setSizes(sizes:Array<Int>):Void;
}
