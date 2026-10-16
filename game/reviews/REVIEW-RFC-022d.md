# Review RFC-022d (cielo)

Veredicto: **FAIL con bloqueantes** (2). Una pasada, solo lectura. Evidencia: lectura de `scenes/world/look/sky/*`, `data/look/sky/*.tres`, `look_rig`, `sky.gd`, lámina `agent/out/rfc022/022d/lamina_022d_final.jpg` y refs del original; suite y cargas headless.

## Ejecutado
- `res://debug/rules_suite.tscn` (`--fixed-fps 600 --quit-after 600000`): exit 0, 36 casos PASS, `RULES SUITE PASS`.
- Carga headless de `scenes/world/high_noon.tscn` y `debug/look_gallery.tscn` (`--quit-after 120`): 0 `ERROR` / `WARNING`.
- No corrí el banco ni toqué `grass/`. Los procesos Godot vivos (PIDs 1052, 74602) son el editor del usuario, no míos.
- GUT/suite no son playtest ni visual: el look del cielo queda para `studio-visual`.

## Bloqueantes
1. **El modo Legacy dibuja capas encima del cielo original** (VISUAL.md «cielo original… nada de saturación extra»; RFC-022 §17.6 «sin capas encima»; pedido del orquestador).
   - `scenes/world/look/sky/sky_discs.tscn` (pieza `Discs`) se pinta siempre que haya perfil, también en Legacy, con blend aditivo sobre el cielo. Los `.tres` Legacy llevan halo: `data/look/sky/persephone_sky.tres:18` (`halo_strength = 1.1`, `halo_power = 14`), `pyro_sky.tres:18` (0.8), `james_sky.tres:18` (0.5), `stratos_sky.tres:18` (0.5) y `charnel_sky.tres:17` (`moon_intensity = 4.0`, una luna que el original no tiene).
   - El shader `sky_discs.gdshader:17-27` suma `halo_color * pow(s, halo_power)` sobre el cielo y no hay guarda por `sky_mode`.
   - Arreglo: en Legacy, `SkyLayer._push_pieces` (`sky_layer.gd:154-163`) debe ocultar `Discs` (o los `.tres` Legacy deben llevar `halo_strength = 0`, `moon_intensity = 0`, `sun_intensity = 0`). El halo solo vale en Swirl.
2. **Costo del cielo no medido** y el banco sin resultado válido. El criterio de perf del RFC queda sin evidencia. Ver «Banco» abajo: no hay regresión demostrable del cielo, pero tampoco una corrida limpia.

## Chequeos pedidos
| Punto | Resultado |
|---|---|
| Shaders del cielo original intactos | PASS: `sky_band.gdshader` y `sky_clouds.gdshader` sin diff (siguen `fog_disabled`, `unshaded`). `sky.tscn` sin cambios. |
| `sky.gd` | Modificado, no pedido en el RFC (alcance): `@tool`, `editor_preview_scale`, loader por extensión (`load_png_from_buffer`/jpg/webp), `_validate_property` que quita `transform` del guardado. El runtime usa `SCALING` igual que antes. Aceptable para el editor; declararlo. |
| Legacy sin niebla ni capas encima | FAIL, ver bloqueante 1. Sí cumple lo de niebla: las piezas y el cielo original son `fog_disabled`. |
| Modo clásico (`look = null`) idéntico | PASS en imagen: `_look == null` -> `_restore()`, legacy visible, `SkyLook.new()` neutro, `Discs` hace `discard` (`sky_discs.gdshader:16`). Nit: el quad sigue rasterizándose a pantalla completa cada frame aunque descarte; ocultar `Discs` y `_process` sin perfil lo evita. |
| Restauración al apagar | PASS: `_refresh` -> `_restore` (`sky_layer.gd:111-123`) devuelve el `Environment` original (`_source_env`) o las `ENV_PROPS` capturadas; trabaja sobre `duplicate()` si el recurso es compartido. El orden con la capa de luz (ambas duplican) se resuelve porque la segunda ve `resource_path == ""`. |
| Restauración en `PRE_SAVE` | PASS con nit: restaura env, `clear_legacy()` y `legacy_sky.visible = true`, pero no devuelve `Swirl.visible = false` (`sky_layer.tscn` lo guarda apagado). Si se previsualiza Swirl en el editor y se guarda `high_noon`, puede quedar un override `visible = true` en el `.tscn`. Agregar `swirl.visible = false` en PRE_SAVE. |
| Restos de las capas rechazadas | PASS en archivos y escenas: `rg sky_shafts|sky_cloud_volume` fuera de `agent/out` y `.md` solo da `sky_layer.gd:169`, **un texto de advertencia viejo** («sky_shafts, sky_cloud_volume»). Corregir el mensaje. `data/look/sky/noise_clouds.tres` queda sin uso (`rg` sin referencias): borrarlo o justificarlo. |
| Swirl y licencias | PASS: `sky_swirl.gdshader` es propio (62 líneas; domain warp de dos planos, texturas del propio juego), el encabezado dice «nothing copied» y cita las técnicas en general, sin enlazar un shader concreto. No hay código CC BY-NC-SA. Pedir que el encabezado nombre la fuente de la técnica si se tomó alguna. |
| Swirl vs estética del original | Observación: en la lámina, Swirl de Persephone queda rosado/anaranjado y turbio, y el de Pyro cambia el carácter (celdas tipo «bubble») frente al original. No se parece a las capturas `orig_*`; como es opcional y ningún `.tres` de producción lo usa (todos `sky_mode = 0`), no bloquea, pero no debe activarse. |
| Composición y `@export` | PASS: `SkyLayer` -> `pieces`/`swirl` por socket tipado, piezas = packed scenes, `SkyLook` Resource con `@export_group`; `look_rig` expone `legacy_sky`. Sin `get_node("../")` entre sistemas (solo `legacy.get_node_or_null("%Clouds")`, `%Top`, entre piezas de la misma escena). |
| Editor sin autoloads | PASS: todo `@tool`, vía `_rig` y sockets. |
| Nada en el dedicado | PASS: `LookRig._ready` hace `queue_free` si no hay presentación (`look_rig.gd:35`). |
| MP / glue | N/A. |
| Producto juego (SQL/XSS/auth) | N/A. |

## Banco (sin correrlo)
- `capa_1` en `debug/look_bench.gd:129-131` es **solo la capa 0 (Luz)**: `_set_layers(rig, n, 0)` apaga Suelo y Cielo. Con el cielo apagado `SkyLayer._refresh` hace `_restore()` y no deja `env.sky`. Por tanto los 86 ms de `capa_1` no se pueden atribuir al cielo.
- Las capas 2+ (`capa_2` = Suelo, `capa_3` = Cielo) no completaron. No hay log del banco en `agent/out/rfc022/022d/` (solo PNG), así que no hay datos para afirmar regresión. Con otro agente usando la GPU en paralelo, la explicación de contención es plausible pero **no probada**.
- Único costo real del cielo que veo en código: `_apply_environment` crea un `Sky` nuevo (`make_sky`, radiancia 128) en cada `_refresh`, que ocurre en cada `layer_toggled` y cambio de visibilidad. Es barato pero regenera la radiancia; en el banco ocurre una vez por caso. Más el quad a pantalla completa de `Discs` siempre presente.
- Hace falta una corrida sola (sin el pasto) con `capa_3` y `todas_encendidas`, antes y después de ocultar `Discs`, para cerrar el criterio de costo.

## Causa probable del velo de Persephone
En la lámina, la columna «capa apagada» ya lo muestra, así que no es solo el cielo nuevo. Perillas, por orden de probabilidad:
1. `data/look/sky/persephone_sky.tres:18` `halo_strength = 1.1` / `halo_power = 14` (bloqueante 1): un glow aditivo ancho alrededor del sol sobre el cielo original. Bajarlo a 0 en Legacy.
2. `data/look/env_base.tres:9` `fog_sun_scatter = 0.4`: la niebla se aclara hacia el sol sobre el horizonte y el terreno. Probar 0 y 0.1.
3. `data/look/env_base.tres:7` `glow_enabled = true`: el cielo es `unshaded` con `energy = 1.7` (`sky.gd`), así que supera 1.0 y el glow lo desborda en HDR. Probar `glow_hdr_threshold` más alto o `glow_intensity` menor, o glow apagado en esta biome.
4. `data/look/env_base.tres:4` `tonemap_mode = 4` (AgX) más `tonemap_exposure = 0.9` en `persephone_light.tres`: AgX comprime y desatura, el original no pasa por tonemap (el RFC §17.6 pide que el cielo no cambie con él). Probar `tonemap_white` o saturación (`adjustment_saturation`) mayor; la corrección completa sería que el cielo no pase por el tonemap, que un `Environment` único no permite sin un pase aparte.
5. `data/look/sky/persephone_sky.tres:20` `fog_horizon_mix = 0.6` y `haze_tint`/`volumetric_density = 0.01`: aclaran las lomas hacia el horizonte; es lo pedido («el horizonte se funde»), pero con un `horizon_color` más pálido (0.7, 0.84, 0.88) que el del original. Bajar el mix o saturar `horizon_color`.

## Nits
- `sky_layer.gd:169` mensaje de advertencia con nombres de piezas borradas; `sky_look.gd` cabecera habla de «layers over the original» y de «sun disc follows the Sun», revisar.
- `sky_look.gd` conserva `moon_*` y `sun_*` en un perfil que en Legacy no debe usarlos: separar por `@export_group` solo Swirl o documentar que Legacy los ignora.
- `noise_clouds.tres` sin uso.

## Cierre
RFC-022d **no se puede cerrar**. Pedir **una** corrección: (a) ocultar `Discs` en Legacy y en clásico; (b) `swirl.visible = false` en PRE_SAVE y mensaje de advertencia correcto; (c) medir costo con el banco corriendo solo; (d) re-capturar Persephone Legacy contra `orig_3_pradera_cielo.webp` tras ajustar `fog_sun_scatter`/glow/tonemap (el look final es de `studio-visual`).
