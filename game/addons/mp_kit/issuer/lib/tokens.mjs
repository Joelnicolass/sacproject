// @ts-check
// Relay tokens: a short JWT, signed here with the Ed25519 private key, that the relay checks with the public key.
// It says "the bearer may connect to relay room R as a host (or a client) until T". The relay reads the same
// contract (relay/lib/tokens.mjs); README section "Tokens" has the table.

import crypto from "node:crypto";
import { SignJWT, importJWK } from "jose";

export const ISSUER = "mpkit-issuer";
export const AUDIENCE = "mpkit-relay";

/**
 * @typedef {object} TokenClaims
 * @property {string} room        the relay room, `p-<code>`
 * @property {"host" | "client"} role
 * @property {string} sub         the install id that asked
 * @property {number} [max]       host tokens: how many clients the relay lets into the room
 */

/**
 * A function that signs tokens with `jwk` (an Ed25519 private JWK with its kid).
 * @param {Record<string, unknown>} jwk
 * @param {number} ttlS
 * @returns {Promise<(claims: TokenClaims) => Promise<string>>}
 */
export async function createSigner(jwk, ttlS) {
  const key = await importJWK(/** @type {import("jose").JWK} */ (jwk), "EdDSA");
  const kid = String(jwk.kid);
  return async ({ room, role, sub, max }) => {
    const now = Math.floor(Date.now() / 1000);
    /** @type {Record<string, unknown>} */
    const body = { room, role };
    if (max !== undefined) body.max = max;
    return new SignJWT(body)
      .setProtectedHeader({ alg: "EdDSA", kid, typ: "JWT" })
      .setIssuer(ISSUER)
      .setAudience(AUDIENCE)
      .setSubject(sub)
      .setJti(crypto.randomUUID())
      .setIssuedAt(now)
      .setNotBefore(now - 5)
      .setExpirationTime(now + ttlS)
      .sign(key);
  };
}
