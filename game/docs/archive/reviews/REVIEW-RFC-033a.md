# REVIEW RFC-033 corte 033a (F167)

Veredicto: APPROVE (sin bloqueantes).

## 1. .gdignore en cache/look/anim_f37/ (riesgo principal): OK
- Los OBJ se leen con FileAccess (scenes/world/obj_mesh.gd:62-64) y las texturas con Image.load sobre ruta globalizada (obj_mesh.gd:132). Ninguno pasa por ResourceLoader, así que .gdignore (que solo oculta la carpeta al escaneo/import del editor) no los afecta. No hay `load()` de OBJ/textura en obj_mesh.gd.
- Los fotogramas bakeados: ClipPosePlayer._baked_frame (scenes/world/components/clip_pose_player.gd:309-331) usa ResourceLoader.exists/load sobre `cache/baked/clips/*.res`. Esa carpeta ya tenía .gdignore desde el 16/10 (.res binario, no importado) y funciona. Lo mismo cache/look/bodies, fx, icons, etc. (todas con .gdignore previo): precedente directo de que FileAccess/.res sobreviven.
- Ninguna ruta `anim_f37` en scenes/; solo tools/audit_skeletal.gd:19 (herramienta, FileAccess). Las rutas llegan por cache/data/anim_mesh_clips_f37.json como `look/anim_f37/<x>/<y>/N.obj`.
- Conclusión: las unidades siguen animando en ventana. Efecto buscado: se dejan de importar 18 k OBJ + 2 k TGA (20 k .import). Verificación sugerida (no bloqueante): el banco de 033a ya incluye captura en ventana de body_gallery.

## 2. .gitignore: OK
- `git check-ignore`: agent/out/033/base/x.png y agent/out/a/b/c.png ignorados (el `*` cubre subcarpetas); `!agent/out/.gdignore` lo deja versionable (game/.gitignore:19-20, .gitignore raíz). `git ls-files agent/out` = 0 archivos, o sea no había nada versionado que se pierda.
- assets/original/*.res, *.exr y .obj/README no están ignorados; .res y .exr van a LFS (.gitattributes raíz, +2 líneas); *.import se versionan por la excepción previa. No se escapa arte original: lo que sí se versiona es el destino final del plan (assets/original, LFS), y las capturas siguen fuera.
- Nit: la regla duplicada en dos .gitignore (raíz y game/) es redundante pero coherente.

## 3. Un dueño y capturas
- scenes/data/original_assets.gd define todas las rutas de assets/original; no hay duplicados (sin consumidores, correcto para el corte). Las constantes cubren las familias del plan.
- Capturas: agent/run_rfc033_shots.sh + agent/flows/rfc033_shots.json + agent/harness/rfc033_view.gd. Escenas y fixtures existen; cámara fija vía `frame(...)` y `hide_log()` oculta el único texto variable (frame_ms). Las 15 capturas base existen en agent/out/033/base.
- Nit 1: run_rfc033_shots.sh:6 tiene ROOT absoluto hardcodeado (/Users/joelsartori/...); derivarlo de `$0`.
- Nit 2: solo el HUD tiene la afirmación de 0 px de diferencia; fx_gallery/biomas dependen de `wait` fijo con partículas/animación; el "after" puede mostrar ruido legítimo. Conviene correr base dos veces y diffear antes de usarlo como criterio numérico (RFC lo pide al cerrar 033i, no acá).
- N/A: SQL/XSS/auth, MP.

El RFC-033a puede darse por cerrado.
