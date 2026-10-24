# VISCRAFT 4.1 — VIS OS Universe

VISCRAFT is a browser-based block-world prototype with an Aurora-inspired interface.

## Features in this build
- Three.js 3D scene, deterministic procedural terrain, trees, water and ore blocks.
- Mining, placing blocks, hotbar, health, hunger, XP and simple hostile mobs.
- Local save/load in the browser; automatic save approximately every 25 seconds while playing.
- Crafting panel (**B**) with resource checks, plus quick recipes (**C** for planks, **V** for a brick).
- World chat (**T**) and a WebSocket relay client for player positions and block changes.
- Keyboard/mouse controls and basic mobile movement buttons.

## Run on Windows 10/11
1. Install Node.js 18 or newer.
2. Open a terminal in the `VISCRAFT` folder.
3. Run `npm install`.
4. Run `npm start`.
5. Open `http://localhost:3000`.

The Three.js module is loaded from jsDelivr, so an internet connection is required unless you vendor the library locally. Saves stay in the current browser profile.

## Controls
- **WASD / arrow keys** — move
- **Mouse** — look around; click the canvas to capture the pointer
- **Space** — jump
- **Left mouse button** — mine the targeted block
- **Right mouse button** — place the selected block
- **1–8 / mouse wheel** — select a hotbar slot
- **E** — eat food
- **B** — open crafting
- **C** — craft 4 planks from 1 wood
- **V** — craft 1 brick from 2 stone
- **T** — open world chat; Enter sends a message
- **Q** — save
- **Esc** — release pointer / pause

## Multiplayer status
The browser client can connect to the Node.js WebSocket relay for player-position, chat and block-change messages. This is a basic relay, not a finished authoritative multiplayer engine: world snapshots, conflict resolution, anti-cheat and reliable reconnect handling are not implemented. For public multiplayer, deploy the Node server on a host that supports persistent WebSocket connections. GitHub Pages can host only the static client.

## Known prototype limits
This build has not yet been validated in a real browser across devices. Collision and mob AI are lightweight, and mobile support currently provides basic movement controls rather than full touch-look controls. Treat it as an active prototype, not a finished Minecraft replacement.
