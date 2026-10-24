# VISCRAFT 4.0 — VIS OS Universe

Browser sandbox prototype with procedural block terrain, mining/placing, survival HUD, hunger/health/XP, night cycle, simple hostile mobs, local world save, keyboard/mouse and mobile movement controls.

## Run locally (Windows 10/11)
1. Install Node.js 18+.
2. Extract the project folder.
3. Open Terminal in this folder and run `npm install`.
4. Run `npm start`.
5. Open `http://localhost:3000`.

The Three.js renderer loads from jsDelivr, so the first launch needs internet. Local saves stay in the same browser profile. The server provides WebSocket room/state/chat/block relay primitives for multiplayer integration; the current browser build is a single-player playable prototype and does not yet connect its world actions to the WebSocket protocol.

## Controls
- WASD / arrow keys: move
- Mouse: look around
- Left mouse: mine block
- Right mouse: place selected block
- Space: jump
- 1–8 / mouse wheel: select hotbar slot
- E: eat food
- Q: save world
- Esc: pause

## Important
This is a prototype, not a Minecraft replacement yet. Physics and mob AI are intentionally lightweight; block collision is not yet voxel-accurate, and multiplayer client integration is a next development step. GitHub Pages can host the static HTML, but the Node.js/WebSocket server must run on a separate Node-capable host for online multiplayer.
