package client;

@:native("Split")
extern class Split {
	function new(divs:Array<String>, opts:Dynamic):Void;
	function getSizes():Array<Int>;
	function setSizes(sizes:Array<Int>):Void;
	function collapse(index:Int):Void;
	function destroy(?preserveStyles:Bool = false, ?preserveGutters:Bool = false):Void;
}