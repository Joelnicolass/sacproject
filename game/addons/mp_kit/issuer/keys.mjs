// @ts-check
// Makes the issuer's Ed25519 key pair and prints both halves:
//   ISSUER_PRIVATE_KEY  for the issuer only (a secret: `fly secrets import`, never in a file in the repo)
//   RELAY_TOKEN_KEYS    for the relay (public: it can only check tokens, not make them)
// To rotate: make a new pair, put BOTH public keys in RELAY_TOKEN_KEYS ({"keys":[old, new]}), switch the issuer to
// the new private key, and drop the old public key once the old tokens expired (a minute later).
//   node keys.mjs

import { generateKeyPair, exportJWK, calculateJwkThumbprint } from "jose";

const { privateKey, publicKey } = await generateKeyPair("EdDSA", { crv: "Ed25519", extractable: true });
const pub = await exportJWK(publicKey);
const kid = (await calculateJwkThumbprint(pub)).slice(0, 16);
const priv = { ...(await exportJWK(privateKey)), kid, alg: "EdDSA" };
const relay = { keys: [{ ...pub, kid, alg: "EdDSA", use: "sig" }] };
console.log(`ISSUER_PRIVATE_KEY='${JSON.stringify(priv)}'`);
console.log(`RELAY_TOKEN_KEYS='${JSON.stringify(relay)}'`);
