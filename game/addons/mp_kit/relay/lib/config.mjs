// @ts-check
// The relay's settings, read once from the environment.

/**
 * @typedef {object} RelayConfig
 * @property {number} port            HTTP port (PORT, 8080).
 * @property {string} hostSecret      RELAY_HOST_SECRET: the key a Godot server needs to host a room ("" = none set).
 * @property {boolean} open           RELAY_OPEN=1: anyone may host without a secret (local tests only).
 * @property {number} maxClients      RELAY_MAX_CLIENTS per room (64).
 * @property {number} maxMessage      RELAY_MAX_MESSAGE: the largest message in bytes (262144).
 * @property {number} hostSilentMs    RELAY_HOST_SILENT_MS: a host silent that long is dropped (15000).
 * @property {number} pingMs          How often hosts are pinged: three times within hostSilentMs, at most every 5 s.
 * @property {boolean} quiet          RELAY_QUIET=1: no log lines.
 */

/**
 * @param {Record<string, string | undefined>} env
 * @returns {RelayConfig}
 */
export function readConfig(env) {
  const hostSilentMs = Number(env.RELAY_HOST_SILENT_MS || 15000);
  return {
    port: Number(env.PORT || 8080),
    hostSecret: env.RELAY_HOST_SECRET || "",
    open: env.RELAY_OPEN === "1",
    maxClients: Number(env.RELAY_MAX_CLIENTS || 64),
    maxMessage: Number(env.RELAY_MAX_MESSAGE || 262144),
    hostSilentMs,
    pingMs: Math.max(250, Math.min(5000, Math.floor(hostSilentMs / 3))),
    quiet: env.RELAY_QUIET === "1",
  };
}
