// Sonic Escape relay server: room codes for online multiplayer.
// It doesn't run the game. It only passes messages between the players in a
// room; Player 1 (the host) is in charge of the game.
//
// Protocol (JSON text messages over WebSocket):
//   client -> server  {t:"host"}             create a room; reply {t:"room", code, id:1}
//   client -> server  {t:"join", code}       join a room;   reply {t:"joined", code, id, ids:[...]}
//                                            or {t:"error", msg}
//   anything else from a client is passed on to the other players in the room
//   with "from" set to the sender's id (add "to": id to send to one player only)
//   server -> clients {t:"peer_join", id} / {t:"peer_left", id} / {t:"host_left"}
//
// Run: npm install && npm start   (PORT env var, default 8080)

const { WebSocketServer } = require("ws");
const http = require("http");

const PORT = process.env.PORT || 8080;
const MAX_PLAYERS = 4;
const CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ"; // no I or O, easy to read out
const rooms = new Map(); // code -> { players: Map<id, ws> }

function newCode() {
  let code;
  do {
    code = Array.from({ length: 4 }, () => CODE_CHARS[Math.floor(Math.random() * CODE_CHARS.length)]).join("");
  } while (rooms.has(code));
  return code;
}

function send(ws, msg) {
  if (ws.readyState === ws.OPEN) ws.send(JSON.stringify(msg));
}

function broadcast(room, msg, exceptId) {
  for (const [id, ws] of room.players) if (id !== exceptId) send(ws, msg);
}

// A plain page for health checks (hosting services ping "/")
const server = http.createServer((req, res) => {
  res.writeHead(200, { "Content-Type": "text/plain" });
  res.end(`Sonic Escape relay: ${rooms.size} room(s) open\n`);
});
const wss = new WebSocketServer({ server, maxPayload: 64 * 1024 });

wss.on("connection", (ws) => {
  ws.room = null;
  ws.id = 0;
  ws.isAlive = true;
  ws.on("pong", () => (ws.isAlive = true));

  ws.on("message", (data) => {
    let msg;
    try { msg = JSON.parse(data.toString()); } catch { return; }
    if (!msg || typeof msg !== "object") return;

    if (!ws.room) {
      if (msg.t === "host") {
        const code = newCode();
        const room = { players: new Map([[1, ws]]) };
        rooms.set(code, room);
        ws.room = code; ws.id = 1;
        send(ws, { t: "room", code, id: 1 });
      } else if (msg.t === "join") {
        const code = String(msg.code || "").toUpperCase().trim();
        const room = rooms.get(code);
        if (!room) return send(ws, { t: "error", msg: "No room with that code" });
        if (room.players.size >= MAX_PLAYERS) return send(ws, { t: "error", msg: "Room is full" });
        if (room.started) return send(ws, { t: "error", msg: "That game has already started" });
        let id = 2;
        while (room.players.has(id)) id++;
        room.players.set(id, ws);
        ws.room = code; ws.id = id;
        send(ws, { t: "joined", code, id, ids: [...room.players.keys()] });
        broadcast(room, { t: "peer_join", id }, id);
      }
      return;
    }

    const room = rooms.get(ws.room);
    if (!room) return;
    if (msg.t === "start" && ws.id === 1) room.started = true;
    msg.from = ws.id;
    if (msg.to) {
      const target = room.players.get(msg.to);
      if (target) send(target, msg);
    } else {
      broadcast(room, msg, ws.id);
    }
  });

  ws.on("close", () => {
    const room = rooms.get(ws.room);
    if (!room) return;
    room.players.delete(ws.id);
    if (ws.id === 1) {
      // The host left: the game can't go on
      broadcast(room, { t: "host_left" });
      for (const other of room.players.values()) other.close();
      rooms.delete(ws.room);
    } else {
      broadcast(room, { t: "peer_left", id: ws.id });
      if (room.players.size === 0) rooms.delete(ws.room);
    }
  });
});

// Drop connections that stopped answering
setInterval(() => {
  for (const ws of wss.clients) {
    if (!ws.isAlive) { ws.terminate(); continue; }
    ws.isAlive = false;
    ws.ping();
  }
}, 15000);

server.listen(PORT, () => console.log(`Sonic Escape relay listening on port ${PORT}`));
