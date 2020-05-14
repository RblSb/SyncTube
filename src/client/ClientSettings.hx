package client;

typedef ClientSettings = {
	version:Int,
	name:String,
	hash:String,
	synchThreshold:Int,
	isSwapped:Bool,
	isUserListHidden:Bool,
	latestLinks:Array<String>,
	hotkeysEnabled:Bool
}
