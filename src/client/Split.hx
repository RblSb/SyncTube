package client;

import client.Main.getEl;
import js.Browser.document;

@:native("Split")
private extern class JsSplit {
	function new(options:Any):Void;
	function destroy(?immediate:Bool = true):Void;
}

class Split {
	static inline var CHAT_MIN_SIZE = 200;

	final settings:ClientSettings;
	final split:JsSplit;

	public function new(settings:ClientSettings) {
		this.settings = settings;
		split = new JsSplit({
			columnGutters: [{
				element: getEl(".gutter"),
				track: 1,
			}],
			minSize: CHAT_MIN_SIZE,
			snapOffset: 0,
			onDragEnd: saveSize
		});
	}

	public function setSize(chatSize:Float):Void {
		if (chatSize < CHAT_MIN_SIZE) return;
		final sizes = document.body.style.gridTemplateColumns.split(" ");
		final chatId = settings.isSwapped ? 0 : sizes.length - 1;
		sizes[chatId] = '${chatSize}px';
		document.body.style.gridTemplateColumns = sizes.join(" ");
	}

	function saveSize():Void {
		final sizes = document.body.style.gridTemplateColumns.split(" ");
		if (settings.isSwapped) sizes.reverse();
		settings.chatSize = Std.parseFloat(sizes[sizes.length - 1]);
		Settings.write(settings);
	}

	public function destroy():Void {
		split.destroy();
	}
}
