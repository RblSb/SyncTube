## SyncTube
Synchronized video viewing with chat and other features.
Based on CyTube layout, but with lightweight implementation and very easy way to run locally.

Default channel example: http://synctube-example.herokuapp.com/

### New features
- Multi-Language support
- Mobile view with page fullscreen
- Way to play local videos for network users (without NAT loopback feature)
- Playback rate synchronization (with leader)
- `/30`, `/-21`, etc to rewind video playback in seconds
- Links mask: `foo.com/bar${1-4}.mp4` to add multiple items
- Override every front-end file you want (`user/res` folder)
- Reworked Modern theme

### Supported players
- Youtube (videos and playlists)
- Raw mp4 videos (or any other media format supported in browser)
- Iframes (without sync)

### Setup
- Open `4200` port in your router settings (port is customizable)
- `npm install ws` in this project folder ([NodeJS](https://nodejs.org) required)
- Run `node build/server.js`
- Open showed "Local" link for yourself and send "Global" link to friends

### Configuration
It's just works, but you can also check [user/ folder](/user/README.md) for server settings and additional customization.

### Plugins
- [octosubs](https://github.com/RblSb/SyncTube-octosubs) - `ASS`/`SSA` subtitles support

### How to use
- Login with any nickname
- Add your video url with "plus" button below (youtube or direct link to mp4 for example)
- Now it plays and syncs for all page users, well done
- You can click "leader" button to get access to global video controls (play/pause, time setting, playback speed)
- If you want to restrict permissions or add admins/emotes, see `Configuration` above

### Intergations
#### Heroku:
- Create app and commit repo to get build
- Remove `user/` folder from `.gitignore` and commit it to change default configuration
- Add `APP_URL` config var with `your-app-link.herokuapp.com` value to prevent sleeping when clients online

### Development
- Install Haxe 4, VSCode and vshaxe extension
- `haxelib install all` to install extern libs
- Open project in VSCode and press `F5` for client+server build and run

### About
- [Original idea](https://github.com/calzoneman/sync) and layout by Calvin Montgomery
- Original theme by Thomas Park
- Default emotes by [emlan](https://www.deviantart.com/emlan)
