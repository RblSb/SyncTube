package client;

typedef ClientSettings = {
	version:Int,
	name:String,
	hash:String,
	isExtendedPlayer:Bool,
	chatSize:Int,
	playerSize:Int,
	synchThreshold:Int,
	isSwapped:Bool,
	isUserListHidden:Bool,
	latestLinks:Array<String>,
	hotkeysEnabled:Bool
}
