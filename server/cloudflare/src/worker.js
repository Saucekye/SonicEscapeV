// Sonic Escape relay on Cloudflare Workers: room codes for online multiplayer.
// The same protocol as ../relay.js (the Render / Node version):
//   client -> server  {t:"host"}             create a room; reply {t:"room", code, id:1}
//   client -> server  {t:"join", code}       join a room;   reply {t:"joined", code, id, ids:[...]}
//                                            or {t:"error", msg}
//   anything else from a client is passed on to the other players in the room
//   with "from" set to the sender's id (add "to": id to send to one player only)
//   server -> clients {t:"peer_join", id} / {t:"peer_left", id} / {t:"host_left"}
// One Durable Object ("main") holds every room; it only lives while players are connected.

const MAX_PLAYERS = 4;
const CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ"; // no I or O, easy to read out

export default {
  async fetch(request, env) {
    const stub = env.RELAY.get(env.RELAY.idFromName("main"));
    return stub.fetch(request);
  },
};

export class Relay {
  constructor(state, env) {
    this.state = state;
    this.rooms = new Map(); // code -> { players: Map<id, ws>, started }
  }

  async fetch(request) {
    if (request.headers.get("Upgrade") !== "websocket") {
      // A plain page, to check it's running
      return new Response(`Sonic Escape relay (Cloudflare): ${this.rooms.size} room(s) open\n`, {
        headers: { "Content-Type": "text/plain" },
      });
    }
    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);
    server.accept();
    this.handle(server);
    return new Response(null, { status: 101, webSocket: client });
  }

  newCode() {
    let code;
    do {
      code = Array.from({ length: 4 }, () => CODE_CHARS[Math.floor(Math.random() * CODE_CHARS.length)]).join("");
    } while (this.rooms.has(code));
    return code;
  }

  send(ws, msg) {
    try { ws.send(JSON.stringify(msg)); } catch (e) { /* already closed */ }
  }

  broadcast(room, msg, exceptId) {
    for (const [id, ws] of room.players) if (id !== exceptId) this.send(ws, msg);
  }

  handle(ws) {
    const me = { room: null, id: 0 };

    ws.addEventListener("message", (event) => {
      let msg;
      try { msg = JSON.parse(typeof event.data === "string" ? event.data : new TextDecoder().decode(event.data)); } catch { return; }
      if (!msg || typeof msg !== "object") return;

      if (!me.room) {
        if (msg.t === "host") {
          const code = this.newCode();
          this.rooms.set(code, { players: new Map([[1, ws]]), started: false });
          me.room = code; me.id = 1;
          this.send(ws, { t: "room", code, id: 1 });
        } else if (msg.t === "join") {
          const code = String(msg.code || "").toUpperCase().trim();
          const room = this.rooms.get(code);
          if (!room) return this.send(ws, { t: "error", msg: "No room with that code" });
          if (room.players.size >= MAX_PLAYERS) return this.send(ws, { t: "error", msg: "Room is full" });
          if (room.started) return this.send(ws, { t: "error", msg: "That game has already started" });
          let id = 2;
          while (room.players.has(id)) id++;
          room.players.set(id, ws);
          me.room = code; me.id = id;
          this.send(ws, { t: "joined", code, id, ids: [...room.players.keys()] });
          this.broadcast(room, { t: "peer_join", id }, id);
        }
        return;
      }

      const room = this.rooms.get(me.room);
      if (!room) return;
      if (msg.t === "start" && me.id === 1) room.started = true;
      msg.from = me.id;
      if (msg.to) {
        const target = room.players.get(msg.to);
        if (target) this.send(target, msg);
      } else {
        this.broadcast(room, msg, me.id);
      }
    });

    const leave = () => {
      const room = this.rooms.get(me.room);
      if (!room || !room.players.has(me.id)) return;
      room.players.delete(me.id);
      if (me.id === 1) {
        // The host left: the game can't go on
        this.broadcast(room, { t: "host_left" });
        for (const other of room.players.values()) { try { other.close(1000, "host left"); } catch (e) {} }
        this.rooms.delete(me.room);
      } else {
        this.broadcast(room, { t: "peer_left", id: me.id });
        if (room.players.size === 0) this.rooms.delete(me.room);
      }
    };
    ws.addEventListener("close", leave);
    ws.addEventListener("error", leave);
  }
}
