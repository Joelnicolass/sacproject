# RFC-022e — Vegetación: pasto estilizado (022e1), dispersión y widgets (022e2), aplastado (022e3)

Sub-corte de [RFC-022](RFC-022-graphics-upgrade.md); reemplaza la fila 022e y las filas «Dispersión / Viento / Lectura» de su §8. Autoridad: VISUAL.md («Referencia principal: el juego original» manda) > RFC-022 §17 > esto.

Pedido (2026-10-14): «podemos sumar también un pasto, con algún método óptimo de rendimiento, estilo breath of the wild/ghibli (bow tiene una gran optimización para correr en s1, podemos usar un método similar)».

## 1. Objetivo y partición

| Corte | Qué | Criterio verificable (captura; primero contra `visual/refs/original/`) | GPU medio |
|---|---|---|---|
| **022e1** Pasto | Briznas por geometría alrededor de la cámara, color del suelo, viento, claros | ver §6 | +1,4 |
| **022e2** Dispersión | Flores, matas, rocas chicas (`ScatterType`) + los ~720 widgets del original con material y viento nuevos | `rts` contra `orig_3`: plantitas y conos dispersos sobre el verde, ninguna flotando ni enterrada; `ref` contra ref 2: flores de color en el pasto; claros en altar/manantiales | +0,6 |
| **022e3** Aplastado (opcional) | Las briznas se abren bajo unidades | `rts`: con 20 unidades quietas en pasto, la base de cada una se ve (captura con/sin) | +0,1 |

La suma de 022e sigue siendo +2,0 ms en medio (techo de RFC-022 §3). 022e1 no depende de 018d; 022e2 sí (§9).

## 2. Técnica: qué hacen BotW y Ghibli (fuentes)

- **BotW** (CEDEC 2017, parte 5 «arte e implementación 3D», Takizawa y Dohta; traducción en thefamicast.com/2017/12/part-5-art-and-implementation-of-3d.html). Nintendo no publicó el detalle del pasto; lo verificable por análisis (hexaquo.at, «Grass rendering series part 1», K. Bittner, 2025; foros de Unreal/Unity) es: **briznas de geometría de muy pocos vértices sin alfa** (sin sobredibujo de recortes, clave en GPU de tiles como Switch y como el M4), solo en un **radio alrededor de la cámara**, **densidad que cae con la distancia** hasta desaparecer, **el suelo debajo tiene el mismo color** que el pasto (a lo lejos el terreno «es» el pasto), **viento por ondas globales** que también aclaran las puntas (las «olas» claras que cruzan el campo), tinte global por clima, aplastado local por personajes. Todo lo que no está en la charla se trata como inferencia, no como dato.
- **Ghost of Tsushima** (GDC 2021, «Procedural Grass in Ghost of Tsushima», E. Wohllaib): grilla de celdas alrededor de la cámara, briznas generadas por GPU, LOD de alto a bajo número de vértices por anillo, viento por ruido que se desplaza, **normales curvadas** para que la brizna se ilumine redonda, color por mechones (clumps).
- **Ghibli**: gradiente raíz oscura → cuerpo saturado → punta clara y cálida; luz suave (normales tiradas hacia arriba, sin especular), translucidez a contraluz; manchas grandes de color, no detalle fino.
- **Godot 4, reutilizable:** `2Retr0/GodotGrass` (**MIT**; MultiMesh por baldosas, normales curvadas, mechones por ruido celular, viento por ruido desplazado; su cambio de LOD «se nota mucho»: lo evitamos con raleo por rango, §3); GDQuest «wind grass» (**MIT**; MultiMesh + viento en vértice, sin sombras); `OpenStylized3D-Godot-Addon` (**MIT**, scatter + `wave.gdshader`); `Simple Grass Textured` (**MIT**, pinta y **guarda las instancias en la escena**: choca con «nada derivado en escenas», solo idea). La serie de hexaquo es **CC BY-SA 4.0**: solo ideas, nada copiado. Cualquier fragmento portado se anota con URL y licencia en el encabezado del shader.

## 3. Técnica recomendada (Godot 4.7)

**Anillo de celdas recicladas con MultiMesh compartida y colocación en GPU** («clipmap de pasto»):

1. **Una `MultiMesh` por anillo de LOD, creada una vez** (runtime, nunca guardada): N instancias en una celda unidad de 16×16 m con offsets estratificados + `INSTANCE_CUSTOM` (giro, alto, curvatura, rango 0–1). Anillo cercano: brizna de 5 vértices (3 tramos); anillo lejano: brizna de 3 vértices más ancha y la mitad de densidad.
2. **`GrassField`** mantiene una grilla de `MultiMeshInstance3D` (todas apuntan a la misma MultiMesh de su anillo) centrada en el punto de suelo bajo la cámara, **adelantada media celda hacia donde mira**. Al cruzar celda solo se mueven `transform`s de las que quedaron atrás: cero regeneración en CPU. Cada celda tiene `custom_aabb` con el rango de alturas del mapa: el motor la descarta por frustum.
3. **El shader de vértice hace el resto:** posición de mundo = origen de celda + offset; **altura** desde `height_tex` (horneado, §4); **densidad** = máscara (§4) × caída por distancia; una brizna se dibuja si `rango < densidad` y, si no, colapsa a un punto (sin rasterizar). Como cada brizna tiene un rango fijo, al alejarse las briznas se van **raleando de a una**, no por celda: no hay salto de LOD. En el último 20 % del radio el alto baja a 0 y el color converge al del suelo: el borde no se ve.
4. **Alternativa:** `GPUParticles3D` con process shader que acomoda las partículas en grilla alrededor de la cámara (truco conocido de Godot 3). Una sola llamada, pero un AABB único (sin descarte por frustum), `amount` fijo y menos control de LOD. Plan B si el número de llamadas por celda pesara (no esperado: ~60–120).

## 4. Diseño para este proyecto

- **Altura:** `tools/bake_grass_height.gd` (SceneTree headless, mismo patrón que `bake_ground_splat.gd`) hornea `cache/look/height.exr` (RF, 1024², 2,5 m/texel) con `Terrain.ground_height()` y un canal «hay suelo» desde `is_on_ground()`. La malla es de 10 m: la interpolación bilineal a 2,5 m se aparta < 5 cm en los pliegues; las briznas se hunden 5 cm. Sin el archivo, `GrassField` no dibuja y avisa (como el resto del caché).
- **Máscara de pasto** (`grass_mask.gd`, RefCounted, `ImageTexture` 512² construida en runtime, nunca guardada): peso de las capas del `GroundSet` listadas en `GrassType.ground_layers` (mismo `TileLayerMap` y splat de 022c; el sendero y la tierra dan 0) × regla de pendiente × **claros**: nodos `VegetationClear` (`@tool Node3D`, radio y borde en el inspector, grupo `vegetation_clear`) que el TA coloca en altares, manantiales y caminos; `GrassField` además crea claros por defecto para los grupos `altar` y `manafount` con los radios de su `@export`. Mover un claro recalcula la máscara (en el editor también).
- **Color que se funde con el suelo:** se extrae de `ground_pbr.gdshader` un `ground_common.gdshaderinc` (splat, pesos de zona, macro-variación) que ambos shaders incluyen; `GroundMaterial` agrega, por capa, el **color medio** del albedo (mip más chico, calculado al cargar) × `tint`. Raíz = color del suelo debajo (exacto, mismo cálculo); cuerpo y punta = `GrassType.color_mid/tip` mezclados por macro-variación y por mechón (ruido celular a `clump_scale_m`). Lejos todo converge al suelo. Así el pasto y el terreno son una sola mancha verde, como `orig_3`.
- **Viento:** global `look_wind` (dirección, fuerza, tiempo) + `noise_tex` ya existente desplazado; curva por altura² de la brizna; las ráfagas **aclaran la punta** (BotW). Mismo global para widgets y partículas.
- **Luz Ghibli:** normal = mezcla de la de la brizna con la del suelo/arriba (`normal_roundness` ≈ 0,7), `roughness` 1, `specular` 0,1, `BACKLIGHT` con el color de la punta (translucidez), AO falso en la raíz por gradiente. **No proyecta sombras** (`cast_shadow` off); **recibe** las del sol (unidades y altar sobre el pasto). Sin alfa ni `discard`: opaco, compatible con la escala 0,67 y FXAA.
- **No tapar unidades ni cursor:** `max_height_m` ≤ 30 % de la unidad más chica (medir en `body_catalog`; inicial 0,45 m); fundido cercano: a menos de `near_fade_m` (6 m) de la cámara el alto cae a 0 (cámara `ref` baja); el marcador de selección/orden se dibuja sobre el pasto (verificar `no_depth_test` o elevarlo; si no, va a la lista de §8).
- **Paleta:** el original manda: verde intenso y vivo, no realista. Luminancia de la punta < la de las unidades (jerarquía de VISUAL.md); el rim de 022g separa unidades.
- **Aplastado (022e3):** array uniforme de las 32 unidades más cercanas a la cámara (`vec4 xyz+radio`) que `GrassField` actualiza cada 0,1 s desde el grupo de cuerpos; la brizna se inclina hacia afuera. CPU < 0,05 ms, GPU ~0,1 ms en el anillo cercano. Apagado en bajo.
- **Widgets del original y 018d:** `map_props.gd` sigue instanciando 720 plantas sueltas (018d no está hecho). 022e1 no los toca. 018d debe **reutilizar `VegetationClear`** en vez de crear `widget_mask.gd`; 022e2 les da a sus MultiMesh el material con viento y el color del suelo en la base.

## 5. Presets (estimado M4, medio a 0,67; a medir)

| | Bajo | Medio | Alto |
|---|---|---|---|
| Radio total / anillo cercano | 25 m / 10 m | 45 m / 15 m | 70 m / 20 m |
| Densidad cerca / lejos (briznas/m²) | 12 / 4 | 32 / 8 | 48 / 10 |
| Vértices brizna cerca / lejos | 3 / 3 | 5 / 3 | 7 / 3 |
| Instancias visibles aprox. | ~10 k | ~68 k | ~200 k |
| Viento / mechones / aplastado | sí / no / no | sí / sí / no | sí / sí / sí |
| GPU estimada | +0,4 | +1,2–1,4 | +2,5 (nativa) |

Campos nuevos en `LookQuality`: `grass_enabled`, `grass_radius_m`, `grass_near_radius_m`, `grass_density_scale`, `grass_near_segments`, `grass_trample`. **Orden de recorte** (dentro del punto 3 de RFC-022 §9): densidad lejana → radio → segmentos cercanos → mechones; el viento no se recorta.

**Medición:** `GrassLayer` es un hijo de `%Look` como las otras capas, así `look_bench` (ya con 60 cuerpos animados y 8 emisores) lo mide solo y con todo encendido sin cambios; se agrega solo `--camera rts|ref` si el banco no la tiene. Reportar `gpu_ms`, `prim` y `draw` por preset; aceptar si medio con luz + suelo + pasto + cuerpos ≤ 9,5 ms.

## 6. Criterio de aceptación de 022e1 (Persephone, High Noon)

1. `rts` y `ref` junto a `orig_3`: el valle se lee como una sola superficie verde saturada con textura de briznas; ninguna brizna de otro color que el suelo en su raíz.
2. Borde invisible: en `ref`, la luminancia media de una franja 5 m dentro y 5 m fuera del radio difiere ≤ 6 %.
3. `rts`: ninguna unidad tapada más de 1/4 de su alto; el cursor y el marcador de orden se ven sobre el pasto.
4. Sin briznas a < radio de claro del altar y de cada manantial, ni en el sendero; un `VegetationClear` nuevo en el editor abre un claro en vivo.
5. Dos capturas a 1 s: las briznas se mueven (diff > 0 en la zona de pasto) y no se ven estelas con MetalFX espacial.
6. Banco: medio ≤ +1,5 ms sobre luz + suelo con cuerpos; bajo ≤ +0,6.
7. Editor: cambiar `color_tip` de un `GrassType` se ve en vivo; tras guardar, `git status` muestra solo el `.tres`. Dedicado: ningún `GrassField`.

**Escena de prueba:** no hay nueva. Se usa `debug/look_gallery.tscn` (bioma Persephone, cámaras `rts`/`ref`/`horizonte`, capa de pasto on/off) y `debug/look_bench.tscn`. Para el aplastado (022e3), un `.tres` de bench con 20 cuerpos quietos en el valle.

## 7. Archivos

```text
game/
├── data/look/grass/persephone_grass.tres        N  GrassSet (lista de GrassType del bioma)
├── data/look/grass/types/{meadow,meadow_short}.tres  N  GrassType
├── data/look/persephone.tres                    M  scatter → grass (socket `grass: GrassSet`)
├── data/look/quality_{low,medium,high}.tres     M  campos de pasto
├── scenes/world/look/
│   ├── look_profile.gd                          M  + @export var grass: GrassSet
│   ├── look_quality.gd                          M  + grupo «Grass (022e)»
│   ├── look_rig.tscn                            M  + hijo GrassLayer (una línea)
│   ├── ground/ground_pbr.gdshader               M  extrae ground_common.gdshaderinc (sin cambio visual)
│   ├── ground/ground_common.gdshaderinc         N  splat, zonas, macro-variación
│   ├── ground/ground_material.gd                M  + color medio por capa
│   └── grass/
│       ├── grass_type.gd / grass_set.gd         N  Resources
│       ├── grass_layer.tscn / grass_field.gd    N  @tool: anillo de celdas, apply_look/apply_quality
│       ├── grass_blade_mesh.gd                  N  estático: malla de brizna por segmentos
│       ├── grass_mask.gd                        N  RefCounted: máscara 512² runtime
│       ├── grass.gdshader                       N  colocación, viento, color, luz
│       └── vegetation_clear.gd                  N  @tool Node3D (radio, borde); lo reutiliza 018d
├── tools/bake_grass_height.gd                   N  hornea cache/look/height.exr
└── agent/flows/rfc022e_*.json                   N
```

| Pieza | Responsabilidad | Tipo | Corre en |
|---|---|---|---|
| `GrassType` | Forma (ancho, alto, segmentos, curvatura), colores raíz/cuerpo/punta, densidad, `ground_layers`, `slope_max`, viento, `normal_roundness`, `translucency`, `clump_scale_m` | Resource | editor/cliente |
| `GrassSet` | Tipos del bioma + radios de claro por defecto | Resource | editor/cliente |
| `GrassField` | Grilla de celdas, recolocar al moverse la cámara, uniforms, máscara | Nodo `@tool` | editor (cámara del editor)/cliente; se libera en dedicado |
| `grass_mask.gd` | Splat × pendiente × claros → textura | RefCounted | editor/cliente |
| `VegetationClear` | Claro colocable | Nodo `@tool` | editor/cliente (sin efecto en dedicado) |
| `bake_grass_height.gd` | Altura al caché | Herramienta | headless, fuera de la partida |

Vista previa en editor sin autoloads: `LookRig.preview_god` → `apply_look` como las otras capas; `GrassField` sigue a la cámara del viewport del editor (`EditorInterface` vía `Engine.is_editor_hint()` en `_process`). MultiMesh, máscara y altura nunca se serializan (`_validate_property` + `NOTIFICATION_EDITOR_PRE_SAVE`, patrón de `terrain.gd`). Nada se replica, sin colisión.

## 8. Riesgos

- **Alturas del horneado vs la malla** en pliegues: hundimiento de 5 cm; si se ve flotar, subir a 2048².
- **Costo de vértices colapsados:** las briznas rechazadas igual pasan por el shader de vértice; si `prim` pesa, bajar N de la MultiMesh y subir la densidad por rango.
- **Viento con escala espacial:** sin vectores de movimiento no hay estelas con MetalFX espacial; prohibido pasar a temporal (RFC-022 §8).
- **Pasto sobre el cursor/selección** si estos no ignoran profundidad: se resuelve en 022e1, no después.
- **Extraer `ground_common`** puede cambiar el suelo: captura de 022c antes/después, diff ≤ 1 %.
- **018d** no hecho: 022e2 queda bloqueado por él; 022e1 no.

## 9. Orden

1. `bake_grass_height.gd` + `ground_common.gdshaderinc` (diff del suelo ≤ 1 %). 2. `GrassType`/`GrassSet`, malla de brizna, `grass.gdshader` con altura y color. 3. `GrassField` con anillos y raleo. 4. Máscara + `VegetationClear`. 5. Viento, luz, presets, banco. 6. Capturas (§6). Developer → reviewer → playtester con ventana. Luego 018d (con `VegetationClear`) → 022e2 → 022e3 si el banco deja margen.

## 10. Preguntas abiertas

1. **Forma de la brizna:** (a) **geometría sin alfa, estilo BotW — recomendado** (sin sobredibujo, se ilumina redonda); (b) tarjetas cruzadas con atlas CC0 (más «foto», alfa caro en GPU de tiles, era el plan v2); (c) mixto: geometría cerca, tarjetas lejos.
2. **Alto del pasto:** (a) **corto, 0,3–0,45 m, como el verde ras del original — recomendado**; (b) medio 0,6 m, más cerca de ref 2 (choca con «no tapar unidades» en las chicas); (c) por zona con un segundo `GrassType` alto solo en bordes.
3. **Aplastado:** (a) **022e3 después del banco, solo medio/alto — recomendado**; (b) dentro de 022e1; (c) no hacerlo.
4. **018d:** (a) **018d antes de 022e2 y reutiliza `VegetationClear` — recomendado**; (b) 022e2 absorbe 018d entero; (c) los widgets quedan como están y 022e2 solo suma flores/rocas.

## Decisiones del usuario (2026-10-14)

Mandan sobre lo anterior.
1. **Brizna:** geometría opaca de 3–7 vértices (recomendado).
2. **Alto: variable por zona** (no la recomendación). Corto (~0,3 m) en caminos, junto al altar, manantiales y bordes de los claros; más alto en zonas abiertas del valle. El alto sale de un campo por zona editable (por ejemplo un multiplicador en la máscara o por capa del `GroundSet`, más ruido de mechones). El criterio de lectura sigue: ninguna unidad tapada más de 1/4 de su alto con la cámara del juego; si el pasto alto de las zonas abiertas lo rompe, se baja el tope o se abre alrededor de las unidades (lo resuelve el aplastado).
3. **Aplastado bajo las unidades: dentro de 022e1** (no como 022e3). Barato: posiciones de unidades cercanas a la cámara pasadas al shader (o una textura de pisadas), las briznas se inclinan/aplastan y se recuperan. Se mide en el banco con los 60 cuerpos.
4. **Plantas del mapa original:** 018d (MultiMesh editable, reutilizando `VegetationClear`) antes de 022e2 (recomendado).
5. **Referencia de look (2026-10-14):** el usuario: «el pasto no me está convenciendo, quiero algo más similar a esto» (BotW, `visual/refs/original/grass_botw.webp`, fuera de git): campo muy denso y continuo, briznas largas y finas, verde amarillento claro con puntas casi blancas a contraluz, ondas de viento, fundido brumoso a lo lejos. Alto en campo abierto ≈ 0,6–0,9 m. El criterio de lectura pasa a: torso y silueta de cada unidad legibles (las patas pueden quedar sumergidas), con el aplastado abriendo espacio alrededor.
6. **Look aprobado (2026-10-14):** el usuario: «sí, me convence… se puede reducir un poco más la distancia de dibujado y la estética estaría bastante correcta». Default único: `meadow.tres` con los valores de la variante BotW, briznas más anchas y especular. Radio de dibujado bajado: bajo 20→16 m, medio 32→26 m, alto 48→38 m.
7. **Iteración en juego (2026-10-14):** tras ver el pasto en partida, el usuario pidió en pasadas sucesivas: menos briznas pero más grandes y dibujadas más lejos (radios 45/100/120 m, cercano 8/14/18, briznas hasta 3× más anchas y 1,5× más altas con la distancia); hierba «bastante más alta» (0,5–2,3 m); más especular (sin escarcha a contraluz rasante); al pisarla se dobla y no desaparece (empuje de stamps con tope 1, piso de altura ~38 %); briznas más anchas (`width_m` 0,16) y ~25 % menos densidad. La vista RTS pinta el valle continuo y la pintura se desvanece con la pendiente. Aprobado como look de Persephone. El cierre (review, playtest, F70) se hace **junto con 022e4**, cuando el pasto esté en los cinco biomas.

## 11. Anexo 022e4: pasto en todos los biomas

Pedido del usuario (2026-10-14): «me gustaría que el pasto exista en todos los biomas». Plan del tech lead, aprobado con las decisiones de abajo.

**Hechos verificados.** Hay un solo mapa (High Noon); los cinco dioses son temas. `ThemeApplier.apply` solo cambia el atlas (`cache/look/themes/<dios>/atlas.png`); malla, `tiles.png`, `light.png` y `cache/look/height.exr` son comunes, así que **no hay que hornear altura de nuevo**. Hoy el pasto corta en `GrassField._refresh()` con `_ground == null`, el horneado (`grass_bake.gdshader`) depende del `GroundSet` PBR y la pintura lejana solo se aplica al material PBR. Los ids de tile significan lo mismo en los cinco atlas; los tiles 0–8 (slot 0) cubren el 96 % del mapa. Color medio de la base: Persephone `#7f8e60`, Pyro `#ae7154`, James `#e6bb97`, Stratos `#eceded`, Charnel `#d29e7f`. En High Noon no hay lava ni agua; sin pasto: sendero (slot 3), transición parcial (slot 2), pendientes (`slope_max_deg`), huecos/borde (canal G de `height.exr`) y claros.

**Opción elegida: pasto sobre el suelo clásico (B).** No se trae PBR a los otros biomas (VISUAL.md: manda la referencia original).
- `grass_bake_classic.gdshader`: hornea el mismo contrato (`ground_data`, `zone_data`) desde atlas del dios (mip = media del tile) × (`light_base + lightmap × light_gain`), igual que `sacrifice_ground.gdshader`; dónde crece = slot del `TileLayerMap` como splat × `density_by_layer`; roca por pendiente. `grass.gdshader` no cambia.
- La pintura lejana se extrae a `ground/grass_paint.gdshaderinc` y se incluye en `ground_common.gdshaderinc` y en `sacrifice_ground.gdshader` (con `amount = 0` por defecto el clásico queda idéntico).
- `GrassField` elige la fuente: PBR si el perfil tiene `GroundSet`, clásico si no.

**Paleta: `GrassPalette`** (Resource nuevo, solo color/material: `color_mid`, `color_tip`, `ground_mix`, `clump_tint`, `gust_lighten`, `specular`, `roughness`, `translucency`, `root_ao`, `paint_amount`, `paint_tone`, `paint_waves`). `GrassSet` gana `palette`; vacío = colores del tipo (Persephone sin cambios). Cada `GrassSet` de bioma apunta al **mismo** `meadow.tres`. `GrassSet.resolved_type()` devuelve una copia en runtime (nunca guardada) con la paleta aplicada; `GrassField` observa tipo y paleta para edición en vivo. `tools/sample_grass_palette.py` propone la paleta (media del slot 0 ponderada por uso, transferencia HSV con las ganancias meadow/suelo de Persephone, tope de saturación) y escribe `data/look/grass/palettes/<dios>.tres`; autocontrol: sobre Persephone da meadow ±0,02.

**Árbol.** N = nuevo, M = modificado.
```text
data/look/{pyro,james,stratos,charnel}.tres            M  + grass
data/look/grass/{pyro,james,stratos,charnel}_grass.tres N  GrassSet: types=[meadow], palette
data/look/grass/palettes/{pyro,james,stratos,charnel}.tres N
debug/rules/biome_{james,stratos,charnel}.tres          N  MatchRules, otro biome_god
scenes/world/sacrifice_ground.gdshader                  M  + include grass_paint
scenes/world/terrain.gd                                 M  + classic_material() (getter)
scenes/world/high_noon.tscn                             M  LookRig.tile_map = high_noon_tiles.tres
scenes/world/look/look_rig.gd                           M  + tile_map; preview() aplica el atlas del dios
scenes/world/look/ground/{ground_common.gdshaderinc,ground_material.gd} M
scenes/world/look/ground/grass_paint.gdshaderinc        N
scenes/world/look/grass/{grass_palette.gd,grass_bake_classic.gdshader} N
scenes/world/look/grass/{grass_set.gd,grass_field.gd}  M
tools/sample_grass_palette.py                           N
```

**Escenas de prueba.** `debug/biome_pick.tscn` con `debug/rules/biome_<dios>.tres` (cámara del juego en el altar) y `debug/look_gallery.tscn` con `classic = false` (F1 bioma, F2 cámara ref/rts/horizonte, F3 calidad).

**Cortes.**
- **022e4a:** extraer `grass_paint` (Persephone diff ≤ 1 %), adaptador clásico, `GrassPalette`, Pyro (paleta a mano contra `orig_1_pyro`).
- **022e4b:** herramienta de paleta, James, Stratos, Charnel; ajuste a mano contra capturas del original.

**Criterios de aceptación.** Por bioma, con capturas en juego (encuadre de juego, giro, RTS) junto a la del original: una sola mancha de la paleta del suelo original; raíces del color del suelo; borde invisible (luminancia ±5 m alrededor del radio ≤ 6 %); torso y silueta de unidades legibles; sin pasto en altar, manantiales ni sendero. Persephone diff ≤ 1 %; modo clásico diff 0. Editor: tocar `palettes/pyro.tres` se ve en vivo; tocar `meadow.tres` cambia los cinco; `git status` solo con ese `.tres`. Costo del pasto por bioma ≤ Persephone + 0,1 ms en medio. Dedicado: ningún `GrassField`. El presupuesto +1,5 ms de §6 sigue abierto y fuera de alcance.

**Decisiones del usuario (2026-10-14).**
1. Paleta de cada bioma: misma forma (meadow), color del suelo original de cada mapa.
2. **Stratos: blanco como el suelo** (no la recomendación gris-azul). Riesgo a vigilar: que no se queme con el sol ni tape la lectura de unidades; se controla con especular/tono de la paleta, sin cambiar el blanco.
3. Paleta: herramienta que propone + ajuste a mano en el inspector.
4. Capturar el original de James, Stratos y Charnel en los mismos encuadres antes de 022e4b.
5. Cierre de 022e1 y 022e4 juntos al final (review, playtest, FEATURES).

## 12. Corrección 022e4c: laderas y pasto lejano (v2)

Reclamo del usuario (2026-10-14, 4.ª vez), sobre una captura en Pyro desde el campo: la ladera beige a ~15–50 m se ve cubierta de briznas sueltas y puntiagudas («parches», grano, espinas). Aclaración del usuario tras la v1 de esta sección (que proponía quitar el pasto de las laderas y fue **rechazada**): «yo SÍ quiero que haya pasto [en las laderas], pero no quiero que se vean esos pastos separados; prefiero que simplemente aparezcan con un shader suavemente, pero sin pasar por esa especie de LOD a lo lejos». Antes: «que directamente se desvanezcan, como en BotW… disminuyan su altura y su aparición/desaparición sea suave». El pasto **cercano** de llanura está aprobado (§ Decisiones 7): no cambian alto, ancho cercano, densidad cercana, especular, pisada ni paleta.

Autoridad: VISUAL.md > decisiones del usuario (§10–§11 y la cita de arriba) > esta sección. Contradicciones señaladas: §5/§6 miden con `look_bench`; las reglas de seguridad de esta sesión lo prohíben, así que el costo se mide con `agent/fixtures/rfc022e4_perf_*.tscn` y con el banco de §12.3. La skill del estudio pide escenas de prueba en `res://debug/`; AgentKit exige `res://agent/`: gana AgentKit (patrón ya usado en 022e4). La decisión 7 aprobó radios de 45/100/120 m (hoy 38/82/100 en `quality_*.tres`, alto 0 al 85 %); esta corrección **reduce el radio efectivo** a cambio de densidad pareja: es un cambio de una decisión aprobada y queda como pregunta abierta 1.

### 12.1 Objetivo (criterios, sin extras)

- Las laderas tienen pasto: el mismo tipo, con la mezcla al color del suelo que ya existe, sin corte por pendiente ni ruido que forme islas.
- **Sin LOD de densidad visible:** el campo se ve continuo en todo su alcance (cobertura mínima medible); nunca briznas aisladas sobre suelo liso, en llanura ni en ladera.
- La desaparición ocurre **solo por altura** (fundido ancho), con el color convergiendo al suelo: pasto parejo que baja y se funde.
- Llanura cercana sin regresión; sin banda oscura; sin pop al caminar ni al girar; costo dentro del presupuesto de instancias por preset.
- Un solo mecanismo para los 5 biomas (`meadow.tres` compartido, sin ramas por bioma).
- Todo se demuestra con el banco determinista de §12.3.

### 12.2 Causa raíz (leída en el código)

1. **LOD de densidad (la causa principal).** `grass.gdshader:168–171`: `falloff = 1/(1+(dist/(0,8·near))^4)` con piso `far_ratio = density_far/density_near = 6/120 = 0,05`. En medio (cercano 14 m) a 20 m la densidad ya es ~9 % y a ~31 m llega al piso del 5 % (6 briznas/m²). El ancho compensa por otra curva (`size_t = smoothstep(0,6·near, 3·near)`): a 20 m el ancho es solo ×1,65. La cobertura (≈ densidad × ancho × alto × 0,55) cae de ~10 cerca a ~1,5 a 20 m: **un hueco de cobertura** justo en 15–30 m. Además, las celdas lejanas (> 2,2 × cercano) usan una MultiMesh con el 5 % de las briznas. En llanura con vista rasante las briznas se solapan igual; en una ladera **de frente a la cámara** el suelo ocupa más pantalla por m² y se ven puntas sueltas. Eso son las «espinas».
2. **La ladera achica las briznas.** `slope_height_scale 0,72` × `slope_width_scale 0,62` = 45 % del área de cada brizna en pendiente plena: la ladera tiene la mitad de cobertura que la llanura a igual distancia.
3. **Términos de pendiente que apagan por zonas.** `slope_data` (horneado `mode 1`) = `1 - smoothstep(34°, 56°)`, y la línea 215 `h *= 1 - hill*smoothstep(0,25r, 0,6r·…)` resta alto según pendiente y distancia. Los dos usan `slope_noise_deg = 9` (±~11°): **islas** de pasto más alto y más bajo sobre la misma ladera, es decir «parches».
4. **El fundido se mide desde `field_center`** (adelantado e interpolado), no desde la cámara: girar cambia los fundidos sin trasladar la cámara. Se mide en el barrido del banco; solo se toca si falla, porque afecta la llanura aprobada.
5. **No es pasto:** las plantitas oscuras sueltas de los cerros son los ~720 widgets del original (`scenes/world/map_props.gd`). No se tocan (018d); en el banco se cancelan (están en A y en B).

### 12.3 Reglas nuevas

**R0 — Cobertura pareja, sin LOD de densidad visible (la clave).**
- La densidad y el ancho dejan de seguir curvas independientes: **los dos se interpolan con el mismo parámetro** `t(d) = smoothstep(near_r, 2,2·near_r, d)`: `D(d) = mix(D_near, D_far, t)`, `w(d) = mix(w, w·far_width_scale, t)`. El producto de una recta que baja por otra que sube es cóncavo en t, así que la cobertura **no tiene mínimo intermedio**: está acotada por sus extremos. Se borra la curva `pow(…, 4)` y el `size_t` separado (el alto lejano `far_height_scale` usa el mismo `t`).
- **Piso de cobertura:** `D_far` se elige para que `C_far = D_far × w_far × h_ref × 0,55 ≥ 2,3` (≈ 90 % de suelo cubierto con solape aleatorio, 1 − e^−C), con `h_ref` = alto mediano de zona abierta lejos. Con `w_far = 0,16 × 3,4 = 0,54 m` y `h_ref ≈ 1,0 m` ⇒ **`D_far ≈ 9–12 briznas/m²`** (hoy 6). Valor final: el que haga pasar el criterio 2 del banco. `GrassType` agrega `func far_coverage() -> float` (helper puro) y `GrassField` avisa en `_get_configuration_warnings()` si queda < 2,3.
- **El preset ya no baja la cobertura lejana:** `grass_density_scale` escala solo la densidad cercana (detalle); `D_far` es del tipo. Lo que ahorra el preset es el **radio**.
- Desde `2,2·near_r` hasta el borde la densidad es **constante**: no hay más raleo. Invariante para el developer: la MultiMesh de cada anillo tiene ≥ la densidad que el shader pide en el borde interior de ese anillo (si no, el anillo recorta briznas y reaparece el LOD). `GrassField` lo comprueba al construir mallas (`push_warning`).
- **Desaparición solo por altura:** `h *= 1 - smoothstep(fade_start·R, R, d)` con `fade_start` ≈ 0,35 (ancho) y `far_k` (color → suelo) con el mismo rango. `R` = radio efectivo (§12.4). Las briznas no se ralean al alejarse: todas se acortan juntas. La aparición por rango (`smoothstep(0, 0,5, (frac−rank)/frac)`) queda solo dentro de la franja cercano→lejano, donde la cobertura está garantizada por R0.

**R1 — Las laderas tienen pasto.**
- Se borran la línea 215, `slope_noise_deg` (en `hill` y en `slope_data`), `slope_max_deg` y `slope_soft_deg`.
- `slope_data.r` (horneado `mode 1`, sin ruido) = `mix(1, slope_height_floor, smoothstep(slope_start_deg, slope_full_deg, pendiente))`, inicial 10° → 40° y piso **0,55**: nunca 0 por pendiente sola. Reemplaza a `slope_height_scale`.
- `slope_width_scale` → **1,0** (la ladera conserva el ancho y por lo tanto la cobertura). Se mantienen `slope_color_mix`, `slope_tip_keep` y `slope_lean_gain` (la mezcla al suelo que ya existe).
- `hill` (color) = `smoothstep(10°, 36°)` **sin ruido**.
- Donde el mapa no da pasto (sendero, roca por `density_by_layer`, claros, huecos de `height.exr`) sigue sin pasto: eso no es pendiente.

**R2 — Tamaño proyectado mínimo (red de seguridad).**
- `px = w(d) × PROJECTION_MATRIX[1][1] × VIEWPORT_SIZE.y × 0,5 / distancia_a_la_cámara`; `h *= smoothstep(min_blade_px, full_blade_px, px)`, inicial 1,0 → 2,0 px.
- Usa `w(d)` de R0, **sin** factores por instancia, por pendiente ni por mechón: a una distancia dada actúa igual sobre todas las briznas, así que no puede dejar «unas pocas». Las briznas cuyo alto es 0 por R2 se colapsan como hoy (sin raster).
- Cifras: en medio (escala 0,67, vFOV ~75°, focal ≈ 283 px internos) una brizna lejana de 0,54 m mide 2 px a ~76 m. Con el radio de §12.4 R2 no actúa en medio ni en alto; en bajo (escala 0,5) empieza a ~57 m. Es una red de seguridad, no la herramienta principal.

Todas las constantes nuevas son uniforms llenados desde `GrassType` (grupos «Density», «Hillsides», «Distance fade»): ningún número mágico nuevo en el shader.

### 12.4 Presupuesto de instancias y radio efectivo

Costo = instancias enviadas (cada celda envía toda su MultiMesh; las briznas rechazadas igual pasan por el shader de vértice). Estimación con vista de juego (≈ 50 % del anillo cercano y ≈ 35 % de los anillos medio y lejano en el frustum), vértices: 5 cerca/medio (2 tramos), 3 lejos. El banco mide el número real: `prims(A) − prims(B)` del monitor `RENDER_TOTAL_PRIMITIVES_IN_FRAME` (hoy el frame completo en Pyro mide 1,12 M prims, `perf_pyro.log`).

| Preset | Hoy: radio efectivo (85 %) / D lejana | Hoy: instancias aprox. (cerca + medio + lejos) | Propuesto: D lejana | Radio efectivo **al mismo costo** | Radio con +15 % |
|---|---|---|---|---|---|
| Bajo (cercano 8, ×0,3) | 32 m / 1,8 /m² | 3,6 k + 3,4 k + 1,4 k ≈ **8,4 k** | 12 /m² | **≈ 20 m** | ≈ 24 m |
| Medio (14, ×1,0) | 70 m / 6 /m² | 42 k + 33 k + 26 k ≈ **101 k** | 12 /m² | **≈ 54 m** | ≈ 58 m |
| Alto (18, ×1,4) | 85 m / 8,4 /m² | 85 k + 80 k + 52 k ≈ **218 k** | 12 /m² | **≈ 74 m** | ≈ 79 m |

Palancas para recuperar radio sin volver al régimen ralo (en orden):
1. **Briznas lejanas más anchas** con densidad pareja: `far_width_scale` 3,4 → 4,5 baja `D_far` a ~9 /m² ⇒ medio ≈ 60 m al mismo costo. Riesgo: briznas lejanas que se leen como cintas; lo ve el playtester.
2. **Mechones** (una instancia = 2–3 briznas en abanico, malla lejana nueva en `GrassBladeMesh.build_tuft()`): reduce instancias y lecturas de textura por brizna, pero **no** vértices; solo conviene si el banco muestra que el costo es por instancia y no por vértice. Condicional, no en este corte salvo que el banco lo pida.
3. Aceptar +15 % de costo (columna derecha), dentro del margen medido en `rfc022e4_perf_*`.

Propuesta: **medio 54 m** (`grass_radius_m` 64 con el 85 %), alto 74 m (87), bajo 20 m (24); `D_far` 12 /m², `far_width_scale` 3,4. Si el usuario quiere más radio en medio, palanca 1 (~60 m) antes que la 3. Los números finales salen del banco (presupuesto: prims de pasto ≤ base × 1,10 por preset).

### 12.5 Banco determinista (escena de prueba)

**Por qué.** Cuatro iteraciones fallaron porque cada captura tenía otra cámara, otro viento y otro instante. El banco fija todo y compara **la misma imagen con y sin briznas**: lo único distinto entre A y B son las briznas.

**Escena:** `res://agent/fixtures/grass_bench_pyro.tscn` y `grass_bench_persephone.tscn`. Instancian `scenes/world/high_noon.tscn` con `debug/rules/biome_pyro.tres` o `agent/fixtures/rfc022c_rules_persephone.tres` (las reglas de `rfc022e4_slope_*`), más un nodo `GrassBench` (`agent/fixtures/grass_bench.gd`) con `@export var views: Array[GrassBenchView]` y `@export var preset: LookQuality` (medio; bajo y alto son otro `.tres`, no otro script). Mismo mapa ⇒ las mismas vistas sirven para los dos dioses.

**Estado inicial que fija `GrassBench`** (tras `settle_s` = 8 s):
1. Mago teletransportado a `spot`/`yaw` (lógica de `rfc022e4_slope.gd`), quieto.
2. `Camera3D` propia, `current = true`, transformación exacta de la vista (`eye`, `target`, `fov`); `GrassField._camera()` la sigue. Espera ≥ 2 s a que `field_center` converja.
3. Tiempo de shader congelado: uniform nuevo `time_override` (≥ 0 reemplaza `TIME`) en `grass.gdshader` y `grass_time_override` en `grass_paint.gdshaderinc` (lo pasan `ground_pbr.gdshader:226` y `sacrifice_ground.gdshader:45`, que hoy usan `TIME`). Default -1 = juego sin cambio. Cielo `set_process(false)` (patrón `look_gallery.gd`). HUD oculto en las capturas de análisis.
4. Por vista, mismo proceso: **A** = juego; **B** = briznas ocultas (oculta los `MultiMeshInstance3D` internos de `GrassField`), pintura intacta; **A2** = A repetida (determinismo). Además lee `RENDER_TOTAL_PRIMITIVES_IN_FRAME` en A y B. Dos `frame_post_draw` antes de cada `save_png`.
5. **Máscara por geometría:** rayo por píxel (grilla de 4 px) marchado contra `GrassField._height_image`; pendiente con la misma diferencia central de 2,5 m que `grass_bake.gdshader`; distancia a la cámara. `mask_<vista>.png`: R = **ladera** (≥ 18°), G = **llanura** (≤ 6°), y por píxel la distancia en m (`dist_<vista>.exr`). Excluye la caja del mago (+10 %), cielo y zonas sin pasto del mapa (sendero/claros: `zone_data.b` = 0).

**Vistas (`GrassBenchView`, Resource en `agent/fixtures/grass_bench/views/*.tres`: `label`, `spot`, `yaw_deg`, `eye`, `target`, `fov`):**
- `hill_game`: cámara del juego (≈ 3–4 m de alto, ~6 m detrás del mago) en llanura, mirando una ladera de ≥ 20° a 15–50 m a la izquierda/fondo, como la captura del usuario. Se elige con `agent/flows/rfc022e4_slope_search.json` (ya imprime `x z pendiente alto`) y queda escrita en el `.tres`.
- `hill_turn45`, `hill_turn90`: mismo ojo, yaw +45° y +90°.
- `hill_on`: el mago **sobre** la ladera (como `fade_slope_y/slope_start.png`), cámara del juego.
- `rts`: ojo a ~40 m, pitch ≈ -55°.
- `plain_p`: llanura del valle de Persephone (encuadre de `lamina_llanura_persephone_antes_despues.png`).
- `sweep`: 24 cuadros con tiempo congelado desde `hill_game`: el ojo avanza 0,75 m y gira 3° por cuadro.

**Análisis:** `agent/grass_bench_metrics.py` (Python 3, PIL 10.4 + numpy 1.26 instalados; `python3 -I`). Luminancia L (Rec.709, 0–255); **píxel de brizna** = |L_A − L_B| > 6 o ΔE RGB > 8. Por región y por anillos de 5 m de distancia:
- `coverage` = fracción de píxeles de brizna.
- `max_hole_px` = mayor componente conexa de NO brizna (8-conexa), tras erosionar 1 px la región.
- `isolated_per_10k` = componentes conexas de brizna de ≤ 12 px cuyo anillo de 3 px alrededor tiene < 20 % de brizna, por cada 10 000 px de región: briznas solas sobre suelo liso.
- `hf_profile` = por anillo, std(L − blur σ 1,5) de A menos la de B: detalle fino que agrega el pasto.
- `lum_profile` = L media de A y de B por anillo (banda oscura).
- `plain_diff` = media |L_A − L_A,base| / 255 en G, contra la línea de base.
- Salida: `metrics.json`, `bench_<dios>.png` (A | B | |A−B|×4 | máscara con briznas aisladas en rojo) y PASS/FAIL por criterio.

**Corrida (reglas de seguridad):** `agent/run_rfc022e4.sh rfc022e4c_bench_pyro bench_y` (flows nuevos `agent/flows/rfc022e4c_bench_{pyro,persephone}.json`: `scene` y `wait_first`; el banco sale solo). Un único Godot a la vez, 1152×648, `--max-fps 60`, vigilancia RSS 2,5 GB, nada de `look_bench`, sin tocar el editor abierto. ~40 s por corrida; medio en los dos dioses y bajo/alto solo en Pyro. **Línea de base:** antes de tocar el pasto, con `time_override` ya agregado (a -1 no cambia nada), guardar `agent/out/rfc022e4c/baseline_*`.

### 12.6 Contrato de aceptación

1152×648; medio en Pyro y Persephone salvo indicación. «Zona visible» = anillos donde el alto nominal de R0 es ≥ 50 % (d ≤ punto medio del fundido).

| # | Criterio | Medida | Umbral |
|---|---|---|---|
| 0 | Banco válido | A vs A2 | media ≤ 0,1 %, píxeles distintos ≤ 0,02 %; si no, nada más cuenta |
| 1 | **Ladera con pasto continuo** (`hill_game`, `hill_turn45/90`, `hill_on`, `rts`) | región R, zona visible | `coverage` ≥ 0,85 en cada anillo; `max_hole_px` ≤ 64 (≈ 8×8) |
| 2 | **Sin briznas aisladas** (todas las vistas, R y G, todos los anillos hasta R) | `isolated_per_10k` | ≤ 1,0 por región; 0 componentes rojos visibles en la lámina de `hill_game` |
| 3 | Desaparición solo por altura | `hf_profile` por anillo desde `near_r` hasta R | monótono no creciente (tolerancia +5 % entre anillos vecinos) y ≤ 10 % del valor a `near_r` en el último anillo; `coverage` no cae > 10 % entre anillos vecinos mientras el alto nominal ≥ 50 % |
| 4 | Llanura cercana sin regresión | G de `plain_p` y `hill_game`, 8–25 m, contra la base | `plain_diff` ≤ 1,0 % |
| 5 | Sin banda oscura | `lum_profile` en G y R | ningún anillo con L_A < L_B − 4 %; ningún salto de L_A > 4 % entre anillos vecinos |
| 6 | Sin pop (determinista) | `sweep` | criterios 1–2 en **cada** cuadro; Δ de L media de (A−B) en G entre cuadros consecutivos ≤ 1,5 % |
| 7 | Costo | prims de pasto del banco (A − B) por preset; GPU con `rfc022e4_perf_*` | prims ≤ base × 1,10; GPU ≤ base + 0,15 ms en medio |
| 8 | R2 no ralea | vista `rts` en **bajo** | criterio 2 se cumple (R2 actuando no deja briznas sueltas) |
| 9 | Dedicado | `--headless -- --dedicated` (patrón `run_f63_net.sh`) | ningún nodo en el grupo `grass_field`; sin errores de shader |
| 10 | Hotswap | `agent/flows/rfc022e4_hotswap.json` | sin errores; al volver a Persephone, `plain_p` vs base ≤ 1,0 % |

**Reviewer (código, una pasada):**
- Densidad y ancho comparten el parámetro `t(d)`; no queda `pow(…, 4)` ni `size_t` separado; el piso es constante.
- Ningún término pone el alto en 0 por pendiente; borrados (no puestos en 0) línea 215, `slope_noise_deg`, `slope_max_deg`, `slope_soft_deg`, `slope_height_scale`; `_signature()` y `_zone_view()` actualizados.
- R2 usa `w(d)` sin factores por instancia.
- Valores nuevos solo en `GrassType`/`meadow.tres` y en `quality_*.tres` (radios); uniforms en el shader, sin números mágicos nuevos; ninguna rama por bioma.
- `grass_density_scale` afecta solo la densidad cercana; invariante de anillos con `push_warning`; `far_coverage()` y su aviso de configuración.
- `time_override` default -1; solo `agent/` lo escribe. El banco vive entero en `agent/`.
- Editar `D_far`, `slope_height_floor` o `fade_start` en el inspector se ve en vivo; `git status` solo con los `.tres`.

**Playtester (con ventana, mirando las PNG):**
- Corre el banco (medio en Pyro y Persephone, bajo y alto en Pyro) y adjunta láminas y `metrics.json`. **Mira** la columna A de `hill_game` y `hill_on`: la ladera tiene un manto parejo que baja de alto y se funde con el suelo; ninguna espina suelta.
- Secuencia real (tiempo sin congelar, `agent/flows/rfc022e4c_walk_pyro.json`): desde `hill_game`, `move_forward` 4 s, `turn_right` 2 × 0,4 s y arrastre a RTS; 12 capturas cada 0,25 s. Sin aparición ni desaparición brusca; el viento sigue.
- Lámina antes/después de la llanura cercana de Persephone y de Pyro.
- Falla un criterio si su PNG muestra otra cosa que la nombrada, aunque el número pase.

### 12.7 Árbol de archivos y responsabilidades

```text
game/
├── data/look/grass/types/meadow.tres                    M  density_far ~12, slope_height_floor 0,55, slope_start/full_deg 10/40,
│                                                           slope_width_scale 1,0, fade_start ~0,35, min/full_blade_px; borra campos viejos
├── data/look/quality_{low,medium,high}.tres             M  grass_radius_m 24 / 64 / 87 (propuesta; final por banco)
├── scenes/world/look/look_quality.gd                    M  doc: grass_density_scale = solo densidad cercana
├── scenes/world/look/grass/
│   ├── grass_type.gd                                    M  campos nuevos/borrados; far_coverage()
│   ├── grass_field.gd                                   M  uniforms, horneado, firma, conteos por anillo + invariante, aviso de cobertura
│   ├── grass_bake.gdshader                              M  mode 1 = alto por pendiente con piso, sin ruido; hill sin ruido
│   └── grass.gdshader                                   M  R0 (t común, piso, fundido solo por alto), R1, R2, time_override; borra 215
├── scenes/world/look/ground/grass_paint.gdshaderinc     M  grass_time_override (default -1)
├── scenes/world/look/ground/ground_pbr.gdshader         M  tiempo vía grass_time_override
├── scenes/world/sacrifice_ground.gdshader               M  ídem
└── agent/
    ├── fixtures/grass_bench.gd                          N  estado fijo, A/B/A2, prims, máscara, sweep, quit
    ├── fixtures/grass_bench_view.gd                     N  Resource: label, spot, yaw_deg, eye, target, fov
    ├── fixtures/grass_bench/views/{hill_game,hill_turn45,hill_turn90,hill_on,rts,plain_p}.tres  N
    ├── fixtures/grass_bench_{pyro,persephone}.tscn      N  high_noon + reglas + GrassBench (preset medio)
    ├── fixtures/grass_bench_{low,high}.tres             N  LookQuality de referencia para el banco (si no se usan los del juego directamente)
    ├── flows/rfc022e4c_bench_{pyro,persephone}.json     N
    ├── flows/rfc022e4c_walk_pyro.json                   N  secuencia real del playtester
    └── grass_bench_metrics.py                           N  métricas + lámina + PASS/FAIL
```

| Pieza | Responsabilidad | Tipo | Corre en |
|---|---|---|---|
| `GrassType` (meadow) | Piso de cobertura lejana, curva de pendiente, fundido, píxeles; los 5 biomas | Resource de tipo | editor/cliente |
| `LookQuality` | Radio por preset y densidad **cercana** | Resource de preset | editor/cliente |
| `GrassField` | Conteos por anillo, uniforms, horneado, avisos | Nodo `@tool` (existente) | editor/cliente; no existe en dedicado |
| `grass_bake.gdshader` | Pendiente → alto restante (con piso), sin ruido | Shader de horneado | cliente, una vez |
| `grass.gdshader` | R0, R1, R2, `time_override` | Shader | cliente |
| `GrassBenchView` / `GrassBench` | Vista fija / congelar, capturar, enmascarar | Resource / Nodo (solo agent) | proceso de prueba |
| `grass_bench_metrics.py` | Números y lámina | Herramienta | fuera de Godot |

`@export` de instancia: solo en `GrassBench` (`views`, `preset`, `settle_s`). Nada nuevo en el nodo `GrassField` del rig.

### 12.8 Riesgos y fuera de alcance

- **Instancias vs radio (el principal).** Densidad pareja cuesta más por m²: al mismo costo el radio efectivo baja (medio 70 → ~54 m). Si el usuario quiere más radio, palancas de §12.4 en orden; cada una se mide con el banco (criterio 7).
- **Briznas lejanas anchas** (0,54 m) pueden leerse como cintas o tarjetas; R0 las acorta y les da el color del suelo antes de que sean dominantes. El playtester lo mira en `hill_game`.
- **Paredes muy empinadas** (> 50°) ahora tienen pasto al 55 %: briznas verticales asomando de una pared. Lo que es roca ya no tiene pasto por `density_by_layer`; si queda alguna pared con pasto, pregunta 2.
- **La franja cercano → lejano** (14–31 m en medio) es donde hoy está el hueco; R0 lo cierra por construcción, pero el invariante de anillos debe cumplirse o vuelve el raleo (aviso + criterio 3).
- **`field_center`** solo se toca si falla el criterio 6.
- **R2 en bajo** puede actuar dentro del radio; el criterio 8 lo cubre.
- Fuera de alcance: widgets/plantas del original (018d); color y paleta; pasto cercano aprobado; mechones (solo si el banco muestra que el costo es por instancia); presupuesto +1,5 ms de §6.

### 12.9 Orden (un corte: 022e4c)

1. `time_override` en los tres shaders (default -1) + banco completo (`GrassBench`, vistas, flows, métricas). Elegir `hill_game` con `rfc022e4_slope_search.json` y fijarlo. **Línea de base** en Pyro y Persephone (medio) y Pyro (bajo, alto): criterio 0, prims de pasto por preset. Se espera que hoy fallen 1, 2 y 3; si pasan, el banco no ve el problema y se corrige antes de seguir.
2. `GrassType`: campos nuevos, borrar los viejos, `far_coverage()`; `meadow.tres`.
3. `grass_bake.gdshader` (R1 sin ruido, con piso) y `grass_field.gd` (parámetros, firma, conteos por anillo con el piso, invariante, aviso).
4. `grass.gdshader`: R0 (borra `pow 4` y `size_t`, `t` común, fundido solo por alto), borra la línea 215, R2.
5. Radios de `quality_*.tres` según §12.4; banco → criterios 1–8. Ajustar **solo** valores de `.tres` hasta pasar.
6. Si falla 5 (banda oscura): AO de raíz escalado por el alto en metros (`root_ao_full_m` en `GrassType`) y repetir 5.
7. Criterios 9–10 (dedicado, hotswap).
8. Developer entrega `metrics.json` + láminas + prims por preset → reviewer → playtester con ventana (§12.6). Recién entonces se le muestra al usuario.

**Cómo lo verifica un humano en el editor:** abrir `agent/fixtures/grass_bench_pyro.tscn`, F6: vista `hill_game` congelada. En el inspector de `meadow.tres`, bajar `density_far` a 6 y ver volver las espinas en la ladera; subirla a 12 y ver el manto parejo. Mover `fade_start` y ver el pasto bajar de alto sin ralear. En `look_gallery.tscn` (F1 bioma, F2 cámara, F3 calidad) recorrer los cinco biomas y los tres presets.

### 12.10 Nota de proceso

El developer **no itera por sensación visual**. Cada cambio se valida con el banco (mismo encuadre, tiempo congelado, A contra B) y solo entrega cuando **pasan los números y la revisión visual de las láminas**. Un reporte sin `metrics.json` de Pyro y Persephone, sin la línea de base, sin prims por preset y sin la lámina A|B|diff está incompleto y vuelve. Las capturas de juego libre sirven para el playtest final, no para decidir umbrales.

### 12.11 Preguntas abiertas

1. **Radio efectivo en medio** (donde el alto llega a 0) con densidad pareja: (a) **~54 m al mismo costo que hoy — recomendado**; (b) ~60 m con briznas lejanas más anchas (`far_width_scale` 4,5), mismo costo y riesgo de que se lean como cintas; (c) mantener ~70 m pagando ~+45 % de instancias de pasto en medio.
2. **Paredes muy empinadas (> 50°):** (a) **pasto al 55 % como el resto de la ladera, salvo donde el mapa ya es roca — recomendado** (lo que pediste: pasto en las laderas); (b) bajar el piso progresivamente sobre 50° (nunca 0).

## Aprobación del usuario (2026-10-16)
El usuario aprobó a ojo el pasto en la vista alta de Persephone y en los demás biomas, con las láminas del playtest de F108 (`agent/out/pt108/`). Con esto queda cerrado el pendiente «juzgar el pasto a ojo».
