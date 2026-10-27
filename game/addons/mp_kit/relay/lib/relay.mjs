// @ts-check
// The relay over HTTP + WebSocket: /health, who may connect as a host, and each connection handed to the rules
// (rooms.mjs) as a Peer. The WebSocket protocol itself (handshake, frames, ping/pong, sizes) is the `ws` library's.

import http from "node:http";
import crypto from "node:crypto";
import { WebSocketServer, WebSocket } from "ws";
import { Rooms } from "./rooms.mjs";

/** A room name is cut to this length. */
const MAX_ROOM_NAME = 128;

/**
 * @param {import("./config.mjs").RelayConfig} config
 * @returns {{ server: http.Server, rooms: Rooms, close: () => Promise<void> }}
 */
export function createRelay(config) {
  const log = (/** @type {string} */ text) => { if (!config.quiet) console.log(`[relay] ${text}`); };
  const rooms = new Rooms({ maxClients: config.maxClients, log });
  const sockets = new WebSocketServer({ noServer: true, maxPayload: config.maxMessage });

  const server = http.createServer((req, res) => {
    if (req.url === "/health") {
      res.writeHead(200, { "content-type": "text/plain" });
      res.end("ok");
      return;
    }
    res.writeHead(426, { "content-type": "text/plain" });
    res.end("MpKit relay: connect with a WebSocket");
  });

  server.on("upgrade", (req, socket, head) => {
    const url = new URL(req.url ?? "/", "http://relay");
    const role = url.searchParams.get("role");
    const room = (url.searchParams.get("room") || "").slice(0, MAX_ROOM_NAME);
    if (!room || (role !== "host" && role !== "client")) return refuse(socket, 400, "Bad Request");
    if (role === "host") {
      // The secret comes in the X-Relay-Secret header (it never lands in an access log); ?secret= is still read.
      const given = String(req.headers["x-relay-secret"] || url.searchParams.get("secret") || "");
      if (!mayHost(given, config)) {
        log(`host refused for ${room}: ${config.hostSecret ? "wrong secret" : "no RELAY_HOST_SECRET set (RELAY_OPEN=1 allows any host)"}`);
        return refuse(socket, 403, "Forbidden");
      }
    }
    sockets.handleUpgrade(req, socket, head, (ws) => seat(ws, role, room));
  });

  /** One connection becomes a host or a client of `room`; the rules decide whether it stays. */
  function seat(/** @type {WebSocket} */ ws, /** @type {"host" | "client"} */ role, /** @type {string} */ room) {
    ws.on("error", () => {}); // a broken socket or a message over maxPayload (ws closes it with 1009 itself)
    /** @type {import("./rooms.mjs").Peer} */
    const peer = {
      heardAt: Date.now(),
      send: (data) => { if (ws.readyState === WebSocket.OPEN) ws.send(data); },
      close: (code, reason) => ws.close(code, reason),
      ping: () => { if (ws.readyState === WebSocket.OPEN) ws.ping(); },
    };
    const link = role === "host" ? rooms.addHost(room, peer) : rooms.addClient(room, peer);
    if (!link) return;
    ws.on("message", (data) => {
      peer.heardAt = Date.now();
      link.onMessage(/** @type {Buffer} */ (data));
    });
    ws.on("pong", () => { peer.heardAt = Date.now(); });
    ws.on("close", link.onClose);
  }

  const heartbeat = setInterval(() => rooms.sweep(Date.now(), config.hostSilentMs), config.pingMs);
  heartbeat.unref();

  return {
    server,
    rooms,
    close: () => new Promise((done) => {
      clearInterval(heartbeat);
      for (const ws of sockets.clients) ws.terminate();
      server.close(() => done());
    }),
  };
}

/** True when a host with this secret may open a room. Without a secret set, only RELAY_OPEN=1 lets anyone host. */
function mayHost(/** @type {string} */ given, /** @type {import("./config.mjs").RelayConfig} */ config) {
  if (!config.hostSecret) return config.open;
  const a = Buffer.from(given);
  const b = Buffer.from(config.hostSecret);
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

/** Answers an upgrade with an HTTP error and closes the socket. */
function refuse(/** @type {import("node:stream").Duplex} */ socket, /** @type {number} */ status, /** @type {string} */ text) {
  socket.end(`HTTP/1.1 ${status} ${text}\r\nConnection: close\r\n\r\n`);
}
