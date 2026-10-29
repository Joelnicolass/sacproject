// @ts-check
// The issuer over HTTP (Express): request checks, limits per IP, CORS for the web build, and each route mapped to
// the rules (rooms.mjs) and the token signer (tokens.mjs). README section "API" lists the routes.

import express from "express";
import helmet from "helmet";
import { rateLimit, ipKeyGenerator } from "express-rate-limit";
import { z } from "zod";
import { Rooms } from "./rooms.mjs";
import { createSigner } from "./tokens.mjs";

const VERSION = /^\d{1,6}(\.\d{1,6}){0,3}([-+][0-9A-Za-z.-]{1,32})?$/;
const TICKET = z.string().regex(/^[A-Za-z0-9_-]{4,64}$/);
const NAME = z.string()
  .transform((s) => s.replace(/[\u0000-\u001f\u007f]/g, "").trim())
  .pipe(z.string().min(1).max(32));
/** Who is asking: every player request carries it (the IP comes from the connection, never from the body). */
const WHO = z.object({
  game: z.string().regex(/^[a-z0-9][a-z0-9_-]{0,31}$/),
  version: z.string().max(40).regex(VERSION),
  kit: z.string().max(40).regex(VERSION),
  platform: z.string().regex(/^[A-Za-z0-9 _.-]{1,24}$/),
  install: z.string().regex(/^[A-Za-z0-9_-]{16,64}$/),
  session: z.string().regex(/^[A-Za-z0-9_-]{8,64}$/).optional(),
});
const CREATE = WHO.extend({
  name: NAME,
  max_players: z.number().int(),
  visibility: z.enum(["public", "private"]).default("public"),
  mode: z.enum(["dedicated", "listen"]),
  seats: z.array(TICKET).max(63).default([]),
});
const JOIN = WHO;
const TOKENS = z.object({ role: z.enum(["host", "client"]) });
const HEARTBEAT = z.object({
  players: z.number().int().min(0).max(64),
  state: z.enum(["open", "playing"]),
  taken: z.array(TICKET).max(63).default([]),
});

/**
 * @param {import("./config.mjs").IssuerConfig} config
 * @param {{ now?: () => number }} [options]
 */
export async function createIssuer(config, { now = Date.now } = {}) {
  const log = (/** @type {string} */ text) => { if (!config.quiet) console.log(`[issuer] ${text}`); };
  const rooms = new Rooms({ config, now, log });
  const sign = await createSigner(config.privateKey, config.tokenTtlS);
  const app = express();
  app.disable("x-powered-by");
  app.set("trust proxy", config.trustProxy === "proxy" ? 1 : false);
  app.use(helmet({ contentSecurityPolicy: false, crossOriginResourcePolicy: { policy: "cross-origin" } }));
  app.use(cors(config.origins));
  app.use(express.json({ limit: "4kb" }));

  const ipOf = (/** @type {express.Request} */ req) => clientIp(req, config.trustProxy);
  const limit = (/** @type {number} */ perMinute) => rateLimit({
    windowMs: 60_000,
    limit: perMinute,
    standardHeaders: "draft-8",
    legacyHeaders: false,
    keyGenerator: (req) => ipKeyGenerator(ipOf(req)),
    handler: (_req, res) => { res.status(429).json({ error: "rate_limited", retry_after_s: 60 }); },
    validate: { xForwardedForHeader: false },
  });

  app.get("/health", (_req, res) => { res.type("text/plain").send("ok"); });

  app.post("/v1/rooms", limit(config.perMinute.create), async (req, res) => {
    const body = parse(CREATE, req.body, res);
    if (!body) return;
    const made = rooms.create(who(body, ipOf(req)), {
      name: body.name, maxPlayers: body.max_players, listed: body.visibility === "public", mode: body.mode, seats: body.seats,
    });
    if ("error" in made) return refuse(res, made);
    const { room, key } = made;
    res.status(201).json({
      code: room.code, room: room.relayRoom, relay_url: config.relayUrl, room_key: key,
      host_token: await sign({ room: room.relayRoom, role: "host", sub: room.hostInstall, max: rooms.relayClients(room) }),
      max_players: room.maxPlayers, heartbeat_s: config.heartbeatS, token_ttl_s: config.tokenTtlS,
    });
  });

  app.get("/v1/rooms", limit(config.perMinute.list), (req, res) => {
    const query = parse(WHO, req.query, res);
    if (!query) return;
    res.json({ rooms: rooms.list(query.game, query.version) });
  });

  app.post("/v1/rooms/:code/join", limit(config.perMinute.join), async (req, res) => {
    const body = parse(JOIN, req.body, res);
    if (!body) return;
    const asker = who(body, ipOf(req));
    const seat = rooms.join(String(req.params.code), asker);
    if ("error" in seat) return refuse(res, seat);
    res.json({
      code: seat.room.code, room: seat.room.relayRoom, relay_url: config.relayUrl, ticket: seat.ticket,
      token: await sign({ room: seat.room.relayRoom, role: "client", sub: asker.install }),
      mode: seat.room.mode, max_players: seat.room.maxPlayers,
    });
  });

  // The host's own calls: the room key from the create answer proves it is the host.
  const host = (/** @type {express.Request} */ req, /** @type {express.Response} */ res) => {
    const key = String(req.get("authorization") || "").replace(/^Bearer\s+/i, "");
    const room = rooms.authorize(String(req.params.code), key);
    if (!room) res.status(404).json({ error: "no_such_room" });
    return room;
  };

  app.post("/v1/rooms/:code/tokens", limit(config.perMinute.host), async (req, res) => {
    const room = host(req, res);
    if (!room) return;
    const body = parse(TOKENS, req.body, res);
    if (!body) return;
    const max = body.role === "host" ? rooms.relayClients(room) : undefined;
    res.json({ room: room.relayRoom, relay_url: config.relayUrl, token: await sign({ room: room.relayRoom, role: body.role, sub: room.hostInstall, max }) });
  });

  app.put("/v1/rooms/:code", limit(config.perMinute.host), (req, res) => {
    const room = host(req, res);
    if (!room) return;
    const body = parse(HEARTBEAT, req.body, res);
    if (!body) return;
    rooms.heartbeat(room, body);
    res.status(204).end();
  });

  app.delete("/v1/rooms/:code", limit(config.perMinute.host), (req, res) => {
    const room = host(req, res);
    if (!room) return;
    rooms.close(room);
    res.status(204).end();
  });

  app.use((_req, res) => { res.status(404).json({ error: "not_found" }); });
  app.use((/** @type {any} */ err, /** @type {express.Request} */ _req, /** @type {express.Response} */ res, /** @type {express.NextFunction} */ _next) => {
    if (err?.type === "entity.too.large") return res.status(413).json({ error: "too_large" });
    if (err?.type === "entity.parse.failed") return res.status(400).json({ error: "bad_json" });
    log(`error ${err?.stack || err}`);
    res.status(500).json({ error: "internal" });
  });

  const sweeper = setInterval(() => rooms.sweep(), 5000);
  sweeper.unref();
  return { app, rooms, close: () => clearInterval(sweeper) };
}

/** The asker as the rules see it. @param {z.infer<typeof WHO>} body @param {string} ip */
function who(body, ip) {
  return { game: body.game, version: body.version, kit: body.kit, platform: body.platform, install: body.install, session: body.session, ip };
}

/**
 * Checks `data` against `schema`; on a mismatch answers 400 with the fields that are wrong and gives null.
 * @template {z.ZodType} T
 * @param {T} schema
 * @param {unknown} data
 * @param {express.Response} res
 * @returns {z.infer<T> | null}
 */
function parse(schema, data, res) {
  const out = schema.safeParse(data ?? {});
  if (out.success) return out.data;
  res.status(400).json({ error: "bad_request", fields: [...new Set(out.error.issues.map((i) => i.path.join(".")))] });
  return null;
}

/** @param {express.Response} res @param {import("./rooms.mjs").Refusal} refusal */
function refuse(res, refusal) {
  const { status, ...rest } = refusal;
  res.status(status).json(rest);
}

/**
 * The player's IP: on Fly the Fly-Client-IP header (Fly's proxy sets it; nobody else can), behind another proxy the
 * first X-Forwarded-For hop (trust proxy 1), else the socket. IPv4 seen through IPv6 (::ffff:1.2.3.4) as plain IPv4.
 * @param {express.Request} req
 * @param {"fly" | "proxy" | "none"} trust
 */
export function clientIp(req, trust) {
  const raw = (trust === "fly" ? req.get("fly-client-ip") : "") || req.ip || req.socket.remoteAddress || "";
  return raw.trim().replace(/^::ffff:(\d+\.\d+\.\d+\.\d+)$/, "$1");
}

/**
 * CORS for the web build: only the listed origins (or every one with "*") may call from a browser. Desktop builds
 * send no Origin and need none of this.
 * @param {string[]} origins
 * @returns {express.RequestHandler}
 */
function cors(origins) {
  const any = origins.includes("*");
  return (req, res, next) => {
    const origin = req.get("origin");
    const allowed = Boolean(origin) && (any || origins.includes(String(origin)));
    if (allowed) {
      res.set({
        "Access-Control-Allow-Origin": String(origin),
        Vary: "Origin",
        "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE",
        "Access-Control-Allow-Headers": "content-type, authorization",
        "Access-Control-Max-Age": "600",
      });
    }
    if (req.method === "OPTIONS") {
      res.status(allowed ? 204 : 403).end();
      return;
    }
    next();
  };
}

