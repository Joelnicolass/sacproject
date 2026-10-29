// @ts-check
// The issuer's rules: who may open a room, who gets a seat in it, which rooms are listed, when a room is gone.
// No HTTP here (app.mjs maps requests to these calls), so the rules run in tests with a fake clock.

import crypto from "node:crypto";

/** The code players type: 6 of these (no 0/O, 1/I), the same letters MpLocalServer uses. */
export const CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
export const CODE_LENGTH = 6;
/** Every issuer room is `p-<code>` on the relay; the relay asks a token for these and only these. */
export const RELAY_PREFIX = "p-";

/**
 * Who is asking (from the request body or query, and the IP from the connection). `install` is kept by the game
 * (limits and bans count it); `session` is new in each process, so two copies of the game on one PC get two seats.
 * @typedef {{ game: string, version: string, kit: string, platform: string, install: string, session?: string, ip: string }} Who
 */

/**
 * A seat handed out but not seen taken yet: it is kept for that install until `until`.
 * @typedef {{ ticket: string | null, until: number }} Reservation
 */

/**
 * @typedef {object} Room
 * @property {string} code
 * @property {string} relayRoom          `p-<code>`
 * @property {string} game
 * @property {string} version            the host's game version; a player must have the same one
 * @property {string} platform           the host's platform (shown in the list)
 * @property {string} hostInstall
 * @property {string} hostIp
 * @property {string} name
 * @property {number} maxPlayers         the host counts
 * @property {boolean} listed            public rooms are listed; private ones are joined by code only
 * @property {"dedicated" | "listen"} mode  dedicated: a match process hosts (every player is a relay client);
 *                                          listen: the host's game hosts and plays
 * @property {string[]} seats            dedicated: the admission tickets of the other seats, handed out one per player
 * @property {Set<string>} taken         dedicated: the tickets the host says are connected
 * @property {number} players            what the host last reported (the host counts)
 * @property {"open" | "playing"} state
 * @property {boolean} live              the host's first heartbeat came (it is on the relay): only then is the room
 *                                       listed and may players join
 * @property {Buffer} keyHash            sha256 of the room key (the host's proof)
 * @property {number} createdAt
 * @property {number} heardAt
 * @property {Map<string, Reservation>} reservations  by install id and session
 */

/** @typedef {{ error: string, status: number, [more: string]: unknown }} Refusal */

/** True when version `a` is at least `b` (numbers between dots; a suffix like "-beta" is ignored). */
export function versionAtLeast(/** @type {string} */ a, /** @type {string} */ b) {
  const parts = (/** @type {string} */ v) => v.split(/[-+]/)[0].split(".").map((n) => Number(n) || 0);
  const x = parts(a);
  const y = parts(b);
  for (let i = 0; i < Math.max(x.length, y.length); i++) {
    const d = (x[i] ?? 0) - (y[i] ?? 0);
    if (d !== 0) return d > 0;
  }
  return true;
}

/** A code as a player may type it: lower case, spaces or dashes in between. */
export function normalizeCode(/** @type {string} */ raw) {
  return String(raw).toUpperCase().replace(/[\s-]/g, "");
}

export class Rooms {
  /** @type {Map<string, Room>} */
  #rooms = new Map();
  #config;
  #now;
  #log;

  /**
   * @param {{ config: import("./config.mjs").IssuerConfig, now?: () => number, log?: (text: string) => void }} options
   */
  constructor({ config, now = Date.now, log = () => {} }) {
    this.#config = config;
    this.#now = now;
    this.#log = log;
  }

  /** How many rooms are open, live or still starting (for tests and logs). */
  get size() {
    return this.#rooms.size;
  }

  /**
   * Opens a room for `who`. Returns the room and its key (shown once), or why not.
   * @param {Who} who
   * @param {{ name: string, maxPlayers: number, listed: boolean, mode: "dedicated" | "listen", seats: string[] }} ask
   * @returns {{ room: Room, key: string } | Refusal}
   */
  create(who, ask) {
    const game = this.#config.games.get(who.game);
    const refused = this.#refuseWho(who, game);
    if (refused) return refused;
    if (!game) return { error: "unknown_game", status: 404 };
    if (ask.maxPlayers < 2 || ask.maxPlayers > game.maxPlayers) {
      return { error: "bad_max_players", status: 400, max_players: game.maxPlayers };
    }
    if (ask.mode === "dedicated" && ask.seats.length !== ask.maxPlayers - 1) {
      return { error: "bad_seats", status: 400, detail: "a dedicated room gives one ticket per seat but the host's" };
    }
    if (ask.mode === "listen" && ask.seats.length > 0) return { error: "bad_seats", status: 400, detail: "a listen room has no tickets" };
    if (new Set(ask.seats).size !== ask.seats.length) return { error: "bad_seats", status: 400, detail: "repeated ticket" };
    const open = [...this.#rooms.values()];
    if (open.filter((r) => r.hostIp === who.ip).length >= this.#config.roomsPerIp
        || open.filter((r) => r.hostInstall === who.install).length >= this.#config.roomsPerInstall) {
      return { error: "too_many_rooms", status: 429, retry_after_s: this.#config.roomSilentS };
    }
    if (open.filter((r) => r.game === who.game).length >= game.maxRooms) return { error: "no_room_left", status: 503 };
    let code = "";
    do code = newCode(); while (this.#rooms.has(code));
    const key = crypto.randomBytes(32).toString("base64url");
    const now = this.#now();
    /** @type {Room} */
    const room = {
      code, relayRoom: RELAY_PREFIX + code, game: who.game, version: who.version, platform: who.platform,
      hostInstall: who.install, hostIp: who.ip, name: ask.name, maxPlayers: ask.maxPlayers, listed: ask.listed,
      mode: ask.mode, seats: [...ask.seats], taken: new Set(), players: 1, state: "open", live: false,
      keyHash: sha256(key), createdAt: now, heardAt: now, reservations: new Map(),
    };
    this.#rooms.set(code, room);
    this.#log(`room ${code} opened (${who.game} ${who.version}, ${ask.mode}, ${ask.maxPlayers} players, ${ask.listed ? "listed" : "private"}) by ${who.platform} ${ipTag(who.ip)}`);
    return { room, key };
  }

  /** How many clients the relay lets into `room`: in a listen room the host is not one of them. */
  relayClients(/** @type {Room} */ room) {
    return room.mode === "listen" ? room.maxPlayers - 1 : room.maxPlayers;
  }

  /**
   * The room `code` if `key` is its key, else null (a wrong key and no room look the same).
   * @param {string} code
   * @param {string} key
   */
  authorize(code, key) {
    const room = this.#rooms.get(normalizeCode(code));
    if (!room || !key) return null;
    const given = sha256(key);
    return crypto.timingSafeEqual(given, room.keyHash) ? room : null;
  }

  /**
   * The host is alive: how many players are in (the host counts), whether it plays, and (dedicated) which tickets are
   * connected. Reported counts are clamped to the room.
   * @param {Room} room
   * @param {{ players: number, state: "open" | "playing", taken: string[] }} report
   */
  heartbeat(room, report) {
    room.heardAt = this.#now();
    if (!room.live) this.#log(`room ${room.code} is live`);
    room.live = true;
    room.players = Math.max(1, Math.min(room.maxPlayers, Math.floor(report.players)));
    room.state = report.state;
    room.taken = new Set(report.taken.filter((t) => room.seats.includes(t)));
  }

  /** The host closed `room`. */
  close(/** @type {Room} */ room) {
    if (this.#rooms.delete(room.code)) this.#log(`room ${room.code} closed by its host`);
  }

  /**
   * A seat in room `code` for `who`: the relay room and (dedicated) the ticket the match admits. Asking again from the
   * same process (install and session) gives the same seat while it is reserved.
   * @param {string} code
   * @param {Who} who
   * @returns {{ room: Room, ticket: string | null } | Refusal}
   */
  join(code, who) {
    const game = this.#config.games.get(who.game);
    const refused = this.#refuseWho(who, game);
    if (refused) return refused;
    const room = this.#rooms.get(normalizeCode(code));
    if (!room || room.game !== who.game) return { error: "no_such_room", status: 404 };
    if (room.version !== who.version) return { error: "version_mismatch", status: 409, host_version: room.version };
    if (!room.live) return { error: "room_starting", status: 409, retry_after_s: 1 };
    const now = this.#now();
    this.#expireReservations(room, now);
    const until = now + 2 * this.#config.tokenTtlS * 1000;
    const seatKey = `${who.install}/${who.session ?? ""}`;
    const mine = room.reservations.get(seatKey);
    if (mine) {
      mine.until = until;
      return { room, ticket: mine.ticket };
    }
    /** @type {string | null} */
    let ticket = null;
    if (room.mode === "dedicated") {
      const held = new Set([...room.reservations.values()].map((r) => r.ticket));
      ticket = room.seats.find((t) => !room.taken.has(t) && !held.has(t)) ?? null;
      if (ticket === null) return { error: "room_full", status: 409 };
    } else if (this.#occupied(room) >= room.maxPlayers) {
      return { error: "room_full", status: 409 };
    }
    room.reservations.set(seatKey, { ticket, until });
    this.#log(`room ${room.code}: seat for ${who.platform} ${ipTag(who.ip)} (${this.#occupied(room)}/${room.maxPlayers})`);
    return { room, ticket };
  }

  /**
   * The listed rooms a player of `game` `version` can join: public, the same version, with a free seat. Newest first.
   * @param {string} game
   * @param {string} version
   */
  list(game, version) {
    const now = this.#now();
    const out = [];
    for (const room of this.#rooms.values()) {
      if (!room.live || !room.listed || room.game !== game || room.version !== version) continue;
      this.#expireReservations(room, now);
      const occupied = this.#occupied(room);
      if (occupied >= room.maxPlayers) continue;
      out.push({ code: room.code, name: room.name, players: occupied, max_players: room.maxPlayers, state: room.state,
        platform: room.platform, age_s: Math.floor((now - room.createdAt) / 1000) });
    }
    return out.sort((a, b) => a.age_s - b.age_s).slice(0, 100);
  }

  /** Drops the rooms whose host went silent or that lived too long. Run every few seconds. */
  sweep() {
    const now = this.#now();
    for (const room of [...this.#rooms.values()]) {
      if (!room.live) {
        if (now - room.createdAt > this.#config.roomStartS * 1000) {
          this.#rooms.delete(room.code);
          this.#log(`room ${room.code} gone (it never started)`);
        }
      } else if (now - room.heardAt > this.#config.roomSilentS * 1000) {
        this.#rooms.delete(room.code);
        this.#log(`room ${room.code} gone (host silent)`);
      } else if (now - room.createdAt > this.#config.roomMaxS * 1000) {
        this.#rooms.delete(room.code);
        this.#log(`room ${room.code} gone (too old)`);
      } else {
        this.#expireReservations(room, now);
      }
    }
  }

  /** Banned, unknown game or a version older than the game allows: why `who` may not go on, or null. */
  #refuseWho(/** @type {Who} */ who, /** @type {import("./config.mjs").GameRules | undefined} */ game) {
    if (this.#config.banned.has(who.ip) || this.#config.banned.has(who.install)) return { error: "banned", status: 403 };
    if (!game) return { error: "unknown_game", status: 404 };
    if (!versionAtLeast(who.version, game.minVersion)) return { error: "version_too_old", status: 426, min_version: game.minVersion };
    return null;
  }

  /** Seats in use: dedicated, the taken or reserved tickets plus the host's seat; listen, what the host reports or
   * the host plus the live reservations (a reserved player may not be connected yet), whichever is more. */
  #occupied(/** @type {Room} */ room) {
    if (room.mode === "dedicated") {
      const used = new Set(room.taken);
      for (const r of room.reservations.values()) if (r.ticket) used.add(r.ticket);
      return 1 + used.size;
    }
    return Math.max(room.players, 1 + room.reservations.size);
  }

  #expireReservations(/** @type {Room} */ room, /** @type {number} */ now) {
    for (const [seatKey, r] of room.reservations) if (r.until < now) room.reservations.delete(seatKey);
  }
}

function newCode() {
  let out = "";
  for (let i = 0; i < CODE_LENGTH; i++) out += CODE_CHARS[crypto.randomInt(CODE_CHARS.length)];
  return out;
}

function sha256(/** @type {string} */ text) {
  return crypto.createHash("sha256").update(text).digest();
}

/** An IP in a log line: a short hash, so logs never hold players' addresses. */
export function ipTag(/** @type {string} */ ip) {
  return "ip:" + crypto.createHash("sha256").update(ip).digest("hex").slice(0, 8);
}
