## SyncTube
Synchronized video viewing with chat and other features.
Based on CyTube layout, but with lightweight implementation and very easy way to run locally.

### New features
Even if some original features are not implemented yet, there is some new things:
- Multi-Language support
- Mobile view with page fullscreen
- Way to play local videos for network users (without NAT loopback feature)
- `/30`, `/-21`, etc to rewind video playback in seconds
- Override every front-end file you want (`user/res` folder)
- Reworked Modern theme

### Supported players
- Youtube
- Raw mp4 and iframe videos

### Setup
- Open `4200` port in your router settings
- `npm install ws`
- Run `node build/server.js`
- Open showed "Local" link for yourself and send "Global" link to friends

### Configuration
It's just works, but you can also check [user/ folder](/user/README.md) for server settings and additional customization.

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
