package utils;

typedef YoutubeVideoDetails = {
	viewCount:String,
	videoId:String,
	title:String,
	thumbnail:{
		thumbnails:Array<{
			url:String,
			width:Int,
			height:Int,
		}>
	},
	shortDescription:String,
	lengthSeconds:String,
	keywords:Array<String>,
	isUnpluggedCorpus:Bool,
	isPrivate:Bool,
	isOwnerViewing:Bool,
	isLiveContent:Bool,
	isCrawlable:Bool,
	channelId:String,
	author:String,
	allowRatings:Bool
}

typedef YoutubeVideoFormat = {
	?signatureCipher:String,
	itag:Int,
	width:Int,
	height:Int,
	url:String,
	qualityLabel:String, // 240p, 1080p, etc
	quality:String,
	projectionType:String,
	mimeType:String,
	lastModified:String,
	bitrate:Int,
	approxDurationMs:String,
	?initRange:{start:Int, end:Int},
	?indexRange:{start:Int, end:Int},
	?audioQuality:String, // AUDIO_QUALITY_LOW
	?audioSampleRate:Int,
	?audioChannels:Int,

	?container:String,
	?videoCodec:String,
	?audioCodec:String,
	?hasVideo:Bool,
	?hasAudio:Bool,
	?contentLength:String,
}

typedef YouTubeVideoInfo = {
	public var videoDetails:YoutubeVideoDetails;
	public var ?formats:Array<YoutubeVideoFormat>;
	public var ?adaptiveFormats:Array<YoutubeVideoFormat>;
	public var ?liveData:{
		manifestUrl:String,
	};
}

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
