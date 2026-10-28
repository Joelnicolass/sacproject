# REVIEW RFC-033b (F168) — texturas

Veredicto: **APPROVE** (sin bloqueantes; 3 notas para el cierre y 033h). Revisión corta, sin correr Godot.

## 1. Chroma en modelos con clips: más fiel
- sacengine aplica el chroma a TODA textura de un modelo SAXS al cargarlo: `source/saxs.d:76-77` (`chromaKey = (limb.flags&1) ? limb.chromaKey&0xffffff : -1` -> `loadSXTX(..., chromaKey)`), y `source/sxtx.d:28-31` pone alfa 0 a los píxeles de esa clave. No distingue clips de cuerpo quieto.
- La tubería vieja solo lo hacía cuando había un `.SAXS` junto al OBJ (`chroma_keys(obj_path)`, borrado de `scenes/world/obj_mesh.gd`): los cuadros `anim_f37/<m>/<clip>/N.obj` no lo tenían. El cambio de las 19 etiquetas / 17 modelos corrige un defecto, no rompe nada.
- Inconsistencia real pero transitoria: `baked/bodies/*.res` ya horneados (cuerpo quieto, textura embebida sin chroma) para esos 17 modelos difieren de los cuadros de clip. Dos looks del mismo modelo hasta re-hornear (`tools/bake_bodies.gd`, que ahora referencia los PNG) o hasta RFC-023. No bloqueante: el RFC lo declara y ninguna captura los muestra. Nota: re-hornear esos 17 en este corte es barato y cierra la inconsistencia.

## 2. Capturas fuera del piso / pose de cámara: sin causa en el diff
- `OriginalMaterial` solo toca superficies de `ObjMesh`/`ClipPosePlayer._baked_frame`/`wizard.gd`. El HUD (`debug/orders_group.tscn`: sin `.tscn` que referencie `ObjMesh`/`texture_path`) y el horizonte no usan materiales de modelos salvo por unidades del fondo; terreno, cámara y simulación no pasan por el diff.
- Camino plausible de tiempo: el diff quita construcción CPU de `ImageTexture` (más rápido al arrancar, no más lento); la carga ahora es `load()` de `CompressedTexture2D` + un JSON de 63 KB. No hay nada que mueva ticks simulados hacia adelante. La pose de cámara distinta ocurrió solo en las corridas 1–2 tras el import (caché fría, otro agente compartiendo CPU) y las bases nunca la mostraron: es ruido del arnés (captura por tiempo de pared), no del código.
- Pendiente (no del diff): `hud_group`/`horizon`/`attack_armed` exceden el piso en 1 de 4 corridas, con ruido difuso global. Pedido para el cierre de 033b: una sola corrida `after` extra y comparar solo píxeles estables (el método ya decidido). Si el gap persiste en los estables, reabrir.
- Aun así: confirmar que ninguna de las unidades de `orders_group` usa uno de los 17 modelos de la lista (grep de `debug/orders_group.tscn` y `unit.tscn` no muestra modelo fijo; lo decide el catálogo en runtime). Si usa `hero`/`xwiz`/etc., esa sería la causa legítima del exceso (cambio de fidelidad, no regresión): anotarlo.

## 3. Un dueño: PASS
- `scenes/data/original_assets.gd`: único que arma rutas (`texture`, `texture_index`); `original_material.gd:42,87` lo usa, ninguna ruta a `assets/original` duplicada en `scenes` (rg).
- `OriginalMaterial` es el único que arma `StandardMaterial3D` de modelos originales (`obj_mesh.gd` ya no tiene `material`/`_build_material`/`chroma_keys`). `ghost_form.gd:300` y `stone_look.gd:86` derivan de materiales existentes: no duplican. No existe `body_material.gd` en el árbol; no hay duplicación.
- Nit: `original_material.gd:44` devuelve null en silencio si el PNG no carga; un `push_warning` ayudaría a detectar un índice con un PNG faltante. Nit: `model_of` conoce el layout `anim_f37` (`original_material.gd:25`); se retira con 023.
- Nit de alcance menor: `tools/audit_original_assets.gd` conserva una copia de la tubería vieja (`_chroma_keys`, `_build_material` equivalente) para la paridad. Aceptable como herramienta temporal; borrarla al cerrar 033h.

## 4. Importador lee de `cache/look`: deuda para 033h, no bloqueante
- Cumple §3 del plan para este corte (mismos píxeles, sin duplicar el lector de WAD) y el resultado queda versionado (PNG + índice en LFS), así que el cierre del RFC (`mv cache cache.off`, F5) no depende de `cache/`.
- Contradice el criterio «regenerable sin cache» solo en el origen: pasa a ser deuda de 033h (importador desde WAD). Pedido: dejarlo anotado explícitamente en la lista de 033h y en `assets/original/README.md` (hoy el docstring de `import_textures.py` lo dice, el README no) y NO borrar `cache/` antes de 033h. `sac_formats/textures.py` se escribió desde el formato (sin copia de código de sacengine GPL): OK.

## 5. API: PASS
- `ObjMesh.build(path, options)`: los 6 callers del repo (`wizard.gd:13`, `clip_pose_player.gd:297`, `bake_clips.gd:58`, `bake_bodies.gd:47,66,74`, `audit_body_pose.gd:94`) ya migrados.
- Ningún `.tscn`/`.tres` setea `texture_path` (rg sobre `*.tscn`/`*.tres`: vacío; `wizard.gd` solo tiene `cache_path` en su default). Sin rotura de escenas.
- Nota de comportamiento: `bake_bodies.gd:74` (plantas) perdió la textura de reserva `item["texture"]`; el índice la resuelve por etiqueta desde `prop_textures()` (fallback incluido en el importador). OK.

## Criterios del RFC (resumen)
Importador idempotente y UIDs intactos (declarado, no re-verificado: no corrí Godot); paridad 701/701 (±1 alfa en mips de 3 texturas, justificado); `rg "\.tga|SAXS|SXMD" scenes` = 0 (afirmado, coherente con el diff); umbral de §8.0 reemplazado por «after ≤ piso» con desvío documentado; GUT/visual: look de HUD/horizonte queda para `studio-visual`/captura. N/A: SQL/XSS/auth.

## Bloqueantes: ninguno.
## Antes de cerrar (no bloqueantes): re-hornear los 17 modelos o anotar la inconsistencia; una corrida `after` de confirmación sobre píxeles estables; anotar en README/033h la dependencia de `cache/look`.
