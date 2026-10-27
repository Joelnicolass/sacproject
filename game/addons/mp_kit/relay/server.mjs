// @ts-check
// MpKit relay: a WebSocket tunnel for MpKit's "relay" transport (Node 18+, `npm install` once for `ws`).
// A Godot server (a dedicated, a room server, a match) connects OUT to it as the host of a room; clients (web or
// desktop) connect to the same room; the relay passes packets between them. So the Godot server needs no public
// port: it can live behind NAT, on a PC, or anywhere. Railway, Render, Fly or a VPS can run it (one HTTPS port).
//
//   PORT=8080 RELAY_HOST_SECRET=change-me node server.mjs
//   wss://relay.example.com/?role=host&room=game-7700   + header X-Relay-Secret: change-me   (the Godot server)
//   wss://relay.example.com/?role=client&room=game-7700                    (each player)
//   GET /health -> 200 ok
//
// lib/config.mjs   the environment (PORT, RELAY_HOST_SECRET, RELAY_OPEN, RELAY_MAX_CLIENTS, RELAY_MAX_MESSAGE,
//                  RELAY_HOST_SILENT_MS, RELAY_QUIET)
// lib/protocol.mjs the binary messages and close codes
// lib/rooms.mjs    the rules: hosts, clients, where each message goes, silent hosts
// lib/relay.mjs    HTTP, /health, the host secret, each WebSocket handed to the rules
// test/            npm test

import { readConfig } from "./lib/config.mjs";
import { createRelay } from "./lib/relay.mjs";

const config = readConfig(process.env);
const { server } = createRelay(config);
server.listen(config.port, () => {
  if (config.quiet) return;
  const who = config.hostSecret ? "" : config.open ? " (RELAY_OPEN: anyone may host, tests only)" : " (no RELAY_HOST_SECRET: every host is refused)";
  console.log(`[relay] ready port ${config.port}${who}`);
});
