// @ts-check
// The relay's rules: who hosts a room, who joins it, where each message goes. No sockets here (server.mjs gives
// each connection as a Peer), so the rules run in tests with fake peers.

import { CLOSE, HOST_ID, MSG, idMessage, isData, readHostMessage, stampSender } from "./protocol.mjs";

/**
 * One connection, as the rules see it.
 * @typedef {object} Peer
 * @property {(data: Buffer) => void} send
 * @property {(code: number, reason: string) => void} close
 * @property {() => void} ping
 * @property {number} heardAt   when it last sent anything (a pong too), in ms
 */

/**
 * What to do with a seated peer's messages and with its end.
 * @typedef {{ onMessage: (msg: Buffer) => void, onClose: () => void }} Link
 */

/** @typedef {{ name: string, host: Peer, clients: Map<number, Peer>, nextId: number, maxClients: number }} Room */

export class Rooms {
  /** @type {Map<string, Room>} */
  #rooms = new Map();
  #maxClients;
  #log;

  /** @param {{ maxClients: number, log?: (text: string) => void }} options */
  constructor({ maxClients, log = () => {} }) {
    this.#maxClients = maxClients;
    this.#log = log;
  }

  /**
   * Makes `peer` the host of room `name`. A room with a live host is taken, like a port in use: a second host is
   * closed (4009) and gets null. `maxClients` (a host token's `max`) lowers RELAY_MAX_CLIENTS for this room.
   * @param {string} name
   * @param {Peer} peer
   * @param {number} [maxClients]
   * @returns {Link | null}
   */
  addHost(name, peer, maxClients) {
    if (this.#rooms.has(name)) {
      this.#log(`host refused: ${name} is in use`);
      peer.close(CLOSE.ROOM_IN_USE, "room in use");
      return null;
    }
    /** @type {Room} */
    const cap = maxClients === undefined ? this.#maxClients : Math.min(maxClients, this.#maxClients);
    const room = { name, host: peer, clients: new Map(), nextId: HOST_ID + 1, maxClients: cap };
    this.#rooms.set(name, room);
    peer.send(idMessage(MSG.WELCOME, HOST_ID));
    this.#log(`host ${name}`);
    return { onMessage: (msg) => this.#fromHost(room, msg), onClose: () => this.#closeRoom(room) };
  }

  /**
   * Seats `peer` as a client of room `name`: it gets the next id and the host gets a JOIN. Without a host (4004) or
   * with the room full (4006) the peer is closed and gets null.
   * @param {string} name
   * @param {Peer} peer
   * @returns {Link | null}
   */
  addClient(name, peer) {
    const room = this.#rooms.get(name);
    if (!room) {
      this.#log(`client refused: no host for ${name}`);
      peer.close(CLOSE.NO_HOST, "no host for this room");
      return null;
    }
    if (room.clients.size >= room.maxClients) {
      peer.close(CLOSE.ROOM_FULL, "room full");
      return null;
    }
    const id = room.nextId++;
    room.clients.set(id, peer);
    peer.send(idMessage(MSG.WELCOME, id));
    room.host.send(idMessage(MSG.JOIN, id));
    this.#log(`client ${id} joined ${name} (${room.clients.size} in the room)`);
    return {
      // Whatever `to` a client writes, its DATA reaches the host only.
      onMessage: (msg) => { if (isData(msg)) room.host.send(stampSender(msg, id)); },
      onClose: () => this.#removeClient(room, id),
    };
  }

  /**
   * The heartbeat, run every pingMs: pings each host, and drops one silent for longer than `silentMs` (4010), so a
   * server that died without closing never blocks its room for good.
   * @param {number} now
   * @param {number} silentMs
   */
  sweep(now, silentMs) {
    for (const room of [...this.#rooms.values()]) {
      if (now - room.host.heardAt > silentMs) {
        this.#log(`host ${room.name} silent, dropped`);
        room.host.close(CLOSE.HOST_SILENT, "host silent");
        this.#closeRoom(room);
      } else {
        room.host.ping();
      }
    }
  }

  /** How many rooms have a host (for tests and logs). */
  get size() {
    return this.#rooms.size;
  }

  /** @param {Room} room @param {Buffer} msg */
  #fromHost(room, msg) {
    const what = readHostMessage(msg);
    if (what?.kind === "kick") {
      const client = room.clients.get(what.id);
      if (!client) return;
      this.#log(`host ${room.name} kicked client ${what.id}${what.reason ? ` (${what.reason})` : ""}`);
      client.close(CLOSE.KICKED, what.reason || "kicked by the host");
      this.#removeClient(room, what.id);
    } else if (what?.kind === "data") {
      const out = stampSender(what.data, HOST_ID);
      if (what.to > 0) room.clients.get(what.to)?.send(out);
      else for (const [id, client] of room.clients) if (what.to === 0 || id !== -what.to) client.send(out);
    }
  }

  /** A client is gone (it left, or was kicked): the host gets a LEAVE while its room is still open. Once only. */
  #removeClient(/** @type {Room} */ room, /** @type {number} */ id) {
    if (!room.clients.delete(id)) return;
    if (this.#rooms.get(room.name) === room) room.host.send(idMessage(MSG.LEAVE, id));
    this.#log(`client ${id} left ${room.name}`);
  }

  /** The host is gone: the room is free again and its clients are closed (4005). Once only. */
  #closeRoom(/** @type {Room} */ room) {
    if (this.#rooms.get(room.name) !== room) return;
    this.#rooms.delete(room.name);
    for (const id of [...room.clients.keys()]) {
      room.clients.get(id)?.close(CLOSE.HOST_GONE, "host gone");
      this.#removeClient(room, id);
    }
    this.#log(`host ${room.name} gone`);
  }
}
