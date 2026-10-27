// @ts-check
// The issuer's rules with a fake clock: rooms, seats, versions, limits, the list, silent hosts.

import { test } from "node:test";
import assert from "node:assert/strict";
import { Rooms, versionAtLeast, normalizeCode, CODE_CHARS } from "../lib/rooms.mjs";
import { testConfig } from "./helpers.mjs";

/** A rules instance on a clock the test moves. */
function setup(/** @type {Record<string, string>} */ env = {}) {
  let t = 1_000_000;
  const config = testConfig(env);
  const rooms = new Rooms({ config, now: () => t });
  return { rooms, config, advance: (/** @type {number} */ ms) => { t += ms; } };
}

let n = 0;
/** A player: its own install id and IP unless given. */
function who(/** @type {Partial<import("../lib/rooms.mjs").Who>} */ over = {}) {
  n += 1;
  return { game: "arena", version: "1.2.0", kit: "0.18.0", platform: "Linux", install: `install-${String(n).padStart(12, "0")}`, ip: `10.0.0.${n}`, ...over };
}

const dedicated = (/** @type {number} */ players) => ({
  name: "Room", maxPlayers: players, listed: true, mode: /** @type {const} */ ("dedicated"),
  seats: Array.from({ length: players - 1 }, (_, i) => `TICKET${i + 1}`),
});
const listen = (/** @type {number} */ players) => ({ name: "Room", maxPlayers: players, listed: true, mode: /** @type {const} */ ("listen"), seats: [] });

/** @param {any} made */
function ok(made) {
  assert.ok(!("error" in made), `refused: ${JSON.stringify(made)}`);
  return made;
}

/** Creates a room and gives its first heartbeat (the host is on the relay): it is live. */
function opened(/** @type {Rooms} */ rooms, /** @type {any} */ asker, /** @type {any} */ ask) {
  const made = ok(rooms.create(asker, ask));
  rooms.heartbeat(made.room, { players: 1, state: "open", taken: [] });
  return made;
}

test("a room: a 6-letter code with no 0/O/1/I, relay room p-<code>, and a key only its host has", () => {
  const { rooms } = setup();
  const { room, key } = opened(rooms, who(), dedicated(4));
  assert.match(room.code, new RegExp(`^[${CODE_CHARS}]{6}$`));
  assert.equal(room.relayRoom, `p-${room.code}`);
  assert.equal(rooms.authorize(room.code, key), room);
  assert.equal(rooms.authorize(room.code.toLowerCase(), key), room);
  assert.equal(rooms.authorize(room.code, key + "x"), null);
  assert.equal(rooms.authorize(room.code, ""), null);
  assert.equal(rooms.authorize("ZZZZZZ", key), null);
});

test("who may create: banned IP or install → 403, unknown game → 404, a version older than the game's minimum → 426", () => {
  const { rooms } = setup({ ISSUER_BANNED: "10.9.9.9,install-banned-000001" });
  assert.equal(rooms.create(who({ ip: "10.9.9.9" }), dedicated(2)).error, "banned");
  assert.equal(rooms.create(who({ install: "install-banned-000001" }), dedicated(2)).error, "banned");
  assert.equal(rooms.create(who({ game: "nope" }), dedicated(2)).error, "unknown_game");
  const old = rooms.create(who({ version: "1.1.9" }), dedicated(2));
  assert.equal(old.error, "version_too_old");
  assert.equal(old.status, 426);
  opened(rooms, who({ version: "1.2.0-beta" }), dedicated(2));
});

test("a room's shape: 2 to the game's max players; dedicated has one ticket per seat but the host's; listen has none", () => {
  const { rooms } = setup();
  assert.equal(rooms.create(who(), dedicated(9)).error, "bad_max_players");
  assert.equal(rooms.create(who(), { ...dedicated(4), seats: ["A1B2", "C3D4"] }).error, "bad_seats");
  assert.equal(rooms.create(who(), { ...dedicated(3), seats: ["SAME1", "SAME1"] }).error, "bad_seats");
  assert.equal(rooms.create(who(), { ...listen(4), seats: ["A1B2"] }).error, "bad_seats");
  assert.equal(rooms.create(who(), { ...listen(1) }).error, "bad_max_players");
});

test("limits: rooms per install (1), per IP (3) and per game", () => {
  const { rooms } = setup({ ISSUER_GAMES: JSON.stringify({ arena: { max_players: 8, max_rooms: 5, min_version: "1.2.0" } }) });
  const host = who();
  opened(rooms, host, dedicated(2));
  const again = rooms.create(host, dedicated(2));
  assert.equal(again.error, "too_many_rooms");
  assert.equal(again.status, 429);
  const ip = "10.1.1.1";
  opened(rooms, who({ ip }), dedicated(2));
  opened(rooms, who({ ip }), dedicated(2));
  opened(rooms, who({ ip }), dedicated(2));
  assert.equal(rooms.create(who({ ip }), dedicated(2)).error, "too_many_rooms");
  opened(rooms, who(), dedicated(2));
  assert.equal(rooms.create(who(), dedicated(2)).error, "no_room_left");
});

test("dedicated seats: one ticket per player, the same one when the same install asks again, full when all are out", () => {
  const { rooms } = setup();
  const { room } = opened(rooms, who(), dedicated(3));
  const a = who();
  const first = ok(rooms.join(room.code, a));
  assert.equal(first.ticket, "TICKET1");
  assert.equal(ok(rooms.join(room.code, a)).ticket, "TICKET1");
  assert.equal(ok(rooms.join(room.code.toLowerCase(), who())).ticket, "TICKET2");
  const full = rooms.join(room.code, who());
  assert.equal(full.error, "room_full");
  assert.equal(full.status, 409);
});

test("two copies of the game on one PC (same install, two sessions) get two seats; the same session gets its own back", () => {
  const { rooms } = setup();
  const { room } = opened(rooms, who(), dedicated(3));
  const pc = who();
  const one = ok(rooms.join(room.code, { ...pc, session: "session-aaaa" }));
  const two = ok(rooms.join(room.code, { ...pc, session: "session-bbbb" }));
  assert.notEqual(one.ticket, two.ticket);
  assert.equal(ok(rooms.join(room.code, { ...pc, session: "session-aaaa" })).ticket, one.ticket);
});

test("an unused seat comes back once its reservation runs out; a seat the host reports taken never does", () => {
  const { rooms, config, advance } = setup();
  const { room } = opened(rooms, who(), dedicated(3));
  ok(rooms.join(room.code, who()));
  ok(rooms.join(room.code, who()));
  rooms.heartbeat(room, { players: 2, state: "open", taken: ["TICKET1"] });
  advance(2 * config.tokenTtlS * 1000 + 1);
  assert.equal(ok(rooms.join(room.code, who())).ticket, "TICKET2");
  assert.equal(rooms.join(room.code, who()).error, "room_full");
});

test("listen seats: no ticket; the count is what the host reports or host + reservations, whichever is more", () => {
  const { rooms, config, advance } = setup();
  const { room } = opened(rooms, who(), listen(3));
  assert.equal(ok(rooms.join(room.code, who())).ticket, null);
  ok(rooms.join(room.code, who()));
  assert.equal(rooms.join(room.code, who()).error, "room_full");
  advance(2 * config.tokenTtlS * 1000 + 1);
  rooms.heartbeat(room, { players: 3, state: "playing", taken: [] });
  assert.equal(rooms.join(room.code, who()).error, "room_full");
  rooms.heartbeat(room, { players: 2, state: "playing", taken: [] });
  ok(rooms.join(room.code, who()));
});

test("joining needs the host's exact game version and the same game", () => {
  const { rooms } = setup({ ISSUER_GAMES: JSON.stringify({ arena: { min_version: "1.2.0" }, other: {} }) });
  const { room } = opened(rooms, who({ version: "1.3.0" }), listen(4));
  const mismatch = rooms.join(room.code, who({ version: "1.2.0" }));
  assert.equal(mismatch.error, "version_mismatch");
  assert.equal(mismatch.host_version, "1.3.0");
  assert.equal(rooms.join(room.code, who({ game: "other", version: "1.3.0" })).error, "no_such_room");
  assert.equal(rooms.join(room.code, who({ game: "unknown", version: "1.3.0" })).error, "unknown_game");
  assert.equal(rooms.join("ZZZZZZ", who()).error, "no_such_room");
});

test("the list: public rooms of the same game and version with a free seat, newest first; private ones by code only", () => {
  const { rooms, advance } = setup();
  const older = opened(rooms, who(), { ...listen(2), name: "Older" }).room;
  advance(1000);
  opened(rooms, who(), { ...listen(4), name: "Newer" });
  const hidden = opened(rooms, who(), { ...listen(4), name: "Hidden", listed: false }).room;
  opened(rooms, who({ version: "1.3.0" }), { ...listen(4), name: "Other version" });
  assert.deepEqual(rooms.list("arena", "1.2.0").map((r) => r.name), ["Newer", "Older"]);
  ok(rooms.join(older.code, who()));
  assert.deepEqual(rooms.list("arena", "1.2.0").map((r) => r.name), ["Newer"]);
  ok(rooms.join(hidden.code, who()));
  const row = rooms.list("arena", "1.2.0")[0];
  assert.deepEqual(Object.keys(row).sort(), ["age_s", "code", "max_players", "name", "platform", "players", "state"]);
});

test("a room whose host is silent past ISSUER_ROOM_SILENT_S, or older than ISSUER_ROOM_MAX_S, is gone", () => {
  const { rooms, config, advance } = setup();
  const quiet = opened(rooms, who(), listen(2)).room;
  const alive = opened(rooms, who(), listen(2)).room;
  advance(config.roomSilentS * 1000 - 1000);
  rooms.heartbeat(alive, { players: 1, state: "open", taken: [] });
  advance(2000);
  rooms.sweep();
  assert.equal(rooms.join(quiet.code, who()).error, "no_such_room");
  ok(rooms.join(alive.code, who()));
  for (let i = 0; i < config.roomMaxS / 20; i++) {
    advance(20_000);
    rooms.heartbeat(alive, { players: 1, state: "open", taken: [] });
  }
  rooms.sweep();
  assert.equal(rooms.size, 0);
});

test("a room is not listed nor joinable until the host's first heartbeat; one that never starts is dropped", () => {
  const { rooms, config, advance } = setup();
  const { room } = ok(rooms.create(who(), listen(2)));
  assert.equal(rooms.list("arena", "1.2.0").length, 0);
  const early = rooms.join(room.code, who());
  assert.equal(early.error, "room_starting");
  assert.equal(early.status, 409);
  rooms.heartbeat(room, { players: 1, state: "open", taken: [] });
  assert.equal(rooms.list("arena", "1.2.0").length, 1);
  ok(rooms.join(room.code, who()));
  const slow = ok(rooms.create(who(), listen(2))).room;
  const beat = () => rooms.heartbeat(room, { players: 2, state: "open", taken: [] });
  for (let s = 20; s < config.roomStartS; s += 20) {
    advance(20_000);
    beat();
    rooms.sweep();
  }
  assert.equal(rooms.size, 2, "a slow room keeps its place for ISSUER_ROOM_START_S");
  advance(40_000);
  beat();
  rooms.sweep();
  assert.equal(rooms.join(slow.code, who()).error, "no_such_room");
  assert.equal(rooms.size, 1);
});

test("closing frees the host's slot for a new room", () => {
  const { rooms } = setup();
  const host = who();
  const { room } = opened(rooms, host, listen(2));
  rooms.close(room);
  opened(rooms, host, listen(2));
});

test("versions compare by number and codes are read as typed", () => {
  assert.equal(versionAtLeast("1.10.0", "1.9.9"), true);
  assert.equal(versionAtLeast("1.2", "1.2.0"), true);
  assert.equal(versionAtLeast("1.2.0-rc.1", "1.2.0"), true);
  assert.equal(versionAtLeast("0.9", "1"), false);
  assert.equal(versionAtLeast("2", "0"), true);
  assert.equal(normalizeCode(" ab-c d3e "), "ABCD3E");
});
