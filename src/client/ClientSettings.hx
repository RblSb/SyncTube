package client;

typedef ClientSettings = {
	version:Int,
	name:String,
	hash:String,
	isExtendedPlayer:Bool,
	playerSize:Float,
	chatSize:Float,
	synchThreshold:Int,
	isSwapped:Bool,
	isUserListHidden:Bool,
	latestLinks:Array<String>,
	latestSubs:Array<String>,
	hotkeysEnabled:Bool
}
