package client;

import js.html.InputElement;
import js.html.KeyboardEvent;

class InputWithHistory {
	final element:InputElement;
	final maxItems:Int;
	final history:Array<String>;
	final onEnter:(value:String) -> Bool;
	var historyId = -1;

	public function new(
		element:InputElement,
		?history:Array<String>,
		maxItems:Int,
		onEnter:(value:String) -> Bool
	) {
		this.element = element;
		if (history != null) this.history = history;
		else this.history = [];
		this.maxItems = maxItems;
		this.onEnter = onEnter;
		element.onkeydown = onKeyDown;
	}

	public static function pushIfNotLast(arr:Array<String>, item:String):Void {
		final len = arr.length;
		if (len == 0 || arr[len - 1] != item) arr.push(item);
	}

	function onKeyDown(e:KeyboardEvent) {
		final key:KeyCode = cast e.keyCode;
		switch (key) {
			case Return:
				final value = element.value;
				if (value.length == 0) return;
				final isAdd = onEnter(value);
				if (isAdd) pushIfNotLast(history, value);
				if (history.length > maxItems) history.shift();
				historyId = -1;
				element.value = "";
				onInput();
			case Up:
				historyId--;
				if (historyId == -2) {
					historyId = history.length - 1;
					if (historyId == -1) return;
				} else if (historyId == -1) historyId++;
				element.value = history[historyId];
				onInput();
			case Down:
				if (historyId == -1) return;
				historyId++;
				if (historyId > history.length - 1) {
					historyId = -1;
					element.value = "";
				} else {
					element.value = history[historyId];
				}
				onInput();
			default:
		}
	}

	function onInput():Void {
		if (element.oninput != null) element.oninput();
	}
}
