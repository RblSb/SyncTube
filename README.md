# <img src="./res/img/favicon.svg" height="40" align="top"> SyncTube
Synchronized video viewing with chat and other features.
Lightweight modern implementation and a very easy way to run locally.

Default channel example: https://synctube.onrender.com/

## Features
- Control video playback for all users with active `Leader` button
- Start watching local videos while uploading them to the server, before upload completes
- External `vtt`/`srt`/`ass` subtitles support
- External audiotrack / voiceover support
- `/30`, `/-21`, etc chat commands to rewind video playback by seconds
- Hotkeys (`Alt-P` for global play/pause, [etc](https://github.com/RblSb/SyncTube/blob/382f9b2ebedca905028341825350a0fa69d88673/src/client/Buttons.hx#L416-L427))
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
- [Streamable](https://streamable.com)
- [VK](https://vk.com/video)
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
> docker run --rm -it -p 4200:4200 -v ${PWD}/user:/usr/src/app/user synctube
> ```

or

> ```shell
> docker compose up -d
> ```

- (Docker container hides real local/global ips, so you need to checkout it manually)


## Optional dependencies
If you want to enable `Cache on server` feature for Youtube player, you can also run:
```shell
npm i @distube/ytdl-core@latest
```
And install `ffmpeg` on your server system, it's only used to build single mp4 from downloaded audio/video tracks. Default cache size is 3.0 GiB.

## Configuration
It's just works, but you can also check [user/ folder](/user/README.md) for server settings and additional customization.

## How to use
- Login with any nickname
- Add your video url with "plus" button below (youtube or direct link to mp4 for example)
- Now it plays and syncs for all page users, well done
- You can click "leader" button to get access to global video controls (play/pause, seeking, playback speed)
- If you want to restrict permissions or add admins/emotes, see `Configuration` above

## Chat commands
- `/-1h9m54` - Command format to rewind video **back** by `1 hour 9 minutes 54 seconds`
- `/ad` - Rewind sponsored block in active YouTube video
- `/fb` (`/flashback`) - rewind video to a prev time if someone rewinded/restarted video accidentally
- `/clear` - Clear chat. Admin clears chat globally
- `/help` - Show initial tutorial message

### Admins only:

- `/ban Guest 1 2h` - Ban user `Guest 1` ip for `2 hours`
- `/unban Foo` (`/removeBan`) - Unban user `Foo`
- `/kick Foo` - Force `Foo` disconnection until page reload
- `/dump` - Download state dump to report issues

## Plugins
- [octosubs](https://github.com/RblSb/SyncTube-octosubs) - More colorful `ASS`/`SSA` subtitles support
- [qswitcher](https://github.com/aNNiMON/SyncTube-QSwitcher) - Raw video quality switcher

## Integrations
### Heroku:
- Create app and commit repo to get build
- Remove `user/` folder from `.gitignore` and commit it to change default configuration
- Add `APP_URL` config var with `your-app-link.herokuapp.com` value to prevent sleeping when clients online

## Development
- Install [Haxe 4.3](https://haxe.org/download/), [VSCode](https://code.visualstudio.com) and [Haxe extension](https://marketplace.visualstudio.com/items?itemName=nadako.vshaxe)
- `haxelib install all` to install extern libs
- If you skipped `Setup` section before: `npm ci`
- Open project in VSCode and press `F5` for client+server build and run

## About
- [Redesign](https://github.com/RblSb/SyncTube/pull/5) by Austin Riddell
- [Original idea](https://github.com/calzoneman/sync) by Calvin Montgomery
- Default emotes by [emlan](https://www.deviantart.com/emlan)
