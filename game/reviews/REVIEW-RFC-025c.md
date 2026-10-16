# Review RFC-025c (F80): iconos y cursores del original, sin textos indicadores

Una pasada, sin implementar. Veredicto global: **NEEDS WORK** (1 bloqueante de alcance, 1 hueco funcional de P1). El resto es PASS.

## Veredicto por dimensión

| Dimensión | Veredicto |
|---|---|
| Sin textos indicadores dibujados | NEEDS WORK (B1) |
| Compatibilidad de los ~86 flows con `%Battle` | PASS |
| Composición (Log / Cue / Skin / Probe) | PASS con observaciones |
| Cursor sobre la HUD | PASS (estático), sin verificar con mouse real |
| Riesgos RFC-024 / Retina | PASS con observaciones |
| Respaldo sin caché / nada del original en el repo | PASS |

## Bloqueantes

**B1. Queda un texto indicador dibujado fuera de `Hud`: «Sin almas».**
`scenes/world/souls/soul_system.gd:105-108` (`_say` hace `message_label.text = text; visible = true`) y `scenes/world/souls/soul_system.tscn:21` (Label `Notice/SoulMessage`, CanvasLayer propio, fuente 28 con contorno). Se muestra 2,5 s al soltar un alma sin tener (`:63`, `:93`). Es justo el tipo de texto que pidió sacar el usuario. La auditoría `agent/harness/hud_text_audit.gd` solo recorre el nodo `Hud` (`find_child("Hud")`), por eso devuelve 0/0/0/0 y no lo ve: el criterio de «0 textos» se cumple por construcción de la auditoría, no del juego. Corrección pedida (una): que `SoulSystem` deje de dibujar (quitar `Notice/SoulMessage` o enrutar `message` a `%Battle.say` para que se vea como destello `ncst`; hoy nadie conecta la señal `message`) y que la auditoría recorra todos los `CanvasLayer` de la escena actual, no solo `Hud`. Con el `selftest` extendido a un Label puesto fuera de `Hud`.

## Hueco funcional (NEEDS WORK, no bloquea el cierre si el orquestador lo acepta)

**H1. Dos rechazos de MatchCommand quedan mudos (P1 dice: todo rechazo = destello `ncst`).**
`CueSet.refusals` (`data/ui/command_cues.tres:14-28`) no incluye «Nadie» (`match_command.gd:504`, orden sin selección) ni «Sin mago» (`match_command.gd:180, 200, 223, 495`). Antes eran texto visible; ahora el click no hace nada y no se ve nada. Además el mapa palabra→cue es frágil por diseño: cualquier mensaje nuevo o cualquier `reason` de habilidad (`_apply_ability`) que no esté en la tabla se pierde sin aviso. Sugerencia mínima: agregar esas dos palabras al `.tres`. Mejor a futuro: que la señal sea de rechazo (`refused(reason)`), no una palabra a comparar.

## Evidencia por pedido

**(1) Textos indicadores.** grep de asignaciones a `.text`/`tooltip_text` en `scenes/ui`, `match_command.gd`, `command_log.gd`:
- Dibujados y permitidos (grupo `hud_text_allowed`): `Title`, `Stats`, `GhostState` (`hud.tscn:19,29,39`), `RitualNotice`, `MatchResult`. Coinciden con P3.
- Dígitos solos (permitidos por la auditoría): `spell_slot.gd:50` (`%Time`, segundos de enfriamiento), `roster_cell.gd:102`.
- Nombre de respaldo cuando no hay icono: `spell_slot.gd:57-58`, `spell_book.gd:45`, `selection_roster.gd:221`. Aceptable (solo sin caché).
- `tooltip_text` en `spell_slot.gd:17,25` y roster (`selection_roster.gd:164,190,223,252`, con flag `tooltips`): aparecen al pasar el mouse. Son texto indicador estricto; el RFC no los prohíbe, pero el usuario podría contarlos. Decidir si P3 los cubre.
- `%Battle.text` sigue existiendo solo como dato (`command_log.gd:24`); `match_command.gd` ya no asigna `.text` a ningún Label (todo va por `say`/`arm`). Confirmado.
- `Label3D` «Falta el terreno…» (`high_noon.tscn:85`): aviso de error de datos, N/A.
- Fuera de lo auditado: B1.

**(2) Flows con `%Battle`.** Las claves usadas sobre `%Battle` en `agent/flows/*.json` son `assert text_equals/text_contains` y `print prop=text` (233 referencias, 0 con `visible`, 0 con propiedades de Label). `CommandLog` tiene `var text`, así que el AgentKit lo lee igual. Solo `high_noon.tscn` define `Battle` (ninguna escena de `debug/` lo pisa ni lo menciona; todas heredan `high_noon`). Corrí dos flows, uno por vez, ventana 1280x720, `--max-fps 60`, RSS máx ~380 MB, editor pid 9527 intacto:
- `f24_cast.json` (debug/cast_heal): 16 asserts ok, `AGENT_ERRORS []`.
- `f27_orders.json` (debug/orders_group): 12 asserts ok, `AGENT_ERRORS []`.
No corrí `pt*` (la familia usa los mismos asserts por texto). Riesgo residual bajo: un flow que dependa de que `text` se limpie al desarmar (`disarm` no lo borra; `arm` solo lo pisa si hay `prompt`).

**(3) Composición.**
- `CommandLog` (`scenes/world/command_log.gd`): solo estado y señales. Observación: `say()` llama a `cues.cue_for` (clasificación palabra→cue), un poco de lógica; tolerable, ver H1.
- `CommandCue`: presentación. Observación: `_check_hover` (`command_cue.gd`) decide si el icono armado «acepta» el blanco; es una regla de validez en la vista. Mejor que lo decida el probe o el log y la vista solo lea un bool. Nit.
- `CursorSkin`: presentación; no-op si `DisplayServer` es headless y si `MpKit.local_slot() <= 0` (servidor dedicado), con contador `apply_count` para el flow. `_exit_tree` restaura el cursor.
- `TargetProbe`: único rayo de hover (30 Hz, también inactivo y sin icono armado; costo bajo). Observación: `_classify` (`target_probe.gd:80`) duplica la clasificación de `MatchCommand` (`_unit_under` `:590`, `_body_under` `:602`, `_soul_under`, `_building_under`, máscaras). Si RFC-024 cambia máscaras o grupos, el cursor y el click divergen. Nit estructural, no bloquea.
- Sockets `@export` tipados + `_get_configuration_warnings`; look de los textos/colores de respaldo en `@export`; tipos en `command_cues.tres` (solo tags y nombres).
- Sin caché: `HudIcons.*` devuelve null y `CommandCue` dibuja círculo/cruz (`command_cue.gd` `_draw`); `CursorSkin` deja el cursor del sistema. `f80_nocache_refused.png` lo muestra (círculo + cruz). Esa captura es de `debug/rock_hit` y sus textos (`Druid 800/800…`, `mira suelo…`) son del `HitLog` de la escena de debug, no de la HUD de producto.
- Nada del original en el repo: `cache/` está en `.gitignore:2` y `git ls-files | grep cache/` da 0; `command_cues.tres` solo guarda tags. N/A el resto del checklist (sin MP nuevo, sin RPC nuevo; `addons/` solo tiene cambios previos de otros cortes).

**(4) CursorSkin y la HUD.** `CueSet.cursor_for` cae a `hud_cursor = "Cnor"` para la clase `hud`, armado o no, así que sobre panel/libro nunca queda un cursor de blanco (`Tnme`, etc.). `_check_hover` no marca «inválido» sobre HUD. Verificado en `f80_hover_hud_armed.png` (con el estado forzado por flow). **No verificado con mouse real**: `TargetProbe._over_hud` usa `gui_get_hovered_control()` y el probe fuerza «no HUD» cuando el flow pone `debug_pointer`, así que la rama real nunca se ejerció. Observación: el `Control` raíz del `SpellBook` y su `Frame` son `mouse_filter = IGNORE` (`spell_book.tscn:16,23`), por lo que sobre el arte del libro entre slots el probe devuelve «mundo» (y el click también cae al mundo): consistente, pero el cursor mostrará `T*` ahí. Probar a mano.

**(5) Riesgos.**
- RFC-024 (`match_command.gd`): el setter de `_mode` llama a `%Battle.disarm()` (resuelve `%Battle` en el setter; solo corre después de `_ready`, bien). Cualquier código que escriba `_mode` antes de `_ready` o fuera de `high_noon` rompería. Los nuevos modos `structure`/`menu` y `_arm_order_icon` conviven con `arm()`; el `_mode == "menu"` + click re-arma por `_arm_order_icon` sin pasar por `_mode = ""`, correcto. Conviene que RFC-024 no meta rayos propios para la hover: reutilizar `TargetProbe`.
- Cursor de hardware en Retina: sin `stretch` en `project.godot` (solo `viewport 1280x720`), el tamaño es `32 · alto/480` en unidades del viewport (48 px a 720). Godot en macOS lo muestra a 1x (puntos = píxeles de la imagen), por lo que en Retina se verá del tamaño correcto pero rescalado (borroso). Sin verificar; la captura nunca incluye el cursor del sistema, por eso existe `%Mirror` (solo captura). Si luego se activa `stretch_mode` el cálculo con `get_visible_rect().size.y` dejará de coincidir con la ventana real.

## Capturas miradas
`f80_1_rock_armed_enemy_side_by_side.png` (Tnme rojo + kcor, coincide con el PNG del caché), `f80_4_refused_side_by_side.png` (Tntr azul + kcor + `ncst` cruz roja superpuesto), `f80_hover_hud_armed.png` (sin textos indicadores, solo Mago·Dios y Vida/Maná/Almas), `f80_nocache_refused.png` (respaldo). Look final de iconos/cursor y el cielo en RTS: a ojo del usuario (criterio 10), no hay captura RTS de este corte.

## ¿Se puede cerrar?
No todavía: una corrección (B1, más H1 que es una línea en el `.tres`). Después de eso, 025c se puede dar por cerrado en lo que es verificable por flows; quedan para el usuario: cursor de hardware real, Retina y el cursor sobre la HUD con mouse real.
