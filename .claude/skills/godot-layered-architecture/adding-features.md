# Cómo agregar una feature

En el juego: command `/implement-feature` (orquestador). No regeneres el PRD.

Leer primero `SKILL.md` (Clean vs estándar y tipo de MP ya elegidos). Tipos: [resources.md](../godot-composition-first/resources.md). Tests: [godot-testing](../godot-testing/SKILL.md). Red: `godot-mp-kit` **solo** si hay MP (local = listen; online = dedicated). Si no hay MP, el bloque de red es N/A.

Si un ítem no aplica, escribir “N/A”. No saltearlo en silencio.

## 1P (siempre)

1. [ ] Alcance de producto explícito. Si es un RFC del studio: el tech-lead mostró árbol + responsabilidades **antes** del OK.
2. [ ] ¿Es un **tipo** (otro proyectil, enemigo, item)? → Resource `.tres` + la misma escena. No un script por skin de stats.
3. [ ] Reglas de **ronda** (vidas, duración, layers): `MatchRules.tres`. Look de instancia: `@export`.
4. [ ] InputMap: acciones semánticas (`move_left`, `attack`), no `KEY_*`. Hold en `_physics_process`; one-shot de gameplay en `_unhandled_input`.
5. [ ] Sockets `@export` / `%UniqueName` para nodos propios. Escena jugable con F6. FSM: addon `fsm_kit` si hay estados. Platformer 2D: `plat_kit` (coyote/buffer), no `is_on_floor()` pelado.
6. [ ] Clean: ¿regla testeable sin escena? → `src/domain/` + test. Estándar: ¿el World se hincha? → componente, no domain inventado.
7. [ ] FX locales; shaders de [Godot Shaders](https://godotshaders.com/shader/?orderby=date&order=DESC) / [Shadertoy](https://www.shadertoy.com). Sprites 2D: ¿el usuario quiere MCP/arte? Si sí, referencias + [godot-animation](../godot-animation/SKILL.md). Si el feature es **3D**: ¿quiere MCP Blender? Si sí, referencias + [assets.md](../godot-composition-first/assets.md). Si no, placeholder. Copy de UI en el idioma del producto; código en inglés. HUD: no inventar look; `VISUAL.md` o refs.

## Si hay red (MpKit)

Si eligieron **local / WiFi** o **online**. Si no hay MP: N/A. Online: dedicated, ver [dedicated.md](../godot-mp-kit/dedicated.md).

8. [ ] Input local distingue host vs guest (`rpc_id(1, …)`). Túnel `send_custom` solo si no alcanza `submit_*` / Resource.
9. [ ] RPC cliente → servidor: allowlist, `any_peer` + sender vs `MpKit.peer_id_for(slot)`. No `call_local` que duplique daño/spawn.
10. [ ] Spawn de simulación: **solo host** + `MultiplayerSpawner` **antes** de `add_child`.
11. [ ] Transform: `MultiplayerSynchronizer` (o `MpAuthority.ensure_sync`).
12. [ ] Colisión / `queue_free` / puntos: autoridad del servidor.
13. [ ] Guest no muta vidas/trackers.
14. [ ] 1P: mismo código (`OfflineMultiplayerPeer`), **sin** `host()`.
15. [ ] 2P: no se duplican actores. Rejoin: decisión explícita. Dedicated: sin pawn para el server (`local_slot() == 0`).
16. [ ] El actor no tiene RPC de score.

## Pipeline de input

```
1. InputMap (acciones), no scancodes
2. if not puede_actuar(): return
3. if hay red y MpAuthority.should_send_command():
      rpc_id(1, submit_action, payload)
   else:
      apply_action(payload)
```

El nodo de input **no** instancia proyectiles ni suma puntos. Solo pide.

## Presentación

- Post-proceso, flashes: cada peer. No van en el snapshot de reglas.
- Un pass FX = una packed scene.
- HUD: `mouse_filter = IGNORE` salvo controles que traguen el pointer.
