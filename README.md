## SyncTube
Synchronized video viewing with chat and other features.
Based on CyTube, but with lightweight implementation and very easy way to run locally.

### New features
Even if some original features are not implemented yet, there is some new things:
- Multi-Language
- Mobile view with page fullscreen
- Updated Des theme

TODO:
- Way to play local videos for network users (without NAT loopback feature)
- `/30`, `/-21`, etc to rewind video playback in seconds

### Setup
- Open `4200` and `4201` ports in your router settings
- `npm install ws`
- Run `node build/server.js`
- Open showed "Local" link for yourself and send "Global" link to friends

### Development
- Install Haxe 4, VSCode and vshaxe extension.
- `haxelib install all` to install extern libs.
- Open project in VSCode and press `F5` for client+server build and run.
