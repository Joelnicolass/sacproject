---

# RFC-029 — VFX modernos, luces y clima (día/noche, nubosidad, lluvia, tormenta)

Estado: plan del tech lead (Opus), 2026-10-16. Sin código. Arquitectura estándar. Online = dedicado; todo lo de este RFC es presentación y corre solo en procesos con ventana. Autoridad: PRD > FEATURES > RULES > VISUAL > RFC-022/022e/027 > este RFC.

Features: **F95–F110** (F92–F94 quedan para RFC-028). Cada corte entra en el flujo de 4 pasos: plan (este), código, review y playtest con ventana y capturas. Lo que cambia el look visible se le muestra al usuario con capturas antes de cerrar.

## 0. Pedido y restricciones

Pedido del usuario (2026-10-16): «encola la corrección de los VFX, hay que modernizarlos y hacerlos un poco más estéticos. Deberíamos agregar también luces al escenario. Creo que un buen agregado es que los poderes y VFX emitan luces y que haya un ciclo de día/noche y de variabilidad en la nubosidad. En el original también llovía cada tanto, había rayos, etc. Todo este sistema de clima sería bueno agregarlo».

Restricciones que rigen:
- **(a) Manda el look del original.** Una paleta por mapa (VISUAL.md, `visual/refs/original/`).
- **(b) Se conserva el cielo original.** Ni nubes nuevas ni saturación. Día/noche y nubosidad se construyen modulando el Legacy (oscurecer, teñir, mezclar, animar), nunca reemplazándolo.
- **(c) Determinismo (RULES «IA», `match_seed`).** El clima no toca la simulación. Corre en clientes, nunca en el dedicado. Se sincroniza por semilla y tiempo del servidor, sin RPC por cuadro.
- **(d) Rendimiento.** Cada efecto tiene presupuesto por preset de `LookQuality` y se puede apagar. RFC-027 sigue en curso.

## 1. Investigación (V = verificado, I = inferido)

### 1.1 El original y sacengine
- **V. ENVI no tiene clima, hora ni ciclo.** `sacengine/source/envi.d:13-66` trae dirección del sol (41-43), colores, niebla lineal (58-65) y las texturas `sky_/skyt/skyb/sun_/undr`. Es estático por mapa.
- **V. sacengine fija la luz al cargar.** `renderer.d:1136-1145` fija `sunStrength` por dios (Persephone 6, Pyro 2, James 14, Stratos 12, Charnel 4). `renderer.d:1157` toma el fondo de ENVI y `renderer.d:1194-1199`, la niebla. Nada de eso cambia en la partida.
- **V. El cielo solo gira y desplaza nubes.** `renderer.d:1203-1237`: rotación `2π/512·t` (1207), nubes `frame%(64·60)` (1206) y sol `sun_` a 25× de energía (1227). `updateFPS = 60` (`state.d:15`). **Conclusión V+I: el original no tiene día/noche.**
- **V. El clima es una acción de trigger.** `trig.d:1306-1319` define `TrigWeather {rain=163, snow, hail, cinders, ash, insects=168}` y `TrigSetWeatherAction(weather, switch)`; `setWeather=169` está en `trig.d:2739`. sacengine la parsea (`2585-2589`, `2882`) pero nadie la consume: el `grep` fuera de `trig.d` da 0. **sacengine no implementa clima.**
- **V (escaneo crudo).** Recorrí los TRIG de las 32 `.scp` de escaramuza y de toda la campaña buscando el par `169, 163..168`:
  - Lluvia en `ch09`, `in05`, `in08`, `ja09`, `pe05`, `pe09` y `pr01`.
  - Insectos en `ja04`.
  - **Ningún mapa de escaramuza, High Noon incluido.** Script en el scratchpad de esta sesión, no en el repo.
- **V. El renderer del original solo dibuja lluvia y nieve.** `game3d.dll` exporta las clases `ATMOS`, `RAIN` y `SNOW` (`InitDrop`, `Draw`, `Run`); no hay clase para granizo, brasas, ceniza ni insectos (I: no tienen dibujo propio o usan otra vía). `Sacrifice.exe` tiene el evento de red `Weather` y `RainDropStart`/`RainDropRun`: el clima se replica entre peers.
- **I. La lluvia es solo visual.** Vive en la dll de render y no tiene ganchos de juego en sacengine.
- **V. No hay rayos de clima.** No están en `TrigWeather`. `LIGHTNING`/`LIGHTNINGPRIM` de `game3d.dll` son la primitiva de los hechizos. Los «rayos» que recuerda el usuario son, con toda probabilidad, Lightning, Chain Lightning y Call Lightning de Stratos (I).
- **V. Rayo del hechizo en sacengine.** `state.d:2815-2836`: `LightningBolt` de 10 segmentos con desplazamiento aleatorio de caja 2,5 que cambia de forma cada 6 ticks; `Lightning.totalFrames=64` (≈ 1,07 s) y `travelDelay=12` (0,2 s). La forma usa `state.uniform`, el RNG de la simulación: el port debe usar un RNG propio. Se dibuja en `renderer.d:1861-1905`.
- **V/I. Sin luces dinámicas.** No hay `PointLight` ni luces dinámicas en `renderer.d` ni en `dagonBackend.d` (V). El original usa lightmap horneado (`LAND::GenerateLightMap` en `game3d.dll`; I: sin luces dinámicas de hechizos). Las luces de VFX son un agregado del remaster, que VISUAL.md permite («Bloom fuerte… hechizos, manantiales»; RFC-022 §8 «Luces locales»).
- **V. High Noon no tiene antorchas.** Estructuras del mapa (`cache/high_noon_ntts.json`): `jcc*`, `bld*`, `bon*`, `jeg*`, `jwg1`, `jhut`, 5 `jfnt` (manantiales) y 2 `jaal` (altares). Las fuentes de luz posibles son altares, manantiales, Manaliths y almas.
- **V. Referencia de lluvia del original.** `visual/refs/original/orig_2_lluvia_pradera.webp` muestra trazos finos verticales y translúcidos, un cielo más oscuro y gris con la misma pintura, y efectos (fuego, columnas verdes) que brillan más por contraste.

### 1.2 Estado del port
- **V. Partículas.** `FxBus` (autoload, `scenes/fx/fx_bus.gd:9-20`) instancia un `CPUParticles3D` nuevo en cada `play`, sin pool.
  - 29 `ParticleType` en `data/fx/`. Ráfagas grandes: `wrath_explosion2` 400; `blood`, `wrath_explosion1` y `wrath_particle` 200.
  - Shader `sprite_particle.gdshaderinc`: `unshaded`, cuadro de atlas con `floor` (salta de cuadro), sin fundido contra el suelo.
  - `sprite_particle_add.gdshader` y `_mix.gdshader` llevan `fog_disabled`. La sangre y la tierra (mix) no reciben ni luz ni niebla.
- **V. Estelas atadas al render.** `rock_projectile.gd:104-111` y `wrath_strike.gd:65-69` (y swarm, fireball, ranged) emiten la estela cada `TRAIL_EVERY` cuadros de render, así que depende de los fps. Cada estela es un nodo nuevo. Los proyectiles se arman en código, sin `.tscn`.
- **V. Lightning sin rayo.** `caster.gd:551-557` (Lightning) dibuja `wrath_explosion1` como placeholder.
- **V. Determinismo en riesgo.** `scenes/fx/portal_disc.gd:114` usa el `randf()` global. `MatchSeed.begin` siembra el RNG global (`match_seed.gd`, `seed(wanted)`), así que un efecto con ventana en solo puede mover el `digest`.
- **V. Cero luces locales.** No hay `OmniLight3D` ni `SpotLight3D` en `scenes/` ni en `debug/`.
- **V. Capas de look.** `LookRig` (`look_rig.gd`) con capas `LookLayer` (Light, Ground, Sky, Grass) que se liberan en headless o dedicado. `LookProfile` tiene sockets `atmosphere` y `grade` vacíos (022f, 022h).
  - `LightLayer` escribe sol y env una vez por perfil (`light_layer.gd`).
  - `SkyLayer` deja el Legacy intacto y da una fuente invisible (`ProceduralSkyMaterial`).
  - El Legacy (`scenes/world/sky.gd`, `sky_band.gdshader`, `sky_clouds.gdshader`) no tiene tinte ni cobertura: solo `energy`, `max_alpha` y `offset`.
- **V. Presets.** `LookQuality` tiene grupos de escala, AA, sombras, SSAO/SSIL, suelo y pasto; no hay nada de VFX ni de clima. El proyecto no tiene `shader_globals`.
- **V. Red.** `MatchBiome` manda `god` por `MpKit.push_custom_to` en `client_world_ready` (patrón a reusar). No hay reloj de partida replicado.
- **V. Sin audio.** No hay `AudioStreamPlayer` en `scenes/` y el PRD deja el audio original fuera.

## 2. Contradicciones y cuál gana

1. **RFC-022 §12 deja fuera día/noche y clima.** Gana el pedido del usuario del 2026-10-16: este RFC los incorpora. Nada en PRD, FEATURES, RULES ni VISUAL lo prohíbe.
2. **El original no tiene día/noche ni clima en High Noon.** Frente al «el look del original manda», propongo esto (pregunta 1):
   - El ciclo arranca en la luz aprobada de cada bioma.
   - La noche es la misma paleta multiplicada, nunca otra.
   - El ciclo se apaga con un `.tres`.
3. **Rayos de clima no existen en el original.** Gana el pedido: se agregan solo visuales, lejos de las unidades, sin daño. El hechizo Lightning sí es del original y se porta fiel (029d).
4. **«Variabilidad en la nubosidad» contra «nada de nubes nuevas».** Versión fiel: cobertura por umbral de alfa de la **misma** textura, velocidad y oscurecido con tope. La segunda capa de nubes queda como opción (pregunta 2).
5. **Trueno contra «audio original fuera» y sin sistema de audio.** Solo la señal `struck(at, thunder_delay_s)`; el sonido va a un RFC de audio.
6. **«Arte nuevo» fuera del primer corte (PRD).** Calcos, gotas y ceniza salen de texturas generadas en código (`GradientTexture2D`, `NoiseTexture2D`). No entra arte externo.
7. **Solape con RFC-022:**
   - **022l** («VFX restantes») queda **reemplazado** por 029a–g.
   - **022k** usa `StageLight` (029f) para las luces locales de Charnel.
   - **022h** no agrega su propia `OmniLight3D` al portal: usa la del altar de 029f. Su convención de glow (emisivo ≥ 2,0; suelo y nubes < 1,0; RFC-022 §8) es prerrequisito de 029g.
   - **022f:** si llega, su densidad de niebla se multiplica por el `AtmosState` igual que la de `LightLook`.
8. **Choque de archivos con RFC-027.** 027f y 027g tocan `look_quality.gd` y `quality_*.tres`. Grupos separados, y nunca dos developers a la vez en esos archivos.

## 3. Objetivo (criterios globales)

- **VFX más legibles y actuales sin cambiar su identidad.** Mismos atlas, colores y tiempos de sacengine. Se suman bordes suaves contra el suelo, cuadros interpolados, HDR que florece dentro de la paleta, luz que emite, marca en el suelo y distorsión sutil solo en fuego y explosión.
- **Luces de VFX con tope por preset y sin sombras, en pool.** Luces del escenario en altares, manantiales y Manaliths, que pesan más de noche.
- **Día/noche y clima sobre el Legacy.** En estado neutro, la captura es idéntica a la de antes del corte (diff ≤ 1 %, y 0 % en el cielo).
- **Clima determinista por semilla y tiempo.** Dos clientes ven el mismo estado (±0,5 s). El dedicado no construye nada. El `digest` de `ai_match ai_vs_trivial --seed=1 --minutes=3` sigue igual en todos los cortes.
- **Presupuesto medio de RFC-029** ≤ +1,0 ms de GPU con cielo despejado y ≤ +2,0 ms en tormenta (método 022a, ±1 ms). Cada efecto se apaga desde el preset.

## 4. Diseño

### 4.1 Flujo de la atmósfera (presentación)

```
servidor/solo: AtmosSync ──(una vez por peer + cada 120 s: {seed, t})──► AtmosSync del cliente
                                                                │
                                         LookRig/%Clock (AtmosClock): t local, semilla
                                                                │ sample() una vez por cuadro
                     AtmosState = DayCycle(fase) ⊗ WeatherSchedule(semilla, t) (función pura)
       ┌─────────────┬──────────────┬───────────────┬──────────────┬────────────┬──────────────┐
  LightLayer     SkyLayer      StageLight      Precipitation   StormLayer    GrassLayer
  sol/luna,     Legacy: tinte, ×noche          lluvia, nieve,  rayos lejanos, viento ×
  ambiente,     cobertura,                     ceniza; mojado  destello,
  niebla vol.   velocidad; fondo                (global)       señal struck
                y niebla de color
```

- **Un solo dueño por propiedad.** `LightLayer` sigue siendo el único que escribe el sol y el ambiente; ahora multiplica `LightLook` por el `AtmosState`. `SkyLayer` es el único que toca el Legacy, `background_color`, `fog_light_color` y las distancias de niebla.
- **`WeatherSchedule` es una función pura** de `(perfil, semilla, t)`: los segmentos y los rayos salen de `hash([semilla, índice])`. No guarda RNG ni llama a `randf()`. Un cliente tardío calcula lo mismo.
- **`AtmosSync` vive en el mundo, junto a `MatchBiome`,** porque el rig se libera en el dedicado.
  - En la autoridad: `seed = MatchSeed.derive(["atmos"])`, que es un hash y no consume RNG. Si no hay partida activa, usa `RandomNumberGenerator.new().randomize()`, nunca el global. `t` es el tiempo desde el `_ready` del mundo.
  - Manda `{seed, t}` por el canal custom `atmos` en `client_world_ready` y cada `resync_s` (120 s).
  - En el dedicado: calcula, manda e imprime `atmos semilla <n>`, y nada más.
- **Regla nueva para este RFC:** ningún archivo de `scenes/fx/`, `scenes/world/look/` ni `scenes/world/atmos_sync.gd` llama a `randf`, `randi`, `seed` ni `randomize` globales. El reviewer lo comprueba con `grep` en cada corte.

### 4.2 Modernizar los VFX sin perder identidad

| Técnica | Qué cambia | Referencia | Preset |
|---|---|---|---|
| Fundido contra el suelo | El sprite se desvanece cerca de la profundidad de la escena (`hint_depth_texture`, como `proximity_fade` de `BaseMaterial3D`); se acaba el corte recto contra el suelo | Godot docs, BaseMaterial3D | bajo no |
| Interpolación de cuadros | Mezcla del cuadro n y n+1 del atlas; mismo `frame_s` | flipbook blending | bajo no |
| HDR dentro de la paleta | `energy` ≥ 2 florece y el suelo no; rampa de color opcional por vida (`GradientTexture1D`), p. ej. fuego que se enfría | RFC-022 §8 (glow) | todos |
| Sangre, tierra y polvo con luz y niebla | `lit` en `ParticleType`: el mix pasa a sombreado y con niebla, deja de verse pegado lejos | — | todos |
| Luz que emite | `FxLightSpec` en el tipo: `OmniLight3D` sin sombra, con ataque y caída, desde un pool | — | 0 / 8 / 16 |
| Marca en el suelo | `Decal` de quemado o cráter que se desvanece en 6–10 s, textura generada | Godot `Decal` | 0 / 12 / 24 |
| Distorsión | Anillo de refracción con `hint_screen_texture` solo en explosiones y fuego, ≤ 2 a la vez | godotshaders «shockwave» (solo CC0/MIT; anotar fuente) | bajo no |
| Rayo fiel | Cinta de 10 segmentos con el atlas `ltn2`, cambia de forma cada 0,1 s, dura ≈ 1,07 s; se reusa en la tormenta | sacengine `state.d:2815-2836` | todos |
| Estelas por tiempo y pool | Nodo `FxTrail` hijo del proyectil; `FxBus` reusa emisores | — | todos |

Queda igual: atlas y colores originales, siluetas de los efectos, tiempos de sacengine y el «aditivo brillante» del original. No entran (VISUAL «No»): aberración cromática, destellos de lente, motion blur ni grano.

### 4.3 Presupuesto por preset (nuevo grupo «VFX y clima (029)» en `LookQuality`)

| Campo | Bajo | Medio | Alto |
|---|---|---|---|
| `fx_soft_particles` / `fx_frame_blend` | no / no | sí / sí | sí / sí |
| `fx_max_lights` | 0 | 8 | 16 |
| `fx_max_decals` | 0 | 12 | 24 |
| `fx_distortion` | no | sí (≤ 2) | sí (≤ 4) |
| `stage_lights` / `stage_light_fade_m` / sombra del altar | no / – / no | sí / 150 / no | sí / 220 / sí |
| `precip_density_scale` / colisión / salpicadura | 0,35 / no / no | 1,0 / no / no | 1,5 / sí / sí |
| `sky_source_update_hz` (radiancia de la fuente invisible) | 0,5 | 1 | 2 |
| GPU estimada sobre la base (despejado / tormenta) | +0,1 / +0,4 | +1,0 / +2,0 | +1,6 / +3,0 |

**Orden de recorte:** 1) distorsión; 2) colisión y salpicadura de la lluvia; 3) densidad de la lluvia; 4) luces de VFX de 8 a 4; 5) calcos; 6) fundido contra el suelo; 7) luces del escenario. El ciclo de luz y la modulación del cielo no se recortan: su costo GPU es casi cero.

## 5. Resource, nodo, `@export`

- **Resources (plantillas; no se mutan en runtime):**
  - De efectos: `ParticleType` (M), `FxLightSpec`, `FxDecalSpec`, `FxDistortionSpec`, `BeamType`, `StageLightLook`.
  - De atmósfera: `DayCycle`, `WeatherKind`, `WeatherProfile`, `PrecipitationType`.
  - Modificados: `LookQuality` (M) y `LookProfile` (M: sockets `cycle` y `weather`).
  - Un bioma es un `.tres` por pieza. Otro clima es otro `WeatherKind`.
- **Nodos:**
  - Capas del rig: `FxLightLayer`, `PrecipitationLayer`, `StormLayer`.
  - Del rig: `AtmosClock` (`%Clock` del rig).
  - Escenas empaquetadas: `StageLight`, `BeamFx` (con `LightningBolt`), `FxDecal`, `FxDistortion`.
  - Componentes y mundo: `FxTrail` (hijo del proyectil) y `AtmosSync` (en el mundo).
- **Puro:** `AtmosState` (valor; `sample()` estático) y `WeatherSchedule` (estático).
- **`@export` de instancia:**
  - `StageLight.look` y `pulse_source` (el `SpriteEmitter` del manantial).
  - `AtmosClock.time_scale`, `frozen` y `phase_override`.
  - `LookRig.clock`.
  - `AtmosSync.look_rig`, `resync_s` y `channel`.
  - `PrecipitationLayer.box_m`.
  - `StormLayer.min_strike_m`, `max_strike_m` y `flash_scale` (accesibilidad; ver §8).
  - En `look_gallery`: `cycle_override`, `weather_override` y `freeze_clock`, como el `sky_override` actual.
- **Globals de shader (`project.godot`):** `fx_soft_particles`, `fx_frame_blend` (los escribe `QualityApplier`) y `look_wetness` (lo escribe `PrecipitationLayer`). Los materiales de `FxAtlas` están en caché por tipo, así que cambiar de preset no los reconstruye.

## 6. Cortes

**Común a todos:**
- Regresión: `ai_match` con `digest` igual, `rules_suite`, y `grep` de RNG global igual a 0 en las carpetas de §4.1.
- Costo: método 022a (o `FrameBudget` de 027a si ya existe), ±1 ms, una corrida por vez, vsync o `--max-fps 60` salvo en el banco, y un solo Godot a la vez.
- **Escena base de laboratorio `debug/vfx_lab.tscn`** (N en 029a):
  - Hereda `debug/look_gallery.tscn` (mapa del producto, cámaras `ref`/`rts`/`horizonte`, F1 bioma, F2 cámara, F3 preset).
  - `classic = false` y Persephone.
  - Suma un `Node3D` `FxSlots` con el script ya existente `debug/fx_gallery.gd` y su `%Slots` (marcadores con nombre de `ParticleType`, `auto_fill_missing_slots`), al pie de la cámara `ref`, donde los sprites cortan el terreno.
  - El playtester pulsa `check_tick` para repetir todo. No lleva script nuevo.

### 029a — Shader de sprites moderno (F95)
- **Objetivo:**
  - Fundido contra la profundidad, interpolación de cuadros y rampa de color opcional.
  - `lit` (mix sombreado y con niebla), y niebla también para lo aditivo (se desvanece con la distancia en vez de quemar a lo lejos).
  - Globals por preset.
  - Arreglo de `portal_disc.gd:114` (RNG propio sembrado por instancia).
- **Criterios:**
  1. Con un preset debug con los dos globals en 0 (`debug/look/quality_medium_fx_legacy.tres`, mismo script `LookQuality`), la captura de `vfx_lab` en `ref` difiere ≤ 1 % de la previa al corte.
  2. En medio, en `pt95_soft_zoom.png` no se ve la línea recta donde `rock`, `dirt` y `summon` cortan el suelo; en el preset legacy sí.
  3. `heal` con `debug/fx/heal_slow.tres` (mismo `ParticleType`, `frame_s` ×4): en 6 capturas seguidas a 60 fps, el cambio de cuadro es gradual (sin saltos).
  4. GPU medio ≤ +0,3 ms con los 29 efectos a la vez.
  5. `grep` de `randf(` en `scenes/fx` igual a 0.
- **Escena de prueba:** `vfx_lab.tscn` en `ref`. Arranca con los efectos en el aire, todavía sin repetir. El playtester pulsa F3 (preset) y `check_tick`. Aún no está: luces, calcos ni pool.
- **Árbol:**
```
scenes/fx/sprite_particle.gdshaderinc     M  fundido, interpolación, rampa, niebla
scenes/fx/sprite_particle_add.gdshader     M  sin fog_disabled; fundido por niebla
scenes/fx/sprite_particle_mix.gdshader     M  render_mode según lit (dos shaders: _mix y _mix_lit)
scenes/fx/sprite_particle_mix_lit.gdshader N  mix sombreado (sangre, tierra, polvo)
scenes/fx/particle_type.gd                 M  soft_distance_m, frame_blend, color_ramp, lit
scenes/fx/fx_atlas.gd                      M  pasa los uniforms nuevos; elige shader
scenes/fx/portal_disc.gd                   M  RandomNumberGenerator propio
scenes/world/look/look_quality.gd          M  grupo «VFX y clima (029)»: fx_soft_particles, fx_frame_blend
scenes/world/look/quality_applier.gd       M  RenderingServer.global_shader_parameter_set
data/look/quality_{low,medium,high}.tres   M  valores de §4.3
project.godot                              M  shader_globals fx_soft_particles, fx_frame_blend
debug/vfx_lab.tscn                         N  hereda look_gallery + FxSlots (fx_gallery.gd)
debug/look/quality_medium_fx_legacy.tres   N  mismo script, globals en 0
debug/fx/heal_slow.tres                    N  mismo ParticleType, frame_s ×4
agent/flows/f95_vfx_lab.json               N
```

### 029b — Pool de emisores y estelas por tiempo (F96)
- **Objetivo:**
  - `FxBus` reusa `SpriteParticles` por tipo (lista libre con tope por tipo) en vez de instanciar en cada `play`.
  - `FxTrail` (componente) reemplaza los `TRAIL_EVERY` por cuadro en `rock_projectile`, `wrath_strike`, `swarm_projectile`, `fireball_projectile` y `ranged_shot`. La estela sale cada `interval_s` de tiempo.
- **Criterios:**
  1. En `vfx_lab`, 10 × `check_tick`: los hijos de `FxBus` no pasan de Σ topes y a los 4 s quedan ociosos y ocultos (impreso `fx_pool activos <n> libres <m>`).
  2. Con `--max-fps 30` y `--max-fps 120`, la cantidad de estelas de una roca en 2 s difiere ≤ 10 % (impreso `fx_trail <n>`).
  3. CPU de `FxBus.play` (medido con `Time.get_ticks_usec`) ≤ 50 µs tras calentar.
  4. Las capturas de `rock_hit` y `wrath_splash` no cambian a ojo.
- **Escena de prueba:** `debug/rock_hit.tscn` (existente): R + clic en el Druid (`spell_N` de Rock según la barra; el flow lo hace por input). Más `vfx_lab` para el pool.
- **Árbol:**
```
scenes/fx/fx_bus.gd                        M  pool por tipo; tope max_pooled_per_type (@export)
scenes/fx/sprite_particles.gd              M  reinicio en vez de queue_free; señal finished → pool
scenes/fx/fx_trail.gd                      N  class_name FxTrail: type_name, interval_s; FxTrail.attach(node, type, s)
scenes/world/spells/{rock_projectile,wrath_strike,swarm_projectile,fireball_projectile}.gd  M  usan FxTrail
scenes/world/units/ranged_shot.gd          M  usa FxTrail
agent/flows/f96_pool.json                  N
```

### 029c — Luces de efectos (F97)
- **Objetivo:**
  - `ParticleType.light: FxLightSpec` (color, energía, alcance, `attack_s`, `decay_s`).
  - `FxLightLayer` (capa del rig) tiene un pool de `OmniLight3D` sin sombra, con tope `fx_max_lights` del preset. Prioridad: energía × alcance / distancia a la cámara; con el tope lleno, roba la luz más débil.
  - En headless no hay rig y por lo tanto no hay luces.
- **Criterios:**
  1. En `vfx_lab`, cámara `ref`, `wrath_explosion1` sube ≥ 30 % la luminancia media del suelo en 6 m durante 0,2 s y vuelve a la base en ≤ `decay_s` + 0,1 s.
  2. Con los 29 efectos a la vez: `fx_luces activas <n>` ≤ 8 en medio, 0 en bajo y ≤ 16 en alto.
  3. Ninguna luz proyecta sombra (`shadow_enabled` falso en todas).
  4. GPU medio ≤ +0,3 ms con 8 luces.
  5. Quitar el nodo `FxLight` del rig deja todo como en 029b, sin errores.
- **Escena de prueba:** `vfx_lab.tscn`, cámara `ref` en la sombra del altar (F2). `check_tick`. Aún no: luces del escenario.
- **Árbol:**
```
scenes/fx/fx_light_spec.gd                 N  Resource
scenes/fx/particle_type.gd                 M  @export var light: FxLightSpec
scenes/fx/sprite_particles.gd              M  pide luz al pool (grupo "fx_light_pool"; sin pool, nada)
scenes/world/look/fx/fx_light_layer.gd     N  LookLayer: pool, prioridad, apply_quality(fx_max_lights)
scenes/world/look/fx/fx_light_layer.tscn   N
scenes/world/look/look_rig.tscn            M  + Layers/FxLight
scenes/world/look/look_quality.gd          M  fx_max_lights
data/look/quality_*.tres                   M
data/fx/lights/{wrath_burst,heal_glow,cast_glow,rock_spark,teleport_flash}.tres  N
data/fx/{wrath_explosion1,heal,cast_*,teleport_*,summon}.tres  M  socket light
```

### 029d — Rayo fiel de Lightning (F98)
- **Objetivo:**
  - `BeamFx` + `LightningBolt` (malla de cinta con 11 puntos y desplazamiento de caja 2,5 con `RandomNumberGenerator` propio; cambia cada 6/60 s; vida 64/60 s; recorrido 12/60 s; atlas `ltn2`/`elec`) desde el cielo o la mano hasta el blanco.
  - `FxBus.broadcast_beam(type, from, to)`, un RPC por rayo.
  - `caster.gd:_strike_lightning` deja `wrath_explosion1` y usa el rayo más un destello (`FxLightSpec`).
- **Criterios:**
  1. En `cast_stratos.tscn`, Lightning sobre el Druid: hay un rayo visible entre el origen y el centro del blanco durante 1,0–1,15 s, que cambia de forma ≥ 9 veces (capturas a 0,05 s).
  2. Con dedicado + 1 cliente, el cliente ve el rayo.
  3. El daño y el `digest` no cambian.
  4. Quitar `BeamFx` del tipo vuelve al destello solo.
- **Escena de prueba:** `debug/cast_stratos.tscn` (existente, mago de Stratos, blancos a 40/60 m). El playtester pulsa la acción `spell_N` que la barra muestra para `ntil` (el flow la deja escrita) y clic izquierdo en el Druid.
- **Árbol:**
```
scenes/fx/beam_type.gd                     N  Resource: atlas, ancho, segmentos, jitter_m, cambio_s, vida_s, recorrido_s, energía, light
scenes/fx/beam_fx.tscn / beam_fx.gd        N  MeshInstance3D + LightningBolt; se libera solo; pool en FxBus
scenes/fx/lightning_bolt.gd                N  RefCounted: puntos (port de LightningBolt)
scenes/fx/beam.gdshader                    N  cinta aditiva con fundido y niebla
scenes/fx/fx_bus.gd                        M  broadcast_beam / play_beam (rpc unreliable)
scenes/world/spells/caster.gd              M  _strike_lightning usa el rayo
data/fx/beams/lightning.tres               N
agent/flows/f98_lightning.json             N
```

### 029e — Calcos de impacto y distorsión (F99)
- **Objetivo:**
  - `ParticleType.decal: FxDecalSpec` (textura generada de quemado o cráter, tamaño, vida 6–10 s, fundido), con pool y tope `fx_max_decals`.
  - `ParticleType.distortion: FxDistortionSpec` (anillo de refracción por `hint_screen_texture`, ≤ 0,3 s), con tope.
  - Asignados a `rock`, `wrath_explosion1`, la explosión de fireball y `dirt` de cast.
- **Criterios:**
  1. En `rock_hit.tscn`, tras Rock queda una marca oscura bajo el impacto que desaparece entre 6 y 10 s.
  2. Con 30 impactos, los calcos activos no pasan de 12 en medio.
  3. La distorsión se ve 0,2–0,3 s en `wrath_splash.tscn` (medio y alto) y no existe en bajo.
  4. GPU medio ≤ +0,4 ms con 12 calcos y 2 distorsiones.
  5. Licencia del shader de distorsión anotada (CC0 o MIT) en la cabecera.
- **Escena de prueba:** `debug/rock_hit.tscn` y `debug/wrath_splash.tscn` (existentes); `spell_N` de Rock y Wrath más clic.
- **Árbol:**
```
scenes/fx/fx_decal_spec.gd, fx_distortion_spec.gd      N  Resources
scenes/fx/fx_decal.tscn / .gd                          N  Decal con fundido; textura generada (GradientTexture2D + NoiseTexture2D)
scenes/fx/fx_distortion.tscn / .gd / .gdshader         N  quad billboard, refracción de pantalla
scenes/fx/particle_type.gd                             M  sockets decal, distortion
scenes/fx/fx_bus.gd                                    M  pools de calcos y distorsiones con topes del preset
scenes/world/look/look_quality.gd, data/look/quality_*.tres  M  fx_max_decals, fx_distortion
data/fx/decals/{scorch,crater}.tres, data/fx/distortion/blast.tres  N
data/fx/{rock,wrath_explosion1,dirt_cast}.tres         M
```

### 029f — Luces del escenario (F100)
- **Objetivo:**
  - `StageLight` (`OmniLight3D` sin sombra, salvo el altar en alto) con `StageLightLook` (color, energía de día y de noche, alcance, pulso).
  - Va como hijo de `manafount.tscn` (luz azul que pulsa con el chorro; más fuerte y teñida del bando cuando hay Manalith), de `altar.tscn` (portal) y del Manalith (`structure.tscn` cuando es `htlm`).
  - Se apaga sola por distancia (`distance_fade_*` = `stage_light_fade_m`). En bajo, apagadas.
  - Charnel (bioma de noche) es la vidriera.
- **Criterios:**
  1. En `look_gallery` con Charnel (F1), cámara `rts`: cada manantial visible sube ≥ 25 % la luminancia del suelo en 10 m respecto de la capa apagada.
  2. El altar se lee como la luz dominante (ref 3).
  3. Con Persephone de día el cambio en el suelo es ≤ 8 % (no lava la pradera).
  4. En bajo: 0 luces del escenario.
  5. GPU medio ≤ +0,3 ms.
- **Escena de prueba:** `debug/look_gallery.tscn` (existente). F1 hasta Charnel y F2 a `rts`; KP de la capa para comparar. Aún no: ciclo de noche (029i).
- **Árbol:**
```
scenes/world/look/stage/stage_light.tscn / .gd    N  lee el preset del rig si existe; sin rig, apagada
scenes/world/look/stage/stage_light_look.gd       N  Resource
scenes/world/props/manafount.tscn                 M  + StageLight (pulse_source = %FreeFx)
scenes/world/props/altar.tscn                     M  + StageLight
scenes/world/structures/structure.tscn            M  + StageLight (activo solo con el Manalith; tinte por SideColors)
scenes/world/look/look_quality.gd, quality_*.tres M  stage_lights, stage_light_fade_m, stage_light_shadows
data/look/stage/{fount,altar,manalith}.tres       N
```

### 029g — Pase estético por familia (F101–F104; datos y ajustes chicos; capturas al usuario antes de cerrar)
Cada subcorte compara lado a lado con `quality_medium_fx_legacy.tres` en `vfx_lab` y en la escena del juego que lo dispara, contra `visual/refs/original/` primero y las refs IA después. Criterio común:
- Lo emisivo florece y el suelo y el cielo no (glow de 022h o RFC-022 §8).
- Ningún píxel 255 fuera del núcleo del efecto.
- La unidad sigue legible a la distancia de `rts`.
- La familia comparte paleta con el bioma.

| Subcorte | F | Familia y escena de prueba | Toca |
|---|---|---|---|
| **029g1** | F101 | Proyectiles e impactos: Rock, Wrath, Fireball, Swarm, Lightning (`rock_hit`, `wrath_splash`, `cast_pyro`, `cast_stratos`) | `data/fx/{rock*,wrath*,dirt*}.tres`, `data/fx/beams/lightning.tres`, `data/fx/lights/*`, rampas |
| **029g2** | F102 | Lanzamiento, convocatoria, curación, velocidad, teleport (`cast_heal`, `vfx_lab`) | `cast_*`, `summon`, `heal`, `speedup`, `teleport_*`; `teleport_rings.gd` (M: suavizado) |
| **029g3** | F103 | Manantial, Manalith, portal, vórtice, cuerdas, almas, derrumbe (`fount_fx_probe`, `guardian_altar`, `desecrate_ritual`, `look_gallery` Charnel) | `manafount`, `manalith`, `portal_*`, `red_vortex`, `needle`; `portal_disc.gdshader`, `tether.gdshader`, `guardian_tether.gdshader`, `soul.gdshader` (M: fundido y HDR) |
| **029g4** | F104 | Sangre, polvo y escupitajos (`ability_spit`, `rock_hit`) | `blood`, `hover_blood`, `dust`, `spit_*` (`lit = true`) |

### 029h — Reloj y sincronía de atmósfera (F105; sin cambio visible)
- **Objetivo:**
  - `AtmosClock` (`%Clock` en `look_rig.tscn`; `time_scale`, `frozen`).
  - `AtmosState` (valor neutro) y `WeatherSchedule` (puro).
  - `DayCycle`, `WeatherKind` y `WeatherProfile` vacíos y neutros.
  - Sockets `cycle` y `weather` en `LookProfile`.
  - `AtmosSync` en `high_noon.tscn` junto a `MatchBiome` (canal `atmos`).
  - Registro `atmos t=<s> fase=<p> clima=<id>` cada 10 s con `--atmos-log`.
- **Criterios:**
  1. Dedicado + A + B (B entra 30 s después): con `debug/look/weather_walk.tres` (recorre los 4 estados cada 30 s), A y B imprimen la misma `fase` y el mismo `clima` en ventanas de ±0,5 s durante 5 min.
  2. El dedicado imprime `atmos semilla <n>`, no instancia `AtmosClock` y no manda nada fuera de un mensaje por peer más los resync de 120 s (contados en el log).
  3. `digest` igual.
  4. `WeatherSchedule.segment_at` con la misma semilla y tiempo da lo mismo en 1000 consultas desordenadas (caso nuevo `atmos_schedule` en `rules_suite`).
  5. Captura de `look_gallery` idéntica (diff 0 %).
- **Escena de prueba:** `high_noon` real con dedicado + 2 clientes (`agent/run_pt105.sh`, como `run_pt60.sh`). `debug/rules/atmos_walk.tres` (mismo `MatchRules`) apunta al perfil de prueba. Sin input: el criterio está en la consola.
- **Árbol:**
```
scenes/world/look/atmos/atmos_clock.gd            N  nodo: t, semilla, time_scale, frozen, sample() cacheado por cuadro
scenes/world/look/atmos/atmos_state.gd            N  RefCounted: valores y neutro; sample(cycle, weather, seed, t)
scenes/world/look/atmos/weather_schedule.gd       N  estático puro: segment_at, strikes_in
scenes/world/look/atmos/day_cycle.gd              N  Resource
scenes/world/look/atmos/weather_kind.gd, weather_profile.gd  N  Resources
scenes/world/look/look_profile.gd                 M  @export cycle: DayCycle, weather: WeatherProfile
scenes/world/look/look_rig.gd / .tscn             M  socket clock + %Clock; atmos_state()
scenes/world/atmos_sync.gd                        N  autoridad: semilla y t; clientes: clock.sync()
scenes/world/high_noon.tscn                       M  + AtmosSync (look_rig = ../Look)
debug/rules_suite.gd + debug/atmos_cases.gd       M/N  caso atmos_schedule
debug/look/weather_walk.tres, debug/rules/atmos_walk.tres  N
agent/run_pt105.sh                                N
```

### 029i — Día/noche en la luz (F106; capturas al usuario)
- **Objetivo:**
  - `DayCycle` por bioma (`length_s` 1440 = 24 min; `start_phase` 0 = la luz aprobada de cada bioma).
  - Curvas y gradientes de elevación del sol, color y energía (multiplicadores), ambiente, exposición, luna y `night`.
  - `LightLayer` aplica `LightLook × AtmosState`. El sol baja, cruza a la luna con fundido de energía (sin saltos) y la luna sube.
  - Las `StageLight` suben con `night`.
  - Charnel: noche siempre, con la luna subiendo y bajando.
- **Criterios:**
  1. Fase 0 con `DayCycle` neutro: diff ≤ 1 % contra la captura previa.
  2. Con `debug/look/cycle_fast.tres` (120 s), en 8 capturas F4 (1/8 de ciclo cada una): de noche, la luminancia media del mago en `rts` es ≥ 40 % de la del día. El suelo nunca es negro (≥ 0,05). Las luces del escenario dominan de noche.
  3. Sin saltos: la diferencia de luminancia entre cuadros consecutivos es ≤ 2 % al cruzar el horizonte.
  4. La fuente invisible del cielo se actualiza a ≤ `sky_source_update_hz`.
  5. GPU medio ≤ +0,1 ms.
- **Escena de prueba:** `debug/atmos_lab.tscn` (N): hereda `look_gallery` con `classic = false`, `cycle_override = debug/look/cycle_fast.tres` y `freeze_clock = false`. El playtester pulsa F4 (acción de debug `debug_time_step`, registrada en `look_gallery.gd` como F1–F3). El cielo todavía no se oscurece: es 029j. Se cierra junto con 029j.
- **Árbol:**
```
scenes/world/look/light/light_layer.gd            M  _process mientras haya ciclo; multiplica; captura y restaura igual que hoy
scenes/world/look/stage/stage_light.gd            M  × night
scenes/world/look/sky/sky_layer.gd                M  fuente invisible con tope de Hz
data/look/cycle/{persephone,pyro,james,stratos,charnel}_cycle.tres  N
data/look/{dios}.tres                             M  socket cycle
debug/look_gallery.gd                             M  cycle_override, weather_override, freeze_clock, F4 y F5
debug/atmos_lab.tscn, debug/look/cycle_fast.tres  N
```

### 029j — Cielo Legacy modulable: noche y nubosidad (F107; capturas al usuario)
- **Objetivo:**
  - Uniforms nuevos con neutro exacto en `sky_band.gdshader` y `sky_clouds.gdshader`:
    - `tint` (blanco): `ALBEDO = min(rgb·energy, 1)·tint`.
    - `desaturate` (0).
    - Cobertura con reasignación lineal `clamp((a − lo)/(hi − lo))` con `lo = 0`, `hi = 1`. No `smoothstep`, que no es identidad.
  - `sky.gd`: `set_modulation(tint, energy_mul, lo, hi, speed_mul, desaturate)`. La velocidad de las nubes pasa a un acumulador (con `speed_mul = 1`, mismo `offset` que hoy).
  - `SkyLayer` lleva el tinte del `AtmosState` al cielo, a `background_color` y a `fog_light_color` con **el mismo multiplicador**: una paleta.
  - Topes en `WeatherKind`: `sky_darken` ≤ 0,5 y `sky_desaturate` ≤ 0,4.
- **Criterios:**
  1. Neutro: captura `horizonte` con diff 0 % en el cielo.
  2. De noche (`atmos_lab`, F4) cielo, fondo y niebla bajan juntos: el tono medio del cielo y el de la niebla en el horizonte difieren ≤ 10° de matiz.
  3. Con `overcast` (F5) la cobertura sube visiblemente con la misma textura (sin dibujo nuevo) y las nubes se mueven ×1,5.
  4. En modo clásico (`look = null`) el cielo no cambia.
  5. Swirl fuera de alcance.
- **Escena de prueba:** `debug/atmos_lab.tscn` con `weather_override = debug/look/weather_walk.tres`. F4 (hora) y F5 (siguiente estado, acción `debug_weather_next`). Aún no: lluvia ni rayos.
- **Árbol:**
```
scenes/world/sky_band.gdshader, sky_clouds.gdshader   M
scenes/world/sky.gd                                   M  set_modulation; acumulador
scenes/world/look/sky/sky_layer.gd                    M  aplica AtmosState; ENV_PROPS + background_color, fog_depth_*
data/look/weather/kinds/{clear,overcast}.tres         N
```

### 029k — Lluvia y nublado (F111; capturas al usuario)
- **Objetivo:**
  - `PrecipitationLayer`: `GPUParticles3D` que sigue a la cámara (caja `box_m` 40 m) con trazo alineado a la velocidad.
  - Textura generada; cantidad = `PrecipitationType.amount` × `precip_rate` × `precip_density_scale`.
  - En alto, colisión con `GPUParticlesCollisionHeightField3D` (sigue a la cámara) y salpicaduras.
  - Global `look_wetness`: `ground_pbr.gdshader` oscurece el albedo (≤ 30 %) y baja la rugosidad (≤ 50 %).
  - `WeatherKind` rain: sol ×0,45, ambiente ×0,9, niebla volumétrica ×1,6 y distancias ×0,8.
  - El pasto recibe el viento ×1,5 (`grass_field.gd`: `set_wind_scale`, a ≤ 2 Hz).
- **Criterios:**
  1. En `atmos_lab` con rain (F5), trazos finos y translúcidos como en `orig_2_lluvia_pradera.webp`.
  2. Una unidad a 100 m sigue distinguible.
  3. Transmitancia de la niebla a 150 m ≥ 75 % (VISUAL «niebla que tape»).
  4. Partículas: ≤ 1500 en bajo, ≤ 4000 en medio, ≤ 6000 en alto.
  5. GPU medio ≤ +0,6 ms.
  6. Al volver a `clear` en 45 s no quedan gotas y `look_wetness` vuelve a 0 en ≤ 90 s.
  7. Con dos clientes, los dos llueven en la misma ventana de ±0,5 s.
- **Escena de prueba:** `debug/atmos_lab.tscn`, F5 hasta rain. Aún no: rayos.
- **Árbol:**
```
scenes/world/look/atmos/precipitation_type.gd         N  Resource
scenes/world/look/atmos/precipitation_layer.tscn/.gd  N  LookLayer
scenes/world/look/atmos/precip_streak.gdshader        N
scenes/world/look/look_rig.tscn                       M  + Layers/Precipitation
scenes/world/look/ground/ground_pbr.gdshader          M  global look_wetness
scenes/world/look/grass/grass_field.gd                M  set_wind_scale
scenes/world/look/light/light_layer.gd                M  volumétrica × niebla del clima
project.godot                                         M  shader_globals look_wetness
scenes/world/look/look_quality.gd, quality_*.tres     M  precip_*
data/look/weather/kinds/rain.tres, data/look/weather/precip/rain.tres, data/look/weather/persephone_weather.tres  N
```

### 029l — Tormenta: rayos lejanos, destello y gancho de trueno (F109; capturas al usuario)
- **Objetivo:**
  - `StormLayer` en el estado storm:
    - Rayos de `BeamFx` (tipo `storm_bolt.tres`, de 120 m de altura al suelo) en puntos entre `min_strike_m` (150) y `max_strike_m` (600) del foco de la cámara, nunca a menos de 150 m de una unidad.
    - Los tiempos y lugares salen de `WeatherSchedule.strikes_in`.
    - Destello del `AtmosState` (doble pulso de 60 y 90 ms en ambiente y tinte del cielo) más una luz del pool si hay lugar.
    - Señal `struck(at: Vector3, thunder_delay_s: float)` con distancia/343, sin sonido.
  - **Accesibilidad:** ≤ 1 destello cada 4 s y ≤ 3 cambios de luminancia por segundo (umbral de fotosensibilidad); `flash_scale` 0 lo apaga.
- **Criterios:**
  1. En `atmos_lab` con storm, en 60 s: 3–8 rayos, todos a ≥ 150 m de las unidades y de la cámara `ref`.
  2. El destello sube el ambiente sin pasar a blanco el suelo.
  3. Dos clientes ven el mismo rayo en ±0,5 s y en el mismo lugar (log `rayo t=… x=… z=…`).
  4. `struck` se emite con el retardo correcto (log).
  5. `digest` igual.
- **Escena de prueba:** `atmos_lab` con `debug/look/weather_storm.tres` (perfil con storm al 100 %); F5 no hace falta.
- **Árbol:**
```
scenes/world/look/atmos/storm_layer.tscn/.gd      N  LookLayer; usa BeamFx del pool de FxBus
scenes/world/look/atmos/weather_schedule.gd       M  strikes_in
scenes/world/look/atmos/atmos_state.gd            M  flash
scenes/world/look/look_rig.tscn                   M  + Layers/Storm
data/fx/beams/storm_bolt.tres, data/look/weather/kinds/storm.tres  N
debug/look/weather_storm.tres                     N
```

### 029m — Clima por bioma (F110; datos y tipos de precipitación; capturas al usuario)
Propuesta (la decide el orquestador y se muestra con capturas). Frecuencias estimadas, no del original:

| Bioma | Estados y pesos | Precipitación | Base en el original |
|---|---|---|---|
| Persephone | despejado 0,55 · nublado 0,25 · lluvia 0,15 · tormenta 0,05 | lluvia | lluvia (`pe05`, `pe09`) |
| James | despejado 0,7 · nublado 0,2 · lluvia 0,1 | lluvia | lluvia (`ja09`) |
| Stratos | despejado 0,5 · nublado 0,25 · nieve 0,15 · tormenta 0,1 | nieve | `snow` (`TrigWeather`, clase `SNOW`) |
| Pyro | despejado 0,6 · ceniza 0,3 · brasas 0,1 | ceniza (mix) y brasas (aditivas) | `ash` y `cinders` |
| Charnel | nublado 0,5 · lluvia 0,35 · tormenta 0,15 | lluvia | lluvia en campaña |

Segmentos de 4–9 min y fundido de 45 s; el primer segmento siempre despejado (la partida arranca en la luz aprobada).
- **Criterios:**
  1. En `atmos_lab`, F1 recorre los 5 biomas con `weather_walk` y cada uno muestra su precipitación en su paleta.
  2. Nieve y ceniza cuestan lo mismo que la lluvia (±0,2 ms).
- **Árbol:**
```
data/look/weather/{james,stratos,pyro,charnel}_weather.tres          N
data/look/weather/kinds/{snow,ash,cinders}.tres, data/look/weather/precip/{snow,ash,cinders}.tres  N
data/look/{dios}.tres                                               M  socket weather
scenes/world/look/atmos/precipitation_layer.gd                      M  rotación y deriva para nieve y ceniza (si hace falta)
```

## 7. Mapa de responsabilidades

| Pieza | Responsabilidad (una) | Tipo | Por qué no se fusiona |
|---|---|---|---|
| `ParticleType` (M) | Cómo se ve un efecto y qué partes suma | Resource | Otro efecto = otro `.tres`; los sockets nulos apagan |
| `FxLightSpec`, `FxDecalSpec`, `FxDistortionSpec`, `BeamType` | Una parte de un efecto | Resource | Se reusan entre tipos |
| `FxBus` (M) | Reproducir y reusar efectos por nombre; RPC | Autoload (ya existe) | No conoce luces ni clima |
| `FxTrail` | Emitir la estela por tiempo | Nodo hijo | Saca un contador de 5 proyectiles |
| `FxLightLayer` | Pool y prioridad de luces de efectos | `LookLayer` | Se libera con el rig en el dedicado; quitarla apaga |
| `BeamFx` / `LightningBolt` | Dibujar un rayo / su forma | Packed / RefCounted | Lo usan el hechizo y la tormenta |
| `FxDecal` / `FxDistortion` | Marca de impacto / refracción | Packed | Un efecto, un archivo; F6 sola |
| `StageLight` + `StageLightLook` | Luz de un prop | Packed + Resource | Hija del prop; se quita y no hay luz |
| `AtmosClock` | Tiempo local y muestreo cacheado | Nodo del rig | No dibuja |
| `AtmosState` / `WeatherSchedule` | Estado del instante / qué clima toca | Valor / estático puro | Determinista y testeable sin escena |
| `DayCycle`, `WeatherKind`, `WeatherProfile`, `PrecipitationType` | Datos de bioma y clima | Resource | Noche, tormenta o nieve = `.tres` |
| `AtmosSync` | Semilla y tiempo de la autoridad a los peers | Nodo del mundo | Vive en el dedicado; el rig no |
| `LightLayer`, `SkyLayer` (M) | Únicos dueños de sol/env y de cielo/fondo/niebla de color | `LookLayer` | Evita dos escritores |
| `PrecipitationLayer` / `StormLayer` | Lluvia, nieve o ceniza y mojado / rayos y destello | `LookLayer` | Se apagan por separado |

## 8. Riesgos

- **Determinismo.** RNG global en presentación (hallazgo `portal_disc.gd:114`); se impone el `grep` de §4.1. El rayo de sacengine usa `state.uniform` y aquí se usa uno propio. `AtmosSync` usa `derive` (hash). Puerta: el `digest` en todos los cortes.
- **Cielo legacy.** El neutro debe ser identidad exacta: reasignación lineal, sin `smoothstep` y con acumulador de velocidad. El reviewer compara con diff 0 % en el cielo. La modulación vive dentro de los shaders del Legacy, no en capas encima: el FAIL de la review de 022d fue por capas encima.
- **Una paleta por mapa.** Cielo, fondo y niebla con el mismo multiplicador; la noche nunca cambia el matiz más de 10°.
- **Legibilidad.** La noche y la tormenta oscurecen. Hay piso de luminancia del mago (≥ 40 % del día) y de transmitancia (≥ 75 % a 150 m).
- **Fotosensibilidad.** Tope de destellos y `flash_scale`. Sin menú de opciones todavía: queda como `@export`.
- **Rendimiento.** Quedan ~2 ms de margen en medio, con el pasto y 027 abiertos. Están el orden de recorte de §4.3 y el banco en cada corte. La radiancia de la fuente invisible se actualiza con tope de Hz. Forward+ agrupa luces y calcos (tope de cluster 512) y los topes de preset quedan muy por debajo.
- **La Mac.** Un solo Godot por vez, vsync o `--max-fps 60`, corte si pasa de 2,5 GB (memoria del proyecto).
- **Red.** Desvío de reloj de ±RTT/2 más deriva, con resync cada 120 s. Los rayos difieren en menos de 0,5 s entre clientes, aceptable porque son visuales. El canal `atmos` va por `push_custom_to`, como `biome`.
- **GPUParticles en Metal.** La colisión por heightfield solo en alto. Sin colisión, la lluvia atraviesa la losa del altar en bajo y medio (aceptado).
- **Coordinación de archivos.** Con RFC-027 (`look_quality.gd`, `quality_*.tres`) y RFC-022h (portal y glow): un developer por vez en esos archivos.

## 9. Fuera de alcance

- Sonido de trueno y lluvia (RFC de audio; queda la señal `struck`).
- Insectos y granizo del original.
- Modo Swirl con clima.
- Cielo de Charnel (RFC-022 §17.9a) y video del cielo de Pyro (§17.9b).
- Clima que afecte el juego (visibilidad, daño, movimiento).
- Menú de opciones gráficas y de accesibilidad.
- Campaña y triggers `SetWeather`.
- Estrellas o luna nuevas en el Legacy.
- Reflejos en charcos o SSR, gotas en la «lente», motion blur, aberración.
- Convertir los proyectiles hechos en código en `.tscn`.

## 10. Orden de implementación

1. 029a → 029b → 029c → 029d → 029e (en serie por `fx_bus.gd` y `particle_type.gd`). 029h se puede programar en paralelo con 029a (archivos disjuntos); el playtest sigue en serie.
2. 029f (después de 029c).
3. 029g1–g4 (después de 022h o con su convención de glow; g3 después de 029f).
4. 029i → 029j (cierran juntos ante el usuario) → 029k → 029l (necesita 029d) → 029m.

Cada corte: developer → reviewer → playtester con ventana y capturas. Lo visible se muestra al usuario antes de cerrar.

## 11. Cómo verifica un humano en el editor

- **`vfx_lab.tscn` (F6):** F3 cambia de preset y `check_tick` repite.
  - Elegir `data/fx/wrath_explosion1.tres` y editar `light.energy` o `decal`: cambia en la siguiente repetición.
  - Vaciar el socket: la parte desaparece.
- **Rig de `high_noon.tscn`:** ocultar `Look/Layers/FxLight`, `Precipitation` o `Storm` apaga esa capa sin errores. `Look/Clock.frozen` congela la hora.
- **`atmos_lab.tscn` (F6):**
  - F4 avanza la hora y F5 el clima.
  - Editar `data/look/cycle/persephone_cycle.tres` (curvas) o `data/look/weather/kinds/rain.tres`: se ve en vivo.
  - Con `look = null` en un `GodTheme`: modo clásico sin ciclo.
- **Props:** en `manafount.tscn` y `altar.tscn`, el nodo `StageLight` con su `.tres` en el inspector. Quitarlo no deja luz.
- **Dedicado (`--headless -- --dedicated`):** la consola muestra `atmos semilla <n>` y ningún nodo de `look/`.

## 12. Preguntas abiertas (lo visible se muestra con capturas)

1. **¿Cuánto día/noche?**
   - **(a) Recomendada:** ciclo de 24 min que arranca en la luz aprobada de cada bioma, con atardecer, noche en la misma paleta (multiplicador frío, nunca negra; mandan las luces del escenario y los hechizos) y amanecer. Charnel sigue de noche con la luna subiendo y bajando.
   - (b) Solo tarde ↔ atardecer, sin noche.
   - (c) Apagado por defecto (fiel al original, que no tiene ciclo) y activable por `.tres`.
2. **¿Cómo se ve «más nublado» sobre el cielo original?**
   - **(a) Recomendada, fiel:** solo se modulan las capas originales (más cobertura con la misma textura, más velocidad, oscurecer y desaturar con tope). Nunca nubes nuevas.
   - (b) Además, en tormenta, una segunda pasada de la **misma** textura original, más baja y oscura: más cargado, pero es contenido nuevo en el cielo y roza la regla «nada de nubes nuevas».


## 13. Decisiones del orquestador (2026-10-16, delegadas por el usuario)

- **Numeración:** 029k pasa de F108 a **F111**, porque F108 ya es el pasto de James, Stratos y Charnel (RFC-022e). En las tablas, donde diga F108 para 029k, léase F111.
- **P1 = (a):** ciclo de 24 min que parte de la luz aprobada de cada bioma; la noche es fría y nunca negra. Se puede apagar por `.tres`.
- **P2 = (a):** solo se modulan las capas originales del cielo, sin nubes nuevas (memoria «conservar el cielo original»).
- **Clima en High Noon:** el original no lo trae, pero el usuario lo pidió. Va como desvío declarado y se puede apagar por `.tres`. Los rayos de tormenta también son contenido nuevo pedido por el usuario.
- **Enmienda del criterio 3 de 029b (REVIEW-F96):** las estelas cuestan ≤ 50 µs de media por `FxBus.play` en cualquier fps, y el evento de ráfaga más caro (la explosión de wrath) ≤ 0,5 ms. El costo depende de la cantidad de partículas y, a 30 fps, la CPU baja de frecuencia.
- **Enmienda del criterio 4 de 029c (REVIEW-F97):** Metal no da tiempo de GPU. El proxy es que, con 8 luces activas, la CPU de render y los draws no aumenten de forma medible. Se vuelve a medir con una GPU que lo informe. La misma regla vale para los cortes de luz siguientes.
