// @ts-check
// The issuer over real HTTP on a free local port: routes, checks, limits, CORS, the player's IP, the tokens it signs,
// and (when the relay's packages are installed next to it) the relay accepting those tokens.

import { test, after } from "node:test";
import assert from "node:assert/strict";
import { once } from "node:events";
import { jwtVerify, decodeJwt } from "jose";
import { createIssuer } from "../lib/app.mjs";
import { testConfig, publicKey, publicJwks } from "./helpers.mjs";

/** @type {Array<() => void>} */
const cleanups = [];
after(() => { for (const c of cleanups) c(); });

/** An issuer listening on a free port; `call(method, path, body, headers)` -> {status, body, headers}. */
async function issuer(/** @type {Record<string, string>} */ env = {}) {
  const made = await createIssuer(testConfig(env));
  const server = made.app.listen(0, "127.0.0.1");
  await once(server, "listening");
  const address = server.address();
  const base = `http://127.0.0.1:${typeof address === "object" && address ? address.port : 0}`;
  cleanups.push(() => { made.close(); server.close(); });
  /**
   * @param {string} method
   * @param {string} path
   * @param {unknown} [body]
   * @param {Record<string, string>} [headers]
   */
  const call = async (method, path, body, headers = {}) => {
    const res = await fetch(base + path, {
      method,
      headers: { ...(body === undefined ? {} : { "content-type": "application/json" }), ...headers },
      body: body === undefined ? undefined : typeof body === "string" ? body : JSON.stringify(body),
    });
    const text = await res.text();
    /** @type {any} */
    let json = null;
    try { json = JSON.parse(text); } catch { json = text; }
    return { status: res.status, body: json, headers: res.headers };
  };
  return { call, base, rooms: made.rooms };
}

let n = 0;
/** What a game sends about itself. */
function who(/** @type {Record<string, string>} */ over = {}) {
  n += 1;
  return { game: "arena", version: "1.2.0", kit: "0.18.0", platform: "Web", install: `install-app-${String(n).padStart(8, "0")}`, ...over };
}
const query = (/** @type {Record<string, string>} */ w) => "?" + new URLSearchParams(w).toString();
/** The host's first heartbeat: it is on the relay, the room goes live. */
const live = (/** @type {any} */ call, /** @type {any} */ made) =>
  call("PUT", `/v1/rooms/${made.code}`, { players: 1, state: "open" }, { authorization: `Bearer ${made.room_key}` });

test("/health answers ok", async () => {
  const { call } = await issuer();
  const res = await call("GET", "/health");
  assert.equal(res.status, 200);
  assert.equal(res.body, "ok");
});

test("create a dedicated room: code, relay room and URL, a host token the public key accepts (max = every player)", async () => {
  const { call } = await issuer();
  const res = await call("POST", "/v1/rooms", { ...who(), name: "  Friday\u0007 ", max_players: 4, mode: "dedicated", seats: ["S1S1", "S2S2", "S3S3"] });
  assert.equal(res.status, 201);
  assert.match(res.body.code, /^[A-Z2-9]{6}$/);
  assert.equal(res.body.room, `p-${res.body.code}`);
  assert.equal(res.body.relay_url, "ws://127.0.0.1:9");
  assert.equal(res.body.heartbeat_s, 10);
  const { payload, protectedHeader } = await jwtVerify(res.body.host_token, publicKey, { issuer: "mpkit-issuer", audience: "mpkit-relay" });
  assert.equal(protectedHeader.alg, "EdDSA");
  assert.equal(protectedHeader.kid, "test-key");
  assert.equal(payload.room, res.body.room);
  assert.equal(payload.role, "host");
  assert.equal(payload.max, 4);
  assert.equal(Number(payload.exp) - Number(payload.iat), 60);
  assert.ok(typeof payload.jti === "string" && payload.jti.length > 10);
});

test("a listen room's host token lets max_players - 1 clients in (the host plays in its own game)", async () => {
  const { call } = await issuer();
  const res = await call("POST", "/v1/rooms", { ...who(), name: "Tab", max_players: 4, mode: "listen" });
  assert.equal(res.status, 201);
  assert.equal(decodeJwt(res.body.host_token).max, 3);
});

test("bad requests: a missing or wrong field names it (400), a body over 4 KB (413), broken JSON (400)", async () => {
  const { call } = await issuer();
  const bad = await call("POST", "/v1/rooms", { ...who({ install: "short" }), name: "", max_players: 4, mode: "dedicated" });
  assert.equal(bad.status, 400);
  assert.equal(bad.body.error, "bad_request");
  assert.deepEqual(bad.body.fields.sort(), ["install", "name"]);
  assert.equal((await call("POST", "/v1/rooms", { ...who(), name: "x".repeat(5000), max_players: 2, mode: "listen" })).status, 413);
  const broken = await call("POST", "/v1/rooms", "{not json");
  assert.equal(broken.status, 400);
  assert.equal(broken.body.error, "bad_json");
  assert.equal((await call("GET", "/v1/nope")).status, 404);
});

test("join, the host's own tokens, heartbeat and close, with the room key as proof", async () => {
  const { call } = await issuer();
  const made = (await call("POST", "/v1/rooms", { ...who(), name: "Duel", max_players: 2, mode: "dedicated", seats: ["SEAT2X"] })).body;
  const key = { authorization: `Bearer ${made.room_key}` };
  const early = await call("POST", `/v1/rooms/${made.code}/join`, who());
  assert.equal(early.status, 409);
  assert.equal(early.body.error, "room_starting");
  assert.equal((await live(call, made)).status, 204);
  const join = await call("POST", `/v1/rooms/${made.code.toLowerCase()}/join`, who());
  assert.equal(join.status, 200);
  assert.equal(join.body.ticket, "SEAT2X");
  assert.equal(join.body.room, made.room);
  const client = await jwtVerify(join.body.token, publicKey, { audience: "mpkit-relay" });
  assert.equal(client.payload.role, "client");
  assert.equal(client.payload.max, undefined);
  assert.equal((await call("POST", `/v1/rooms/${made.code}/join`, who())).body.error, "room_full");
  const tokens = await call("POST", `/v1/rooms/${made.code}/tokens`, { role: "client" }, key);
  assert.equal(tokens.status, 200);
  assert.equal(decodeJwt(tokens.body.token).role, "client");
  assert.equal(decodeJwt((await call("POST", `/v1/rooms/${made.code}/tokens`, { role: "host" }, key)).body.token).max, 2);
  assert.equal((await call("POST", `/v1/rooms/${made.code}/tokens`, { role: "host" }, { authorization: "Bearer wrong" })).status, 404);
  assert.equal((await call("POST", `/v1/rooms/${made.code}/tokens`, { role: "host" })).status, 404);
  assert.equal((await call("PUT", `/v1/rooms/${made.code}`, { players: 2, state: "playing", taken: ["SEAT2X"] }, key)).status, 204);
  assert.equal((await call("PUT", `/v1/rooms/${made.code}`, { players: 2, state: "lost" }, key)).status, 400);
  assert.equal((await call("DELETE", `/v1/rooms/${made.code}`, undefined, key)).status, 204);
  assert.equal((await call("POST", `/v1/rooms/${made.code}/join`, who())).status, 404);
});

test("the list answers rooms for the asker's game and version", async () => {
  const { call } = await issuer();
  await live(call, (await call("POST", "/v1/rooms", { ...who(), name: "Open one", max_players: 3, mode: "listen" })).body);
  await live(call, (await call("POST", "/v1/rooms", { ...who(), name: "Hidden", max_players: 3, mode: "listen", visibility: "private" })).body);
  await call("POST", "/v1/rooms", { ...who(), name: "Starting", max_players: 3, mode: "listen" });
  const list = await call("GET", "/v1/rooms" + query(who()));
  assert.equal(list.status, 200);
  assert.deepEqual(list.body.rooms.map((/** @type {any} */ r) => r.name), ["Open one"]);
  assert.equal((await call("GET", "/v1/rooms" + query(who({ version: "9.9.9" })))).body.rooms.length, 0);
  assert.equal((await call("GET", "/v1/rooms?game=arena")).status, 400);
});

test("an old game version is told the minimum (426); an unknown game is 404", async () => {
  const { call } = await issuer();
  const old = await call("POST", "/v1/rooms", { ...who({ version: "1.0.0" }), name: "Old", max_players: 2, mode: "listen" });
  assert.equal(old.status, 426);
  assert.deepEqual(old.body, { error: "version_too_old", min_version: "1.2.0" });
  assert.equal((await call("POST", "/v1/rooms", { ...who({ game: "unknown" }), name: "X", max_players: 2, mode: "listen" })).status, 404);
});

test("rate limit per IP and route: past ISSUER_RATE_CREATE a minute → 429 with RateLimit headers", async () => {
  const { call } = await issuer({ ISSUER_RATE_CREATE: "2", ISSUER_ROOMS_PER_IP: "10" });
  const make = () => call("POST", "/v1/rooms", { ...who(), name: "R", max_players: 2, mode: "listen" });
  assert.equal((await make()).status, 201);
  assert.equal((await make()).status, 201);
  const third = await make();
  assert.equal(third.status, 429);
  assert.equal(third.body.error, "rate_limited");
  assert.ok(third.headers.get("ratelimit"));
  assert.equal((await call("GET", "/v1/rooms" + query(who()))).status, 200);
});

test("CORS: a listed origin gets the headers and its preflight (204); another origin's preflight is 403", async () => {
  const { call } = await issuer({ ISSUER_ORIGINS: "https://game.example" });
  const pre = await call("OPTIONS", "/v1/rooms", undefined, { origin: "https://game.example", "access-control-request-method": "POST" });
  assert.equal(pre.status, 204);
  assert.equal(pre.headers.get("access-control-allow-origin"), "https://game.example");
  assert.match(String(pre.headers.get("access-control-allow-headers")), /authorization/);
  assert.equal((await call("OPTIONS", "/v1/rooms", undefined, { origin: "https://evil.example" })).status, 403);
  const get = await call("GET", "/health", undefined, { origin: "https://evil.example" });
  assert.equal(get.headers.get("access-control-allow-origin"), null);
});

test("the player's IP: Fly-Client-IP counts with ISSUER_TRUST_PROXY=fly, and is ignored without it", async () => {
  const fly = await issuer({ ISSUER_TRUST_PROXY: "fly", ISSUER_ROOMS_PER_IP: "1" });
  const room = () => ({ ...who(), name: "R", max_players: 2, mode: "listen" });
  assert.equal((await fly.call("POST", "/v1/rooms", room(), { "fly-client-ip": "203.0.113.7" })).status, 201);
  assert.equal((await fly.call("POST", "/v1/rooms", room(), { "fly-client-ip": "203.0.113.7" })).status, 429);
  assert.equal((await fly.call("POST", "/v1/rooms", room(), { "fly-client-ip": "203.0.113.8" })).status, 201);
  const plain = await issuer({ ISSUER_ROOMS_PER_IP: "1" });
  assert.equal((await plain.call("POST", "/v1/rooms", room(), { "fly-client-ip": "203.0.113.7" })).status, 201);
  assert.equal((await plain.call("POST", "/v1/rooms", room(), { "fly-client-ip": "203.0.113.9" })).status, 429);
});

test("the relay takes the issuer's tokens: host the room with host_token, join it with a seat's token", async (t) => {
  let relayLib;
  try {
    relayLib = {
      ...(await import("../../relay/lib/relay.mjs")),
      ...(await import("../../relay/lib/config.mjs")),
      ws: await import("../../relay/node_modules/ws/wrapper.mjs"),
    };
  } catch {
    t.skip("the relay's packages are not installed (npm install in ../relay)");
    return;
  }
  const relay = relayLib.createRelay(relayLib.readConfig({ RELAY_QUIET: "1", RELAY_TOKEN_KEYS: JSON.stringify(publicJwks) }));
  relay.server.listen(0, "127.0.0.1");
  await once(relay.server, "listening");
  const a = relay.server.address();
  const relayBase = `ws://127.0.0.1:${typeof a === "object" && a ? a.port : 0}`;
  cleanups.push(() => relay.close());
  const { call } = await issuer();
  const made = (await call("POST", "/v1/rooms", { ...who(), name: "Live", max_players: 2, mode: "listen" })).body;
  const open = (/** @type {string} */ q) => new Promise((done) => {
    const ws = new relayLib.ws.WebSocket(`${relayBase}/?${q}`);
    ws.once("open", () => done({ ws, status: 101 }));
    ws.once("unexpected-response", (/** @type {any} */ _r, /** @type {any} */ res) => done({ ws, status: res.statusCode }));
  });
  /** @type {any} */
  const host = await open(`role=host&room=${made.room}&token=${made.host_token}`);
  assert.equal(host.status, 101);
  await live(call, made);
  const seat = (await call("POST", `/v1/rooms/${made.code}/join`, who())).body;
  /** @type {any} */
  const client = await open(`role=client&room=${seat.room}&token=${seat.token}`);
  assert.equal(client.status, 101);
  /** @type {any} */
  const replay = await open(`role=client&room=${seat.room}&token=${seat.token}`);
  assert.equal(replay.status, 403);
  host.ws.close();
  client.ws.close();
});
