// @ts-check
// The relay's binary messages (little-endian). README section 4 has the same table; MpRelayPeer (Godot) speaks it.
//
//   relay -> peer:  WELCOME u32 your_id | JOIN u32 id (to the host) | LEAVE u32 id (to the host)
//                   DATA u32 from u8 channel u8 mode bytes…
//   peer -> relay:  DATA i32 to u8 channel u8 mode bytes…   (host: a client id, 0 = every client, -id = every client
//                   but id; a client: `to` is ignored, it always reaches the host)
//                   KICK u32 id [reason]   (host only)

export const MSG = Object.freeze({ WELCOME: 1, JOIN: 2, LEAVE: 3, DATA: 4, KICK: 5 });

/** The host is always peer 1; clients get 2, 3… */
export const HOST_ID = 1;

/** WebSocket close codes the relay uses; MpRelayPeer turns each into a message for the player. */
export const CLOSE = Object.freeze({
  NO_HOST: 4004, // a client of a room without a host
  HOST_GONE: 4005, // the room's host left
  ROOM_FULL: 4006, // RELAY_MAX_CLIENTS reached
  KICKED: 4007, // the host turned the client away (the reason says why)
  ROOM_IN_USE: 4009, // a second host for a room with a live host
  HOST_SILENT: 4010, // the host stopped answering pings
});

/** Header of a DATA message: type, the i32/u32 peer id, channel, mode. */
const DATA_HEADER = 7;
/** A kick reason is cut to this many bytes (it becomes a WebSocket close reason, at most 123 bytes). */
const MAX_REASON = 100;

/**
 * WELCOME, JOIN or LEAVE: a type and one peer id.
 * @param {number} type
 * @param {number} id
 */
export function idMessage(type, id) {
  const out = Buffer.alloc(5);
  out[0] = type;
  out.writeUInt32LE(id >>> 0, 1);
  return out;
}

/**
 * A DATA message as its receiver sees it: the same bytes with the sender's id where the target was.
 * @param {Buffer} data a DATA message from a peer
 * @param {number} from
 */
export function stampSender(data, from) {
  const out = Buffer.from(data);
  out.writeUInt32LE(from >>> 0, 1);
  return out;
}

/**
 * @typedef {{ kind: "data", to: number, data: Buffer }
 *   | { kind: "kick", id: number, reason: string }} HostMessage
 */

/**
 * What a host sent, or null for anything else (ignored).
 * @param {Buffer} msg
 * @returns {HostMessage | null}
 */
export function readHostMessage(msg) {
  if (msg.length >= 5 && msg[0] === MSG.KICK) {
    // The optional reason (MpKit sends why it turned the client away), printable ASCII only.
    const reason = msg.subarray(5, 5 + MAX_REASON).toString("utf8").replace(/[^\x20-\x7e]/g, "");
    return { kind: "kick", id: msg.readUInt32LE(1), reason };
  }
  if (isData(msg)) return { kind: "data", to: msg.readInt32LE(1), data: msg };
  return null;
}

/**
 * True for a well-formed DATA message (a client may send nothing else).
 * @param {Buffer} msg
 */
export function isData(msg) {
  return msg.length >= DATA_HEADER && msg[0] === MSG.DATA;
}
