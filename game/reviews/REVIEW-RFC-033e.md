# REVIEW RFC-033e (F171): temas de dioses y cielo a assets/original/themes/

Veredicto: **APPROVE** (sin bloqueantes; 3 nits).

## 1. Default de Terrain.tileset_dir (cache/look -> themes/james)
- En partida el default no se ve: `match_biome.gd:83-86` llama `ThemeApplier.apply` (salvo dedicado, que no pinta) y `theme_applier.gd:58` pone `resolved.dir()` del dios elegido, incluido james. `rg tileset_dir` no encuentra ningun `.tscn` que lo fije.
- El default solo se usa cuando se instancia `high_noon.tscn` sin `MatchBiome` (escenas `debug/*`, editor). Ahi hay una diferencia que el RFC no menciona: `cache/look/edge.png` no existe, asi que el default viejo daba `has_edge=false`; `themes/james/edge.png` si existe, y `sacrifice_ground.gdshader:36` ahora dibuja las paredes del vacio con el edge de ENVI (mas fiel). Ademas difieren los ids de baldosa no usados (el developer ya lo dijo).
- No es bloqueante: ningun camino de juego ni dios usa ese default, y el cambio acerca al original. Nit: corregir la frase del «Resultado» («difieren solo en baldosas») para incluir el edge en escenas sin bioma.

## 2. Cielo original
- `sky.gd` solo cambia los paths por defecto (`themes/persephone/*`) y `_load_png` (ahora textura importada con mips; el audit dice mips identicos). Shader, mallas, `rotation_period_s`, `cloud_period_s`, `cloud_alpha` y colores intactos. PASS.

## 3. Un dueno
- Rutas: `OriginalAssets.theme_dir/theme` es el dueno, `GodTheme.dir()` deriva de `god`. Nit: `sky.gd:20-22` y `terrain.gd:6` concatenan `OriginalAssets.THEMES_DIR + "..."` en vez de `OriginalAssets.theme("persephone","skyt")` / `theme_dir("james")` (no se puede en `const`, pero si en un var estatico o en `_ready`); hoy el literal del dios queda duplicado en dos archivos.
- `GodEnvi` vs `GodTheme`: `resolved()` copia 7 campos de envi sin duplicar datos persistidos (los `.tres` de tema quedan con perillas del motor). PASS.
- Campos sin lector (`god_envi.gd:17-25`: `fog_density`, `sun_ambient_strength`, `shadow_strength`, `sun_direction`): no hay RFC que los lea (`rg` solo da la nota del RFC L412). Nit: es el registro ENVI fiel y esta documentado; aceptable, pero si 033f/g no los usa, borrarlos de `GodEnvi` y de `import_themes.py:64-75`. `GodEnvi.fog_density` ademas se confunde con `GodTheme.fog_density`.

## 4. pyro
- Plausible: `sky.gd:76,84` rota `_spin` con `_time/rotation_period_s` (512 s) y desplaza nubes con `cloud_period_s`, ambos dependen del tiempo de captura; el developer reporta que dos `after` identicos difieren 74 k px, mas que after vs base, y todo en el tercio superior. Nit de rigor: no se fijo `_time` en el arnes, asi que es evidencia indirecta; para 033f conviene congelar el tiempo del cielo en capturas de bioma.

## Cierre
RFC-033e se puede dar por cerrado. Audit de paridad (35 imagenes, 5 envi) y `quick` iguales segun el developer; no se corrio Godot.
