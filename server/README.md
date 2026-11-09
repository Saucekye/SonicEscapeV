# Sonic Escape relay server (online multiplayer)

A tiny Node.js server that lets up to 4 players find each other with a
4-letter room code and passes their messages along. It doesn't run the game;
Player 1 (the host) is in charge.

## Run it on your PC (to test)

    cd server
    npm install
    npm start          # listens on port 8080

The game connects to `ws://localhost:8080` by default.

## Put it online (so friends and the itch.io web build can join)

Any host that runs Node and supports WebSockets works. Render.com, Railway,
Fly.io and Glitch all have free or cheap tiers:

1. Make a new "Web Service" from this `server` folder.
2. Build command `npm install`, start command `npm start`. The host sets `PORT`.
3. It gives you an address like `https://sonic-escape-relay.onrender.com`.
4. In `Scripts/Online/net.gd`, set `DEFAULT_SERVER_URL` to the same address
   with `wss://` instead of `https://`, e.g.
   `wss://sonic-escape-relay.onrender.com`, then export the game again.

Use `wss://` for the web build: itch.io pages are https and browsers block
plain `ws://` from them. A player can also point their own copy at another
server with `[online] server_url="wss://..."` in `user://settings.cfg`.

Free tiers often go to sleep when unused; the first connection after a while
can take ~30 seconds while the server wakes up.
