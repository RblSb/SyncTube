## SyncTube
Synchronized video viewing with chat and other features.
Based on CyTube layout, but with lightweight implementation and very easy way to run locally.

### New features
Even if some original features are not implemented yet, there is some new things:
- Multi-Language
- Mobile view with page fullscreen
- Way to play local videos for network users (without NAT loopback feature)
- `/30`, `/-21`, etc to rewind video playback in seconds
- Override every front-end file you want (`user/res` folder)
- Updated Des theme

### Setup
- Open `4200` and `4201` ports in your router settings
- `npm install ws`
- Run `node build/server.js`
- Open showed "Local" link for yourself and send "Global" link to friends

### Configuration
It's just works, but you can also check [user/ folder](/user/README.md) for server settings and additional customization.

### Development
- Install Haxe 4, VSCode and vshaxe extension.
- `haxelib install all` to install extern libs.
- Open project in VSCode and press `F5` for client+server build and run.
