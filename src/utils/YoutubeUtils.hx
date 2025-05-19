package utils;

class YoutubeUtils {
	static final matchId = ~/youtube\.com.*v=([A-z0-9_-]+)/;
	static final matchShort = ~/youtu\.be\/([A-z0-9_-]+)/;
	static final matchShorts = ~/youtube\.com\/shorts\/([A-z0-9_-]+)/;
	static final matchEmbed = ~/youtube\.com\/embed\/([A-z0-9_-]+)/;
	static final matchPlaylist = ~/youtube\.com.*list=([A-z0-9_-]+)/;

	public static function extractVideoId(url:String):String {
		if (matchId.match(url)) {
			return matchId.matched(1);
		}
		if (matchShort.match(url)) {
			return matchShort.matched(1);
		}
		if (matchShorts.match(url)) {
			return matchShorts.matched(1);
		}
		if (matchEmbed.match(url)) {
			return matchEmbed.matched(1);
		}
		return "";
	}

	public static function extractPlaylistId(url:String):String {
		if (!matchPlaylist.match(url)) return "";
		return matchPlaylist.matched(1);
	}
}
