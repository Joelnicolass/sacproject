// @ts-check
// The relay's rules with fake peers: no sockets, no timers.

import { test } from "node:test";
import assert from "node:assert/strict";
import { Rooms } from "../lib/rooms.mjs";
import { CLOSE, MSG, idMessage } from "../lib/protocol.mjs";

/** A peer that records what it got. */
function fakePeer() {
  return {
    /** @type {Buffer[]} */ got: [],
    /** @type {[number, string] | null} */ closed: null,
    pings: 0,
    heardAt: 0,
    send(/** @type {Buffer} */ data) { this.got.push(Buffer.from(data)); },
    close(/** @type {number} */ code, /** @type {string} */ reason) { this.closed = [code, reason]; },
    ping() { this.pings++; },
  };
}

/** A DATA message from a peer: to, channel 0, mode 2, payload. */
function data(/** @type {number} */ to, /** @type {string} */ payload) {
  const out = Buffer.alloc(7 + payload.length);
  out[0] = MSG.DATA;
  out.writeInt32LE(to, 1);
  out[6] = 2;
  out.write(payload, 7);
  return out;
}

/** The sender and payload of a DATA message as a peer received it. */
function received(/** @type {Buffer} */ msg) {
  return { from: msg.readUInt32LE(1), payload: msg.subarray(7).toString() };
}

function kick(/** @type {number} */ id, reason = "") {
  return Buffer.concat([idMessage(MSG.KICK, id), Buffer.from(reason)]);
}

/** A room "r" with a host and `n` clients (ids 2…). */
function roomWith(/** @type {number} */ n, maxClients = 64) {
  const rooms = new Rooms({ maxClients });
  const host = fakePeer();
  const hostLink = rooms.addHost("r", host);
  assert.ok(hostLink);
  const clients = [];
  for (let i = 0; i < n; i++) {
    const peer = fakePeer();
    const link = rooms.addClient("r", peer);
    assert.ok(link);
    clients.push({ peer, link });
  }
  host.got = [];
  for (const c of clients) c.peer.got = [];
  return { rooms, host, hostLink, clients };
}

test("the host is peer 1; clients get 2, 3… and the host hears each JOIN", () => {
  const rooms = new Rooms({ maxClients: 64 });
  const host = fakePeer();
  rooms.addHost("r", host);
  const a = fakePeer(), b = fakePeer();
  rooms.addClient("r", a);
  rooms.addClient("r", b);
  assert.deepEqual(host.got, [idMessage(MSG.WELCOME, 1), idMessage(MSG.JOIN, 2), idMessage(MSG.JOIN, 3)]);
  assert.deepEqual(a.got, [idMessage(MSG.WELCOME, 2)]);
  assert.deepEqual(b.got, [idMessage(MSG.WELCOME, 3)]);
});

test("a room with a live host refuses a second host (4009)", () => {
  const rooms = new Rooms({ maxClients: 64 });
  rooms.addHost("r", fakePeer());
  const second = fakePeer();
  assert.equal(rooms.addHost("r", second), null);
  assert.equal(second.closed?.[0], CLOSE.ROOM_IN_USE);
});

test("a client of a room without a host is refused (4004); a full room refuses one more (4006)", () => {
  const rooms = new Rooms({ maxClients: 1 });
  const early = fakePeer();
  assert.equal(rooms.addClient("r", early), null);
  assert.equal(early.closed?.[0], CLOSE.NO_HOST);
  rooms.addHost("r", fakePeer());
  assert.ok(rooms.addClient("r", fakePeer()));
  const extra = fakePeer();
  assert.equal(rooms.addClient("r", extra), null);
  assert.equal(extra.closed?.[0], CLOSE.ROOM_FULL);
});

test("host DATA: to one id, to everyone (0), to everyone but one (-id); the sender reads as 1", () => {
  const { hostLink, clients: [a, b, c] } = roomWith(3);
  hostLink.onMessage(data(3, "one"));
  hostLink.onMessage(data(0, "all"));
  hostLink.onMessage(data(-2, "not-a"));
  assert.deepEqual(a.peer.got.map(received), [{ from: 1, payload: "all" }]);
  assert.deepEqual(b.peer.got.map(received), [{ from: 1, payload: "one" }, { from: 1, payload: "all" }, { from: 1, payload: "not-a" }]);
  assert.deepEqual(c.peer.got.map(received), [{ from: 1, payload: "all" }, { from: 1, payload: "not-a" }]);
});

test("client DATA always reaches the host, stamped with the client's id; junk is ignored", () => {
  const { host, clients: [a, b] } = roomWith(2);
  a.link.onMessage(data(3, "hi")); // a client cannot write to another client
  a.link.onMessage(Buffer.from([MSG.DATA, 0]));
  a.link.onMessage(kick(3)); // nor kick one
  assert.deepEqual(host.got.map(received), [{ from: 2, payload: "hi" }]);
  assert.equal(b.peer.got.length, 0);
  assert.equal(b.peer.closed, null);
});

test("a KICK closes the client with 4007 and its reason, and the host gets one LEAVE", () => {
  const { host, hostLink, clients: [a, b] } = roomWith(2);
  hostLink.onMessage(kick(2, "full\u0007"));
  hostLink.onMessage(kick(3));
  assert.deepEqual(a.peer.closed, [CLOSE.KICKED, "full"]);
  assert.deepEqual(b.peer.closed, [CLOSE.KICKED, "kicked by the host"]);
  a.link.onClose(); // the socket's own close event, later
  assert.deepEqual(host.got, [idMessage(MSG.LEAVE, 2), idMessage(MSG.LEAVE, 3)]);
});

test("a client that leaves: the host gets a LEAVE", () => {
  const { host, clients: [a] } = roomWith(1);
  a.link.onClose();
  assert.deepEqual(host.got, [idMessage(MSG.LEAVE, 2)]);
});

test("the host leaves: its clients are closed (4005) and the room is free for a new host", () => {
  const { rooms, hostLink, clients: [a, b] } = roomWith(2);
  hostLink.onClose();
  assert.equal(a.peer.closed?.[0], CLOSE.HOST_GONE);
  assert.equal(b.peer.closed?.[0], CLOSE.HOST_GONE);
  assert.equal(rooms.size, 0);
  assert.ok(rooms.addHost("r", fakePeer()));
  a.link.onClose(); // a late close of an old client says nothing to the new host
});

test("sweep pings a live host and drops a silent one (4010), freeing its room", () => {
  const rooms = new Rooms({ maxClients: 64 });
  const live = fakePeer(), silent = fakePeer(), client = fakePeer();
  live.heardAt = 1000;
  rooms.addHost("live", live);
  rooms.addHost("silent", silent);
  rooms.addClient("silent", client);
  rooms.sweep(1000, 500);
  assert.equal(live.pings, 1);
  assert.equal(silent.closed?.[0], CLOSE.HOST_SILENT);
  assert.equal(client.closed?.[0], CLOSE.HOST_GONE);
  assert.equal(rooms.size, 1);
  assert.ok(rooms.addHost("silent", fakePeer()));
});
