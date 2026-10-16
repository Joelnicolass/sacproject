# RFC-022 — Remaster visual por capas (v2)

Estado: PLAN v2 (tech lead, 2026-10-13). Sin código. Reemplaza a la v1. Manda `game/VISUAL.md`. Se implementa al cerrar RFC-020d y 020e.
**Los ms de este documento son estimaciones, no mediciones**: el proyecto no tiene ningún `Performance.get_monitor`. 022a mide la línea de base y cada corte corrige su número.

## 0. Qué cambia respecto de la v1

- Cae la regla «no sumar arte» y la de «perilla en 0 = look de hoy». Entra arte CC0 (suelo, pasto, rocas, cielo) y mapas generados (normal, AO) para lo original.
- El suelo deja el atlas × lightmap y pasa a un material PBR por capas; el look de hoy queda solo como modo «clásico» de comparación (`look = null`).
- El cielo pasa a ser un `Sky` de Godot (alimenta ambiente, reflejos y niebla); el cilindro original se retira de la vista por defecto.
- La niebla volumétrica sube a protagonista: entra en calidad media con volumen reducido (v1: solo alta).
- Aparecen tres sistemas nuevos: dispersión de vegetación, mapas para modelos originales y partículas ambientales.
- La calidad media se alcanza con resolución de render escalada (v1: nativa a 1080p).
- Primero un bioma completo (Persephone) y después la réplica; v1 iba capa por capa en los cinco.
- Siguen: AgX compensado, gradiente de color por dios, capas apagables, galería, banco, nada en el dedicado.

## 1. Lectura de las referencias (por capa)

Las cuatro comparten encuadre (cámara baja detrás del mago, altar al fondo) y las refs 2, 3 y 4 son **la misma escena con otra luz, cielo y partículas**: eso valida el diseño «un bioma = datos».
- **Suelo:** relieve fino por normales y AO, no por geometría; 3–4 materiales mezclados (pasto en lo llano, roca y tierra en pendiente, sendero pelado); sin repetición visible.
- **Vegetación:** pasto denso y bajo (no pasa la rodilla de la criatura), matas y flores sueltas, rocas medianas que rompen la silueta de la loma. En el desierto (ref 1): matas secas ralas y piedras chicas.
- **Luz:** sol bajo y lateral, sombras largas y suaves, sombra nunca negra; de noche, relleno azul de luna y el altar como luz local dominante.
- **Cielo:** nubes con volumen y borde iluminado, claro detrás del altar, sol/luna visibles; ocupa un tercio del cuadro.
- **Atmósfera:** bruma en los valles, haces entre nubes (ref 2), polvo que cruza (ref 1), luciérnagas (ref 3), brasas y humo (ref 4).
- **Post y VFX:** bloom fuerte solo en el portal (columna de luz + chispas bajo la losa), contraste alto, paleta teñida por bioma.
- **Modelos originales:** conviven porque reciben sombra, AO de contacto y relieve en la piedra del altar.

## 2. Objetivo, pilares y bioma de prueba

- Llevar el juego hacia las referencias con capas apagables, medibles y editables por un technical artist.
- Un bioma = un `LookProfile` que referencia suelo, dispersión, cielo, luz, atmósfera, partículas y color.
- Texturas nuevas se suman creando un `.tres` (§6), sin tocar código.
- 60 fps en medio con render escalado; nada corre ni se carga en el dedicado; la simulación usa la misma altura de terreno.
- Lectura de RTS intacta: jerarquía de `VISUAL.md`.

**Bioma de prueba: pradera de Persephone (ref 2).** Ejercita todas las capas a la vez y la más riesgosa (pasto + volumétrica + sombras); las refs 3 y 4 son la misma escena, así que noche y fuego salen después como datos; `map_props.gd` ya usa plantas de Persephone. El desierto es más barato pero no prueba el pasto.

## 3. Sub-cortes

Presupuesto: ms de GPU sumados a la línea de base, preset medio (render interno ~1707×960 → 2560×1440). Techo total medio: **≤ 14 ms**. Cámaras fijas: `ref` (encuadre de las referencias), `rts` (zoom máximo de juego), `horizonte`.

| Corte | Objetivo | Criterio verificable (captura) | Se ve al terminar | GPU |
|---|---|---|---|---|
| **022a** Andamiaje | Resources, rig, env `.tres`, presets con escala de render, galería, banco | `look_bench` imprime base por preset y modo de escala; captura clásica idéntica a la previa (diff ≤ 1 %); dedicado sin nodos de `look/` | Nada nuevo; línea de base | 0 |
| **022b** Luz base | Sol por bioma, PSSM, penumbra, relleno, AgX, SSAO | `ref`: unidad a la sombra ≥ 35 % de la luminancia al sol; penumbra visible; sin píxeles 255 en el suelo | Sombras largas y suaves, nada negro | +2,0 |
| **022c** Terreno PBR | Suelo por capas (Persephone) | `ref`: 3 capas distinguibles, relieve con sol rasante, sin repetición a 150 m; `rts`: las zonas siguen la distribución del mapa original | Suelo con relieve | +1,5 |
| **022d** Cielo | `Sky` con nubes, sol/luna, ambiente desde el cielo | `horizonte`: disco en la dirección del `Sun`, nubes con borde iluminado que se mueven (capturas a 3 s y 16 s); el suelo a la sombra toma el tinte del cielo | Cielo dramático | +0,4 |
| **022e** Vegetación → **[RFC-022e](RFC-022e-grass.md)** | e1 pasto estilizado por geometría (BotW/Ghibli) alrededor de la cámara; e2 flores, matas, rocas y widgets del original; e3 aplastado opcional | Ver RFC-022e §1 y §6 (primero contra `refs/original/`, luego ref 2; ninguna unidad tapada más de 1/4; claros en altar, manantiales y sendero) | Pradera | +2,0 (e1 1,4 + e2 0,6) |
| **022f** Atmósfera | Volumétrica, niebla de altura, `FogVolume`, partículas ambientales | `ref`: haces desde el sol y bruma en el valle; unidad a 150 m distinguible; quitar el nodo apaga la capa | Rayos y bruma | +2,0 |
| **022g** Mapas de lo original | Normal + AO/roughness generados para cuerpos, altar, estructuras, props | Altar y 3 cuerpos con luz rasante: relieve visible, sin costuras ni brillo plástico; con y sin, lado a lado | Modelos integrados | +0,4 |
| **022h** Post y portal | Glow, gradiente de Persephone, portal del altar | `ref`: brilla el portal y no el suelo ni el cielo; columna y chispas como ref 2 | Portal de referencia | +0,6 |
| **022i** Cierre del slice | Pase del artista + `studio-visual` + banco de 3 presets | Informe sin bloqueantes contra ref 2; pisos de §9 | Persephone terminada | — |
| **022j** James y Pyro | Datos + lo que falte (lava emisiva, focos de fuego, polvo) | `ref` contra ref 1 y ref 4 | 3 biomas | ≤ medio |
| **022k** Noche y quinto | Charnel (ref 3): luna, luces locales, luciérnagas; Stratos | `ref` contra ref 3; unidad legible lejos del altar | 5 biomas | +0,5 |
| **022l** VFX restantes | Manantiales, aro y cuerda del Sac Doctor, vórtice, hechizos: energía, luz local | `fx_gallery` por bioma: todo emisivo florece, nada quema a blanco | VFX coherentes | +0,3 |

### Medido en 022a (M4, 2560×1440 Retina, Forward+ sobre Metal, sin vsync)

> **Aclaración de la review (2026-10-14):** la línea de base ya incluye lo que el `Environment` de antes tenía encendido y `env_base.tres` conserva: AgX (`tonemap_mode = 4`), SSAO (radio 3,5), glow, niebla con dispersión de sol y **niebla volumétrica** (anisotropía 0,75) con sus valores por defecto. 022b, 022f y 022h no suman esas capas de cero: las recalibran, y su costo se mide como diferencia sobre esta base. El método (cuadro / 9 con 8 `SubViewport`) sirve para comparar entre cortes, no como ms absolutos: tomar ±1 ms de margen y repetir cada corte con el mismo método.

- **`viewport_get_measured_render_time_gpu` devuelve 0 en Metal (4.7.2)**: los timestamps de GPU no existen (`vp_begin`/`vp_end` = 0). El banco deriva el GPU: renderiza la misma escena en 8 `SubViewport` extra con el mismo preset y `gpu_ms = frame_ms / 9` (válido mientras `frame_ms` > ~9; la pantalla topa en ~120 Hz). Son ms de **una vista**, mapa High Noon + 8 emisores, **sin cuerpos** (ver abajo), capas apagadas.
- Los cinco modos de escala **funcionan y se leen de vuelta** en Forward+/Metal: bilinear, FSR 1, MetalFX espacial, FSR 2, MetalFX temporal.

| Preset / modo | Interno | GPU ms |
|---|---|---|
| Nativa (1,0, sin AA) | 2560×1440 | 7,3 |
| Bajo 0,5 bilinear / FSR 1 / MetalFX esp. | 1280×720 | 3,2 / 3,8 / 3,6 |
| Bajo 0,5 FSR 2 / MetalFX temporal | 1280×720 | 7,6 / 6,5 |
| Medio 0,67 bilinear / FSR 1 / MetalFX esp. | 1715×965 | 4,4 / 5,1 / 4,9 |
| Medio 0,67 FSR 2 / MetalFX temporal | 1715×965 | 9,4 / 7,9 |
| Alto 1,0 + MSAA 2× | 2560×1440 | 8,9 |

- Línea de base **sin remaster** en medio (MetalFX espacial + FXAA): ~4,9 ms de GPU de 16,6; **el techo de 14 ms de este RFC queda para sumar capas sobre ~5 ms, no sobre 0**. El costo del escalado espacial sobre bilinear es +0,5 (FSR 1) / +0,5 (MetalFX) ms. Los modos temporales cuestan el doble y se confirmó con captura (`agent/out/rfc022/022a/scale_*.png`) que MetalFX temporal deja restos luminosos alrededor de los cuerpos animados: **descartados**.
- **Hallazgo fuera de 022a:** 60 cuerpos con clips corriendo dan **~190 ms por cuadro (5 fps) y ~7,7 GB de memoria de video**, igual en todos los presets (cuello en CPU/memoria, no en GPU; `cpu_render_ms` 0,65). Es el `material()`/`ImageTexture` por cuadro de `obj_mesh.gd` y/o la malla por cuadro de `clip_pose_player.gd` (la sospecha de §8 «Material por cuadro»). Hay que arreglarlo (prerrequisito de 022g) antes de que el banco con 60 cuerpos sirva para medir GPU.

### Medido en 022b (luz base, mismo método que 022a, Persephone, sin cuerpos, ±1 ms)

Con la niebla volumétrica recalibrada por la capa (densidad 0,01; antes el default del motor, 0,05, la volvía un velo lechoso).

| Preset | Capa apagada (clásico) | Capa de luz encendida | Diferencia |
|---|---|---|---|
| Bajo (FSR 1 0,5; 2 splits 120 m; sin SSAO) | 3,23 | 2,99 | -0,2 |
| Medio (MetalFX 0,67; 4 splits 220 m; SSAO) | 4,81 | 5,27 | +0,5 |
| Alto (1,0 + MSAA 2×; SSAO + SSIL) | 8,81 | 14,49 | +5,7 |
| Alto sin SSIL (aislado) | 8,81 | 10,94 | +2,1 |

- SSIL cuesta ~3,5 ms en alto (14,49 vs 10,94).
- Criterio `ref` (mismo modelo `apez`, uno al sol y otro a la sombra del altar, luminancia lineal): sombra/sol = 1,14 (la cámara `ref` mira hacia el sol y ve el lado no iluminado de ambos; cumple ≥ 0,35); sin píxeles 255 en el suelo. Doctores bajo la losa (`convert_ritual`, James, cámara del juego): luminancia 0,011 → 0,153; píxeles casi negros 35 % → 15 %.
- `%Look/Quality` de `high_noon.tscn` usa `quality_medium.tres` por defecto.

## 4. Escenas de prueba, captura y medición

- **`res://debug/look_gallery.tscn`**: instancia el mapa del producto, 6 cuerpos (3 al sol, 3 a la sombra del altar), un `sprite_particles.tscn` en bucle y tres `Marker3D` de cámara. Estado inicial: modo clásico, capas apagadas (el criterio aparece al encenderlas). Acciones solo de debug: `debug_next_biome`, `debug_next_camera`, `debug_toggle_layer_1..8`, `debug_next_quality`. Imprime `look <dios> cam <n> capas <máscara> calidad <q>`.
- **`res://debug/look_bench.tscn`**: mapa + 60 cuerpos animados + 8 emisores. Sin vsync, descarta 120 cuadros, promedia 300: `viewport_get_measured_render_time_gpu()` (con `viewport_set_measure_render_time`), `Performance.TIME_PROCESS`, draw calls, memoria de video. Recorre preset × capa × modo de escala y sale.
- **`res://debug/surface_gallery.tscn`** (022g): altar + cuerpos con luz rasante giratoria, con y sin mapas.
- Flows AgentKit `agent/flows/rfc022_gallery.json` y `rfc022_bench.json` → `agent/out/rfc022/<corte>/<dios>_<cam>.png`; el playtester arma la lámina captura | referencia. Regresión: `f32_biomes`, `f19_sky_motion`, `f23_fx_gallery`.

## 5. Árbol de archivos (N nuevo, M modificado)

```text
game/
├── assets/cc0/                          N  LICENSES.md (procedencia por archivo)
│   ├── ground/<material>/{albedo.jpg,normal.png,orm.png}
│   ├── scatter/{*.glb, *_atlas.png}     ├── sky/{noise_*.png, *.hdr opcional}
├── data/look/
│   ├── env_base.tres                    N  Environment del artista
│   ├── <dios>.tres                      N  LookProfile ×5
│   ├── ground/<dios>_ground.tres, layers/*.tres   N  GroundSet / GroundLayer
│   ├── ground/high_noon_tiles.tres      N  TileLayerMap (baldosa → capa)
│   ├── scatter/<dios>_scatter.tres, types/*.tres  N  ScatterSet / ScatterType (022e2; pasto: ver RFC-022e §7)
│   ├── sky/<dios>_sky.tres  light/<dios>_light.tres  atmosphere/<dios>_atmo.tres  N
│   ├── grade_<dios>.tres                N  GradientTexture1D
│   ├── surfaces/{default,altar,<modelo>}.tres     N  SurfaceLook
│   └── quality_{low,medium,high}.tres   N  LookQuality
├── data/themes/*.tres, scenes/world/god_theme.gd  M  + look: LookProfile
├── scenes/world/
│   ├── theme_applier.gd                 M  copia el env base; delega en LookApplier
│   ├── terrain.gd                       M  colisión desde los arrays originales; material por socket
│   ├── obj_mesh.gd                      M  material() delega en BodyMaterial
│   ├── high_noon.tscn                   M  env → .tres; + %Look (una línea)
│   └── look/
│       ├── look_profile.gd, look_quality.gd, look_applier.gd   N
│       ├── look_rig.tscn/.gd            N  @tool, contiene las capas
│       ├── quality_applier.gd           N
│       ├── ground/{ground_layer.gd, ground_set.gd, tile_layer_map.gd, ground_pbr.gdshader, ground_material.gd}  N
│       ├── grass/…  (022e1, árbol en RFC-022e §7)  N
│       ├── scatter/{scatter_type.gd, scatter_set.gd, scatter_field.tscn/.gd, scatter_wind.gdshader}  N  (022e2)
│       ├── sky/{sky_look.gd, biome_sky.gdshader}                N
│       ├── light/{light_look.gd, fill_light.tscn, local_light.tscn}  N
│       ├── atmosphere/{atmosphere_look.gd, valley_fog.tscn, ambient_particles.tscn/.gd, light_shaft.tscn/.gdshader}  N
│       └── surface/{surface_look.gd, surface_library.gd, body_material.gd, body_pbr.gdshader}  N
├── scenes/fx/portal_column.tscn/.gd/.gdshader     N  (022h)
├── tools/{bake_ground_splat.gd, bake_surface_maps.gd}  N  SceneTree headless, escriben en cache/
├── debug/{look_gallery, look_bench, surface_gallery}.tscn/.gd  N
└── agent/flows/rfc022_*.json            N
```

| Pieza | Responsabilidad (una) | Tipo | Por qué no se fusiona |
|---|---|---|---|
| `GodTheme` (M) | Datos del ENVI original + socket `look` | Resource | `look = null` = modo clásico |
| `LookProfile` | Qué suelo, dispersión, cielo, luz, atmósfera y color usa un bioma | Resource | Solo referencias: cada parte se cambia sola |
| `GroundLayer` | Una capa de suelo: texturas, escala, reglas de mezcla | Resource | Textura nueva = `.tres` nuevo |
| `GroundSet` | Lista de hasta 4 capas + macro-variación | Resource | Un bioma comparte capas con otro |
| `TileLayerMap` | Baldosa original → capa | Resource | Es del mapa, no del bioma |
| `ground_pbr.gdshader` | Mezclar 4 capas PBR | Shader | Un efecto, un archivo; el clásico queda intacto |
| `ground_material.gd` | Volcar un `GroundSet` a los uniforms | RefCounted | `terrain.gd` no conoce capas |
| `ScatterType` / `ScatterSet` | Un tipo de planta o roca y sus reglas / lista por bioma | Resource | Otro pasto = otro `.tres` |
| `scatter_field.tscn` | Generar y mostrar `MultiMesh` por celdas | Packed `@tool` | Se quita y no hay vegetación |
| `SkyLook` + `biome_sky.gdshader` | Parámetros y dibujo del cielo | Resource + shader | El `Sky` es de Godot; no hay nodo propio |
| `LightLook` | Sol/luna, relleno, sombras | Resource | Noche = otro `.tres` |
| `AtmosphereLook` | Niebla, volumétrica, partículas | Resource | Se ajusta sin tocar la luz |
| `valley_fog` / `ambient_particles` / `light_shaft` / `local_light` | Una capa colocable cada una | Packed | Se apagan quitándolas; F6 solas |
| `SurfaceLook` | Parámetros de normal/AO/roughness de un modelo + reemplazo a mano | Resource | Lo leen el horneado y el material |
| `surface_library.gd` | Buscar el `SurfaceLook` de un modelo | Estático | Como `body_catalog`; sin autoload |
| `body_material.gd` | Un material por textura, con caché | Estático | Único enganche para cuerpos, cuadros y props |
| `bake_surface_maps.gd` / `bake_ground_splat.gd` | Generar mapas al caché | Herramienta | No corren en la partida |
| `LookApplier` / `QualityApplier` | Aplicar perfil / preset | RefCounted / nodo | Bioma y máquina son ejes distintos |
| `look_rig.tscn` | Contener capas y vista previa | Packed `@tool` | Una línea en el mapa; 018e la mueve entera |
| `portal_column.tscn` | Columna, chispas y luz del portal | Packed | Hija del altar; se quita |

## 6. Resource, nodo, `@export`; cómo se suma una textura

- **Resource de tipo:** todo lo de `data/look/`. Neutro documentado en cada campo. No se mutan en runtime (`duplicate()` del env).
- **Nodo:** capas del rig, `ScatterField`, `QualityApplier`, luces locales, `FogVolume`.
- **`@export` de instancia:** en `LookRig` (`preview_god`, `preview_quality`, botón de vista previa), en cada `valley_fog`, `light_shaft`, `local_light`, `scatter_field` (semilla, área, máscaras).
- **Globals de shader:** `look_sun_dir`, `look_sun_color`, `look_wind` (dirección, fuerza, tiempo), `look_camera_fade`.
- **`GroundLayer`:** `albedo`, `normal`, `orm`, `uv_scale_m`, `tint`, `height_contrast`, `slope_min/max`, `altitude_min/max`, `tile_weight`, `triplanar`, `stochastic`.
- **`ScatterType`:** `mesh`, `material`, `density_per_100m2`, `scale_min/max`, `max_height_m`, `ground_layers`, `slope_max`, `wind_strength`, `cast_shadow`, `draw_distance`, `min_quality`.
- **`SurfaceLook`:** `normal_strength`, `invert`, `blur_px`, `ao_strength`, `roughness`, `roughness_from_luma`, `specular`, `rim`, `normal_override`, `orm_override` (si están, el mapa generado no se usa: es el enganche para mapas a mano).
- **Sumar una textura de suelo:** copiar la carpeta a `assets/cc0/ground/<nombre>/`, anotar en `LICENSES.md`, crear un `GroundLayer` `.tres`, arrastrarlo al `GroundSet` del bioma. **Por pieza:** crear `data/look/surfaces/<modelo>.tres` con sus `*_override`.

## 7. Editor, cliente, dedicado

- **Editor:** `look_rig.gd` (`@tool`) aplica tema + perfil del `preview_god` sobre una copia del env y escucha `changed` de cada Resource; sin autoloads. Lo que viene del caché (splat, mapas generados, malla) no se guarda: `_validate_property` + `NOTIFICATION_EDITOR_PRE_SAVE`, patrón de `terrain.gd`. Los CC0 son recursos normales.
- **Cliente:** `MatchBiome` → `ThemeApplier.apply` → `LookApplier.apply`; `QualityApplier` en `_ready`.
- **Dedicado:** `match_biome.gd:83` ya corta con `MpKit.is_dedicated()`. `look_rig`, `scatter_field`, partículas y luces locales se liberan en headless. La dispersión no tiene colisión. Nada se replica.
- **Altura del terreno:** `ground_height()` usa su propio índice de triángulos (`terrain.gd:243`) y no cambia. La colisión hoy sale de `mesh.create_trimesh_shape()` (`terrain.gd:369`): si alguna vez se subdivide la malla visual, la colisión debe construirse desde los arrays originales (022c lo deja así).

## 8. Técnicas

| Tema | Recomendada (Godot 4.7) | Alternativa barata | ms est. | Riesgo |
|---|---|---|---|---|
| Escala de render | `Viewport.scaling_3d_mode = METALFX_SPATIAL`, `scaling_3d_scale` 0,67 + `screen_space_aa = FXAA` | `FSR 1.0` o bilineal | 0,3 | **No usar modos temporales (FSR 2.2, MetalFX Temporal, TAA) por defecto**: la animación cambia la malla entera por cuadro, sin vectores de movimiento → estelas. 022a lo confirma con captura |
| Sol y sombras | `PSSM 4 splits`, `directional_shadow_max_distance` 220, `blend_splits`, `light_angular_distance` 0,7, atlas 4096, `shadow_opacity` 0,85 | 2 splits, 2048 | 1,5 | Parpadeo: `shadow_bias`/`normal_bias` |
| Relleno | Ambiente desde el `Sky` + `fill_light.tscn` sin sombra ni especular | Solo ambiente | 0,1 | Aplanar: energía ≤ 0,3 |
| GI | **SSIL solo en alto.** SDFGI **descartado de nuevo**: 3–6 ms en M4, fugas de luz en terreno abierto, los cuerpos dinámicos no aportan; se deja una perilla experimental en alto | Cielo + relleno | 1,5–3 | Ruido |
| SSAO | `ssao_radius` 1,2, `ssao_intensity` 1,5–2 | Apagado en bajo | 0,8 | Halo |
| Tonemap | AgX, `tonemap_exposure`, `adjustment_saturation` ≤ 1,15 | — | 0 | Corregir F32 en FEATURES (dice ACES 0,85) |
| Suelo: máscara | `cache/look/tiles.png` (256×256, un id de baldosa por celda de 10 m) + `TileLayerMap` → splat RGBA horneado, desenfocado y roto con ruido | Solo pendiente y altura | 0 | Clasificar 256 baldosas: herramienta por color medio + corrección a mano |
| Suelo: mezcla | `ground_pbr.gdshader`: 4 capas, peso = splat × pendiente × altitud, mezcla por altura (canal en ORM) | 2 capas en bajo | 1,0–1,5 | 13 samplers: dentro del límite |
| Anti-repetición | Macro-variación (ruido de 200 m en albedo y roughness) + segunda escala lejana; estocástico por capa, solo en alto | Solo macro | 0,2 / 0,6 | Técnica: Deliot-Heitz 2019 o «texture repetition» de I. Quilez; licencia a verificar al portar |
| Pendientes | Triplanar solo en la capa roca | UV de mundo XZ | 0,3 | Estirado si se omite |
| Facetas de 10 m | **No subdividir.** Normal macro por píxel: mapa de normales del relieve (bicúbico, 1024²) horneado al caché. La silueta gruesa la tapan rocas y pasto | Normales suaves actuales | 0,1 | Si no alcanza: subdivisión ×2 solo visual con desvío ≤ 0,15 m |
| Lightmap original | Fuera del remaster (sus sombras horneadas chocan con el sol nuevo); opcional como tinte macro con peso ≤ 0,25 | — | 0 | — |
| Pasto (022e1) | **Reemplazado por RFC-022e §3–4:** briznas de geometría sin alfa en anillo de celdas recicladas con MultiMesh compartida, colocación y raleo en el shader, color del suelo en la raíz | `GPUParticles3D` en grilla | 1,4 | Ver RFC-022e §8 |
| Dispersión (022e2) | `MultiMeshInstance3D` por celda de 32 m, `visibility_range_end` + fundido; flores, matas y rocas; sin proyectar sombra | Menos densidad y radio | 0,6 | Sobredibujo |
| Viento | `scatter_wind.gdshader`: desplazamiento en `vertex()` por altura, global `look_wind` | Sin viento en bajo | 0,1 | — |
| Lectura | `max_height_m` ≤ 30 % de la unidad más chica; máscaras (las de 018d) en altar, manantiales y arranques; fundido cerca de la cámara; pasto menos saturado que las unidades; rim en unidades | Aplastado bajo unidades (textura de presencia): no recomendado ahora | 0 | Es el criterio de 022e |
| Normales de lo original | `Image.bump_map_to_normal_map()` sobre luminancia suavizada; AO = cavidad (luminancia − desenfoque); roughness desde luminancia | Solo AO | horneado | Las texturas traen luz pintada: `normal_strength` bajo y `invert` por modelo |
| Tangentes | **Las mallas no tienen tangentes** (`obj_mesh.gd:44-47`: solo vértice, UV, normal) y cada cuadro de animación se construye en runtime (`clip_pose_player.gd:163`). Recomendado: `body_pbr.gdshader` arma la base tangente con derivadas (`dFdx`/`dFdy` de posición y UV): no toca mallas ni cuadros | `SurfaceTool.generate_tangents()` en `build()`: tirón al construir cada cuadro | 0,3 | Costuras en UV espejadas: probar en `surface_gallery` |
| Material por cuadro | `obj_mesh.material()` crea material e `ImageTexture` en cada `build()` (`:130-132`; no vi caché: confirmar). `body_material.gd` los comparte por textura | — | ahorra memoria | Prerrequisito de 022g |
| Cielo | `Environment.sky` con `biome_sky.gdshader` (`shader_type sky`): gradiente, disco de sol/luna, 2 capas de nubes por ruido con borde iluminado hacia `LIGHT0_DIRECTION`, estrellas; ranura opcional de panorama HDRI CC0. `Sky.process_mode = INCREMENTAL`, radiancia 128 | HDRI fijo | 0,4 | Nubes animadas re-generan radiancia: excluirlas con `AT_CUBEMAP_PASS` |
| Cielo original | `sky.tscn` oculto por defecto; visible solo en modo clásico | Capa lejana | 0 | Con `fog_disabled` hace costura con la volumétrica |
| Volumétrica | `volumetric_fog_enabled`, densidad 0,01–0,03, `anisotropy` 0,6–0,8, `length` 200, reproyección temporal; proyecto `volumetric_fog/volume_size` 48 y `volume_depth` 48 en medio (64×96 en alto) | Niebla de altura + `light_shaft.tscn` de autor (bajo) | 1,5–2 / 3 | Tapar unidades: transmitancia a 150 m ≥ 75 % |
| Niebla local | `FogVolume` + `FogMaterial` en valles, altar y manantiales | — | incl. | — |
| Partículas ambientales | `GPUParticles3D` que sigue a la cámara, `local_coords = false`, caja de 40 m; una packed por tipo | `amount` por preset | 0,3 | No tapar el cursor: alfa y tamaño acotados |
| Glow | `glow_hdr_threshold` 1,0, `glow_bloom` 0, convención: emisivo ≥ 2,0 de energía, suelo y nubes < 1,0 | — | 0,4 | Sol y nubes brillando: es el criterio de 022h |
| Color | `adjustment_color_correction` = `GradientTexture1D` por dios | — | 0 | — |
| Luces locales | `OmniLight3D` sin sombra en altar, manantiales y hechizos; con sombra solo el altar y solo en alto | Solo emisivo + glow | 0,1 c/u | Muchos hechizos: tope de luces activas |
| Portal | `portal_column.tscn`: cilindro aditivo con ruido que sube, chispas `GPUParticles3D`, `OmniLight3D`, `FogVolume` chico | Subir energía del `portal_disc` | 0,3 | — |

### Medido en 022c (terreno PBR, mismo método, Persephone, sin cuerpos, ±1 ms)

Solo la capa de suelo encendida contra todo apagado (capa_2 del banco `--quick`); «todo» suma luz + suelo.

| Preset | Todo apagado | Suelo solo | Diferencia del suelo | Luz + suelo |
|---|---|---|---|---|
| Bajo (2 capas, sin triplanar) | 3,34 | 3,85 | +0,5 | 3,38 |
| Medio (4 capas, triplanar en roca, macro) | 4,94 | 6,71 | +1,8 | 7,73 |
| Alto (+ estocástico, 1,0 + MSAA 2×) | 9,38 | 16,03 | +6,7 | 22,22 |

- Medio queda en 7,7 ms de los 14 de techo (estimado para el suelo: +1,5; medido +1,8, dentro del margen). Alto cae en el piso de 30-45 fps por el estocástico (2 taps por capa) a resolución nativa.
- Las capas se muestrean solo donde su regla pesa (la regla no usa texturas): en el valle de Persephone solo hay pasto y parches de tierra. Sin esa poda el medio daba +2,2.
- **El mapa original cuenta otra historia que el nombre de la baldosa:** las baldosas claras (grises) son las lomas, y las verdes son el valle y todo lo de afuera; el anillo de baldosas intermedias bordea las claras. El `TileLayerMap` de High Noon manda el valle al pasto (slot 0), las intermedias a tierra (2) y las claras a sendero/tierra suelta (3). Las pendientes del mapa son suaves (lomas de 10-25 grados tras suavizar normales): la roca sale por parches en altura, no por pendiente.

## 9. Presets y orden de recorte

| | Bajo | Medio (por defecto) | Alto |
|---|---|---|---|
| Escala de render (medido 022a: GPU 3,8 / 4,9 / 8,9 ms sin capas) | 0,5 FSR 1 | 0,67 MetalFX espacial + FXAA | 1,0 + MSAA 2× |
| Sombras | 2 splits, 2048, 120 m | 4 splits, 4096, 220 m | ídem + filtro alto |
| Suelo | 2 capas, sin triplanar | 4 capas, macro | + estocástico |
| Pasto (RFC-022e §5) | 25 m, 12/m² | 45 m, 32/m² | 70 m, 48/m² + aplastado |
| Dispersión (022e2) | 25 %, 40 m, sin flores | 60 %, 80 m | 100 %, 130 m |
| Volumétrica / SSAO / SSIL | no / no / no | 48³ / sí / no | 64×64×96 / sí / sí |
| Partículas ambientales | 30 % | 100 % | 100 % |
| Mapas de lo original, glow, color, cielo | sí | sí | sí |
| Piso (Mac de desarrollo) | 60 fps | 60 fps (GPU ≤ 14 ms) | 30–45 fps |

**Orden de recorte si no se llega:** 1) SSIL; 2) volumen de la volumétrica y luego apagarla (quedan niebla de altura y haces de autor); 3) densidad y radio del pasto; 4) splits y distancia de sombra; 5) estocástico y triplanar; 6) SSAO; 7) escala de render hasta 0,6; 8) partículas. Glow, color y cielo no se recortan.

## 10. Los cinco biomas

| Dios | Suelo | Vegetación | Cielo | Luz | Niebla | Partículas | Color |
|---|---|---|---|---|---|---|---|
| **Persephone** (ref 2) | pasto, tierra, roca con musgo, sendero | pasto denso, flores, arbustos, rocas | nubes pesadas con claro dorado | sol bajo cálido | bruma de valle, haces | esporas, polen | verdes cálidos, sombras frías |
| **James** (ref 1) | arena compacta, tierra agrietada, grava, roca | matas secas ralas, piedras | nublado alto con claros | sol alto blanco, sombras marcadas | polvo bajo | polvo que cruza | ocres desaturados |
| **Pyro** (ref 4) | tierra quemada, ceniza, roca volcánica, lava emisiva | pasto chamuscado, focos de fuego | humo rojo, columnas | luz roja baja + luces de fuego | humo denso | brasas y ceniza | rojos y negros |
| **Charnel** (ref 3, propuesto) | pasto oscuro, barro, roca húmeda | pasto, matas, flores apagadas | noche nublada con luna | luna azul + relleno; altar dominante | niebla fría baja | luciérnagas | azules fríos |
| **Stratos** (a diseñar) | roca clara, pasto pálido, grava, nieve en altura | pasto corto, rocas grandes | cielo alto, nubes rápidas, sol nítido | sol frío y fuerte | bruma fina, sin valle | motas y viento | celestes y blancos |

Falta decidir: quién es la noche, el diseño de Stratos y cuánta lava emisiva lleva Pyro (pregunta 1).

## 11. Assets CC0 a conseguir

| Tipo | Fuente candidata | Cantidad y resolución | Peso est. |
|---|---|---|---|
| Suelo PBR (albedo JPG, normal PNG, ORM con altura) | ambientCG, Poly Haven (ambas CC0) | ~12 materiales a 2K | ~90 MB |
| Rocas | Poly Haven / Quaternius / Kenney (CC0; confirmar por archivo) | 6–8 mallas `.glb` de bajo polígono, 1K | ~20 MB |
| Pasto | ninguno: briznas generadas por código (RFC-022e) | — | 0 |
| Matas, flores (022e2) | atlas CC0 (ambientCG, Poly Haven) sobre tarjetas generadas por código | 3–4 atlas a 1K | ~8 MB |
| Cielo | ruidos propios; HDRI de Poly Haven opcional | 3 ruidos 512²; 0–5 HDRI a 2K | 1–30 MB |
| Partículas | sprites propios por shader o Kenney | 1 atlas | < 1 MB |

Total estimado: **120–150 MB**. La compresión de VRAM ocurre en `.godot/` (fuera de git). Cada archivo con fuente, autor, licencia y URL en `assets/cc0/LICENSES.md`; el reviewer lo comprueba.

## 12. Riesgos y fuera de alcance

- **Modelos de 2000 junto a un entorno detallado:** se integran con normales y AO generados, sombras suaves, SSAO, rim sutil, especular bajo y el mismo gradiente; el pasto bajo tapa la base. Si aun así desentonan, se baja el detalle del entorno, no se tocan las siluetas.
- **Malla del terreno gruesa:** normal macro por píxel; subdivisión visual como reserva.
- **Costo en M4** de volumétrica + pasto + sombras: son 5,5 de los 14 ms; hay orden de recorte.
- **Tamaño del repo:** ~150 MB sin LFS (pregunta 3).
- **Lectura:** topes de altura y de niebla como criterio de aceptación.
- **Dispersión sin colisión:** rocas dispersas no más altas que la rodilla; las grandes siguen siendo props del mapa.
- **Vista previa:** el rig no debe ensuciar la escena; el reviewer hace `git diff` tras guardar.
- **Glow y tonemap** recalibran todos los VFX existentes.
- **Fuera de alcance:** ciclo día/noche, clima, mallas o animaciones nuevas de personajes, mapas pintados a mano (queda el enganche), menú de opciones gráficas, otros mapas, agua, SSR, motion blur, DOF, grano, destellos.

## 13. Conflictos y orden con la cola

- **Antes de 022:** 020d y 020e (decidido). **018e** (mapa en su escena) conviene antes de 022c; si no, el rig es una sola línea y se mueve.
- **018d** (vegetación en MultiMesh) **precede a 022e2, no a 022e1** (RFC-022e §4, §9): 022e1 crea `VegetationClear` y 018d lo reutiliza en lugar de `widget_mask.gd`; 022e2 no reescribe `widget_field`, solo le da viento y material nuevos.
- **019c, 021b, 021c** antes de 022h/022l; si salen después, repiten su captura con el glow nuevo. Regla desde ya: lo emisivo se sube con la energía del `ParticleType`, nunca con un glow propio.
- **018c** en paralelo con todo. **019a** queda como modo clásico (no se pierde).
- **En paralelo entre sí:** 022d con 022c; 022g con 022e y 022f. En serie: a → b → c; h después de f; i al final del slice.

## 14. Orden de implementación

1. 022a: Resources vacíos, env a `.tres`, rig, presets y modos de escala, galería, banco, línea de base.
2. 022b: sol y sombras, relleno, AgX, SSAO, sobre el look actual.
3. 022c: herramienta de splat, `GroundLayer`, shader, 4 capas de Persephone.
4. 022d: `Sky` y ambiente desde el cielo (en paralelo con 3).
5. 022e1 pasto (RFC-022e §9) → 018d → 022e2 `ScatterType`, `scatter_field` → 022e3 opcional.
6. 022f: volumétrica, `FogVolume`, partículas; 022g en paralelo.
7. 022h: glow, gradiente, portal. 8. 022i: cierre del slice.
9. 022j → 022k → 022l.
Cada corte: developer → reviewer → playtester con ventana y capturas.

## 15. Cómo verifica un humano

- Abrir el mapa, seleccionar `%Look`, elegir `preview_god` y pulsar la vista previa: el editor muestra el bioma. Editar un `GroundLayer` o `ScatterType`: cambia en vivo. Guardar y `git status`: solo el `.tres` tocado.
- Borrar u ocultar un hijo de `%Look`: esa capa desaparece sin errores.
- F6 en `look_gallery`: recorrer biomas, cámaras y capas; comparar con `visual/refs/`. F6 en `look_bench`: leer los ms.
- Arrastrar un `GroundLayer` nuevo al `GroundSet`: aparece sin tocar código.
- `look = null` en un `GodTheme`: modo clásico. Dedicado: ningún nodo de `look/`.

## 16. Preguntas abiertas

1. **¿Quién es la noche y cómo es el quinto bioma?** (a) **Charnel de noche y Stratos de altura fría y ventosa — recomendado**; (b) Stratos de noche estrellada y Charnel pantano gris de día; (c) otra idea del usuario.
2. **Cielo:** (a) **shader procedural con ranura opcional de HDRI — recomendado** (animado, liviano, editable); (b) HDRI CC0 por bioma (más realista, estático, +30 MB); (c) capas nuevas sobre el cilindro original (no alimenta la niebla).
3. **Repo:** (a) **suelo a 2K y el resto a 1K, sin LFS, tope 150 MB — recomendado**; (b) todo a 1K (~40 MB, suelo más blando de cerca); (c) 2K–4K con Git LFS.
4. **Mallas CC0 de rocas:** (a) **usar `.glb` de bajo polígono ya listos — recomendado**; (b) rocas escaneadas de Poly Haven reducidas con Blender (requiere el MCP de Blender y tu OK).
5. **Modo clásico:** (a) **se conserva solo para comparar en la galería — recomendado**; (b) también como opción del jugador; (c) se elimina al cerrar 022i.

## 17. Decisiones del usuario (2026-10-14)

Mandan sobre las secciones anteriores; donde el texto de arriba diga otra cosa, vale esto.
1. **Biomas:** Charnel = noche con luna (ref 3). Stratos = altura fría y ventosa, de día (fila de §10).
2. **Cielo: capas sobre el cielo original** (no la recomendación). El cilindro, el anillo y las nubes de `sky.tscn` siguen siendo el cielo visible en todos los modos; 022d les suma capas nuevas encima (nubes con volumen y borde iluminado, disco de sol/luna, haces) como piezas apagables. Como ese cielo no alimenta ambiente, reflejos ni niebla, 022d define una fuente aparte para eso (por ejemplo un `Sky` de color o gradiente por bioma que no se ve, o ambiente por color) y resuelve la costura con la volumétrica (`fog_disabled` del cilindro vs. niebla). Se retiran de §8 y §5 el `biome_sky.gdshader` como fondo visible y el «`sky.tscn` oculto por defecto».
3. **Texturas: 2K–4K con Git LFS** (no la recomendación). Suelo hasta 4K, resto 2K; los binarios de `assets/cc0/` (imágenes, `.glb`, `.exr`/`.hdr`) van por LFS con su `.gitattributes`. Requisito antes de 022c: instalar `git-lfs` en la máquina (hoy no está) y correr `git lfs install` con el OK del usuario. El tope de 150 MB de §11 deja de aplicar; el reviewer controla igual resolución y compresión de cada archivo.
4. **Rocas:** `.glb` CC0 de bajo polígono ya listos (Poly Haven / Quaternius / Kenney), licencia confirmada por archivo.
5. **Modo clásico:** se conserva solo para comparar en la galería (decisión del orquestador con la recomendación del plan; el usuario puede cambiarla).
6. **Cielo (2026-10-14, reemplaza el punto 2 en lo visible):** el usuario vio nubes nuevas súper saturadas y las rechazó: «no está cerca ni del original ni de la referencia… quiero que se conserve la estética del original». El cielo visible tiene que verse como en el juego original (y no cambiar con el tonemap ni la niebla); 022d no suma nubes; solo la fuente de ambiente/reflejos y, si encaja, un disco de sol sutil.
7. **Cielo nuevo + legacy (2026-10-14, a continuación del 6):** el usuario pidió: «puedes usar godot shaders o shadertoy para ver cómo construir un cielo similar, con ese impacto visual. Pero conserva también el modo legacy». 022d entrega el cielo original fiel como modo legacy seleccionable y un cielo por shader que reproduce la estética del original. Código externo solo con licencia compatible (CC0/MIT), nunca CC BY-NC-SA copiado.
8. **Rendimiento del cielo legacy (2026-10-14):** el usuario: «no te preocupes por rendimiento en el cielo legacy». El costo del modo Legacy no es criterio de 022d; el Swirl, si alguna vez se activa, sí se mide.
9. **Pendientes de cielo para otro corte (2026-10-14):** (a) el cielo de Charnel es el original (`char.LAND` SKY_); al usuario no le gusta y quiere iterarlo en un corte aparte (un primer intento de suavizarlo con suavidad/contraste/saturación no lo convenció y se revirtió); (b) el cielo de Pyro en el original es un video animado (`ENVI.sky_` = `data/anims/pyro_a.smk`, 64×64, 16 fps), que sacengine no implementa (lee SKY_ fijo): se puede pasar a cuadros con ffmpeg al caché.
