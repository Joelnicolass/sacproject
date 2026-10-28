// @ts-check
// MpKit issuer: hands out relay tokens for rooms that players host (Node 20+, `npm install` once).
// A player's game asks it for a room (a code and a token to host it on the relay), others ask it for a seat in that
// room (a token to join, and the match's ticket); it lists public rooms and drops the ones whose host went silent.
// The relay checks each token with the public key; the private key never leaves this process.
//
//   ISSUER_PRIVATE_KEY='{…}' ISSUER_RELAY_URL=wss://relay.example.com ISSUER_GAMES='{"my-game":{"max_players":8}}' node server.mjs
//   GET /health -> 200 ok
//
// lib/config.mjs   the environment (keys, relay, games, limits)
// lib/tokens.mjs   the relay tokens (JWT, EdDSA)
// lib/rooms.mjs    the rules: rooms, seats, the list, silent hosts
// lib/app.mjs      HTTP (Express): checks, rate limits, CORS, the routes
// keys.mjs         makes the key pair (private here, public on the relay)
// test/            npm test

import { readConfig } from "./lib/config.mjs";
import { createIssuer } from "./lib/app.mjs";

const config = readConfig(process.env);
const { app } = await createIssuer(config);
app.listen(config.port, () => {
  if (!config.quiet) console.log(`[issuer] ready port ${config.port} (${[...config.games.keys()].join(", ")}; relay ${config.relayUrl})`);
});
