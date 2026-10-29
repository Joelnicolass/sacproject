// @ts-check
// Tokens for the rooms players host (`p-<code>`): the MpKit issuer signs them (Ed25519), the relay checks them with
// the public keys in RELAY_TOKEN_KEYS. A token says which room, as host or client, until when; each one is good for
// one connection (its jti is spent once the peer is seated, so a host retrying a busy room keeps its token).

import { createLocalJWKSet, jwtVerify } from "jose";

export const ISSUER = "mpkit-issuer";
export const AUDIENCE = "mpkit-relay";

/**
 * @typedef {object} Granted
 * @property {string} jti
 * @property {number} exp      seconds
 * @property {number} [max]    host tokens: how many clients the room may have
 */

/**
 * The relay's token checker, or null when no keys are set (then every `p-` room is refused).
 * @param {{ keys: object[] } | null} jwks
 */
export function createTokens(jwks) {
  if (!jwks) return null;
  const keySet = createLocalJWKSet(/** @type {import("jose").JSONWebKeySet} */ (jwks));
  /** @type {Map<string, number>} jti -> exp (ms) */
  const spent = new Map();
  return {
    /**
     * Checks `token` for `room` and `role`: what it grants, or why not (a word for the log, never the token).
     * @param {string} token
     * @param {string} room
     * @param {"host" | "client"} role
     * @returns {Promise<{ ok: true, granted: Granted } | { ok: false, reason: string }>}
     */
    async check(token, room, role) {
      if (!token) return { ok: false, reason: "no token" };
      let payload;
      try {
        ({ payload } = await jwtVerify(token, keySet, { issuer: ISSUER, audience: AUDIENCE, algorithms: ["EdDSA"], clockTolerance: 5 }));
      } catch (err) {
        return { ok: false, reason: /** @type {{ code?: string }} */ (err).code === "ERR_JWT_EXPIRED" ? "token expired" : "bad token" };
      }
      if (payload.room !== room) return { ok: false, reason: "token for another room" };
      if (payload.role !== role) return { ok: false, reason: `not a ${role} token` };
      if (typeof payload.jti !== "string" || typeof payload.exp !== "number") return { ok: false, reason: "bad token" };
      if (spent.has(payload.jti)) return { ok: false, reason: "token already used" };
      const max = typeof payload.max === "number" && payload.max >= 0 ? Math.floor(payload.max) : undefined;
      return { ok: true, granted: { jti: payload.jti, exp: payload.exp, max } };
    },
    /** The peer with this token is seated: the token is spent. @param {Granted} granted */
    spend(granted) {
      spent.set(granted.jti, granted.exp * 1000);
    },
    /** Forgets spent tokens past their expiry (they would be refused as expired anyway). */
    sweep(/** @type {number} */ now) {
      for (const [jti, exp] of spent) if (exp + 10_000 < now) spent.delete(jti);
    },
    get spentCount() {
      return spent.size;
    },
  };
}

/**
 * RELAY_TOKEN_KEYS as the issuer's keys.mjs prints it: {"keys":[public JWK, …]} (or a bare array). A private key is
 * an operator mistake: the relay refuses to start rather than hold it.
 * @param {string | undefined} raw
 * @returns {{ keys: object[] } | null}
 */
export function readTokenKeys(raw) {
  if (!raw) return null;
  /** @type {unknown} */
  let parsed;
  try {
    parsed = JSON.parse(raw);
  } catch {
    throw new Error("RELAY_TOKEN_KEYS must be the JSON the issuer's keys.mjs prints");
  }
  const keys = Array.isArray(parsed) ? parsed : /** @type {{ keys?: unknown }} */ (parsed)?.keys;
  if (!Array.isArray(keys) || keys.length === 0) throw new Error('RELAY_TOKEN_KEYS must be {"keys": [public keys]}');
  for (const key of keys) {
    if (key?.d !== undefined) throw new Error("RELAY_TOKEN_KEYS holds a PRIVATE key: give the relay the public one only");
    if (key?.kty !== "OKP" || key?.crv !== "Ed25519" || typeof key?.kid !== "string") throw new Error("RELAY_TOKEN_KEYS: Ed25519 public keys with a kid");
  }
  return { keys };
}
