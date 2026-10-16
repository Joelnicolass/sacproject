# Editor, scaffold y túnel

El plugin, habilitado, registra el autoload y el menú **Project → Tools**.

| Acción | Qué hace |
|--------|----------|
| **Wire replication on selection** | Hijo `MpReplicate` + `MultiplayerSynchronizer` (undo). No clona el dock Replication de Godot. |
| **New replicated feature...** | Crea `res://features/<id>/` (o la carpeta que indiques): `.gd` + `.tscn` con replicate, sync y opcional `MpCustomPipe`. |
| **New session flow...** | Escribe `res://glue/session_flow.tscn` + `.gd` (`extends MpFlow`) y lo registra como autoload. |
| **Install Cursor/VS Code snippets** | Copia `.vscode/mpkit.code-snippets`. Recargá la ventana del editor. Prefijos: `mpkit-submit`, `mpkit-custom`, `mpkit-boot`, `mpkit-flow`, `mpkit-lan-adv`, `mpkit-lan-browse`. |

Al Enable también copia **script templates** a `res://script_templates/` (con `.gdignore`). Al adjuntar un script a `CharacterBody2D/3D` o `Node2D/3D`, plantilla **MpKit replicated**.

CI/headless: autoload en `project.godot`. No dupliques Enable + línea manual.

Sin Godot abierto (Claude Code o Cursor): command `/new-mp-feature` (mismo layout de archivos). `./install.sh --addon` también instala los snippets en `.vscode/`.

## Nodos (Create New Node)

| Nodo | Uso |
|------|-----|
| `MpReplicate` | Hijo del actor. Authority peer 1, props de sync, freeze RigidBody proxy. `interpolate` opcional en proxies. |
| `MpSpawner` | `MultiplayerSpawner` + `extra_scenes`. `spawn_path` = padre de actores. Hold + `request_world_ready` en el cliente. Un nodo basta. |
| `MpSlotSpawner` | Igual + un `pawn_scene` por slot ocupado (`Pawn_<n>`). Dedicated no spawnea slot 0. |
| `MpBootMenu` | Lobby drop-in. Usa `MpFlow` si está en el árbol; si no, `world_scene` para zero-glue. Copy por `@export`. |
| `MpFlow` | Autoload de sesión: boot/world(s), host/join/1P, late join. Varios mapas: `add_world` / `select_world`. |
| `MpWorldReady` | Legado. No hace falta si hay `MpSpawner`. |
| `MpCustomPipe` | Un canal del túnel `Dictionary`. |

LAN y dedicated: el mismo árbol. El boot elige `host()` / `host_dedicated()`.

## Túnel `Dictionary` (bajo nivel, controlado)

El kit **no** interpreta el dict. No hay reflect automático (el servidor decide si reenvía).

```
Cliente / 1P / servidor local    MpKit.send_custom(channel, data)
Servidor → todos                 MpKit.broadcast_custom(channel, data)
Servidor → un peer               MpKit.push_custom_to(peer_id, channel, data)
Señal                            custom_received(channel, data, from_peer)
```

Allowlist opcional en `configure(..., custom_channels)`. Vacío = todos los nombres. No vacío = se descarta lo que no está en la lista.

O un nodo `MpCustomPipe` por feature (`@export channel`, signal `packet`).

No metas meshes, puntaje ni `kind` de bala acá: Resources + `submit_*` del actor. El túnel es el escape hatch (emote, debug, un handshake vuestro).

Paso a paso humano (mandar / recibir / reenviar al servidor, salas hub y cola, con diagramas): `addons/mp_kit/README.md`.

## Estructura de una feature

```
res://features/<id>/
  <id>.gd      try_/submit_/apply_  (y send_manual si hay pipe)
  <id>.tscn    root + MpReplicate + MultiplayerSynchronizer [+ MpCustomPipe]
```

Después: registrar la packed scene en `MpSpawner` / spawnable_scenes. Tipos de contenido = `.tres` del juego, no un canal por `kind`.
