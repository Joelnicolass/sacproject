# Plan 070: MpKit como envoltorio (fase 3 de PLAN-v2)

Tech lead, 2026-10-26. Estado: **aprobado** 2026-10-26 (N0, N1, N2 lanzados; el resto según §7). Revisado con la sesión del kit 2026-10-26: sin `slot_away` (usar `seat_away` de la puerta / `player_left` de MpMatch), LICENSE ya existe en el kit, y K va encima del PR #12 corregido con el número siguiente y su par rc EN/ES. Fase aprobada por el usuario 2026-10-26 («buena mejora y buen enfoque»); mejoras genéricas al kit se suben como fix (rc EN + ES; el usuario mergea).

## 1. Criterios
- C12 70 → 0; ninguna otra regla sube.
- Un componente que simula no sabe de red: `is_multiplayer_authority()` (Godot; verdadero en solo, host y dedicado; falso en cliente).
- Cableado de red en un solo lugar: `scenes/net/`, nodos `*Net` con `@rpc` (patrón `TerrainNet`/`GroundScarsNet`), subclases de nodos del kit y los nodos del kit en `match.tscn`.
- Sin cambio de comportamiento: NET QUICK (enet y ws), `run_068_gate.sh`, `ptnet_real_run.sh`, `run_determinism.sh quick` con el mismo digest.

## 2. Inventario (70)
| Patrón | Cant. | Muestra |
|---|---|---|
| A1 «¿simulo?» (`is_networked() and not is_server()`, `_has_authority()`) | 42 | `health.gd:293`, `ability_effect.gd:75`, `unit_body.gd:168`, `fireball_projectile.gd:49`, `path_follower.gd:62`, `ai_side.gd:42` |
| A2 spawners (servidor `spawn()`, cliente null, solo `_make`+`add_child`) | 5 | `unit_spawner.gd:30`, `shot_spawner.gd:49,64`, `spell_spawner.gd:57`, `structure_spawner.gd:34`, `wizard_spawner.gd:13-34` |
| B «¿quién mira?» (`local_slot`, `slot_assigned`) | 10 | `selection.gd:111`, `pointer_ray.gd:179`, `unit_health_bar.gd:43`, `music_director.gd:180`, `soul.gd:371`, `ghost_form.gd:299`, `match_result.gd:29` |
| C «¿dibuja?» (`is_dedicated`) | 3 | `damage_numbers.gd:208`, `camera_shake.gd:147`, `altar_collapse.gd:114` |
| D snapshot/canal propio | 2 | `match_state.gd:69-89,352,385`, `match_biome.gd:23-43,77` |
| E flujo y pantallas de red | 8 | `sacrifice_flow.gd`, `scenes/ui/lobby/*`, `scenes/ui/local_server/*`, `pause_menu.gd:50` |
El juego nunca llama `set_multiplayer_authority` (todo nodo con autoridad en el peer 1). El lint cuenta comentarios.

## 3. Diseño
- Autoridad: el propio nodo con `is_multiplayer_authority()`; fuera los `_has_authority()` privados; los públicos (`UnitBody.simulates()`, `MatchState.is_authority()`, `Terrain.is_authority()`) solo cambian el cuerpo.
- Spawners: `MpSpawner.spawn_here(data)` (kit) — crea en servidor y solo, null en cliente. Subclases `Mp*` a la allowlist.
- Asiento local: nodo del kit `MpLocalSeat` en `match.tscn` (`slot`, `is_mine(slot)`, `is_online()`, `changed(slot)`, `preview_slot` en el inspector). HUD, audio, órdenes, pausa y resultado lo reciben por `@export var seat`; lo que nace en runtime usa `MpLocalSeat.of(self)` (`const GROUP`).
- Presentación: `ScreenGate.is_open()` (hermano de `AudioGate`): no headless y no dedicado.
- Snapshots: el estado de la partida por un `MpState` `Shared` (`shared.set_value(&"match", ...)`, cliente `shared.watch(&"match", apply_snapshot)`, kit nuevo). El bioma NO va a `MpState` (`MatchSky.message()` lleva `at_s`): va por un nodo de red con `@rpc` — **es el `BiomeLink` de 055i-b b3** (`scenes/net/biome_link.gd`); N7 lo reusa en lugar de crear `MatchBiomeNet`.
- Comandos: sin cambios (`submit_*` + `MpAuthority`).
- Lint C12: cuenta `\bMp(Kit)?\.`; allowlist suma `extends Mp[A-Z]…`, `scenes/ui/lobby/`, `scenes/ui/local_server/`, `scenes/ui/match_wait/`.

## 4. Árbol
Kit (`addons/mp_kit/`, versión siguiente a la de 069): `[~] mp_spawner.gd` (spawn_here), `[~] mp_slot_spawner.gd` (peers ya listos en `_ready`), `[+] nodes/mp_local_seat.gd`, `[~] nodes/mp_state.gd` (watch), `[~] tests/`, docs; en rc `skills/godot-mp-kit/*`.
Juego: `[~] tools/lint/conventions.sh`, `baseline.txt`, `CONVENTIONS.md`; `[+] scenes/core/screen_gate.gd`; `[~] match.tscn` (Shared, LocalSeat, `seat_away` de la puerta → WizardSpawner, `seat` en Selection/PointerRay/CommandFeedback/DamageNumbers/MusicDirector/Advisor*/PauseMenu/Hud/MatchResult/LobbyReturn), `match_state.gd`, `match_biome.gd`; los 42 de A1, 5 spawners, 10 de B, 3 de C, `pause_menu`, `lobby_return`, `ai_side`. Sin archivos borrados.

## 5. Mejoras al kit
| # | Propuesta | ¿Subir? |
|---|---|---|
| K1 | `MpSlotSpawner` crea en `_ready` los peers ya listos (hoy el juego lo parchea en `wizard_spawner.gd:31`) | Sí (bug) |
| K2 | ~~`slot_away`~~: se usa `seat_away` (gate) / `player_left` (MpMatch) | No |
| K3 | `MpSpawner.spawn_here(data)` | Sí |
| K4 | docs: `is_multiplayer_authority()` dentro de un nodo (los ejemplos actuales con `not MpKit.is_server()` rompen jugando solo) | Sí (EN y ES) |
| K5 | nodo `MpLocalSeat` | Sí |
| K6 | `MpState.watch(key, cb)` | Sí |
| K7 | `LICENSE` en la copia del juego (el kit ya la tiene) | Sí, solo la copia |
| K8 | `each_world_ready(cb)` | No (un llamador) |
| K9 | `MpKit.draws()` | No (`ScreenGate`) |
| K10 | sincronizadores en escena en vez de `ensure_sync` | No ahora |

## 6. Riesgos
`is_multiplayer_authority()` fuera del árbol (revisar llamadores en `setup()` antes de `add_child`: `ranged_shot._add_in_flight`, `health`, `unit_body.simulates`). Relay / id de servidor ≠ 1 sin verificar. `MpState` ON_CHANGE en vez de RPC puede cambiar el orden con los FX del altar (si falla, `MatchStateNet`). Referencias en debug/agent a métodos que salen.
Fuera de alcance: `MpActor`/`MpInput`, `ensure_sync`, los ~30 `DisplayServer.get_name()=="headless"` (055z), `MpMatch`.

## 7. Cortes
| Corte | Contenido | Cuándo |
|---|---|---|
| K | kit K1, K3–K6 + tests | después del PR #12 corregido y de integrar 069 W1 (mismo addon) |
| N0 | lint C12 ampliado + allowlist | ya |
| N1 | `scenes/units/**` (27) | ya |
| N2 | hechizos y sacrificio (9) | ya |
| N3 | `health`, `mana_pool`, `soul_purse`, `soul` | después de 060s |
| N4 | mapa, nav e IA (7) | después de 055i-b b1 |
| N5 | spawners + `seat_away` | después de K |
| N6 | asiento y pantalla + `ScreenGate` | después de K y N5 |
| N7 | `Shared` + `MatchState` + bioma (reusa `BiomeLink`) | después de K, N6 y 055i-b b3 |
| F | pasada única; kit a rc EN y ES | al final |

## 8. Pruebas
Por corte sin Godot: lint (C12 baja, nada sube), greps del patrón y `_has_authority` en 0. K: tests del kit + `mpkit_lab` quick. F: import, lint C12 = 0, determinismo quick idéntico en 3 modos, NET QUICK enet y ws, gate, ptnet_real. A mano: F5 solo (órdenes, números de daño), LAN dos ventanas (color de alma, música de resultado).
