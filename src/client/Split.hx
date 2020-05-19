package client;

@:native("Split")
extern class Split {
	function new(options:Any):Void;
	function destroy(?immediate:Bool = true):Void;
}
