// @ts-check
// Player rooms (`p-<code>`) on a real relay: tokens signed the way the issuer signs them, checked with the public key.

import { test, after } from "node:test";
import assert from "node:assert/strict";
import { once } from "node:events";
import crypto from "node:crypto";
import { WebSocket } from "ws";
import { SignJWT, generateKeyPair, exportJWK } from "jose";
import { readConfig } from "../lib/config.mjs";
import { createRelay } from "../lib/relay.mjs";
import { readTokenKeys } from "../lib/tokens.mjs";
import { CLOSE, MSG } from "../lib/protocol.mjs";

const SECRET = "s3cret";
const pair = await generateKeyPair("EdDSA", { crv: "Ed25519", extractable: true });
const other = await generateKeyPair("EdDSA", { crv: "Ed25519", extractable: true });
const jwks = { keys: [{ ...(await exportJWK(pair.publicKey)), kid: "k1", alg: "EdDSA" }] };
const relay = createRelay(readConfig({
  RELAY_HOST_SECRET: SECRET, RELAY_QUIET: "1", RELAY_TOKEN_KEYS: JSON.stringify(jwks), RELAY_MAX_CLIENTS: "8",
}));
relay.server.listen(0);
await once(relay.server, "listening");
const address = relay.server.address();
const base = `ws://127.0.0.1:${typeof address === "object" && address ? address.port : 0}`;
after(() => relay.close());

/**
 * A token like the issuer's. `over` changes claims; `key`/`kid` sign with something else.
 * @param {Record<string, unknown>} claims
 * @param {{ key?: CryptoKey, kid?: string, exp?: number, iss?: string, aud?: string }} [o]
 */
function token(claims, o = {}) {
  const now = Math.floor(Date.now() / 1000);
  return new SignJWT(claims)
    .setProtectedHeader({ alg: "EdDSA", kid: o.kid ?? "k1" })
    .setIssuer(o.iss ?? "mpkit-issuer")
    .setAudience(o.aud ?? "mpkit-relay")
    .setSubject("install-test-0001")
    .setJti(crypto.randomUUID())
    .setIssuedAt(now)
    .setExpirationTime(o.exp ?? now + 60)
    .sign(o.key ?? pair.privateKey);
}

/** Opens a socket; resolves with it, its messages and the HTTP status (101 when accepted). */
function connect(/** @type {string} */ query, /** @type {Record<string, string>} */ headers = {}) {
  const ws = new WebSocket(`${base}/?${query}`, { headers });
  /** @type {Buffer[]} */
  const got = [];
  ws.on("message", (data) => got.push(/** @type {Buffer} */ (data)));
  return new Promise((done) => {
    ws.once("unexpected-response", (_req, res) => done({ ws, got, status: res.statusCode }));
    ws.once("open", () => done({ ws, got, status: 101 }));
  });
}

async function firstMessage(/** @type {{ ws: WebSocket, got: Buffer[] }} */ conn) {
  while (conn.got.length < 1) await once(conn.ws, "message");
  return conn.got[0];
}

const room = (/** @type {string} */ code) => `p-${code}`;

test("a player room needs a host token: none, the secret, another room's, a client's, another key's, expired → 403", async () => {
  const r = room("NOTOK1");
  assert.equal((await connect(`role=host&room=${r}`)).status, 403);
  assert.equal((await connect(`role=host&room=${r}`, { "X-Relay-Secret": SECRET })).status, 403);
  assert.equal((await connect(`role=host&room=${r}&token=${await token({ room: room("OTHER1"), role: "host" })}`)).status, 403);
  assert.equal((await connect(`role=host&room=${r}&token=${await token({ room: r, role: "client" })}`)).status, 403);
  assert.equal((await connect(`role=host&room=${r}&token=${await token({ room: r, role: "host" }, { key: other.privateKey })}`)).status, 403);
  assert.equal((await connect(`role=host&room=${r}&token=${await token({ room: r, role: "host" }, { exp: Math.floor(Date.now() / 1000) - 60 })}`)).status, 403);
  assert.equal((await connect(`role=host&room=${r}&token=${await token({ room: r, role: "host" }, { aud: "someone-else" })}`)).status, 403);
  assert.equal(relay.rooms.size, 0);
});

test("host and client with tokens (in ?token= or the X-Relay-Token header): WELCOME, JOIN; a client without one → 403", async () => {
  const r = room("PLAY01");
  const host = await connect(`role=host&room=${r}&token=${await token({ room: r, role: "host", max: 3 })}`);
  assert.equal(host.status, 101);
  assert.equal((await firstMessage(host))[0], MSG.WELCOME);
  assert.equal((await connect(`role=client&room=${r}`)).status, 403);
  const client = await connect(`role=client&room=${r}`, { "X-Relay-Token": await token({ room: r, role: "client" }) });
  assert.equal(client.status, 101);
  assert.equal((await firstMessage(client))[0], MSG.WELCOME);
  host.ws.close();
  client.ws.close();
});

test("a token works once: the same host token again → 403, a fresh one hosts", async () => {
  const r = room("ONCE01");
  const t = await token({ room: r, role: "host" });
  const first = await connect(`role=host&room=${r}&token=${t}`);
  assert.equal(first.status, 101);
  await firstMessage(first);
  first.ws.close();
  await once(first.ws, "close");
  await new Promise((done) => setTimeout(done, 50));
  assert.equal((await connect(`role=host&room=${r}&token=${t}`)).status, 403);
  const fresh = await connect(`role=host&room=${r}&token=${await token({ room: r, role: "host" })}`);
  assert.equal(fresh.status, 101);
  fresh.ws.close();
});

test("a host refused because the room is busy (4009) keeps its token for the retry", async () => {
  const r = room("BUSY01");
  const live = await connect(`role=host&room=${r}&token=${await token({ room: r, role: "host" })}`);
  await firstMessage(live);
  const t = await token({ room: r, role: "host" });
  const second = await connect(`role=host&room=${r}&token=${t}`);
  assert.equal(second.status, 101);
  const [code] = await once(second.ws, "close");
  assert.equal(code, CLOSE.ROOM_IN_USE);
  live.ws.close();
  await once(live.ws, "close");
  await new Promise((done) => setTimeout(done, 50));
  const retry = await connect(`role=host&room=${r}&token=${t}`);
  assert.equal(retry.status, 101);
  assert.equal((await firstMessage(retry))[0], MSG.WELCOME);
  retry.ws.close();
});

test("the host token's max caps the room: the client past it gets ROOM_FULL (4006)", async () => {
  const r = room("FULL01");
  const host = await connect(`role=host&room=${r}&token=${await token({ room: r, role: "host", max: 1 })}`);
  await firstMessage(host);
  const one = await connect(`role=client&room=${r}&token=${await token({ room: r, role: "client" })}`);
  await firstMessage(one);
  const two = await connect(`role=client&room=${r}&token=${await token({ room: r, role: "client" })}`);
  const [code] = await once(two.ws, "close");
  assert.equal(code, CLOSE.ROOM_FULL);
  host.ws.close();
  one.ws.close();
});

test("server rooms are unchanged: a secret hosts game-7700, a token alone does not", async () => {
  const host = await connect("role=host&room=game-7700", { "X-Relay-Secret": SECRET });
  assert.equal(host.status, 101);
  host.ws.close();
  assert.equal((await connect(`role=host&room=game-7701&token=${await token({ room: "game-7701", role: "host" })}`)).status, 403);
});

test("RELAY_TOKEN_KEYS: a private key, a missing kid or bad JSON stop the relay before it starts", async () => {
  const priv = await exportJWK(pair.privateKey);
  const pub = await exportJWK(pair.publicKey);
  assert.throws(() => readTokenKeys(JSON.stringify({ keys: [{ ...priv, kid: "k" }] })), /PRIVATE/);
  assert.throws(() => readTokenKeys(JSON.stringify({ keys: [pub] })), /kid/);
  assert.throws(() => readTokenKeys("{nope"), /JSON/);
  assert.equal(readTokenKeys(""), null);
});

test("without RELAY_TOKEN_KEYS every player room is refused", async () => {
  const bare = createRelay(readConfig({ RELAY_HOST_SECRET: SECRET, RELAY_QUIET: "1" }));
  bare.server.listen(0);
  await once(bare.server, "listening");
  const a = bare.server.address();
  const ws = new WebSocket(`ws://127.0.0.1:${typeof a === "object" && a ? a.port : 0}/?role=host&room=p-NOKEYS&token=${await token({ room: "p-NOKEYS", role: "host" })}`);
  const [, res] = await once(ws, "unexpected-response");
  assert.equal(res.statusCode, 403);
  await bare.close();
});
