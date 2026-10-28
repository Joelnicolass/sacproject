# 055b: look (cielo, luz, Environment) con un solo dueño. Plan aprobado 2026-10-23

Aprobado por el usuario con: bloom/glow agregado y P1–P7 según la recomendación. Fuente: informe del tech lead; referencia visual en `rfcs/research/055R-visual-reference.md`.

## Hoy (medido)
- `Environment` con 3 escritores que se pisan (`ThemeApplier`, `SkyLayer`, `LightLayer`), cada uno con copia y restauración de un `Dictionary`.
- `Sun`, nodo `Sky` y material del terreno con 2 o 3 escritores cada uno.
- Dos cadenas de datos (`GodType.theme_path` → `GodTheme` → `GodEnvi` generado por `import_themes.py`; y `GodType.look_path` → `LookProfile`).
- `LightLook` pisa sol y ambiente del ENVI en los 5 dioses: del ENVI solo sobreviven color de fondo y niebla.
- El patch del usuario (aurora en `env_base.tres`) no se veía porque `ThemeApplier` repone `BG_COLOR`.

## Árbol
```
map.tscn ×7                         [~] se borran Sky, Environment y Sun sueltos
Look : LookRig                      look_rig.gd/.tscn [~] ≤120: reparte profile y quality a las capas
├── Layers                          (índices 0..5 iguales; ActorLights es el 6)
│   ├── Sun : SunLayer              light/sun_layer.gd [+] ~90. ÚNICO escritor de Sun y Fill
│   │   ├── Sun : DirectionalLight3D  %Sun (movido desde los mapas)
│   │   └── Fill
│   ├── Ground : TerrainLayer       [~] ÚNICO escritor del material del terreno (+ ground_classic)
│   ├── Environment : EnvironmentLayer  sky/environment_layer.gd [+] ~120. ÚNICO escritor del Environment y fx_fog_*
│   │   └── WorldEnvironment        %WorldEnvironment, environment = data/look/env_base.tres
│   ├── Grass / FxLight / Flora     (igual)
│   └── ActorLights : ActorLightBudget  lights/actor_light_budget.gd [+] ~90
├── TimeOfDay : Node                [+] slot vacío (RFC-058)
├── Weather : Node                  [+] slot vacío (RFC-058)
└── Quality : QualityApplier
unit.tscn, wizard_body.tscn, fireball/swarm/rock projectiles, wrath_strike
└── Light : ActorLight              scenes/look/lights/actor_light.tscn [+] (= light_unit.tscn movido, mismos valores) + actor_light.gd ~60
```
Capas renombradas: `Light`→`Sun`, `Sky`→`Environment` (P2; arreglar `debug/look/grass_lab.gd:55`).

## Datos
| Resource | Campos |
|---|---|
| `LookProfile` [~] | `display_name`, `sky: SkyLook`, `light: LightLook`, `ground_classic: ShaderMaterial`, `ground`, `grass`, `grade: GradientTexture1D`, **`glow: GlowLook`** (nuevo, ver abajo) |
| `SkyLook` [~] | `material: ShaderMaterial` (de `sacrifice_sky.gdshader`: texturas, `background_color`, `energy`, `rotation_period_s`, `cloud_period_s`, `cloud_alpha`, degradé de ambiente, `aurora_*`) · Ambient: `ambient_sky_contribution`, `radiance_size` · Fog: `fog_enabled`, `fog_color` (ya mezclado), `fog_begin_m`, `fog_end_m`, `fog_density`, `fog_aerial_perspective`, `haze_tint`, `volumetric_density`, `volumetric_length_m` |
| `LightLook` [~] | sol, sombras, relleno, ambiente, exposición, SSAO/SSIL (pierde Fog). `SunLayer` y `EnvironmentLayer` leen; cada objeto tiene un solo escritor |
| **`GlowLook`** [+] | `enabled`, `intensity`, `strength`, `bloom`, `hdr_threshold`, `hdr_scale`, `blend_mode`, `levels` (agregado por el usuario: el original es muy luminoso). Lo escribe `EnvironmentLayer` |
| `GodType` [~] | `look: LookProfile` tipado; se borran `theme_path`, `look_path`, `load_theme()`, `load_look()` |
| `LookQuality` [~] | `actor_max_lights` (low 4 · medium 12 · high 24); el glow se apaga en low |

Shaders: `scenes/look/sky/sacrifice_sky.gdshader` [+] (shader_type sky; pasada principal con fondo + bandas + nubes + aurora + discos; `AT_CUBEMAP_PASS` solo el degradé), includes `sky_bands`, `sky_clouds`, `sky_discs`, `aurora.gdshaderinc` (funciones del `sky_aurora.gdshader` del usuario, con su crédito). `sky_aurora.gdshader` queda como cielo suelto e incluye el include.

## Quién habla con quién
- Abajo: `MatchBiome._apply()` → `map.look.apply_profile(god.look)` → cada `LookLayer.apply_look(profile, rig)` / `apply_quality(preset)`. Cada capa recalcula su objeto completo desde (profile, quality, visible): derivado e idempotente, sin guardar ni restaurar.
- Arriba: `LookRig.profile_applied`, `MatchBiome.applied(god)` (igual).
- Luces: `ActorLight` entra a `ActorLightBudget.GROUP`. Cada 0,2 s el budget ordena por `priority / max(dist_cámara, min_m)`, prende las mejores N con histéresis ×1,25 y llama `set_budget_on(bool)`. `ActorLight` es único dueño de su `visible` (`lit and budget_on`). Sin budget (F6, editor) queda prendida. En headless `queue_free()`. `CorpseLook` recibe socket `light` y la apaga con el fade del cadáver (P5). `distance_fade` 60 m + 20 m, sin sombras, `specular` 0,35.
- `TimeOfDay`/`Weather` nunca escriben el `Environment`: mañana son sockets de los dueños.

## Se borra
`scenes/look/theme/{god_envi,god_theme,theme_applier}.gd`, `scenes/look/look_applier.gd`, `scenes/look/sky/{sky.gd,sky.tscn,sky_layer.*,sky_piece.gd,sky_swirl.*,sky_discs.gd/.tscn,sky_band.gdshader,sky_view.gdshaderinc}` (P1: SWIRL se borra), `scenes/look/light/light_layer.*`, `data/themes/*.tres`, `assets/original/themes/*/envi.tres`, `data/look/sky/*_swirl.tres`, `noise_clouds.tres`, fixtures/flows de SWIRL, `debug/look/sky_probe.gd` + `sky_motion.tscn`. `import_themes.py` deja de escribir `envi.tres`. `match_biome.gd`: `pick_god` → `scenes/match/biome_rules.gd` estático (misma secuencia RNG), `print` → `DebugLog`.

## Decisiones (aprobadas)
P1 borrar SWIRL · P2 renombrar capas · P3 aurora solo en Charnel, `aurora_strength` 0,35 · P4 `GodType.look` tipado · P5 la luz se apaga con el cadáver · P6 el canal `biome` de MpKit no se mueve · P7 `light_unit.tscn` → `scenes/look/lights/actor_light.tscn`.

## Sub-cortes
| Día | Sub-corte | Entrega |
|---|---|---|
| 1 | 055b-1 | shader + includes + aurora include; `debug/look/sky_compare.tscn` (cielo viejo vs nuevo en dos SubViewport, cámara fija, tiempo congelado, 5 dioses; criterio ΔE medio < 2 y nada > 6); capturas «antes» de `biome_gallery`. No toca el juego |
| 2 | 055b-2a | `environment_layer.gd`, `sun_layer.gd`, rig con WorldEnvironment/Sun/TimeOfDay/Weather; `LookProfile`/`SkyLook`/`LightLook`/`GlowLook`; migrar 5 dioses |
| 3 | 055b-2b | `GodType.look`, `biome_rules.gd`, `match_biome.gd`, 7 `map.tscn`, `TerrainLayer`, borrar; lint y baseline; capturas «después»; humo de `quick` (no debe cambiar) |
| 4 | 055b-3a | `actor_light`, budget, `actor_max_lights`, `Light` en unit/wizard/4 proyectiles, socket en `CorpseLook`; `debug/look/actor_lights_lab.tscn` (200 luces, medium ≥ 60 fps) |
| 5 | 055b-3b | glow por dios (más fuerte en hechizos y manantiales: emisión de FX que supere `hdr_threshold`); Persephone más verde (valores abajo); review; playtest con ventana |

Persephone: `persephone_light.tres` ambient (0.70, 0.86, 0.72), sun (1, 0.96, 0.85), fill (0.78, 0.90, 0.80), saturation 1.12; `persephone_sky.tres` `ground_color` (0.16, 0.26, 0.10), `ambient_sky_contribution` 0.6; `persephone.tres` `grade` negro → (0.47, 0.56, 0.44) → blanco. Criterio: en `biome_gallery`, G/(R+G+B) del suelo sube ≥ 0,03 y el cielo queda con ΔE < 2.

Lint esperado: C1a 113→109, C7 70→69, C9 372→370, C13 47→40, C14 230→227. Todo es presentación: `quick` no cambia.

## Resultado de 055b-1 (medido con ventana por el orquestador, 2026-10-23)
El shader compila sin errores. Diferencia de color contra el cielo viejo (CIE76, viewports 320×180, 3 poses por dios):

| Dios | ΔE medio | p99 | máx |
|---|---|---|---|
| persephone | 0.65 | 10.35 | 17.85 |
| pyro | 0.51 | 7.22 | 12.60 |
| james | 0.40 | 6.04 | 9.25 |
| stratos | 0.17 | 4.34 | 7.76 |
| charnel | 0.53 | 5.92 | 13.78 |

Mirando hacia arriba (35°) es casi idéntico (máx < 2,6). Los picos están en las poses de horizonte (5° y −15°): el borde de las bandas y el cono inferior. Antes de que 055b-2 cambie el juego, cerrar ese residuo (mipmaps a 320×180, geometría del cono) hasta p99 < 6 en el horizonte, o medir a mayor resolución para descartar el muestreo.

## Corrección del horizonte (055b-2, paso 0)
Causa: el cielo viejo dibuja las bandas como una malla de 64 caras planas con dos triángulos por cara y la `u` solo en las esquinas; `sacrifice_sky` calculaba la `u` sobre un cono perfecto. En el cilindro las dos cosas coinciden; en el cono cada cara es un trapecio y los dos triángulos curvan la textura (verificado numéricamente contra la malla: hasta 0,0068 de `u`, unos 7 texels de una textura de 1024, medio píxel a 320×180, a lo largo del cono del horizonte). Ahora `sky_bands.gdshaderinc` lanza el rayo contra las caras planas y reproduce los mismos triángulos (error contra la malla 1e-15). Además el mip de `u` se deriva sin plegar el espejo (antes una columna de píxeles en cada pliegue pedía un mip demasiado fino). `sky_compare` acepta `-- --sky-compare-size=1280x720` y sus `SubViewportContainer` ya no estiran los viewports. Hay que volver a medir con ventana.
