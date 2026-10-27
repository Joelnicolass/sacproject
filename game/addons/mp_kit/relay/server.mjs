// MpKit relay: a WebSocket tunnel for MpKit's "relay" transport, with no dependencies (Node 18+).
// A Godot server (a dedicated, a room server, a match) connects OUT to it as the host of a room; clients (web or
// desktop) connect to the same room; the relay passes packets between them. So the Godot server needs no public
// port: it can live behind NAT, on a PC, or anywhere. Railway, Render, Fly or a VPS can run it (one HTTPS port).
//
//   PORT=8080 RELAY_HOST_SECRET=change-me node server.mjs
//   wss://relay.example.com/?role=host&room=game-7700   + header X-Relay-Secret: change-me   (the Godot server)
//   wss://relay.example.com/?role=client&room=game-7700                    (each player)
//   GET /health -> 200 ok
//
// Environment: PORT (default 8080), RELAY_HOST_SECRET (required to host; without it every host is refused, unless
// RELAY_OPEN=1 lets anyone host: only for local tests), RELAY_MAX_CLIENTS per room (default 64), RELAY_MAX_MESSAGE bytes
// (default 262144), RELAY_HOST_SILENT_MS (default 15000: a host silent that long is dropped).
// Protocol (binary frames, little-endian):
//   relay -> peer:  0x01 WELCOME u32 your_id | 0x02 JOIN u32 id (host) | 0x03 LEAVE u32 id (host)
//                   0x04 DATA u32 from u8 channel u8 mode bytes…
//   peer -> relay:  0x04 DATA i32 to u8 channel u8 mode bytes…   (host: to = a client id, 0 = every client,
//                   -id = every client but id; a client: to is ignored, it always reaches the host)
//                   0x05 KICK u32 id [reason]   (host only: the relay closes that client, 4007, with the reason)
// The host is id 1; clients get 2, 3… A room with a live host is taken: a second host is refused (4009). A host
// silent for RELAY_HOST_SILENT_MS (pinged three times in that span, at most every 5 s) is dropped (4010) and its room
// freed. Clients of a room without a host are refused (4004); when the host leaves every client of the room is
// closed (4005).

import http from "node:http";
import crypto from "node:crypto";

const PORT = Number(process.env.PORT || 8080);
const SECRET = process.env.RELAY_HOST_SECRET || "";
// Without a secret nobody may host, unless RELAY_OPEN=1 says so on purpose (a relay on your own machine for tests).
const OPEN = process.env.RELAY_OPEN === "1";
const MAX_CLIENTS = Number(process.env.RELAY_MAX_CLIENTS || 64);
const MAX_MESSAGE = Number(process.env.RELAY_MAX_MESSAGE || 262144);
// A host that sends nothing (not even a pong) for this long is dropped and its room freed (ms).
const HOST_SILENT_MS = Number(process.env.RELAY_HOST_SILENT_MS || 15000);
// Pinged three times within the silence limit, so a live host always answers in time (at most every 5 s).
const PING_MS = Math.max(250, Math.min(5000, Math.floor(HOST_SILENT_MS / 3)));
const GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
const WELCOME = 1, JOIN = 2, LEAVE = 3, DATA = 4, KICK = 5;

/** room name -> { host: Conn, clients: Map<id, Conn>, next: number } */
const rooms = new Map();

class Conn {
  constructor(socket) {
    this.socket = socket;
    this.buffer = Buffer.alloc(0);
    this.fragments = [];
    this.closed = false;
    this.heardAt = Date.now();
    this.onMessage = () => {};
    this.onClose = () => {};
    socket.on("data", (chunk) => this.#read(chunk));
    socket.on("close", () => this.#gone());
    // The HTTP server keeps upgraded sockets half open: the other side ending its half (a process that exits, a
    // dropped tab) is the end of this connection, at once.
    socket.on("end", () => { this.#gone(); socket.destroy(); });
    socket.on("error", () => this.#gone());
    socket.setNoDelay(true);
  }

  send(payload) {
    if (this.closed) return;
    const len = payload.length;
    let head;
    if (len < 126) head = Buffer.from([0x82, len]);
    else if (len < 65536) { head = Buffer.alloc(4); head[0] = 0x82; head[1] = 126; head.writeUInt16BE(len, 2); }
    else { head = Buffer.alloc(10); head[0] = 0x82; head[1] = 127; head.writeBigUInt64BE(BigInt(len), 2); }
    this.socket.write(Buffer.concat([head, payload]));
  }

  close(code = 1000, reason = "") {
    if (this.closed) return;
    const body = Buffer.alloc(2 + Buffer.byteLength(reason));
    body.writeUInt16BE(code, 0);
    body.write(reason, 2);
    this.socket.write(Buffer.concat([Buffer.from([0x88, body.length]), body]));
    this.socket.end();
    this.#gone();
  }

  #gone() {
    if (this.closed) return;
    this.closed = true;
    this.onClose();
  }

  ping() {
    if (!this.closed) this.socket.write(Buffer.from([0x89, 0]));
  }

  #read(chunk) {
    this.heardAt = Date.now();
    this.buffer = Buffer.concat([this.buffer, chunk]);
    while (this.buffer.length >= 2) {
      const b0 = this.buffer[0], b1 = this.buffer[1];
      let len = b1 & 0x7f, off = 2;
      if (len === 126) { if (this.buffer.length < 4) return; len = this.buffer.readUInt16BE(2); off = 4; }
      else if (len === 127) { if (this.buffer.length < 10) return; len = Number(this.buffer.readBigUInt64BE(2)); off = 10; }
      const masked = (b1 & 0x80) !== 0;
      if (len > MAX_MESSAGE) return this.close(1009, "too big");
      const need = off + (masked ? 4 : 0) + len;
      if (this.buffer.length < need) return;
      let data = this.buffer.subarray(off + (masked ? 4 : 0), need);
      if (masked) {
        const mask = this.buffer.subarray(off, off + 4);
        data = Buffer.from(data);
        for (let i = 0; i < data.length; i++) data[i] ^= mask[i & 3];
      }
      this.buffer = this.buffer.subarray(need);
      const opcode = b0 & 0x0f, fin = (b0 & 0x80) !== 0;
      if (opcode === 0x8) return this.close();
      if (opcode === 0x9) { this.socket.write(Buffer.concat([Buffer.from([0x8a, data.length]), data])); continue; }
      if (opcode === 0xa) continue;
      if (opcode === 0x0 || opcode === 0x1 || opcode === 0x2) {
        this.fragments.push(data);
        if (fin) { const whole = Buffer.concat(this.fragments); this.fragments = []; this.onMessage(whole); }
      }
    }
  }
}

function u32(type, value) {
  const b = Buffer.alloc(5);
  b[0] = type;
  b.writeUInt32LE(value >>> 0, 1);
  return b;
}

/** A DATA frame as the receiver sees it: from replaces to. */
function forward(from, msg) {
  const out = Buffer.from(msg);
  out.writeUInt32LE(from >>> 0, 1);
  return out;
}

function sameSecret(given, secret) {
  const a = Buffer.from(String(given));
  const b = Buffer.from(secret);
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

function attachHost(conn, name) {
  // A room with a live host is taken, like a port in use: a second host is refused (4009) and picks another port.
  // A host that died without closing its socket stops answering pings and is dropped (4010), freeing the room.
  const old = rooms.get(name);
  if (old) {
    log(`host refused: ${name} is in use`);
    return conn.close(4009, "room in use");
  }
  const room = { host: conn, clients: new Map(), next: 2 };
  rooms.set(name, room);
  conn.send(u32(WELCOME, 1));
  log(`host ${name}`);
  conn.onMessage = (msg) => {
    if (msg.length >= 5 && msg[0] === KICK) {
      const id = msg.readUInt32LE(1);
      // An optional reason after the id (MpKit sends why it turned the client away); it becomes the close reason.
      const why = msg.length > 5 ? msg.subarray(5, 105).toString("utf8").replace(/[^\x20-\x7e]/g, "") : "";
      if (room.clients.has(id)) log(`host ${name} kicked client ${id}${why ? ` (${why})` : ""}`);
      room.clients.get(id)?.close(4007, why || "kicked by the host");
      return;
    }
    if (msg.length < 7 || msg[0] !== DATA) return;
    const to = msg.readInt32LE(1);
    const out = forward(1, msg);
    if (to > 0) room.clients.get(to)?.send(out);
    else for (const [id, c] of room.clients) if (to === 0 || id !== -to) c.send(out);
  };
  conn.onClose = () => {
    if (rooms.get(name) !== room) return;
    rooms.delete(name);
    for (const c of room.clients.values()) c.close(4005, "host gone");
    log(`host ${name} gone`);
  };
}

// Pings every host; one silent for HOST_SILENT_MS is closed, so its room is free again.
setInterval(() => {
  const now = Date.now();
  for (const [name, room] of rooms) {
    if (now - room.host.heardAt > HOST_SILENT_MS) {
      log(`host ${name} silent, dropped`);
      room.host.close(4010, "host silent");
      continue;
    }
    room.host.ping();
  }
}, PING_MS).unref();

function attachClient(conn, name) {
  const room = rooms.get(name);
  if (!room) { log(`client refused: no host for ${name}`); return conn.close(4004, "no host for this room"); }
  if (room.clients.size >= MAX_CLIENTS) return conn.close(4006, "room full");
  const id = room.next++;
  room.clients.set(id, conn);
  conn.send(u32(WELCOME, id));
  room.host.send(u32(JOIN, id));
  log(`client ${id} joined ${name} (${room.clients.size} in the room)`);
  conn.onMessage = (msg) => {
    if (msg.length < 7 || msg[0] !== DATA) return;
    room.host.send(forward(id, msg));
  };
  conn.onClose = () => {
    if (room.clients.delete(id) && rooms.get(name) === room) room.host.send(u32(LEAVE, id));
    log(`client ${id} left ${name}`);
  };
}

function log(text) {
  if (process.env.RELAY_QUIET !== "1") console.log(`[relay] ${text}`);
}

const server = http.createServer((req, res) => {
  if (req.url === "/health") { res.writeHead(200, { "content-type": "text/plain" }); return res.end("ok"); }
  res.writeHead(426, { "content-type": "text/plain" });
  res.end("MpKit relay: connect with a WebSocket");
});

server.on("upgrade", (req, socket) => {
  const url = new URL(req.url, "http://relay");
  const key = req.headers["sec-websocket-key"];
  const role = url.searchParams.get("role");
  const name = (url.searchParams.get("room") || "").slice(0, 128);
  if (!key || !name || (role !== "host" && role !== "client")) { socket.end("HTTP/1.1 400 Bad Request\r\n\r\n"); return; }
  if (role === "host") {
    // The secret comes in the X-Relay-Secret header (it never lands in an access log); ?secret= is still read.
    const given = req.headers["x-relay-secret"] || url.searchParams.get("secret") || "";
    if (SECRET ? !sameSecret(given, SECRET) : !OPEN) {
      log(`host refused for ${name}: ${SECRET ? "wrong secret" : "no RELAY_HOST_SECRET set (RELAY_OPEN=1 allows any host)"}`);
      socket.end("HTTP/1.1 403 Forbidden\r\n\r\n");
      return;
    }
  }
  const accept = crypto.createHash("sha1").update(key + GUID).digest("base64");
  socket.write(`HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: ${accept}\r\n\r\n`);
  const conn = new Conn(socket);
  if (role === "host") attachHost(conn, name);
  else attachClient(conn, name);
});

server.listen(PORT, () => log(`ready port ${PORT}${SECRET ? "" : OPEN ? " (RELAY_OPEN: anyone may host, tests only)" : " (no RELAY_HOST_SECRET: every host is refused)"}`));
