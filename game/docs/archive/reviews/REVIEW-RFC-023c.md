# Review RFC-023 (023c) - commit 316cbd2

Veredicto: APPROVE (con 2 nits y 1 pendiente para 023g/023h). Sin Godot; solo lectura de diff y del original.

## 1. Sim / visual: PASS
- Nada de la sim lee esqueleto ni BodyAnimator: los lectores de `body_rig`/`skeleton` son visual (stone_look, body_visual, carry_rope solo comenta). `active_frame/impact_frame` de unit_body.gd:1014-1016 son telemetria que ya existia.
- `ClipClock` (body/clip_clock.gd) es RefCounted, sin RNG, sin nodos; datos de index.json.
- Dedicado: `BodyAnimator._choose_body` (body_animator.gd:~95) sale con `not BodyCatalog.loads_meshes()`; `ClipClock._from_index` solo lee JSON, no el .glb. OK.
- Gesto: `hash(String(name))` unit_body.gd:965 = `String.hash()` (djb2 del texto), estable entre plataformas/corridas. OK.

## 2. Un dueno: NEEDS WORK (nit, no bloquea)
- Camino horneado de BodyAnimator (body_animator.gd `_baked`): el `ClipPosePlayer` hijo sigue con su `_physics_process -> advance()` (clip_pose_player.gd:76) ademas de `_clock`. Dos relojes sincronizados por construccion (mismo delta, ambos reinician en play) pero duplicados; hoy el `_baked` nunca emite al cuerpo (clip_looped sale de `_clock`), asi que no hay efecto visible. Cerrarlo en 023h con el retiro del horneado; si se quiere ya: `_baked.set_physics_process(false)` y dirigirlo por el reloj.
- `ClipPlayback` (contrato), `BodyAnimator` y `UnitClipRoles` no repiten logica: cada uno tiene su rol. `ClipClock.has_clip` estatico vs `ClipPlayback.has_clip` de instancia es la unica duplicacion de firma, aceptable.

## 3. Draw calls 1072 -> 7137: NEEDS WORK (diferir a 023g)
- Los materiales YA se comparten (`OriginalMaterial.apply_to` usa `for_part` con cache estatica, original_material.gd:74-83) y `set_surface_override_material` es sobre material compartido: no hay causa barata en cache de materiales.
- Causa: el .glb tiene una primitiva por parte del cuerpo (export_skeletal.py:5) y las mallas skinned no se fusionan; el horneado fusionaba por material. Cada superficie = 1 draw call por pasada (color + sombra). Arreglo real: fusionar en el exportador primitivas que comparten material/textura (cambia los 69 .glb y el mapeo `for_part(model, i)`), por eso no es barato. Medida: +1 % ms, VRAM igual -> no bloquea. 023g.
- Nota: `StoneLook._dress_rig` crea un material de piedra por original (cache `_stone_for`); correcto, pero revisarlo en 023g si se fusionan superficies.

## 4. Fidelidad del reposo: NEEDS WORK (nit documentado)
- sacengine state.d:7957-7992: tras cada vuelta del stance (frame==0) `!state.uniform(5)` = 1/5 con el RNG de la sim, y elige al azar entre idle0/idle1/idle3 (mustFly: hover,idle0,idle1,idle3), o idle2 si esta danado. El port: 1/5 por `posmod(hash(nombre)+vueltas,5)` y solo idle0. Diferencias: (a) sin variedad idle1/3 (ya anotado, falta export en export_stats.py); (b) sin idle2 danado; (c) sin hover/idle de voladores.
- Sincronia: el nombre de cada unidad es unico, asi que la fase `hash(nombre) mod 5` varia entre unidades; dos del mismo tipo gesticulan a la vez solo si coinciden en fase y en inicio de vuelta (~1/5 de los pares nacidos en el mismo tick). Se nota poco, no es "todos los Trogg a la vez". Es ademas determinista en todos los peers y no toca la sim: decision correcta. Si molesta, mezclar el hash con el indice de spawn.

## 5. Repo: PASS
- 69 .glb en LFS (verificado: todos los blobs de 316cbd2 son punteros git-lfs). `.glb.import` y `index.json` en git normal (ok, chicos). 0 archivos `cache/` versionados.
- `--baked-bodies`: documentado en body_catalog.gd:74, RFC (Desvios) y rig023c_shots.gd; retiro previsto en 023h. Nota: `ClipClock._from_baked_list` lee `res://cache/data/anim_mesh_clips_f37.json` (cache no versionado): es el camino de fallback que 023h debe retirar; sin esa cache el fallback queda sin clips (ya era asi para el horneado).
- Nit: git status muestra assets cc0 `M` en el worktree (ruido LFS del checkout, no del commit).

## Ruta de archivos
- game/scenes/world/body/{clip_clock,body_animator,unit_clip_roles}.gd, components/{clip_playback,clip_pose_player}.gd, unit_body.gd:915-975, look/stone_look.gd, body_catalog.gd:17-80.

RFC-023c se puede dar por cerrado.
