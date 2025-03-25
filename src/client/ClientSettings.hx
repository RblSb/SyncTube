package client;

import Types.PlayerType;

typedef ClientSettings = {
	var version:Int;
	var uuid:Null<String>;
	var name:String;
	var hash:String;
	var chatSize:Float;
	var synchThreshold:Int;
	var isSwapped:Bool;
	var isUserListHidden:Bool;
	var latestLinks:Array<String>;
	var latestSubs:Array<String>;
	var hotkeysEnabled:Bool;
	var showHintList:Bool;
	var checkboxes:Array<{id:String, checked:Null<Bool>}>;
	var checkedCache:Array<PlayerType>;
}
