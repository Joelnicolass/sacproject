# RFC-037 — Minimapa

Estado: plan del tech lead (Opus), pendiente de OK. Arquitectura **estándar**. MP **online con dedicado**: el minimapa es presentación local, **sin RPC nuevo**. Para el plan no se corrió Godot: todo sale de leer el código.
- **Pedido del usuario (2026-10-18, después de una partida contra la IA):** falta el minimapa.
- **Autoridad:** pedido del usuario > PRD > FEATURES > RULES (§Fidelidad y pruebas: Godot estándar primero; del original solo lo que nota el jugador) > VISUAL > este plan.
- **Features:** las asigna el orquestador (una F por corte, desde la siguiente libre después de F211).

## 0. Qué hace el original

Fuente: sacengine `source/renderer.d:4459-4760` (`renderMinimap`), `dagonBackend.d:892, 948-970, 1314-1325`, `state.d:29694-29780`. Se describe, no se copia (GPL).

- **Forma y lugar:** un círculo abajo a la derecha, de radio `80 · hudScaling` px, con fondo verde azulado oscuro y marco del HUD.
- **Orientación:** gira con la cámara (arriba = hacia donde mira). El centro no es el mago: es un punto **por delante** de la cámara (`distance · 3,73` hacia adelante).
- **Zoom:** propio, con la rueda sobre el minimapa (`minimapZoom` 2,7, de 0,5 a 15). La rueda fuera del minimapa sigue siendo el zoom de la cámara.
- **Fondo:** las mallas del terreno vistas desde arriba, con su textura, sin luz y teñidas a 0,5 gris. Sin edificios ni plantas.
- **Iconos** de un atlas (`icon.FLDR/mmic.TXTR`; **no está exportado** en `assets/original/ui/`):
  - criatura: punto chico; mago: icono propio y más grande;
  - altar, Manalith, Shrine: icono propio; manantial de maná: icono celeste fijo;
  - almas: punto con el color del alma.
  - El color es el del lado (`sideColor`; en el port, `SideColors.side_color`). Los NPC son grises.
  - Una alerta (te atacan) hace parpadear el icono en rojo.
- **Flechas en el borde:** lo propio (criaturas, Manalith, altar) y los magos que caen fuera del círculo se dibujan como una flecha pegada al borde que apunta hacia ellos.
- **Cuña de visión:** dos líneas amarillas desde el mago, de 82°, en la dirección a la que mira.
- **Qué se oculta:** muertos y disolviéndose; enemigos en modo invisible (sigilo). Con niebla de guerra encendida, además, lo que el lado no vio. **La niebla está apagada por defecto** en sacengine (`options.d:93`), así que en una partida normal se ve todo el mapa.
- **Clics:** el minimapa es otra superficie para apuntar. Un clic en el minimapa da un objetivo de terreno (o de criatura/edificio si cae sobre el icono) **igual que un clic en la escena**: clic derecho = orden, hechizo armado = lanzarlo ahí, arrastre izquierdo = selección por rectángulo de los iconos. **La cámara no salta**: en Sacrifice la cámara sigue siempre al mago.
- **Dudoso:** el radio exacto del marco a escala 0,8 del port (F84), el dibujo exacto del marco y si el centro adelantado se nota al jugar. Se mide en 037d contra una captura del original si hace falta.

## 1. Diseño en Godot estándar

### 1.1 Piezas

| Pieza | Qué es | Responsabilidad (una) |
|---|---|---|
| `MinimapTerrainBake` (`minimap_terrain_bake.tscn`) | `SubViewport` con `own_world_3d = true`, un `MeshInstance3D` con la malla de `%Terrain` y una `Camera3D` **ortográfica** cenital. `render_target_update_mode = ONCE` | Produce **una vez** la textura del terreno visto desde arriba. No dibuja nada más |
| `Minimap` (`minimap.tscn`, `Control`) | Raíz del minimapa en el HUD. Sockets `@export`: `camera` (WorldCamera), `terrain_bake`, `units_root`, `hud_scale` | Arma el estado de cada cuadro (centro, giro, zoom) y se lo pasa a los hijos. Traduce un punto de pantalla a un punto del mundo (`screen_to_world`) |
| `MinimapGround` (hijo, `TextureRect` o `Control._draw`) | Dibuja la textura horneada con el giro y la escala del cuadro | Fondo |
| `MinimapMarkers` (hijo, `Control._draw`) | Recorre los grupos `wizard`, `unit`, `structure`, `manafount`, `soul` y dibuja un icono por cuerpo | Marcadores y flechas de borde |
| `MinimapMarkerStyle` (Resource, `.tres` por tipo) | `texture: Texture2D` (vacía = forma dibujada), `size_px`, `shape` (punto / triángulo / rombo), `use_side_color`, `fixed_color`, `edge_arrow` | Look de cada tipo, editable en el inspector |
| `MinimapStyleSet` (Resource, `data/ui/minimap/style_set.tres`) | `wizard`, `creature`, `altar`, `manalith`, `manafount`, `soul`, `background_color`, `ground_tint`, `fov_color`, `fov_deg` (82) | Un solo lugar para el look entero |
| `MinimapView` (Resource, `data/ui/minimap/view.tres`) | `radius_px` (80 a escala 1), `zoom` (2,7), `min_zoom`, `max_zoom`, `zoom_step`, `lead_factor` (3,73), `heading_up` (true) | Knobs de comportamiento |
| `circle_mask.gdshader` | Shader de `CanvasItem` que recorta a un círculo y pone el borde | Recorte circular; el marco es un `NinePatchRect`/`TextureRect` hermano |

### 1.2 Terreno

- El bake instancia **la misma malla** que `%Terrain` (no una copia), en un mundo propio, así no entran plantas, edificios, cielo ni niebla.
- Cámara ortográfica a la altura máxima del terreno + margen, `size` = lado del mapa (2560 m en High Noon; se lee de la AABB de la malla, no se escribe a mano).
- Sin luz: `SubViewport.debug_draw = DEBUG_DRAW_UNSHADED`. Si en el binario exportado no sirve (ver §5, riesgo R1), se usa un `material_override` sin sombreado con el mismo atlas de tiles (`tiles.png`).
- Tamaño de la textura: `@export var resolution := 1024` (2,5 m por píxel). Se hornea al cargar el mapa y queda fija. Si el mapa cambia en el editor, se rehace al abrir la escena.
- En el dedicado (`DisplayServer` headless) no se hornea y el `Minimap` no existe (el `Hud` no hace nada sin pantalla).

### 1.3 Marcadores

- Un solo `_draw` por cuadro para todos los iconos (150 criaturas + NPC ≈ 200 iconos): sin un nodo por unidad. Si mide más de 0,5 ms con 300 cuerpos, se pasa a `MultiMeshInstance2D` (§5, R3).
- Se oculta lo que el original oculta y el port ya sabe: un **enemigo** con `is_targetable() == false` (muerto, convocándose, haciéndose el muerto, sigilo, afligido que oculta). Lo propio se ve siempre.
- **Niebla:** el port no tiene niebla (`SideVision` guarda la grilla pero nadie la dibuja, F165). El minimapa **no** la usa en este RFC.
- Flechas de borde para lo propio y los magos, como el original.
- Cuña de 82° del mago local con `fov_color`.
- Parpadeo de alerta: **fuera de alcance** (no hay evento de alerta en el port todavía).

### 1.4 Entrada

Acciones nuevas en el InputMap (no scancodes):

| Acción | Tecla por defecto | Qué hace |
|---|---|---|
| `minimap_zoom_in` / `minimap_zoom_out` | rueda arriba / abajo **sobre el minimapa** | Zoom propio, en `Minimap._gui_input` |
| `minimap_toggle` | `M` | Muestra u oculta el minimapa (`observerMinimap` del original) |

- **Clic derecho** sobre el minimapa: `Minimap` emite `ground_pointed(point: Vector3, button)`. `MatchCommand` lo conecta y llama al mismo `_order("move", point, null)` que el clic derecho en el suelo. **Usa `Orders.request` → `submit_order`, como hoy.**
- **Clic izquierdo con una orden o un hechizo armado:** mismo camino que `_left_at` con el punto de mundo en lugar del rayo.
- **Clic izquierdo sin nada armado:** no hace nada en 037 (ver P2).
- `TargetProbe`/`CursorSkin`: el `Minimap` entra en `hud_controls` para que el cursor cambie igual que sobre el resto del HUD.
- `WorldCamera` lee la rueda en `_input`, que corre **antes** que la GUI: consumirla en el `Control` no alcanza. Se le suma a la cámara un socket `@export var wheel_blockers: Array[Control]` (el `Minimap`) y no hace zoom si el puntero está sobre uno de ellos, igual que hoy `edge_area` limita los bordes.
- El `Minimap` tiene `mouse_filter = STOP` y está por encima de `%View`, así que el clic sobre él no llega al `gui_input` de `%View` (no hay doble orden).

### 1.5 Red

- El minimapa lee nodos que ya están replicados en el cliente (posición de magos, unidades, almas, estructuras). **No agrega RPC ni sincronizadores.**
- Una orden desde el minimapa es un `Orders.request` normal: el dedicado valida dueño y aplica, como cualquier clic derecho.
- Riesgo: si `_stealth` no se replica al cliente, el enemigo en sigilo se vería en el minimapa del rival (R2).

## 2. Árbol de archivos

```text
scenes/ui/minimap/
├── minimap.tscn                 # Control raíz (anclado abajo a la derecha): Ground + Markers + Frame
├── minimap.gd                   # class_name Minimap: estado del cuadro, screen_to_world, señal ground_pointed
├── minimap_ground.gd            # dibuja la textura horneada girada y escalada
├── minimap_markers.gd           # _draw de iconos, flechas de borde y cuña de visión
├── minimap_marker_style.gd      # class_name MinimapMarkerStyle (Resource)
├── minimap_style_set.gd         # class_name MinimapStyleSet (Resource)
├── minimap_view.gd              # class_name MinimapView (Resource)
├── minimap_terrain_bake.tscn    # SubViewport own_world + MeshInstance3D + Camera3D ortográfica
├── minimap_terrain_bake.gd      # class_name MinimapTerrainBake: toma la malla, encuadra, hornea una vez
└── circle_mask.gdshader         # recorte circular del CanvasItem

data/ui/minimap/
├── view.tres                    # radio, zoom, límites, adelanto, heading_up
├── style_set.tres               # look del minimapa completo
├── wizard.tres  creature.tres  altar.tres  manalith.tres  manafount.tres  soul.tres   # MinimapMarkerStyle

scenes/world/high_noon.tscn      # + Hud/Minimap (instancia) y MinimapTerrainBake (hijo de HighNoon, socket terrain)
scenes/world/world_camera.gd     # + @export wheel_blockers: sin zoom de cámara con el puntero sobre el minimapa
scenes/world/match_command.gd    # conecta Minimap.ground_pointed → _order / _left_at con punto de mundo
project.godot                    # + minimap_zoom_in, minimap_zoom_out, minimap_toggle

debug/
└── (ninguna nueva) usa debug/orders_group.tscn: ya instancia high_noon.tscn, trae 4 Trogg propios y un Druid enemigo

agent/flows/
├── f037_minimap.json            # captura del minimapa en orders_group, giro de cámara, zoom
└── f037_minimap_order.json      # clic derecho en el minimapa → los Trogg caminan ahí
agent/harness/minimap_probe.gd   # lee Minimap.screen_to_world y el estado de los marcadores para los flows
```

### Mapa de responsabilidades

| Pieza | Responsabilidad (una) | Tipo | Por qué no se fusiona |
|---|---|---|---|
| `minimap_terrain_bake.tscn` | Textura cenital del terreno, una vez | Packed scene (SubViewport) | Corre sola con F6 y se puede reusar en otro mapa o en el lobby |
| `minimap.gd` | Centro/giro/zoom y conversión pantalla ↔ mundo | Nodo Control | Si también dibujara iconos, crecería con cada tipo nuevo |
| `minimap_ground.gd` | Dibujar el fondo | Nodo hijo | Se apaga sacándolo (por ejemplo, para probar solo iconos) |
| `minimap_markers.gd` | Dibujar iconos, flechas, cuña | Nodo hijo | Mismo motivo; es la pieza que puede pasar a MultiMesh |
| `MinimapMarkerStyle` `.tres` | Look de un tipo de icono | Resource | Otro tipo = otro `.tres`, sin código |
| `MinimapStyleSet` / `MinimapView` | Look completo / comportamiento | Resource | Separar look de comportamiento deja tunear zoom sin tocar colores |
| `match_command.gd` (cambio) | Traducir el punto del minimapa a una orden | Nodo existente | El minimapa no conoce `Orders`: emite una señal |

### Qué es qué

- **Resource de tipo:** `MinimapMarkerStyle` (uno por tipo de icono), `MinimapStyleSet`, `MinimapView`. No se mutan en partida: el zoom actual vive en el nodo `Minimap` (`var zoom`), arrancando del `.tres`.
- **Nodo:** `Minimap`, `MinimapGround`, `MinimapMarkers`, `MinimapTerrainBake`.
- **`@export` de instancia:** sockets `camera`, `terrain_bake`, `hud_scale`, `style`, `view` en `Minimap`; `terrain` y `resolution` en `MinimapTerrainBake`; anclaje y margen en `minimap.tscn`.

## 3. Escena de prueba

- **Ninguna nueva.** El criterio aparece en cualquier partida, y `debug/orders_group.tscn` ya instancia `high_noon.tscn` con 4 Trogg propios seleccionables y un Druid enemigo a 40 m.
- **Estado inicial:** mago local, 4 Trogg delante, Druid enemigo, minimapa visible, nada seleccionado.
- **Qué no está todavía:** los Trogg no se movieron.
- **Acciones del playtester:** `check_tick` (selecciona el grupo, ya existe), clic derecho sobre el minimapa a un punto lejos del grupo, rueda sobre el minimapa, `turn_left`, `minimap_toggle`.

## 4. Cortes

Cada corte es chico y cierra con una prueba barata. Ninguno toca la simulación: `quick` no debe mover digests.

| Corte | Qué entra | Prueba barata |
|---|---|---|
| **037a** — terreno horneado | `MinimapTerrainBake` (+ `.gd`). F6 sobre la escena con la malla de High Noon | F6 de `minimap_terrain_bake.tscn` + captura de la textura (`agent/out/f037a/terrain.png`). Criterio: se reconocen los 5 manantiales y el contorno de la meseta; sin sombras. Import limpio |
| **037b** — minimapa que se ve | `Minimap`, `MinimapGround`, `MinimapMarkers`, los tres Resources, `circle_mask`, instancia en `high_noon.tscn`, `HudScale`. Heading-up, centro adelantado, iconos de forma (sin atlas), cuña, flechas de borde | Flow `f037_minimap` en `orders_group.tscn`: captura a 720 y 1080; giro de 90° con `turn_left` y otra captura. Criterio numérico desde `minimap_probe`: el icono del mago local está a ≤ 2 px de donde `world_to_minimap(mago)` dice; tras girar, el Druid cambia de cuadrante. `f80_hud_text` auditoría 0 (no hay texto nuevo). `quick` PASS sin regrabar |
| **037c** — entrada | Zoom con rueda sobre el minimapa (sin mover la cámara), `minimap_toggle`, clic derecho = orden de mover, clic izquierdo con orden/hechizo armado | Flow `f037_minimap_order`: seleccionar, clic derecho en el minimapa a un punto conocido; a los 8 s el centro del grupo está a ≤ 6 m del punto. Rueda sobre el minimapa: `Minimap.zoom` cambia y `WorldCamera.target_zoom` no. `run_034e` (dedicado) E2E PASS: la orden pasa por `submit_order` |
| **037d** — cierre | Medida contra el original (radio, posición), RULES/FEATURES | Playtest con ventana, partida Solo contra la IA (`pt037`): AGENT_OK, sin errores, capturas del minimapa con criaturas de los dos lados. `quick` PASS |

Orden: 037a → 037b → 037c → 037d. 037a y 037b son de presentación pura (sin review separada, RULES §Fidelidad). 037c toca la entrada: verificación del orquestador con el E2E de red.

## 5. Riesgos

- **R1 — Sin luz en el bake.** `debug_draw = UNSHADED` en un `SubViewport` puede no aplicarse en un export de release. Plan B: `material_override` sin sombreado con `tiles.png`. Se decide en 037a mirando la captura.
- **R2 — Sigilo en el cliente.** El minimapa del cliente lee `is_targetable()`. Si `_stealth` o el modo no se replican, el enemigo en sigilo se vería. Se verifica en 037b con `village_net` o `run_034e`; si falla, se replica el flag (propiedad del `MultiplayerSynchronizer` ya existente, sin RPC nuevo).
- **R3 — Costo del `_draw`** con 300 cuerpos. Se mide en 037b (`perf` del flow). Por encima de 0,5 ms por cuadro, pasar `MinimapMarkers` a `MultiMeshInstance2D`.
- **R4 — Rueda doble.** `WorldCamera._input` recibe la rueda antes que cualquier `Control`. Se resuelve en 037c con `wheel_blockers` (§1.4), sin tocar el resto de la cámara.

## 6. Fuera de alcance

- Niebla de guerra (en el minimapa y en el mundo). Cuando exista, será otro RFC que le dé a `SideVision` su consumidor.
- Parpadeo de alerta, iconos del atlas `mmic` si no se aprueba P3, selección por rectángulo sobre el minimapa, Shrine (fuera del primer corte en el PRD).
- Mover la cámara con el minimapa (ver P1).

## 7. Cómo verifica un humano en el editor

1. Abrir `scenes/ui/minimap/minimap_terrain_bake.tscn` y F6: se ve High Noon desde arriba.
2. Abrir `data/ui/minimap/creature.tres` y cambiar `size_px`: al correr `debug/orders_group.tscn` (F6) los Trogg se ven más grandes.
3. En `debug/orders_group.tscn`, F6: minimapa abajo a la derecha; girar con las flechas y ver que el mapa gira; rueda sobre el minimapa; `check_tick` y clic derecho en el minimapa: el grupo camina hasta ahí.
4. `data/ui/minimap/view.tres` → `heading_up = false`: el mapa queda fijo con el norte arriba.

## 8. Preguntas abiertas

- **P1 — ¿Clic en el minimapa mueve la cámara?** El pedido dice «clic para mover la cámara». En Sacrifice, la cámara sigue siempre al mago (tercera persona, `WorldCamera.follow`). No hay cámara libre para mover. **Recomendación:** hacer lo del original: clic derecho = orden ahí; clic izquierdo con algo armado = apuntar ahí. La cámara no salta. Una cámara libre sería otro RFC y cambia cómo se juega.
- **P2 — ¿Clic izquierdo solo (sin nada armado)?** **Recomendación:** no hacer nada en 037. La selección por rectángulo de iconos (original) es poco usada y se puede sumar después.
- **P3 — ¿Iconos del original?** El atlas `mmic` no está exportado. **Recomendación:** sí, en 037b, sumar `mmic` a `tools/import_ui.py` (una línea de `ICON_ROOT`, se versiona en `assets/original/ui/hud/` como el resto, RFC-033) y recortarlo con `AtlasTexture` en los `.tres`. Si el usuario prefiere no tocar el importador, las formas dibujadas quedan como placeholder.
- **P4 — ¿Orientación?** **Recomendación:** heading-up, como el original (`heading_up = true`). Queda como knob para quien prefiera norte arriba.

## Decisión 2026-10-18 (orquestador, cola delegada)

Se aplican las recomendaciones de todas las preguntas. El usuario puede revisarlas al volver; la más visible es P1 de 037: el clic en el minimapa no mueve la cámara, como en el original.

## Cierre 2026-10-18

037a–037d hechos (F212–F215). `all` PASS y partida con ventana PASS.
