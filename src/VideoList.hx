package;

import Types.VideoItem;

// TODO move itemPos to abstract
// typedef VideoListData = {
// 	items:Array<VideoItem>,
// 	itemPos:Int
// }

@:forward
abstract VideoList(Array<VideoItem>) from Array<VideoItem> to Array<VideoItem> {

	public function new() {
		this = [];
	}

	@:arrayAccess
	public inline function get(i:Int):VideoItem {
		return this[i];
	}

	@:arrayAccess
	public inline function set(k:Int, v:VideoItem):VideoItem {
		return this[k] = v;
	}

	public function findIndex(f:(item:VideoItem) -> Bool):Int {
		var i = 0;
		for (v in this) {
			if (f(v)) return i;
			i++;
		}
		return -1;
	}

	public function addItem(item:VideoItem, atEnd:Bool, itemPos:Int):Void {
		if (atEnd) this.push(item);
		else this.insert(itemPos + 1, item);
	}

	public function setNextItem(pos:Int, itemPos:Int):Int {
		final next = this[pos];
		this.remove(next);
		if (pos < itemPos) itemPos--;
		this.insert(itemPos + 1, next);
		return itemPos;
	}

	public function toggleItemType(pos:Int):Void {
		this[pos].isTemp = !this[pos].isTemp;
	}

	public function removeItem(index:Int, itemPos:Int):Int {
		if (index < itemPos) itemPos--;
		this.remove(this[index]);
		if (itemPos >= this.length) itemPos = 0;
		return itemPos;
	}

	public function skipItem(itemPos:Int):Int {
		final item = this[itemPos];
		if (!item.isTemp) itemPos++;
		else this.remove(item);
		if (itemPos >= this.length) itemPos = 0;
		return itemPos;
	}

	public function itemsByUser(client:Client):Int {
		var i = 0;
		for (item in this) if (item.author == client.name) i++;
		return i;
	}

}
