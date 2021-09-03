package test.tests;

import js.node.Http;
import server.Main;
import utest.Assert;
import utest.Async;
import utest.Test;

@:access(server)
class TestServer extends Test {
	@:timeout(500)
	function testBadRequests(async:Async) {
		final server = new Main();
		server.onServerInited = () -> {
			final url = 'http://${server.localIp}:${server.port}';
			request('$url/你好，世界!@$^&*)_+-=', data -> {
				Assert.equals("File 你好，世界!@$^&*)_+-= not found.", data);
			});
			request('$url/Привет%00мир!', data -> {
				Assert.equals("File Приветмир! not found.", data);
			});
			request('$url/Ы%ы%00ы!', data -> {
				Assert.equals("File %D0%AB%%D1%8B%00%D1%8B! not found.", data);
			});
			request('$url/video/skins/default.php?dir_inc=/etc/passwd%00', data -> {
				Assert.equals("File video/skins/default.php?dir_inc=/etc/passwd not found.", data);
			});
			request('$url/%20', data -> {
				Assert.equals("File   not found.", data);
			});
			request('$url/build/../../server.js', data -> {
				Assert.equals("File server.js not found.", data);
				async.done();
			});
		}
	}

	function request(url:String, onComplete:(data:String) -> Void):Void {
		Http.get(url, r -> {
			r.setEncoding("utf8");
			final data = new StringBuf();
			r.on("data", chunk -> data.add(chunk));
			r.on("end", _ -> onComplete(data.toString()));
		}).on("error", e -> trace(e));
	}
}
