# <img src="./res/img/favicon.svg" width="40" height="40" align="top"> SyncTube
Synchronized video viewing with chat and other features.
Lightweight modern implementation and a very easy way to run locally.

Default channel example: https://synctube.onrender.com/

## Features
- Control video playback for all users with active `Leader` button
- Start watching local videos while uploading them to the server, before upload completes
- External `vtt`/`srt`/`ass` subtitles support
- External audiotrack / voiceover support
- `/30`, `/-21`, etc chat commands to rewind video playback by seconds
- [Hotkeys](#hotkeys) (`Alt-P` for global play/pause, etc)
- Compact view button with page fullscreen on Android
- Playback rate synchronization (with leader)
- Links mask: `foo.com/bar${1-4}.mp4` to add multiple items
- Override every front-end file you want (`user/res` folder)
- [Native mobile client](https://github.com/RblSb/SyncTubeApp)

### Easier playback controls for smaller groups
- Enable `requestLeaderOnPause` to allow global pause by any user, without `Leader` button
- Enable `unpauseWithoutLeader` to allow global unpause for non-leaders

## Supported players
- Youtube (videos, shorts, streams and playlists)
- Twitch (streams)
- Vimeo
- [Streamable](https://streamable.com)
- [VK](https://vk.com/video)
- [Peertube](https://joinpeertube.org) (with `pt:` url prefix)
- Raw mp4 videos and m3u8 playlists (or any other media format supported in browser)
- Iframes (without sync)

## Setup
- Open `4200` port in your router settings (port is customizable)
- `npm ci` in this project folder ([NodeJS 14+](https://nodejs.org) required)
- Run `node build/server.js`
- Open showed "Local" link for yourself and send "Global" link to friends

## Setup (Docker)
As alternative, you can install Docker and run:
> ```shell
> docker build -t synctube .
> docker run --rm -it -p 4200:4200 -v ${PWD}/user:/app/user synctube
> ```

or

> ```shell
> docker compose up -d
> ```

- (Docker container hides real local/global ips, so you need to checkout it manually)

## Setup (NixOS)
A [NixOS module](nix/README.md) is included: it packages the project (Haxe build, no npm/haxelib network access at build time beyond pinned tarballs), assembles a writable runtime tree under `/var/lib/synctube` at service start and runs a hardened systemd service:
```nix
 services.synctube = {
   enable = true;
   openFirewall = true;
   enableYtDlp = true; # optional "Cache on server" (yt-dlp + ffmpeg)
   settings.channelName = "-=SuperChannel=-";
 };
```
For a one-off local run without NixOS: `nix-run github:RblSb/SyncTube` (see [nix/README.md](nix/README.md)).

## Optional dependencies
If you want to enable `Cache on server` feature for Youtube and other [supported sites](https://github.com/yt-dlp/yt-dlp/blob/master/supportedsites.md), you can also run:
```shell
npm i https://github.com/RblSb/ytdlp-nodejs
```
And install `ffmpeg/ffprobe` on your server system. Default cache size is 3.0 GiB.

## Configuration
It just works, but you can also check [user/ folder](/user/README.md) for server settings and additional customization.

## How to use
- Login with any nickname
- Add your video url with "plus" button below (youtube or direct link to mp4 for example)
- Now it plays and syncs for all page users, well done
- You can click "leader" button to get access to global video controls (play/pause, seeking, playback speed)
- If you want to restrict permissions or add admins/emotes, see `Configuration` above

## Chat commands
- `/1h9m54` - Command format to rewind video by `1 hour 9 minutes 54 seconds`
- `/-1h9m54` - Same, but rewinds back
- `/ad` - Rewind sponsored block in active YouTube video
- `/fb` (`/flashback`) - Rewind video to a prev time if someone rewinded/restarted video accidentally
- `/volume 2.6` - Change player volume in `0-1` range or boost it in `0-3` range for quiet videos
- `/clear` - Clear chat. Admin clears chat globally
- `/help` - Show initial tutorial message

### Admins only:

- `/ban Guest 1 2h` - Ban user `Guest 1` ip for `2 hours`
- `/unban Foo` - Unban user `Foo`
- `/kick Foo` - Force `Foo` disconnection until page reload
- `/dump` - Download state dump to report issues
- `/crash` - Crash server if you need to test your auto-restart solution

### Hotkeys
- `Alt-L` - Request leader
- `Alt-P` - Request leader and toggle pause/play for everyone
- `Alt-R` - Refresh player
- `Alt-F` - Fullscreen player
- `Alt-S` - Vote for skip
- `Alt-C` - Retrieve playlist links
- `Alt-U` - Toggle video synchronization
- `Alt-click` on playlist item lock icon - Make all items permanent/temporary

## Plugins
- [octosubs](https://github.com/RblSb/SyncTube-octosubs) - More colorful `ASS`/`SSA` subtitles support
- [qswitcher](https://github.com/aNNiMON/SyncTube-QSwitcher) - Raw video quality switcher

## Integrations
### Platform services without permanent storage:
- Create app and commit repo to get build
- Remove `user/` folder from `.gitignore` and commit it to change default configuration
- Add `APP_URL` config var with `your-app-link.herokuapp.com` value if you need to prevent sleeping when clients online

## Development
- Install [Haxe 4.3](https://haxe.org/download/), [VSCode](https://code.visualstudio.com) and [Haxe extension](https://marketplace.visualstudio.com/items?itemName=nadako.vshaxe)
- `haxelib install all` to install extern libs
- If you skipped `Setup` section before: `npm ci`
- Open project in VSCode and press `F5` for client+server build and run

## About
- [Redesign](https://github.com/RblSb/SyncTube/pull/5) by Austin Riddell
- [Original idea](https://github.com/calzoneman/sync) by Calvin Montgomery
- Default emotes by [emlan](https://www.deviantart.com/emlan)
