---
name: godot-mp-kit
description: >-
  Implement host-authoritative multiplayer in Godot 4 with the informal MpKit
  addon (ENet, slots, handshake, snapshots) plus game glue. Ask the MP type
  first: none (do not copy the addon), local/Wi-Fi (listen-server), or online
  (dedicated server, same project, VPS). Use when copying addons/mp_kit,
  host/host_dedicated/join, submit_* RPCs, Dictionary tunnel, MultiplayerSpawner,
  1P offline, rejoin, dedicated export, feature scaffold, or extracting netcode
  to another project.
---

# Godot — MpKit and multiplayer

One simulator (the server). Clients send intents and paint copies. The addon is small on purpose: reusable pipe, zero gameplay.

Architecture: [godot-layered-architecture](../godot-layered-architecture/SKILL.md) (**ask** Clean vs standard; do not assume layers). Nodes/FX/Resources: [godot-composition-first](../godot-composition-first/SKILL.md). Dedicated / VPS: [dedicated.md](dedicated.md).

## Network scope (required)

**Always ask** (AskQuestion if available) **before** copying the addon or writing RPCs. Do not assume LAN.

| Choice | What to do |
|----------|-----------|
| **No multiplayer** | Do not install MpKit. No autoload, no RPC, no `MultiplayerSpawner`. |
| **Local / Wi-Fi** (same device or same LAN) | `MpKit.host()` listen-server. The host process **is** a player (slot 1 / peer 1). |
| **Online** (internet, VPS) | **Dedicated server** in the **same project**. `MpKit.host_dedicated()`; clients `join(ip)`. Peer 1 is **not** a player. Develop that way from day one (headless + clients to `127.0.0.1`); the VPS is the same binary with a public IP and open UDP. Several matches = **in-process rooms** (`MpKit.rooms` / `MpKit.matchmaker`) on that process. Steam / WebRTC / process-per-match: only if the product asks, **later**, not instead of dedicated. |

Do not ask again if the user already chose in this chat or PRD/RULES declares it.

Pawn/projectile/enemy types: Resource `.tres` on the actor, not an RPC per `kind` string.

## Priorities (always)

Always prioritize:

- architecture that is easy to scale and clean in layers
- composition structures always take priority
- nodes and editor configuration always take priority
- component reusability always takes priority

On the network that means:

| Priority | In MpKit / glue |
|-----------|-----------------|
| Layers | `addons/mp_kit` does not name session, scenes, copy, or score. Online = dedicated in the addon, not a title `NetworkManager`. |
| Composition | Transport (kit) + glue + (`GameSession` **or** Match node) + actors with `submit_*`. |
| Editor | Spawners, replication config, and pawn scenes are built as nodes. The kit does not generate the world. |
| Reuse | Copy this framework’s canonical addon. The game writes glue + domain; no per-title forks of the kit. |

## Canonical source

The plugin is `addons/mp_kit/` **inside the Godot project**. Copy that folder as-is to another title. Do not fork it per game.

If the project addon and a loose copy diverge, `res://addons/mp_kit/` in this project wins.

API: [kit-api.md](kit-api.md). Glue: [game-glue.md](game-glue.md). Dedicated: [dedicated.md](dedicated.md). Editor / tunnel / scaffold: [editor.md](editor.md). Generic code: [examples.md](examples.md).

Human guide (inspector, step-by-step, custom tunnel, hub rooms and queue): `addons/mp_kit/README.md`.

## Quickstart (5 steps)

1. Copy `addons/mp_kit/` and enable **MpKit** (`MpKit` autoload **before** flow).
2. Tools → **MpKit: New session flow...** (or `extends MpFlow`). Set boot/world. `play_solo()` / `host_lan()` / `join_lan()`. 1P: do not call `host()` yourself.
3. In the match: one `MpSpawner` or `MpSlotSpawner` (`spawn_path` = actor parent). The client requests `world_ready` itself; no extra `MpWorldReady` node.
4. Pawns: child `MpReplicate` + `submit_*` with `MpAuthority.accept_command(self, player_slot)`.
5. LAN: `MpFlow` advertises on the host; the lobby browses (or instance `MpBootMenu`). Online: dedicated + public IP, not `host()` behind NAT.

## What the kit is / is not

Copy `addons/mp_kit/` → autoload `MpKit`.

**Does:** ENet listen or dedicated, slot ↔ peer map, capacity, `world_ready` handshake, opaque `Dictionary` push (snapshot **and** `send_custom` tunnel), signals, replication nodes, `MpBoot`. Optional: `MpFlow` (boot/world scenes, not rules). Optional: in-process hub rooms (`MpRoomDirectory` + FIFO `MpMatchmaker`) on a dedicated.

**Does not:** score, title copy, actor input, prediction, Steam/WebRTC, process-per-match, “who wins”. `MpReplicate.interpolate` is an optional proxy lerp, not rollback.

If you put score in `mp_kit.gd`, the kit stops being portable.

## Required model

```
[Play alone]     do not call host(); OfflineMultiplayerPeer; local_slot() == host_slot
[Host LAN]       MpKit.host()
[Dedicated]      MpKit.host_dedicated()     local_slot() == 0
[Client]         MpKit.join(ip)
```

- Stable **slot**: key for lives/score/HUD. Listen: slot 1 = hosting player. Dedicated: slots 1..N = clients only.
- Volatile **peer id**: validate RPCs with `MpKit.peer_id_for(slot)`. Never `get_unique_id()` as a player id. Peer 1 on dedicated is **not** a slot.

Client: `apply_snapshot` **turns off** the session simulation tick. The guest does not tick the clock. Dedicated does simulate (it is the server).

## Input and authority

Actors: the server is authority. If the body is `RigidBody2D`/`RigidBody3D`, freeze proxies (`MpAuthority.freeze_rigid_proxy`). Do not assume RigidBody on every pawn.

```
if MpAuthority.should_send_command():
    pawn.submit_x.rpc_id(1, payload)
else:
    pawn.apply_x(payload)
```

RPC on **your** pawn, not the kit:

```gdscript
@rpc("any_peer", "call_remote", "reliable")
func submit_x(payload) -> void:
	if not MpAuthority.accept_command(self, player_slot):
		return
	apply_x(payload)
```

- Allowlist of `submit_*`. No `rpc add_score`.
- No `call_local` on client commands (duplicates spawn/damage).
- Damage areas: `monitoring = is_multiplayer_authority()`.
- Dedicated never sends `submit_*` (no local player).

## Spawn handshake (required)

Godot’s `MultiplayerSpawner` replicates children on `peer_connected`, while the client is **still on the lobby**; that spawn is lost. `MpSpawner` (default `hold_until_world_ready`) uses the `MultiplayerSynchronizer` per-peer visibility: actors spawn hidden and each peer is revealed on `client_world_ready`; only then does Godot deliver spawn + sync, paired.

```
Server broadcast_load_world() + glue loads the world on the server process
  → listen host add_child(local pawn) in _ready; hidden to not-ready peers
  → client loads scene; MpSpawner calls request_world_ready() (deferred)
  → MpSpawner reveals the peer (set_visibility_for) → Godot sends spawn + sync
  → MpSlotSpawner (or glue) spawns the slot that just joined
```

Do not unparent actors in glue: the kit already reveals on `client_world_ready`.

Actor identity (`player_slot`, etc.): `MultiplayerSynchronizer` properties with `spawn = true`, or the node name (`Pawn_2` / `Ship_2`).

Local FX (post-process, atmosphere) are built in `_ready` **on the client too**, before the guest `return`.

Rejoin: do not reset score; snapshot + `load_world_to`. `MpSpawner` reveals again for the new peer id.

## Snapshots vs transforms

- Position/rotation/visible: `MultiplayerSynchronizer` (`MpAuthority.ensure_sync`).
- Timer/score/lives: `to_snapshot()` at 2–10 Hz via `MpKit.push_snapshot` (Timer, not every `_process` frame).
- Discrete events (floating `+N`): `authority` RPC on a node **of yours**, not MpKit.

Do not put 40 prop positions in the dict if they already go through a synchronizer.

## 1P

Same collision and `submit_*` code (the local host does not send an RPC). Always test play-alone **without** `create_server`.

## Anti-patterns

- Client spawns / `queue_free` / adds points.
- `PlayerId` or `GameSession` imported from `mp_kit.gd`.
- Starting spawn on the same frame as the guest’s `change_scene` (the kit covers this; do not “fix” it by unparenting in glue).
- `leave()` leaving `multiplayer_peer = null` (the kit sets `OfflineMultiplayerPeer`).
- A third peer accepted silently (the kit must `disconnect_peer` when over capacity; “room full” policy is glue + kit).
- HUD that shows the host score because it used peer id 1.
- Dedicated with a pawn for itself, or developing online as a listen-server.
- Pretending a LAN `host()` behind NAT is online.
- Auto-broadcast of the custom tunnel (the server must choose).
- Putting game rules or bullet `kind` in the tunnel dict.

## Checklist

- [ ] MP type declared (none / local-Wi-Fi / online). No MP: this checklist does not apply.
- [ ] Autoload `MpKit` **before** glue. `configure(port, max_players)` before host/join.
- [ ] `MpFlow` autoload (Tools → New session flow) or `extends MpFlow`. Several maps: `add_world` + `select_world`. Extra glue only for copy or a tunnel.
- [ ] Online: `MpBoot` + `host_dedicated()`; clients `join`; dedicated export; spawn only `occupied_slots()`. Optional hub: `MpKit.rooms` / `MpKit.matchmaker` on the same process; score still stays out of the addon.
- [ ] Slots in domain; peers only in RPC/authority.
- [ ] `MpSpawner` or `MpSlotSpawner` with `hold_until_world_ready` (default). The client does not need `MpWorldReady`. No pawn restage in glue.
- [ ] Guest does not simulate rules; server validates sender.
- [ ] 1P offline verified.
- [ ] Pawns are composable packed scenes, not netcode embedded in the kit.
- [ ] New features: Tools scaffold or `/new-mp-feature`; tunnel only for what is not `submit_*` / Resource.
