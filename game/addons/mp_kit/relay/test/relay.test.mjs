// @ts-check
// The relay end to end on a free local port, with real WebSocket clients.

import { test, after } from "node:test";
import assert from "node:assert/strict";
import { once } from "node:events";
import { WebSocket } from "ws";
import { readConfig } from "../lib/config.mjs";
import { createRelay } from "../lib/relay.mjs";
import { CLOSE, MSG, idMessage } from "../lib/protocol.mjs";

const SECRET = "s3cret";
const relay = createRelay(readConfig({ RELAY_HOST_SECRET: SECRET, RELAY_QUIET: "1", RELAY_MAX_MESSAGE: "1024" }));
relay.server.listen(0);
await once(relay.server, "listening");
const address = relay.server.address();
const base = `ws://127.0.0.1:${typeof address === "object" && address ? address.port : 0}`;
after(() => relay.close());

/** Opens a socket; resolves with it and its first message (WELCOME), or with the HTTP status when refused. */
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

/** The close code and reason a socket ends with. */
async function closeOf(/** @type {WebSocket} */ ws) {
  const [code, reason] = await once(ws, "close");
  return [code, reason.toString()];
}

/** Waits until `got` has `n` messages. */
async function messages(/** @type {{ ws: WebSocket, got: Buffer[] }} */ conn, /** @type {number} */ n) {
  while (conn.got.length < n) await once(conn.ws, "message");
  return conn.got;
}

const host = (/** @type {string} */ room) => connect(`role=host&room=${room}`, { "X-Relay-Secret": SECRET });

test("/health answers ok", async () => {
  const res = await fetch(base.replace("ws:", "http:") + "/health");
  assert.equal(res.status, 200);
  assert.equal(await res.text(), "ok");
});

test("hosting needs the secret, in the header or in ?secret=", async () => {
  assert.equal((await connect("role=host&room=h1", { "X-Relay-Secret": SECRET })).status, 101);
  assert.equal((await connect(`role=host&room=h2&secret=${SECRET}`)).status, 101);
  assert.equal((await connect("role=host&room=h3")).status, 403);
  assert.equal((await connect("role=host&room=h4", { "X-Relay-Secret": "wrong" })).status, 403);
  assert.equal((await connect("role=nobody&room=h5")).status, 400);
  assert.equal((await connect("role=client")).status, 400);
});

test("a host and a client: WELCOME, JOIN, DATA both ways, KICK with a reason", async () => {
  const h = await host("play");
  const c = await connect("role=client&room=play");
  assert.deepEqual(await messages(h, 2), [idMessage(MSG.WELCOME, 1), idMessage(MSG.JOIN, 2)]);
  assert.deepEqual(await messages(c, 1), [idMessage(MSG.WELCOME, 2)]);

  const toHost = Buffer.from([MSG.DATA, 9, 9, 9, 9, 0, 2, 0xab]);
  c.ws.send(toHost);
  const [, , heard] = await messages(h, 3);
  assert.equal(heard.readUInt32LE(1), 2, "the host reads the client's id");
  assert.equal(heard[7], 0xab);

  h.ws.send(Buffer.from([MSG.DATA, 0, 0, 0, 0, 1, 0, 0xcd]));
  const [, toClient] = await messages(c, 2);
  assert.equal(toClient.readUInt32LE(1), 1, "the client reads the host's id");
  assert.equal(toClient[7], 0xcd);

  const closed = closeOf(c.ws);
  h.ws.send(Buffer.concat([idMessage(MSG.KICK, 2), Buffer.from("full")]));
  assert.deepEqual(await closed, [CLOSE.KICKED, "full"]);
  assert.deepEqual((await messages(h, 4))[3], idMessage(MSG.LEAVE, 2));
  h.ws.close();
});

test("a second host for a live room gets 4009; a client of no room gets 4004; the host leaving closes clients (4005)", async () => {
  const h = await host("busy");
  assert.deepEqual(await closeOf((await host("busy")).ws), [CLOSE.ROOM_IN_USE, "room in use"]);
  assert.deepEqual(await closeOf((await connect("role=client&room=empty")).ws), [CLOSE.NO_HOST, "no host for this room"]);
  const c = await connect("role=client&room=busy");
  const closed = closeOf(c.ws);
  h.ws.close();
  assert.deepEqual(await closed, [CLOSE.HOST_GONE, "host gone"]);
});

test("a message over RELAY_MAX_MESSAGE closes the sender (1009)", async () => {
  const h = await host("big");
  const closed = closeOf(h.ws);
  h.ws.send(Buffer.alloc(2048));
  assert.equal((await closed)[0], 1009);
});
