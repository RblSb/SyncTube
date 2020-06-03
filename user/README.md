## User-specific config
You can create `config.json` file in this folder to override `default-config.json` options.
All root config fields are optional to override, so you need to create only what you want to change.
File example:
```json
{
	"channelName": "-=SuperChannel=-",
	"totalVideoLimit": 10
}
```
## User-specific resources
You can patch any file you want in project `res/` by creating `user/res/sameName` files.
For example `user/res/index.html` or `user/res/css/custom.css`.
You can also add any new files.

## Server commands
Server has input commands, for example, to set admin users. Simple enter anything to terminal after run to get command list.

## Other files here
- `state.json` - Saved state of latest server session (messages, videos, video time).
- `users.json` - Admin names with password hashes and random channel-specific salt. Do not share this file!
- `crashes/` - Latest error logs, when the server crashes.
- `logs/` - Latest activity logs, saved when the server shuts down.
