package client;

import js.html.KeyboardEvent;
import js.html.InputElement;

class InputWithHistory {

	final element:InputElement;
	final maxItems:Int;
	final history:Array<String>;
	final onEnter:(value:String)->Bool;
	var historyId = -1;

	public function new(
		element:InputElement, ?history:Array<String>, maxItems:Int,
		onEnter:(value:String)->Bool
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
		switch (e.keyCode) {
			case 13: // Enter
				final value = element.value;
				if (value.length == 0) return;
				final isAdd = onEnter(value);
				if (isAdd) pushIfNotLast(history, value);
				if (history.length > maxItems) history.shift();
				historyId = -1;
				element.value = "";
			case 38: // Up
				historyId--;
				if (historyId == -2) {
					historyId = history.length - 1;
					if (historyId == -1) return;
				} else if (historyId == -1) historyId++;
				element.value = history[historyId];
			case 40: // Down
				if (historyId == -1) return;
				historyId++;
				if (historyId > history.length - 1) {
					historyId = -1;
					element.value = "";
					return;
				}
				element.value = history[historyId];
		}
	}

}
