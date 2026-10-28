# REVIEW F89 — Cuadros de clip horneados a .res (RFC-027, corte 027h)

Reviewer: studio-reviewer (Opus 5.5). Guardado por el orquestador.

**Veredicto: PASS.** Sin bloqueantes.

- **Equivalencia:** la malla horneada es idéntica bit a bit a la armada desde el OBJ (10 cuadros comparados, delta 0, mismo material compartido).
- **Invalidación:** la fecha del archivo es coherente con los re-exports. El editor y el dedicado no cargan nada.
- **Pico restante:** los 62–74 ms vienen de la convocatoria (38 ms fijos) y de la primera vez del modelo (material, pipeline), no de los clips.

## Nits aplicados por el orquestador
1. Agregar el paso `bake_clips.gd` en `.studio/MEMORY.md`.
2. `_baked_frame` devuelve null si el OBJ no existe.
3. Comentario: un cambio en `obj_mesh.gd` obliga a correr `--force`.

## Deuda
- Avisar cuando se cae al OBJ.
- Limpiar los `.res` huérfanos.
- Mtime con resolución de segundos.
