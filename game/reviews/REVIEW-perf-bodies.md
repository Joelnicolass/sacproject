# REVIEW perf-bodies (bug de rendimiento, sin RFC)

Veredicto: **PASS con observaciones**. Sin bloqueantes.

## Estado compartido (riesgo principal)
Materiales: `ObjMesh.material()` (scenes/world/obj_mesh.gd:~108) cachea por (ruta, etiqueta, chroma). Grep de mutadores
(`get_active_material`, `surface_get_material`, `albedo_color`, `set_shader_parameter`, `transparency`, `shading_mode`,
`material_override`, `set_surface_override_material`, `set_instance_shader_parameter`) en scenes/ shared/ glue/ src/:
- Ningun codigo de cuerpo (unit_body, wizard_body, body_visual, doctor_body, captive, selection, corpse, theme_applier)
  muta el material de la malla del cuerpo.
- `ghost_form.gd:299-303` (`_set_shadeless`): hace `base.duplicate()` por superficie y lo pone como
  `surface_override_material`; el `albedo_color` (l.282) y `shading_mode` se mutan solo sobre la copia. Seguro.
  La transparencia es `visual.transparency` (propiedad de GeometryInstance3D, por instancia). Seguro.
- Los demas `albedo_color`/`material_override` (ranged_shot, rock/fireball/swarm_projectile, active_ability, fx/*) crean
  materiales propios; no tocan el compartido.
- `wizard.gd:20` (`material_override = null`) es herramienta, por instancia.
Mallas: `_mesh_cache` solo se asigna a `_mesh.mesh`; nadie hace `surface_set_material` / edita arrays de una malla de cuerpo.
Nit: `ghost_form._process` (l.277) re-duplica materiales en cada cambio de malla de cuadro de clip (copia chica, no
textura); aceptable, pero es trabajo por cuadro mientras dura el fantasma.

## Simulacion en headless
`clip_pose_player.gd:148-151`: en headless `_apply_frame_mesh` retorna antes de construir, pero `advance()` ya actualizo
`_frame`/`_tick_left` (l.~100-110), asi que `impact_frame()`, `active_frame()` y los eventos por cuadro salen de
`_active_clip`/`_frame`, no de la malla. Antes, en headless `BodyCatalog.mesh()` ya devolvia null (`loads_meshes()`), por lo
que `body_height`/`half_size`/`feet_drop`/capsulas ya venian de `BodyCatalog.info()` (datos horneados), no de la malla
construida. Grep de lectores de `mesh.get_aabb`/`.mesh.` en simulacion: solo UI (`wizard_preview.gd`) y terreno. Sin cambio de
semantica para el dedicado. Nota: `_restore_base` sigue asignando `_base_mesh` (null en headless), igual que antes.

## BodySeparation
No habia copia del codigo viejo en el scratchpad; compare contra `git diff` de HEAD (la logica vieja esta en el diff).
Equivalencia verificada por lectura:
- Mismo orden de `randi()`: por obstaculo, en orden, solo si no hay separacion en altura (ahi el viejo retornaba antes sin
  randi; el nuevo hace `continue`); candidatos LEFT, RIGHT, BACK, FRONT con el mismo criterio `<` o `is_equal_approx and randi()%2==0`;
  el chequeo "alguna cara <= 0 => NONE" va despues de los randi, igual que antes (nuevo: `all > 0`).
- Dos pasadas (`inner` y `outer`) sobre `at + step` con `step` recalculado entre ellas: igual.
- Los diffs de `GROUPS` (+`&"doctor"`) vienen del arbol de trabajo (cambio previo, no del perf); no lo evalue como parte del arreglo.
No pude comparar numericamente (sin copia ejecutable del viejo); el suite (que incluye separacion/determinismo) paso.
Observacion: `_box` cachea por `Engine.get_physics_frames()` + instance id. Un test/herramienta que cambie `model` y llame
`resolve` dos veces en el mismo cuadro fisico obtendria la caja vieja; en el juego el modelo cambia raramente, y un id
reusado en el mismo tick es inverosimil. Sin accion.

## Caches estaticas
- `_mesh_cache` / `_materials`: acotadas (cuadros de clip y texturas del juego; unos cientos), sin evictar. Retienen entre
  partidas, pero es lo deseado (evita recargas). Cachean tambien `null` para rutas ausentes (no reintenta; ok).
- `@tool` / editor: ninguna se invalida al re-hornear OBJ/texturas. En el editor `ClipPosePlayer` no corre fisica (l.~39) y
  `obj_mesh` lo usan escenas de herramienta; un cambio de textura exige recargar el script/proyecto. Observacion menor.
  Sugerencia opcional: limpiar con `EditorFileSystem.resources_reload`/boton, no urgente.

## Pruebas ejecutadas
- Suite completa (`--fixed-fps 600 --quit-after 600000 res://debug/rules_suite.tscn`): 36 casos `: PASS` + `RULES SUITE PASS`,
  exit 0, sin SCRIPT ERROR. Coincide con 36 esperados.
- Headless `debug/desecrate_ritual`, `convert_ritual`, `guardian_altar`, `teleport_home`, `structure_siege`, `wizard_ghost`:
  exit 0, 0 errores en log, mundo listo.
- `rg -n "func agent_" src scenes glue`: vacio. `agent/perf/perf_probe.*` esta bajo res://agent/ (OK; temporal, ver nit).

## No verificado (queda para studio-playtester / studio-visual)
- Cifras 190 ms -> 8 ms y 7,6 GB -> 213 MB: no las medi (requiere ventana, el editor del usuario esta abierto).
- Que el aspecto de cuerpos (tinte por bando, ghost, destello) se vea igual: sin capturas en este pase.

## Nits
- `agent/perf/perf_probe.*` esta marcado "Temporary": borrarlo o conservarlo a proposito antes de cerrar.
- `git diff --stat -- src scenes glue` no esta vacio, pero este no es un diff de playtest sino el arreglo mismo (esperado).
