## User-specific config
You can create `config.json` file in this folder to override `default-config.json` options.
All root config fields are optional to override, so you need to create only what you want to change.
File example:
```json
{
	"channelName": "-=SuperChannel=-",
	"videoLimit": 10,
}
```
## User-specific resources
You can patch any file you want in project `res/` by creating `user/res/sameName` files.
For example `user/res/index.html` or `user/res/css/custom.css`.
You can also add any new files.
## Other files here
- `state.json` - saved state of latest server session (messages, videos, video time).
- `logs/` - latest 10 logs. You can change count in config.
- `crashes/` - folder with latest error logs, when the server had to restart itself.
