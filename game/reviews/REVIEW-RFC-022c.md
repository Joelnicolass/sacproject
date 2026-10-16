# REVIEW RFC-022c — terreno PBR (Persephone)

Reviewer: studio-reviewer, una pasada, solo lectura. Contra `rfcs/RFC-022-graphics-upgrade.md` (§3 fila 022c, §5, §6, §8, §9, §11, §12, §17, «Medido en 022c») y `VISUAL.md`.

## Veredicto: PASS con observaciones

No hay bloqueantes por código, datos, assets ni red. Hay una observación **mayor** sobre la dureza de los bordes de los parches de tierra. No es bloqueante, pero para el borde de los parches la perilla útil no es un dato: hace falta exponer una constante del shader (ver abajo). La nota de licencia de I. Quilez está incompleta (observación 2). La revisión visual con `studio-visual` sigue pendiente.

Sobre el diff: `git diff` contra el índice no sirve para aislar 022c. El índice es una foto vieja de todo el proyecto y no hay commits. Por eso verifiqué el estado actual de los archivos, no un diff del corte.

## Ejecución

| Qué | Resultado |
|---|---|
| Suite `res://debug/rules_suite.tscn`, `--fixed-fps 600 --quit-after 600000` | `RULES SUITE PASS`, exit 0, 0 `ERROR`/`SCRIPT ERROR` |
| Headless `scenes/world/high_noon.tscn` (`--quit-after 300`) | Carga sin errores (`bioma james`, `mundo listo`) |
| Headless `debug/look_gallery.tscn` | Carga sin errores (`look persephone ... capas 3`) |
| Headless `debug/biome_pick.tscn` | Carga sin errores (`bioma pyro semilla 7`) |
| Red: dedicado `--dedicated --mp-port=29672 --world=high_noon` + cliente `--client1` con ventana, 500 cuadros | Dedicado: `bioma persephone semilla 1847212397`, `slot 1 pick jnwr james`. Cliente: `bioma persephone`. Mismo bioma y 0 errores. Sin procesos vivos |

## Criterios de 022c

- **`ref`: 3 capas distinguibles.** Hecho. `agent/out/rfc022/022c/game/game_walk.png` muestra pasto, parches de tierra y laderas de tierra y roca. La lámina no la abrí. La distinción se ve; la calidad del look queda para `studio-visual`.
- **`ref`: relieve con sol rasante.** Hecho. Normal por capa más relieve de ruido (`bump_height_m`, `ground_pbr.gdshader:268-277`).
- **`ref`: sin repetición a 150 m.** Evidencia parcial. El preset medio apaga el estocástico (`quality_medium.tres`), así que se apoya solo en la macro-variación y en los parches. En `game_walk` el pasto lejano se ve uniforme. Lo confirma `studio-visual`; no lo cuento como fallo.
- **`rts`: las zonas siguen el mapa original.** Hecho. `tile_layer_map.gd`, `high_noon_tiles.tres` y `tools/classify_ground_tiles.py` bajan al splat 256×256 (`ground_material.gd::_splat_texture`). El criterio de zonas lo cubre ese flujo.
- **Costo.** Los números de «Medido en 022c» son coherentes: medio +1,8 ms medidos contra +1,5 estimados, dentro de ±1 ms. No los remedí.
- **Cómo se suma una capa (§6).** Se cumple: carpeta en `assets/cc0/ground/`, fila en `LICENSES.md`, un `GroundLayer` `.tres`, y se arrastra al `GroundSet`. No hay cambios de código.

## Lo que pediste chequear

**Simulación, alturas y colisión.** Sin cambios funcionales por 022c.
- `ground_height()` y el índice de triángulos son los mismos.
- La colisión sale de la misma malla. `_add_collision` sale temprano en el editor; en runtime sigue igual.
- `set_ground_override` solo cambia `material_override`.
- La suite pasa.
- Nit (fuera de 022c): `terrain.gd:_triangle_at` cambió `return -1` por `continue` cuando el id es negativo. `_index_ground` llena los dos huecos de la celda en orden, así que un hueco 0 vacío implica un hueco 1 vacío. Es equivalente y no cambia el resultado, pero no es de 022c.

**`match_biome` y `ThemeApplier` (fuera del corte).** Correcto.
- `pick_god` usa el mismo RNG y la misma lista (`GODS`), así que el sorteo es idéntico al viejo.
- `god` pasa de `theme.god` a `picked`. Los cinco `.tres` de tema tienen `god` igual al nombre del archivo, así que no hay divergencia.
- El respaldo si `forced` no existe es el mismo.
- El dedicado nunca llama `theme_for`: `_apply` corta con `MpKit.is_dedicated()` (`match_biome.gd:81`) y `_draw` ya no carga el tema. Solo se necesita el nombre.
- En la prueba de red, dedicado y cliente coinciden en el bioma.

**El dedicado no instancia nada de look.** `look_rig.gd` se libera en headless y en dedicado (comprobación en `look_rig.gd:103-106`). `GroundMaterial` solo precarga el shader. Las texturas llegan solo vía `theme.look.ground`, que el dedicado no carga.

**`.import` versionados.**
- Son 12, uno por archivo, y todos bajo `assets/cc0/ground/`. `game/.gitignore` tiene `!assets/cc0/**/*.import` y sigue ignorando los demás `*.import`. No se versionan `.import` de otros lados.
- Configuración: VRAM comprimida (`compress/mode=2`, calidad alta) y mipmaps encendidos. `roughness/mode=0`, `normal_map_invert_y=false`, y los `.png` y `.jpg` son LFS (`git check-attr` da `filter: lfs`).
- Normal map: `compress/normal_map=0` (Detect), no «Enable». Funciona porque el shader no usa `hint_normal` y reconstruye Z (`decode_normal`), así que lee RGB como color lineal. Ver nit 1.
- ORM: lineal. `orm_*` no lleva `source_color` y el albedo sí. Sin sRGB en ORM ni en normal: correcto.
- Albedo: sRGB, con `source_color` en el uniform.

**Licencias.** `assets/cc0/LICENSES.md` cubre cada material con id, nombre, autor, licencia, URL y fecha, y describe qué contiene cada mapa (albedo, NormalGL re-guardada, ORM empaquetado). No es una fila por archivo, pero los tres archivos de cada carpeta quedan descritos. Falta la entrada del código de Quilez (observación 2).

**Lo bajado.** `find assets/cc0` solo devuelve los 3 mapas más `.import` de cada material, más `LICENSES.md`. Hay 12 imágenes a 2048×2048 y no hay ejecutables ni sobrantes. Pesa 92 MB. `.gitattributes` manda png, jpg, jpeg, webp, exr, hdr y glb a LFS; `git-lfs 3.8.0` está instalado.

**Quilez.** El shader lo cita en el encabezado (`ground_pbr.gdshader:6-7`, «Inigo Quilez, Texture Repetition, MIT»). Ver observación 2.

**`.gdshader`.** Cumple. No usa `PackedColorArray`. Los arrays de `vec4` se llenan con `PackedVector4Array` en `ground_material.gd:update`, y los de float con `PackedFloat32Array`. El tope está acotado a 4 en `GroundSet.MAX_LAYERS`.

**`@tool` sin autoloads.** `terrain.gd`, `ground_layer.gd`, `ground_set.gd`, `tile_layer_map.gd` y `terrain_layer.gd` están marcados `@tool` o son compatibles. `terrain_layer.gd` solo usa `Engine.is_editor_hint()`, sin autoloads. En `_notification` restaura el suelo clásico antes de guardar.

**Nada derivado del caché en escenas.** El nodo `Terrain` en `high_noon.tscn:72-80` solo guarda el script y `unique_name_in_owner`. No hay `mesh`, `material_override`, `ImageTexture` ni `PackedByteArray`. `terrain.gd` marca `mesh` y `material_override` sin `STORAGE` en `_validate_property`. El material y el splat se reconstruyen desde `cache/` en cada carga.

**Escalabilidad.** Sumar una capa es un `.tres`. El tope de 4 está documentado: en `GroundSet.MAX_LAYERS` y en el RFC §5 («hasta 4 capas», líneas 142 y 144). Subirlo exige tocar el shader (arrays `[4]`, samplers fijos), cosa que el RFC admite y fija en 4.

## Bordes duros de los parches de tierra

Lo que se ve en `game_walk.png` es real: manchas de tierra con borde casi vectorial sobre pasto. La causa está en dos lugares, y solo uno se arregla con datos.

**1. El borde de cada parche tiene una constante fija en el shader, sin perilla (`ground_pbr.gdshader:171`).**
- `patches = mix(1.0, smoothstep(0.52, 0.63, patch_n), h.w)`. La banda de 0,11 sobre un ruido simplex de 4 octavas, con características de pocos metros, da transiciones de menos de un metro. `GroundLayer.patchiness` solo escala cuánto pesa el parche (`h.w`), no la suavidad del borde.
- `patch_scale_m` solo mueve el tamaño de las manchas.
- Con datos no se puede ensanchar esa transición.

**2. La mezcla por altura la endurece más (`ground_pbr.gdshader:222-233`).**
- Con `score = w + orm.b * height_contrast * 0.5` y `f = max(score - (top - blend_depth), 0)`, una capa cae a 0 si queda `blend_depth` por debajo de la mejor.
- Los datos actuales empeoran esto: `soil.tres` tiene `priority 1.5` y `height_contrast 0.8`, y `GroundSet.blend_depth` está en 0,18 (poco, con un rango válido hasta 0,6). Con peso hasta 1,5 y banda de 0,18, el reparto casi no tiene tramo intermedio.
- Esta parte sí se suaviza con datos, pero no alcanza sola por el punto 1.

**Qué tocar con datos (sin cambiar el shader).**
- `GroundSet.blend_depth`: subirlo de 0,18 a 0,3–0,45.
- `GroundLayer.height_contrast` de tierra y sendero: bajarlo de 0,8–1,0 a 0,2–0,4.
- `priority` de tierra: de 1,5 a 1,0, para que el parche no gane por peso bruto.
- `patchiness` de tierra: de 0,9 a 0,4–0,6, para mezclas más parciales.
- La máscara de baldosas **no** es la causa de estos parches: `zone_edge_noise` y `tile_weight` gobiernan los bordes de las zonas grandes (loma/valle), no las manchas del pasto.

**Qué exige cambio de shader (pequeño).** Exponer la banda `smoothstep(0.52, 0.63, ...)` como dato, por ejemplo `GroundLayer.patch_softness` o `GroundSet.patch_edge_softness`, y pasarla en `ground_material.gd`. Con ese cambio el borde puede ensancharse a un degradé de metros, que es lo que pide `ref_2_pradera_atardecer.webp`. Sin él, el techo de suavidad queda limitado por la constante.

**Severidad.** No lo marco bloqueante: el shader permite bordes blandos en la mezcla por altura, y el resto es un cambio de una línea más un campo de `Resource`. No lo probé con una copia del shader; el análisis sale de leer el código y mirar la captura.

**Pasto verde saturado y uniforme.** Se arregla con datos en `grass.tres`: `tint` (hoy `Color(1.0, 1.05, 0.9)`, que empuja el verde), `roughness_offset`, y `macro_strength`/`macro_scale_m` de `persephone_ground.tres` (el RFC pide que el pasto sea menos saturado que las unidades). No lo comparé con la referencia a ojo más allá de la captura. Queda para el pase visual.

## Observaciones

1. **Normal map importado en Detect.** `compress/normal_map=0` y no `1`. Funciona hoy porque el shader no usa `hint_normal` y reconstruye Z. Si alguien suma `hint_normal` al uniform, cambia el formato (RG) y la lectura. Dejarlo en Detect es correcto pero frágil. Ponerlo en Enable sería lo explícito.
2. **Nota de licencia de Quilez incompleta.** El shader dice «MIT» y cita la URL, pero no incluye la línea de copyright ni el texto de permiso del MIT, y `assets/cc0/LICENSES.md` no tiene entrada del código. El MIT pide el aviso en las copias. Falta una línea de copyright y el texto de permiso en el encabezado del shader (o una sección «Código de terceros» en `LICENSES.md`). El código está adaptado, no copiado entero.
3. **Alcance.** `ThemeApplier.pick_god()`/`has_theme()` y el cambio de `match_biome._draw` quedan fuera de 022c, pero están justificados: sin ellos el dedicado cargaría el tema con texturas. No bloquea. El cambio de `terrain.gd` (`continue`, editor, normales suavizadas) no es de 022c y no lo mido.
4. **`GroundLayer.stochastic = true` por defecto.** No cambia nada en medio y bajo, porque el preset lo apaga. En alto cuesta +6,7 ms. Conviene dejarlo documentado como «solo alto».
5. **`TileLayerMap` de High Noon depende de la atlas de Persephone.** La clasificación viene del color medio de `cache/look/themes/persephone/atlas.png`, y esa atlas no se versiona. Queda anotado en el script, pero otro bioma con otra atlas necesitaría su propio mapa.
6. **Costo de GPU del tope de 4 capas.** Alto da 22,2 ms y cae al piso de 30–45 fps por el estocástico (ya anotado en el RFC). No es defecto de 022c, pero el medio (7,7 ms de 14) deja margen para 022d–l.

## Qué queda para otros pases

- Look final (pasto, mezcla, repetición a 150 m): `studio-visual` y playtest con ventana, con capturas contra `visual/refs/ref_2_pradera_atardecer.webp`. GUT y la suite no cubren el look.
- Cuando se arregle la dureza de los bordes, remedir el costo del preset medio y alto.

## Cierre del RFC (022c)

Se puede dar por cerrado para 022c con las observaciones 1–2 anotadas, siempre que `studio-visual` valide el look. Los bordes duros de los parches piden una corrección chica: datos (`blend_depth`, `height_contrast`, `priority`, `patchiness`) más una perilla de banda en el shader. Eso es una iteración de ajuste, no una falla de composición o de alcance.
