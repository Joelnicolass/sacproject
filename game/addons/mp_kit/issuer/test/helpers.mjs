// @ts-check
// A test configuration with a key pair made once per run.

import { generateKeyPair, exportJWK } from "jose";
import { readConfig } from "../lib/config.mjs";

const pair = await generateKeyPair("EdDSA", { crv: "Ed25519", extractable: true });
export const privateJwk = { ...(await exportJWK(pair.privateKey)), kid: "test-key", alg: "EdDSA" };
export const publicJwks = { keys: [{ ...(await exportJWK(pair.publicKey)), kid: "test-key", alg: "EdDSA" }] };
export const publicKey = pair.publicKey;

/** The issuer's config for a test: one game "arena" (8 players, version 1.2.0 or newer) plus `env`. */
export function testConfig(/** @type {Record<string, string>} */ env = {}) {
  return readConfig({
    ISSUER_PRIVATE_KEY: JSON.stringify(privateJwk),
    ISSUER_RELAY_URL: "ws://127.0.0.1:9",
    ISSUER_GAMES: JSON.stringify({ arena: { max_players: 8, min_version: "1.2.0" } }),
    ISSUER_QUIET: "1",
    ...env,
  });
}
