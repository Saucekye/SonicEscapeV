# Sonic Escape relay on Cloudflare (free, no credit card)

The same room-code relay as `../relay.js`, made for Cloudflare Workers. Use it if
the game can't connect to the Render server. Players meet here; once their games
are directly connected (WebRTC), most game traffic doesn't touch it at all.

Free plan limits are generous for this: about 100,000 requests a day, and incoming
WebSocket messages count as 1/20 of a request each.

## Deploy (about 5 minutes; you need Node.js, which you already have)

1. Make a free account at https://dash.cloudflare.com/sign-up
2. Open this `cloudflare` folder, type `cmd` in File Explorer's address bar, then run:

       npm install
       npx wrangler login      (a browser window opens: click Allow)
       npx wrangler deploy

3. At the end it prints your address, like
   `https://sonic-escape-relay.YOUR-NAME.workers.dev`.
   Open it in a browser: it should say `Sonic Escape relay (Cloudflare): 0 room(s) open`.
4. Put that address in the game: in
   `Scripts/Online/net.gd`, set `DEFAULT_SERVER_URL` to it with `wss://` instead of
   `https://`. Or paste it in the ONLINE screen's SERVER box to try it first.

To update it later, run `npx wrangler deploy` again in this folder.

## Test it on your PC first (optional)

    npm install
    npx wrangler dev

Then type `localhost:8787` in the game's SERVER box.
