// @ts-check
// The issuer's settings, read once from the environment. Every limit has a default; the key, the relay URL and the
// games are required (the issuer refuses to start without them, rather than run open).

/**
 * What one game may do on this issuer.
 * @typedef {object} GameRules
 * @property {string} minVersion   the oldest game version that may create or join a room ("0" = any)
 * @property {number} maxPlayers   the most players a room of this game may have (the host counts)
 * @property {number} maxRooms     the most live rooms of this game at once
 */

/**
 * @typedef {object} IssuerConfig
 * @property {number} port              PORT (8090)
 * @property {Record<string, unknown>} privateKey  ISSUER_PRIVATE_KEY: the Ed25519 private JWK (with its kid), from keys.mjs
 * @property {string} relayUrl          ISSUER_RELAY_URL: the relay players connect to (wss://…)
 * @property {Map<string, GameRules>} games  ISSUER_GAMES: {"<game>": {"min_version", "max_players", "max_rooms"}}
 * @property {string[]} origins         ISSUER_ORIGINS: web origins allowed to call it from a browser ("*" = any)
 * @property {"fly" | "proxy" | "none"} trustProxy  ISSUER_TRUST_PROXY: where the player's IP comes from
 * @property {number} tokenTtlS         ISSUER_TOKEN_TTL_S: how long a relay token may wait before it is used (60)
 * @property {number} heartbeatS        ISSUER_HEARTBEAT_S: how often a host says it is alive (10)
 * @property {number} roomSilentS       ISSUER_ROOM_SILENT_S: a room whose host is silent that long is gone (30)
 * @property {number} roomStartS        ISSUER_ROOM_START_S: a new room has this long for its first heartbeat, which
 *                                      the host sends once the relay accepted it (120: a big game loads slowly)
 * @property {number} roomMaxS          ISSUER_ROOM_MAX_S: the longest a room lives (6 h)
 * @property {number} roomsPerIp        ISSUER_ROOMS_PER_IP: live rooms one IP may host (3)
 * @property {number} roomsPerInstall   ISSUER_ROOMS_PER_INSTALL: live rooms one install may host (1)
 * @property {Set<string>} banned       ISSUER_BANNED: IPs and install ids turned away (comma separated)
 * @property {{ create: number, join: number, list: number, host: number }} perMinute  requests per IP and minute:
 *   ISSUER_RATE_CREATE (10), ISSUER_RATE_JOIN (30), ISSUER_RATE_LIST (60), ISSUER_RATE_HOST (60, a host's own calls)
 * @property {boolean} quiet            ISSUER_QUIET=1: no log lines
 */

/**
 * @param {Record<string, string | undefined>} env
 * @returns {IssuerConfig}
 */
export function readConfig(env) {
  const num = (/** @type {string} */ name, /** @type {number} */ fallback) => {
    const raw = env[name];
    if (raw === undefined || raw === "") return fallback;
    const value = Number(raw);
    if (!Number.isFinite(value) || value < 0) throw new Error(`${name} must be a number >= 0, got "${raw}"`);
    return value;
  };
  const relayUrl = env.ISSUER_RELAY_URL || "";
  if (!/^wss?:\/\//.test(relayUrl)) throw new Error("ISSUER_RELAY_URL must be the relay's ws:// or wss:// address");
  const trust = env.ISSUER_TRUST_PROXY || "none";
  if (trust !== "fly" && trust !== "proxy" && trust !== "none") throw new Error("ISSUER_TRUST_PROXY must be fly, proxy or none");
  return {
    port: num("PORT", 8090),
    privateKey: readPrivateKey(env.ISSUER_PRIVATE_KEY),
    relayUrl,
    games: readGames(env.ISSUER_GAMES),
    origins: (env.ISSUER_ORIGINS || "").split(",").map((o) => o.trim()).filter(Boolean),
    trustProxy: trust,
    tokenTtlS: num("ISSUER_TOKEN_TTL_S", 60),
    heartbeatS: num("ISSUER_HEARTBEAT_S", 10),
    roomSilentS: num("ISSUER_ROOM_SILENT_S", 30),
    roomStartS: num("ISSUER_ROOM_START_S", 120),
    roomMaxS: num("ISSUER_ROOM_MAX_S", 6 * 3600),
    roomsPerIp: num("ISSUER_ROOMS_PER_IP", 3),
    roomsPerInstall: num("ISSUER_ROOMS_PER_INSTALL", 1),
    banned: new Set((env.ISSUER_BANNED || "").split(",").map((b) => b.trim()).filter(Boolean)),
    perMinute: {
      create: num("ISSUER_RATE_CREATE", 10),
      join: num("ISSUER_RATE_JOIN", 30),
      list: num("ISSUER_RATE_LIST", 60),
      host: num("ISSUER_RATE_HOST", 60),
    },
    quiet: env.ISSUER_QUIET === "1",
  };
}

/** @param {string | undefined} raw */
function readPrivateKey(raw) {
  if (!raw) throw new Error("ISSUER_PRIVATE_KEY is missing: run `node keys.mjs` and set the private key it prints");
  /** @type {Record<string, unknown>} */
  let jwk;
  try {
    jwk = JSON.parse(raw);
  } catch {
    throw new Error("ISSUER_PRIVATE_KEY must be the JSON key `node keys.mjs` prints");
  }
  if (jwk.kty !== "OKP" || jwk.crv !== "Ed25519" || typeof jwk.d !== "string" || typeof jwk.kid !== "string") {
    throw new Error("ISSUER_PRIVATE_KEY must be an Ed25519 private JWK with a kid (`node keys.mjs`)");
  }
  return jwk;
}

/** @param {string | undefined} raw */
function readGames(raw) {
  if (!raw) throw new Error('ISSUER_GAMES is missing, e.g. {"my-game": {"min_version": "1.0.0", "max_players": 8}}');
  /** @type {unknown} */
  let parsed;
  try {
    parsed = JSON.parse(raw);
  } catch {
    throw new Error("ISSUER_GAMES must be JSON");
  }
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) throw new Error("ISSUER_GAMES must be an object");
  /** @type {Map<string, GameRules>} */
  const games = new Map();
  for (const [id, rules] of Object.entries(parsed)) {
    if (!/^[a-z0-9][a-z0-9_-]{0,31}$/.test(id)) throw new Error(`ISSUER_GAMES: "${id}" is not a game id (a-z, 0-9, _ and -)`);
    const r = /** @type {Record<string, unknown>} */ (rules ?? {});
    const maxPlayers = Number(r.max_players ?? 8);
    const maxRooms = Number(r.max_rooms ?? 500);
    if (!Number.isInteger(maxPlayers) || maxPlayers < 2 || maxPlayers > 64) throw new Error(`ISSUER_GAMES.${id}.max_players: 2 to 64`);
    if (!Number.isInteger(maxRooms) || maxRooms < 1) throw new Error(`ISSUER_GAMES.${id}.max_rooms: 1 or more`);
    games.set(id, { minVersion: String(r.min_version ?? "0"), maxPlayers, maxRooms });
  }
  if (games.size === 0) throw new Error("ISSUER_GAMES has no game");
  return games;
}
