package;

import Types.VideoItem;

using Lambda;

class VideoList {
	public var length(get, never):Int;
	public var pos(default, null) = 0;
	public var isOpen = true;

	final items:Array<VideoItem> = [];

	public function new() {}

	inline function get_length():Int {
		return items.length;
	}

	public inline function getCurrentItem():VideoItem {
		return items[pos];
	}

	public inline function getItem(i:Int):VideoItem {
		return items[i];
	}

	public inline function setItem(i:Int, item:VideoItem):Void {
		items[i] = item;
	}

	public inline function getItems():Array<VideoItem> {
		return items;
	}

	public function setItems(items:Array<VideoItem>):Void {
		clear();
		for (item in items)
			this.items.push(item);
	}

	public function setPos(i:Int):Void {
		if (i < 0 || i > length - 1) i = 0;
		pos = i;
	}

	public function exists(f:(item:VideoItem) -> Bool):Bool {
		return items.exists(f);
	}

	public function findIndex(f:(item:VideoItem) -> Bool):Int {
		var i = 0;
		for (v in items) {
			if (f(v)) return i;
			i++;
		}
		return -1;
	}

	public function addItem(item:VideoItem, atEnd:Bool):Void {
		if (atEnd) items.push(item);
		else items.insert(pos + 1, item);
	}

	public function setNextItem(nextPos:Int):Void {
		final next = items[nextPos];
		items.remove(next);
		if (nextPos < pos) pos--;
		items.insert(pos + 1, next);
	}

	public function toggleItemType(pos:Int):Void {
		items[pos].isTemp = !items[pos].isTemp;
	}

	public function removeItem(index:Int):Void {
		if (index < pos) pos--;
		items.remove(items[index]);
		if (pos >= items.length) pos = 0;
	}

	public function skipItem():Void {
		final item = items[pos];
		if (!item.isTemp) pos++;
		else items.remove(item);
		if (pos >= items.length) pos = 0;
	}

	public function itemsByUser(client:Client):Int {
		var i = 0;
		for (item in items) {
			if (item.author == client.name) i++;
		}
		return i;
	}

	public inline function clear():Void {
		items.resize(0);
		pos = 0;
	}

	public function shuffle() {
		final current = items[pos];
		items.remove(current);
		shuffleArray(items);
		items.insert(pos, current);
	}

	function shuffleArray<T>(arr:Array<T>):Void {
		for (i => a in arr) {
			final n = Std.random(arr.length);
			final b = arr[n];
			arr[i] = b;
			arr[n] = a;
		}
	}
}
