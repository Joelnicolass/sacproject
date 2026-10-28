# RFC-067: Relieve (mapas PBR) en todos los modelos

Estado: P1–P4 y P6 hechos al 2026-10-26. P5 (roles del suelo) espera a la 062-3. Feature F393. Plan: `rfcs/plans/067-surface-maps-plan.md`.

## Decisiones del usuario (2026-10-26, mandan)

1. Primero los pilotos. El lote completo vino después de verlos en `surface_lab`.
2. **La receta no se guarda:** el PNG es la fuente y se retoca en cualquier editor de imágenes.
3. **Por defecto se genera solo el normal map.** El ORM es opcional en la receta, porque una rugosidad variable da el brillo plástico que VISUAL prohíbe.
4. Los mapas van a `assets/surfaces/<owner>/`, espejo de `assets/original/textures/` y por Git LFS. Los del contenido propio van al lado de su albedo.
5. El addon `addons/surface_maps` es genérico y solo de editor: queda fuera del export, y ningún archivo de `scenes/` ni de `data/` lo nombra. Se sube al kit recién después de esta RFC.
6. El generador porta el algoritmo de NormalMap-Online (Sobel o Scharr, `dz = (1 + 2^level) / strength`) con sus valores por defecto: strength 2,5, level 7, smoothing 0 y sin paso alto.
7. Lote completo (P6): todos los materiales llevan normal map. El follaje usa una receta propia y las rayas del pedestal de la casa quedan como están.

## Qué hace

- **Dónde vive el relieve.** Cada textura de un modelo es un `StandardMaterial3D` en `scenes/bodies/materials/`, y su relieve es el slot Normal Map, que apunta a `assets/surfaces/<owner>/<file>_normal.png`. No hay otro lugar ni otro recurso.
- **Petrificar y revelar.** `scenes/look/surface_relief.gd` lleva el relieve a las copias de StoneLook y BuildReveal.
- **Las dos recetas** están en `addons/surface_maps/recipes/`:
  - `default.tres`: los valores de NormalMap-Online, solo normal.
  - `foliage.tres`: smoothing 1, para hojas finas.
- **Herramientas.** En el editor, la sección «Relieve desde albedo» del inspector y Project > Tools > «Generar relieve…». Por consola, `tools/bake/bake_relief.gd` con `--recipe=` y `--force`, en dos pasos: escribir los PNG, importar, asignar.

## Lote (P6)

- **Mapas escritos:** 798, unos 131 MB de PNG en LFS. Los 23 pilotos se saltearon por tener ya su mapa. Fallaron 0.
  - **Follaje** (`foliage.tres`), 50 materiales: las 34 plantas `<TAG>_plant*` además de JAW1, y los props de hojas cat6, pcbs, pct1, pct2, pct4, pct5, pct7, pct8, pct9, plm1, ptre, puav, sfc1, spfl, st1a y stt1. La lista está en `agent/harness/relief_batch_lists.py`.
  - **Resto** (`default.tres`): 748 materiales.
  - **JAW1** (piloto): se volvió a hornear con `foliage.tres`.
- **Excepción: `pct6_M000_cutout` queda sin mapa.** La superficie 46 de `pct6.res` son planos cruzados con normales falsas (todas −Z), así que sus tangentes no pueden quedar perpendiculares y `surface_refs_cases` falla. Para darle relieve hay que arreglar antes las normales de esa malla.
- **Cómo se eligió la receta de follaje.** Se midió sobre el normal map de JAW1 (128², alfa ≥ 0,5) con `agent/harness/relief_recipe_probe.gd` y `measure_mottle.py`. «Relief» es la inclinación media y «mottle» es el ruido de texel a texel.
  - Por defecto: relief 0,780 y mottle 0,495. Los pilotos que no son follaje dan mottle 0,27–0,34 (hero, eorc).
  - Con smoothing 1: relief 0,519 (67 %) y mottle 0,149 (−70 %, por debajo de todos los pilotos que no son follaje).
  - Con smoothing 2: relief 0,338 y mottle 0,043. Es la opción si el moteado todavía se nota.

## Criterios

- **C1.** Sin mapas, nada cambia: 0 px en la fila «sin mapas» de `surface_lab`.
- **C2.** Con luz rasante el laplaciano sube entre +23 y +226 %.
- **C4.** En piedra y revelado sube +91 y +25 %. Medido en P4 con `tools/look/measure_relief.py`.
- **C3.** `surface_refs_cases` da PASS: 822 materiales, 0 referencias colgadas, 821 con normal map y 0 mallas sin tangentes.
- **C5.** El juego no depende del addon (filtro del export).
- **C6.** `surface_maps_cases` da PASS.
- **Captura de multitud** (`agent/harness/relief_crowd_capture.gd` sobre `debug/bodies/body_gallery.tscn`): a la distancia de la galería el laplaciano de todo el cuadro sube solo +2,7 %. De lejos el relieve es sutil; se aprecia de cerca o con luz rasante.

## Fuera de alcance

- Roles del suelo (P5).
- Un interruptor global del relieve en las opciones gráficas (otro corte).
- Parallax.
- Almas, partículas y pasto.
- Arreglar las normales de `pct6.res`.
