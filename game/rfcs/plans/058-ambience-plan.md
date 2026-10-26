Estado: **propuesto**, espera el OK del usuario ; la revisión 2 al final reemplaza las secciones del mismo número.

# Plan RFC-058: ambiente (día y noche, clima, rayos de tormenta, vida ambiental)

Tech lead, 2026-10-26, rama `refactor/new-systems`, HEAD 23b1b83f. No escribí nada en el repo. El lint de hoy está verde y tiene margen en C1a (83 contra 84), C9, C14, C15, C18 y C21.

## 0. Qué leí y qué verifiqué

- **Leí:** CONVENTIONS.md entero, RFC-055 §13.3 (líneas 455-457), RFC-029 §1-13 (planeaba lo mismo como 029h-m y nunca se implementó: no hay `AtmosClock`, `AtmosSync` ni `WeatherSchedule` en el código), VISUAL.md y RULES.md. En código: `scenes/look/*` (`LookRig`, `LookLayer`, `LookProfile`, `EnvironmentLayer`, `SunLayer`, `LightLook`, `SkyLook`, `GlowLook`, `sacrifice_sky.gdshader`, `FxLightLayer`, `look_rig.tscn`), `MatchClock`, `MatchSeed`, `MatchBiome`, `MatchWorld`, `MpNetClock`, `AmbienceDirector`/`AmbienceSet`, `FxBus`, `BeamFx`/`BeamType`, `FxLightSpec`, `Terrain.of`/`height_at`, `debug/look/look_gallery.*`, `data/look/persephone.tres` y las memorias que aplican.
- **Estado de hoy:**
  - `look_rig.tscn` ya tiene dos huecos vacíos, `TimeOfDay` y `Weather`, colgados del rig.
  - `EnvironmentLayer` tiene 150 líneas y es el único que escribe el `Environment`.
  - `SunLayer` tiene 72 y es el único que escribe el sol.
  - El cielo es `sacrifice_sky.gdshader`, con material compartido dentro de cada `SkyLook`.
  - Los únicos globals de shader del look son `fx_fog_*` (`project.godot:425+`).
  - No hay ningún `VisibleOnScreenEnabler3D` en el proyecto.
- **Original (sacengine), verificado:**
  - `envi.d:55-65`: el ambiente de un mapa es estático, con niebla, sin hora y sin ciclo.
  - `trig.d:1306-1317`: existe `TrigWeather` (lluvia, nieve, brasas, ceniza, insectos), con `TrigSetWeatherAction` en `trig.d:1314` y `2882`, pero nadie lo consume fuera de `trig.d`.
  - `state.d:22356`: el Volcano tiene `// TODO: weather`.
  - `renderer.d:1136-1141`: `sunStrength` es fijo por dios.
  - Conclusión: día y noche, lluvia y tormenta son contenido nuevo, como ya decía RFC-055 §13.3.
- **Audio del original que ya está en el repo:** `assets/original/audio/sfx/ambi/` trae `rain.wav`, `thn1-6.wav` (truenos), `ins1-2`, `cri1-2` y `owl1-2`.
- **NO VERIFICADO:**
  - El escaneo de RFC-029 §1.1 que ubica lluvia en `pe05`, `pe09`, `ja09`, `ch09` y otros. No lo repetí.
  - Qué cambiaba el Volcano en el clima.
  - Que `VisibleOnScreenEnabler3D` frene la simulación de un `GPUParticles3D` en Godot 4.7. El diseño no depende de eso.

## 1. Contradicciones y cuál gana

| # | Choque | Gana |
|---|---|---|
| 1 | RFC-029 029h-m (`AtmosClock`, canal `atmos` con resync cada 120 s, capas en `scenes/world/look`, shaders `sky_band`/`sky_clouds` que ya no existen) contra RFC-058 | **RFC-058**. Es más nuevo, 055b reemplazó el cielo y va en el orden aprobado de RFC-055 §13.4. De RFC-029 §13 se conservan dos decisiones: ciclo de 24 min que arranca en la luz aprobada, y solo modular las capas originales del cielo. |
| 2 | VISUAL.md «Bloom fuerte en … hechizos» contra la memoria del usuario del 2026-10-23 («sin bloom fuerte») | **La memoria**, que es la decisión más reciente del usuario. Este RFC no toca ningún `GlowLook` ni `glow_*`, y un criterio lo mide. |
| 3 | RFC-029 029l: rayos a 150 m o más de las unidades | **No se aplica.** Exige leer la simulación desde la presentación. Queda «150-600 m de la cámara», y el rayo no hace daño. |
| 4 | RFC-029 §9 deja los insectos fuera de alcance | **RFC-055 §13.3**: el usuario los pidió el 2026-10-23. |
| 5 | El README de `scenes/look` dice que `TimeOfDay` y `Weather` cuelgan directo del rig | **El plan**: pasan a ser hijos de `Layers/Atmosphere`. Se actualiza el README. |
| 6 | El pedido dice «día y noche a través del único dueño del Environment», pero el sol no es parte del Environment | Cada objeto mantiene su dueño: el sol lo escribe `SunLayer` y el entorno, el cielo y la niebla los escribe `EnvironmentLayer`. Los dos leen la misma muestra de atmósfera. |
| 7 | RFC-029 §1.2 dice «sin audio» | **RFC-052**: el audio ya existe, así que la lluvia y el trueno suenan. |

## 2. Objetivo y criterios de aceptación (medibles)

Todo esto es solo presentación. Nada toca la simulación ni agrega una RPC.

1. **Identidad en neutro.** Con `Atmosphere` oculta, o a la hora de inicio con Clear, la captura de `look_gallery` (`hide_particles`, `freeze_sky`, 3 cámaras) es idéntica byte a byte a la de antes del corte: 0 px distintos.
2. **Noche legible y sin pisar el cielo.** Con `frozen_hour = 0`, cámara `rts` y Persephone:
   - luminancia media del suelo entre 0,05 y 0,45 × la del día;
   - cuerpo del mago ≥ 0,40 × el día;
   - luminancia media del cielo ≥ 0,35 × el día;
   - saturación media del cielo ≤ la del día + 0,02 (nunca satura);
   - diferencia de matiz entre el cielo y la niebla del horizonte ≤ 15°.
3. **Sin saltos.** En el lab con `time_scale = 60`, 240 cuadros alrededor del atardecer:
   - salto máximo de luminancia entre cuadros seguidos ≤ 2 %;
   - cuando la luz pasa de sol a luna, su energía es ≤ 0,05 × la del día.
4. **Clima con estados.** Con `weather_walk.tres` (20 s por estado y 5 s de mezcla):
   - el log `atmosfera` recorre clear → fog → rain → storm;
   - las gotas vivas no pasan de 1500 en bajo, 4000 en medio y 6000 en alto;
   - al volver a clear, en ≤ 8 s hay 0 emisores encendidos y el fondo de lluvia está parado.
5. **La niebla no tapa.** Caso de suite: la transmitancia a 150 m es ≥ 0,75 para cada dios × estado (VISUAL «niebla que tape»).
6. **Tormenta: luz y sonido.** Con el plan `storm_only.tres`, en 60 s:
   - entre 3 y 8 rayos, con ≥ 4 s entre destellos (fotosensibilidad);
   - cada rayo cae a 150-600 m de la cámara;
   - el trueno suena con un retardo igual a la distancia / 343 (±0,05 s);
   - todos los `glow_*` del Environment quedan iguales;
   - el `energy_scale` de `storm_bolt` es ≤ al de `lightning.tres`.
7. **Todos ven lo mismo.** Dedicado + cliente A + cliente B, con B entrando 30 s después y `debug/rules/ambience_storm.tres`, durante 5 min:
   - cada 10 s, A y B imprimen la misma hora (±0,01 h) y el mismo estado;
   - los rayos coinciden en tiempo (±0,5 s), rumbo (±0,5°) y distancia (±1 m);
   - el dedicado imprime `atmosfera semilla <n>` y tiene 0 nodos `Atmosphere`;
   - no hay RPC ni canales nuevos (se cuentan en el log).
8. **Vida ambiental.** En el lab, Persephone, calidad alta:
   - de día hay ≥ 1 enjambre de aire encendido (polen); de noche, las luciérnagas;
   - con lluvia, los enjambres que tienen `in_rain = false` quedan en 0;
   - en `tutorial_valley`, los spots encendidos son ≤ los spots en pantalla (log `vida spots activos a/n`);
   - en calidad baja hay 0 partículas de vida.
9. **Costo** (en Metal no hay tiempo de GPU; se usa el proxy de RFC-029 §13). En el lab, calidad alta, tormenta + noche + vida, contra neutro: CPU de cuadro ≤ +0,7 ms y draw calls ≤ +8.
10. **Determinismo y lint.**
    - El digest de `quick` no cambia.
    - `grep -nE '\brandf|\brandi|randomize\(|\bseed\(' scenes/look/atmosphere scenes/look/life` da 0.
    - Ningún conteo del lint sube.

## 3. Escena de prueba

**`res://debug/look/ambience_lab.tscn`**, escena heredada de `debug/look/look_gallery.tscn`. No lleva script nuevo.

- **Qué instancia:**
  - `scenes/match/high_noon.tscn`, el mundo del producto con el mapa High Noon y su `Look`, los cuerpos y las cámaras `ref`, `rts` y `horizonte` de la galería.
  - Override en la galería: `classic = false`, `freeze_sky = false`, `hide_hud = true`.
  - Override con hijos editables en `HighNoon/Map/Look/Layers/Atmosphere`: `time_scale = 60` (el ciclo dura 24 s) y `plan_override = debug/look/weather_walk.tres`.
- **Estado inicial:** luz aprobada del bioma, a la `start_hour` de su `DayCycle`, con Clear, sin gotas y sin rayos.
- **Lo que todavía no está** (es el resultado del criterio): la noche, la niebla, la lluvia, la tormenta y las luciérnagas. Aparecen solas con el tiempo.
- **Acciones del InputMap:** las de debug que ya registra `look_gallery.gd`: F1 siguiente bioma, F2 cámara, F3 calidad, KP1..KP9 una capa (la capa 1 pasa a ser Atmosphere). No hace falta pulsar nada para el ciclo.
- **Atajos de debug, como otro `.tres` del mismo script:**
  - `debug/look/weather_walk.tres`: un `WeatherPlan` con 20 s por estado y 5 s de mezcla;
  - `debug/look/storm_only.tres`: un `WeatherPlan` con storm al 100 %;
  - `debug/rules/ambience_storm.tres`: un `MatchRules` con `biome_god = charnel`, para la prueba de red;
  - las capturas fijan la hora con `Atmosphere.frozen_hour` (0, 6, 12, 18) desde el arnés.
- **La vida en spots** (criterio 8) se verifica en el mapa real: `scenes/map/maps/tutorial_valley/map.tscn` con F6 en la escena de partida y `--map=tutorial_valley`. No hay un debug aparte.
- Todo esto se anota en el RFC.

## 4. Árbol de archivos

`[+]` nuevo, `[~]` modificado, `[-]` borrado. **⚠** marca un archivo compartido con trabajo en paralelo.

```
scenes/look/atmosphere/                         [+] system
  README.md                                     [+] What/Not/Talks to/Edit/Check
  atmosphere.tscn                               [+] Atmosphere > TimeOfDay, Weather > Precipitation, Storm
  atmosphere.gd                                 [+] LookLayer: hour and weather now -> AtmosphereSample -> changed(sample)
  atmosphere_sample.gd                          [+] RefCounted value: neutral(), mix(a, b), is_close()
  atmosphere_rules.gd                           [+] static pure: hour_at, day_sample, weather_at, strikes_between, fog_transmittance, own int hash
  time_of_day.gd                                [+] Node: the hour's light from DayCycle
  day_cycle.gd                                  [+] Resource (embedded in each god)
  weather.gd                                    [+] Node3D: weather now from WeatherPlan + seed; tells Precipitation and Storm
  weather_state.gd                              [+] Resource: Clear/Fog/Rain/Storm
  weather_plan.gd                               [+] Resource: first state, chances, segment_s, blend_s
  weather_chance.gd                             [+] Resource: state + weight (embedded in the plan)
  precipitation_look.gd                         [+] Resource: drops material and mesh, amount, sound (embedded in the state)
  precipitation_fall.gd                         [+] Node3D: drives Drops (amount_ratio) and Bed (volume)
  storm_strikes.gd                              [+] Node: draws a strike (FxBus.play_beam + FxBus.play) and thunder later
scenes/look/follow_camera.gd                    [+] Node3D: sits ahead of the viewport camera (rain and air life: 2 callers)
scenes/look/life/                               [+] system
  README.md                                     [+]
  ambient_life.tscn                             [+] AmbientLife > Follow > Air1..Air3
  ambient_life_layer.gd                         [+] LookLayer: air swarms of the biome + hands spots their swarm
  ambient_swarm.gd                              [+] Resource: one kind (pollen, fireflies...)
  ambient_life_set.gd                           [+] Resource (embedded in the god): air + per habitat; enum Habitat
  life_spot.tscn / life_spot.gd                 [+] Node3D + VisibleOnScreenEnabler3D + GPUParticles3D, placed in the map
scenes/look/look_rig.tscn                       [~] + Layers/Atmosphere (first), + Layers/AmbientLife; - TimeOfDay, - Weather (loose slots); sockets atmosphere in Sun and Environment
scenes/look/look_profile.gd                     [~] group "Ambience (058)": day: DayCycle, weather: WeatherPlan, life: AmbientLifeSet
scenes/look/look_quality.gd                     [~] group "Ambience (058)": rain_density_scale, life_density_scale
scenes/look/light/sun_layer.gd                  [~] @export atmosphere; elevation + change, tint, energy; moon at night (same light)
scenes/look/sky/environment_layer.gd            [~] @export atmosphere; _write_atmosphere (ambient, fog, sky globals); moves _write_glow and _publish_fx_fog out
scenes/look/sky/glow_look.gd                    [~] write_to(env: Environment, preset_on: bool) (moved from EnvironmentLayer, so it stays at ≤150)
scenes/look/sky/look_globals.gd                 [+] static: the only place that publishes the look's shader globals (fx_fog_*, look_sky_tint, look_sky_grey); only EnvironmentLayer calls it
scenes/look/sky/sacrifice_sky.gdshader          [~] global uniform look_sky_tint (white), look_sky_grey (0): exact identity in neutral; visible pass only
scenes/look/README.md                           [~] Atmosphere and AmbientLife layers; slots
project.godot                                   [~] shader_globals look_sky_tint (vec3 1,1,1), look_sky_grey (float 0)
scenes/match/match_sky.gd                       [+] static: server seconds of the match seen from here + seed of the sky
scenes/match/match_biome.gd                     [~] same message, plus at_s and sky_seed; MatchSky.begin/adopt; log "atmosfera semilla"
data/look/weather/clear.tres fog.tres rain.tres storm.tres   [+] WeatherState (rain/storm embed their PrecipitationLook)
data/look/life/pollen.tres fireflies.tres gnats.tres dust.tres embers.tres ash.tres spores.tres  [+] AmbientSwarm
data/look/{persephone,james,stratos,pyro,charnel}.tres        [~] embedded: Day (DayCycle), Weather (WeatherPlan), Life (AmbientLifeSet)
data/look/quality_{low,medium,high}.tres        [~] densities (⚠ editor noise in git status: rewrite from HEAD, memory show-trees-again)
data/fx/beams/storm_bolt.tres                   [+] BeamType (ltn atlas, long, wide)
data/fx/storm_flash.tres                        [+] ParticleType with embedded FxLightSpec (cold white, range 40 m), no sound  ⚠ 065 (ParticleType flat)
data/audio/cues/rain_loop.tres thunder.tres     [+] SoundCue (rain.wav loop; thn1-6.wav, bus Ambience)
scenes/map/maps/tutorial_valley/map.tscn        [~] + LifeSpots (Node3D) with ~12 LifeSpot; override Look/Layers/AmbientLife.spots  ⚠ terrain_tools/flora
scenes/map/maps/high_noon/map.tscn              [~] + LifeSpots (~8)  ⚠ new-map template / terrain_tools
debug/look/ambience_lab.tscn                    [+] inherits look_gallery.tscn
debug/look/weather_walk.tres storm_only.tres    [+] WeatherPlan
debug/rules/ambience_storm.tres                 [+] MatchRules biome_god charnel
debug/suite/atmosphere_cases.gd                 [+] cases (sec. 11)
debug/suite/rules_suite.gd                      [~] preload + run ATMOSPHERE_CASES
agent/runs/run_058_sync.sh                      [+] dedicated + A + B (B 30 s later), grep of the logs
```

Nada se borra salvo los dos huecos sueltos del rig. No queda código 1 a 1 que deprecar: no hay clima previo.

## 5. Árboles de nodos

**`look_rig.tscn`** (orden de `Layers`):
```
Look (LookRig)
├── Layers
│   ├── Atmosphere      [+] instance atmosphere.tscn
│   ├── Sun (SunLayer)              atmosphere = ../Atmosphere
│   ├── Ground
│   ├── Environment (EnvironmentLayer)  atmosphere = ../Atmosphere
│   ├── Grass · FxLight · Flora · ActorLights · TerrainDeform · Underside
│   └── AmbientLife     [+] instance ambient_life.tscn, atmosphere = ../Atmosphere (map.tscn overrides spots)
└── Quality
```

**`atmosphere.tscn`**:
```
Atmosphere (Atmosphere : LookLayer)   update_hz 10 · time_scale 1 · frozen_hour -1 · fallback_seed 58 · plan_override
│                                     editor: preview_hour -1 · preview_weather
│                                     read-only: hour_now · weather_now
├── TimeOfDay (TimeOfDay : Node)
└── Weather (Weather : Node3D)
    ├── Precipitation (PrecipitationFall : Node3D)
    │   ├── Follow (FollowCamera : Node3D)   ahead_m 25
    │   │   └── Drops (GPUParticles3D)        local_coords off, visibility_aabb 80x40x80, emitting off
    │   └── Bed (AudioStreamPlayer, bus Ambience)
    └── Storm (StormStrikes : Node)   bolt, flash, thunder · min/max_strike_m 150/600 · bolt_top_m 120 · min_gap_s 4 · flash_scale 1
```

**`ambient_life.tscn`**:
```
AmbientLife (AmbientLifeLayer : LookLayer)   atmosphere · spots: Node3D
└── Follow (FollowCamera)   ahead_m 15
    ├── Air1 (GPUParticles3D)
    ├── Air2 (GPUParticles3D)
    └── Air3 (GPUParticles3D)
```
Es un pool fijo en la escena, así que no hay `.new()`. Un bioma con más de 3 enjambres de aire muestra un aviso de configuración.

**`life_spot.tscn`**:
```
LifeSpot (LifeSpot : Node3D)   habitat: AmbientLifeSet.Habitat
├── OnScreen (VisibleOnScreenEnabler3D)   aabb = the spot's box (gizmo); enable_node_path ../Swarm
│                                         screen_entered/exited -> LifeSpot (sets emitting)
└── Swarm (GPUParticles3D)   visibility_aabb = OnScreen.aabb
```

**`map.tscn`** (tutorial_valley y high_noon): `Map > LifeSpots (Node3D) > Meadow01…, Pond01…`, más el override de `Look/Layers/AmbientLife.spots = ../../../LifeSpots`.

## 6. Responsabilidades (una por pieza)

| Pieza | Hace | No hace |
|---|---|---|
| `MatchSky` (estático) | Da los segundos de partida del servidor vistos desde este proceso y la semilla del cielo. Autoridad: `MatchClock.now()/TPS` (se frena con la pausa en solo). Cliente: reloj de pared desde que llegó el mensaje + `at_s`. | Simular, mandar mensajes |
| `MatchBiome` [~] | Además del dios, manda `at_s` y `sky_seed` en el mismo mensaje y en el mismo momento (`client_world_ready`) | Dibujar |
| `Atmosphere` | Lee la hora (o la vista previa), pide las muestras a sus dos hijos, las mezcla y emite `changed(sample)` a ≤ `update_hz`, o en cada cuadro mientras hay un destello | Escribir el sol, el entorno o el cielo |
| `TimeOfDay` | La luz de una hora según `DayCycle` | Saber del clima |
| `Weather` | Qué clima hay ahora (plan + semilla + t) y qué rayos caen en (t0, t1]. Le pasa la cantidad a `Precipitation` y los rayos a `Storm` | Escribir luces |
| `PrecipitationFall` | Gotas y sonido de lluvia en la cantidad que recibe | Decidir cuándo llueve |
| `StormStrikes` | Dibuja un rayo: haz, luz del pool `FxLightLayer` vía `FxBus.play` y el trueno con retardo | Decidir cuándo cae |
| `FollowCamera` | Seguir la cámara del viewport (también la del editor) | Nada más |
| `SunLayer` [~] | Única escritora del sol: `LightLook` × muestra, con la luna como la misma luz | — |
| `EnvironmentLayer` [~] | Única escritora del `Environment` y de los globals del cielo: ambiente, niebla, tinte y gris del cielo | Tocar el glow |
| `LookGlobals` | Único código que publica los globals de shader del look (lo llama solo `EnvironmentLayer`) | Decidir valores |
| `AmbientLifeLayer` | Enjambres de aire del bioma y entregarle a cada spot su enjambre según hora y clima | Ubicar spots |
| `LifeSpot` | Mostrar un enjambre en su caja, solo mientras está en pantalla | Elegir el enjambre |
| `AtmosphereRules` | Toda la matemática pura, probada sin escena | Árbol, nodos |

## 7. Resources, nodos y `@export`

- **Resources de tipo** (`.tres` compartidos; nunca se mutan): `WeatherState` (clear, fog, rain, storm), `AmbientSwarm` (pollen, fireflies…), `BeamType` `storm_bolt`, `ParticleType` `storm_flash`, `SoundCue` (rain_loop, thunder).
- **Resources embebidos en el look de cada dios** (`data/look/<god>.tres`), uno por dios para no dispersar:
  - `DayCycle`: `length_s` (1440; 0 = sin ciclo); `start_hour` (la hora de la luz aprobada); Curves de 0 a 24 h `elevation_change_deg`, `light_energy`, `ambient_energy` y `night`; Gradients `light_tint`, `ambient_tint` y `sky_tint`; `moon_azimuth_offset_deg` y `moon_elevation_deg`. Avisa si en `start_hour` algo no es neutro, o si la energía no es ~0 donde la elevación cruza 0.
  - `WeatherPlan` con sus `WeatherChance`.
  - `AmbientLifeSet`.
- **`PrecipitationLook`**: embebido en `rain.tres` y `storm.tres`.
- **`WeatherState`**: `sun_energy_mul`, `ambient_mul`, `sky_tint` (con tope de luminancia ≥ 0,5), `sky_grey` (0 a 0,4), `fog_density_mul`, `fog_end_mul`, `rain` (0 a 1), `strikes_per_min`, `flash_strength`, `precipitation`.
- **`AmbientSwarm`**: `process_material` (`ParticleProcessMaterial`), `mesh` (`QuadMesh` con un `StandardMaterial3D` embebido y un `GradientTexture2D` radial; placeholder sin arte nuevo), `amount`, `by_day`, `by_night`, `in_rain`.
- **Valores, no Resources:** `AtmosphereSample` (RefCounted) y `MatchSky` (estático).
- **Nodos:** los de §5.
- **`@export` de instancia:**
  - `Atmosphere`: `update_hz`, `time_scale` (solo debug: en red tiene que ser 1, lo dice el doc), `frozen_hour`, `fallback_seed`, `plan_override`, `preview_hour`, `preview_weather`;
  - `StormStrikes`: distancias, `bolt_top_m`, `min_gap_s`, `flash_scale`;
  - `FollowCamera.ahead_m`; `LifeSpot.habitat`; `OnScreen.aabb`;
  - sockets `atmosphere` y `spots`.
- **Calidad:** `LookQuality.rain_density_scale` (0,35 / 1 / 1,5) y `life_density_scale` (0 / 0,6 / 1).
- **Fuente mínima de verdad:** se guardan solo curvas, pesos, estados y spots. La hora, el clima y los rayos se derivan de (semilla, t) en cada proceso. Nada derivado queda guardado.

## 8. Cómo lo hace un humano (los seis verbos y «encontrar un bug»)

| Verbo | Qué abre, qué toca | Lugares |
|---|---|---|
| Entender | `map.tscn` → `Look/Layers/Atmosphere` (README de 5 líneas). En el inspector remoto, `hour_now` y `weather_now` | 1 |
| Modificar | Noche más oscura: `data/look/<god>.tres` → Day → curva `light_energy`. Lluvia más densa: `data/look/weather/rain.tres` → Precipitation → amount. Se ve en vivo eligiendo `preview_god` + `preview_hour` en el `Look` del mapa | 1 |
| Agregar | Clima nuevo (nieve): duplicar `rain.tres` y cambiar su precipitación, y sumar un `WeatherChance` al plan del dios. Enjambre nuevo: duplicar `fireflies.tres` y sumarlo al Life del dios. Spot nuevo: arrastrar `life_spot.tscn` a `LifeSpots`, elegir el hábitat y escalar la caja | 2 |
| Quitar | Borrar el chance; vaciar `Day` (sin ciclo); ocultar `Atmosphere` (todo neutro); borrar el spot | 1 |
| Crear | El ambiente de un bioma nuevo: llenar Day, Weather y Life en su `<god>.tres`, reusando estados y enjambres | 1 + compartidos |
| Escalar | Densidades del preset; muchos spots no cuestan nada fuera de pantalla | 1 |
| Encontrar un bug | F6 en `ambience_lab`; `--log=atmosphere` imprime hora, clima y rayos cada 10 s; ocultar `Atmosphere` o `AmbientLife` (si el bug se va, está ahí); `rules_suite` con los casos de atmósfera | 1-2 |

## 9. Contratos

```gdscript
# scenes/match/match_sky.gd
class_name MatchSky extends RefCounted
static func reset() -> void
static func begin(sky_seed: int) -> void            # authority: time = MatchClock
static func adopt(at_s: float, sky_seed: int) -> void # client: time = wall clock since now + at_s
static func now_s() -> float
static func seed() -> int                           # 0 = no match (Atmosphere uses fallback_seed)
static func message() -> Dictionary                 # {"at_s": float, "sky_seed": int}
```
- **`MatchBiome`.** Payload `{"god": String, "at_s": float, "sky_seed": int}`, por el mismo canal `biome` y en el mismo `client_world_ready`.
  - `sky_seed = MatchSeed.derive(["sky"])`: es un hash, no consume el RNG.
  - Llama a `MatchSky.reset()` en `_ready`, en todos los peers.
- **`signal Atmosphere.changed(sample: AtmosphereSample)`** y `func current() -> AtmosphereSample`.
- **`AtmosphereSample`**. Campos: `hour`, `night`, `elevation_change_deg`, `moon: bool`, `light_tint`, `light_energy`, `ambient_tint`, `ambient_energy`, `sky_tint`, `sky_grey`, `fog_density`, `fog_end`, `rain`, `flash`, `weather: WeatherState`. Funciones: `static neutral()`, `static mix(day, weather)` (producto por componente, `max` para el destello: conmutativa) y `is_close(other, eps)`.
- **`AtmosphereRules`** (estático y puro):
  - `hour_at(cycle, t_s) -> float`
  - `day_sample(cycle, hour) -> AtmosphereSample`
  - `weather_at(plan, seed, t_s) -> AtmosphereSample`
  - `state_at(plan, seed, t_s) -> WeatherState`
  - `strikes_between(seed, t0_s, t1_s, per_min) -> PackedVector3Array`, donde cada elemento es (t, rumbo_deg, distancia_m)
  - `fog_transmittance(sky: SkyLook, sample, d_m) -> float`
  - `hash_int(a: int, b: int) -> int`: splitmix64 entero propio, para no depender de `hash()` entre arquitecturas.
- **Rayos.** Se ponen de acuerdo el tiempo, el rumbo y la distancia a la cámara de cada jugador (pregunta P3). `StormStrikes.strike(at: Vector3, distance_m: float)` calcula el punto de suelo con `Terrain.of(self).height_at(x, z)`. La punta del haz se arma como `Vector3(at.x, at.y + bolt_top_m, at.z)`: es una medida del rayo, no un enganche, y se le avisa al reviewer.
- **`LookLayer`** no cambia. Las capas que usan la atmósfera conectan `atmosphere.changed` en `_ready` y vuelven a calcular su objeto desde (perfil, preset, visible, muestra), de forma idempotente.
- **Shader del cielo.** `COLOR = mix(color, vec3(dot(color, LUMA)), look_sky_grey) * look_sky_tint;` va solo en la pasada visible. El cubemap no se re-hornea: el ambiente baja por `ambient_light_energy`.

## 10. Cortes y paralelismo

Los developers no corren Godot. Hay una sola pasada de pruebas al final.

| Corte | Qué | Depende de | En paralelo con |
|---|---|---|---|
| **058-1 Hora** | `MatchSky`, `MatchBiome`, `Atmosphere` + `Sample` + `Rules` + `TimeOfDay` + `DayCycle`; `SunLayer`, `EnvironmentLayer`, `GlowLook.write_to`, `LookGlobals`, shader y `project.godot`; **todos** los campos nuevos de `LookProfile` y `LookQuality`; `look_rig.tscn` con `Atmosphere` y `AmbientLife` (escena vacía con su script mínimo); `DayCycle` de los 5 dioses; lab; casos 1, 5 y 6 | — | 065, terrain_tools (archivos disjuntos) |
| **058-2 Clima** | `WeatherState`/`Plan`/`Chance`, `Weather`, `PrecipitationLook`/`Fall`, `FollowCamera`, `rain_loop`; 4 estados, planes de los 5 dioses, densidades de calidad; casos 2 y 4; `weather_walk` | 058-1 | 058-4 |
| **058-4 Vida** | `AmbientLifeLayer`, `AmbientSwarm`, `AmbientLifeSet`, `LifeSpot`; 7 enjambres; Life de los 5 dioses; spots en 2 mapas | 058-1; los mapas, después de que entre el trabajo de terrain_tools/plantilla | 058-2 |
| **058-3 Tormenta** | `StormStrikes`, `strikes_between`, destello en la muestra, `storm_bolt`, `storm_flash`, `thunder`, `storm_only`, `ambience_storm`, `run_058_sync.sh`; caso 3 | 058-2 (`weather.gd`); **después de que entre 065** (ParticleType plano) | — |

Conflictos que hay que esperar:
- 058-2 y 058-4 escriben los mismos `data/look/<god>.tres`, en sub-recursos distintos. El segundo en mergear rehace sus sub-recursos sobre el primero.
- Los dos mapas se tocan al final de 058-4, rebasados sobre terrain_tools.

## 11. Pruebas (pasada única al final)

- **`debug/suite/atmosphere_cases.gd`**, en `rules_suite`:
  - (a) cada `DayCycle` es neutro en su `start_hour` (±1e-3) y su energía es ≤ 0,05 donde la elevación cruza 0;
  - (b) `weather_at` da lo mismo en 1000 consultas desordenadas, y el primer segmento es `plan.first`;
  - (c) `strikes_between(0,60)` es igual a `(0,30)` + `(30,60)`, con ≥ `min_gap_s` entre rayos;
  - (d) transmitancia a 150 m ≥ 0,75 para cada dios × estado;
  - (e) `sky_tint` de noche: luminancia ≥ 0,35 y saturación HSV ≤ 0,15;
  - (f) `MatchSky.adopt(100, s)` y luego `now_s()` da ≈ 100 (±1 tick), con `seed() == s`.
- **Capturas** con el arnés en `ambience_lab`: neutro contra base (criterio 1), 4 horas fijas (2), secuencia de atardecer (3) y los criterios 4, 6, 8 y 9 con números del log y de `RenderingServer.get_rendering_info`.
- **Red:** `bash agent/runs/run_058_sync.sh` (criterio 7) y NET QUICK.
- **Determinismo:** `quick` con el digest igual, el grep de RNG y `bash tools/lint/conventions.sh`.

## 12. Red y determinismo

- **Simulación:** no cambia nada. `MatchSeed.derive` es un hash y no mueve ningún stream. No hay RPC nueva: se agregan 2 campos al mensaje `biome` que ya existe, una vez por peer, también en la reconexión.
- **Dedicado:** el rig se libera y el proceso solo deriva la semilla y la manda.
- **Cliente:** el error es la latencia de ida (decenas de ms), y el criterio pide ±0,5 s. Usa reloj de pared para no derivar si pausara su árbol.
- **Host listen:** es autoridad y usa `MatchClock`.
- **Partículas:** su azar es de la GPU, no del RNG global.

## 13. Riesgos

1. **C1a no puede subir.** `EnvironmentLayer` ya tiene 150 líneas. Por eso se mueven `_write_glow` a `GlowLook.write_to` y los globals a `LookGlobals`. El rig no crece porque las capas se suscriben solas.
2. **Cielo.** La identidad tiene que ser exacta (blanco y 0). El cubemap queda de día y los reflejos de noche salen un poco claros; se acepta.
3. **`VisibleOnScreenEnabler3D` con GPU** (NO VERIFICADO): el spot apaga `emitting` con las señales, sin depender del deshabilitado.
4. **La lluvia atraviesa techos** porque no tiene colisión. Se acepta, igual que en RFC-029.
5. **Fotosensibilidad:** `min_gap_s = 4` y `flash_scale`. Todavía no hay opción en el menú (P4).
6. **Paralelo:** `storm_flash.tres` depende del ParticleType plano de 065; los `map.tscn` de terrain_tools y de la plantilla; el ruido del editor en `data/look` (se reescribe desde HEAD).
7. **`hash()` entre arquitecturas:** se usa un hash entero propio.
8. **El volumen del fondo de lluvia** lo escribe solo `PrecipitationFall` después de `SoundBus.play_on`. Hay que confirmar que `SoundBus` no lo pisa por cuadro.
9. **Sombras con el sol bajo:** la elevación del sol se limita a [5°, 89°] y por debajo pasa a la luna.

## 14. Fuera de alcance

- Clima que afecte el juego.
- Suelo mojado: el shader del suelo es de 062 y terrain_tools.
- Más nubes o cambiar las nubes: va contra «conservar el cielo».
- Triggers de campaña y el clima del Volcano.
- Menú de opciones o accesibilidad.
- Luces de escenario que suban de noche.
- Música nocturna.
- Nieve y ceniza como clima (P5).

## 15. Preguntas, cada una con mi recomendación

- **P1. ¿El día y la noche vienen prendidos?** Recomiendo que sí: 24 min, arrancando en la luz aprobada de cada dios, con una noche fría que nunca es negra. Charnel queda de noche con la luna que se mueve. Se apaga vaciando `Day`.
- **P2. ¿El clima afecta el juego** (por ejemplo, que la lluvia frene el fuego)? Recomiendo que **no**: solo presentación, sin RPC y sin riesgo para el determinismo ni para el balance.
- **P3. ¿Dónde cae el rayo?** Recomiendo el mismo instante, rumbo y distancia respecto de la cámara de cada jugador: siempre se ve y todos lo ven igual. La alternativa es un punto fijo del mapa, que casi nunca se vería.
- **P4. ¿Un interruptor de «destellos de tormenta» en Opciones?** Recomiendo dejarlo para el pase de opciones (055h). Por ahora alcanzan el tope de 4 s y `flash_scale`.
- **P5. ¿Nieve en Stratos?** Recomiendo que sí, como quinto `WeatherState` solo de datos en 058-2: demuestra que «agregar clima = un `.tres`». Pyro lleva brasas y ceniza como vida ambiental, no como clima.
- **P6. ¿Sonidos de noche** (`owl1-2`, `cri1-2`, `ins1-2` del original)? Recomiendo que sí, chico, en 058-4: `AmbienceSet.night_one_shots` y `AmbienceDirector` que escuche `night`. No choca con 065.
- **P7. ¿Spots de vida en qué mapas?** Recomiendo `tutorial_valley` y `high_noon` ahora, y un nodo `LifeSpots` vacío en la plantilla de mapa nuevo, coordinado con terrain_tools. Los demás mapas quedan para los humanos.

## 16. Orden de implementación

1. 058-1: `MatchSky` y `MatchBiome`.
2. 058-1: `AtmosphereSample` y `AtmosphereRules` (hora).
3. 058-1: `DayCycle`, `TimeOfDay` y `Atmosphere`.
4. 058-1: `LookGlobals`, el shader y `project.godot`.
5. 058-1: `SunLayer`, `EnvironmentLayer` y `GlowLook.write_to`.
6. 058-1: `LookProfile` y `LookQuality` con todos los campos; `look_rig.tscn`; 5 `DayCycle`; lab; casos a, e y f; README.
7. 058-2 y 058-4 en paralelo (worktrees). 058-2: estados, plan, `Weather`, `Precipitation`, `FollowCamera` y casos b y d. 058-4: enjambres, `AmbientLifeLayer`, `LifeSpot` y los spots al final.
8. 058-3 después de 065: `StormStrikes`, destello y caso c, y `run_058_sync.sh`.
9. Pasada única: import, parse check, `rules_suite`, lab y capturas (§11), sincronía, NET QUICK, `quick`, lint.

## 17. Cómo verifica un humano en el editor

- Abrir `scenes/map/maps/tutorial_valley/map.tscn` y seleccionar `Look`:
  - con `Preview god = persephone` y, en `Layers/Atmosphere`, mover `preview_hour` a 0, 6, 12 o 18: la noche se ve en el viewport;
  - con `preview_weather = rain.tres` o `fog.tres` se ve el clima;
  - vaciar los dos vuelve a la luz aprobada, idéntica.
- Ocultar `Layers/Atmosphere` o `Layers/AmbientLife` apaga cada parte sin errores.
- Seleccionar un `LifeSpot`: la caja de `OnScreen` es el gizmo y se escala arrastrando.
- F6 en `debug/look/ambience_lab.tscn`: ciclo en 24 s y los 4 climas cada 20 s. F1 cambia de bioma y F3 de calidad (en baja no hay vida y hay menos lluvia).
- En partida (F5 con `--log=atmosphere`): una línea `atmosfera t=… hora=… clima=…` cada 10 s, y `rayo t=… rumbo=… dist=…` en tormenta.
- Dedicado: `atmosfera semilla <n>` y ningún nodo de look.

Archivos clave que leí:
- `/Users/joelsartori/Development/sacproject/game/scenes/look/look_rig.tscn`
- `/Users/joelsartori/Development/sacproject/game/scenes/look/sky/environment_layer.gd`
- `/Users/joelsartori/Development/sacproject/game/scenes/look/light/sun_layer.gd`
- `/Users/joelsartori/Development/sacproject/game/scenes/look/sky/sacrifice_sky.gdshader`
- `/Users/joelsartori/Development/sacproject/game/scenes/look/look_profile.gd`
- `/Users/joelsartori/Development/sacproject/game/scenes/match/match_biome.gd`
- `/Users/joelsartori/Development/sacproject/game/scenes/match/match_clock.gd`
- `/Users/joelsartori/Development/sacproject/game/rfcs/RFC-029-vfx-lights-weather.md`
- `/Users/joelsartori/Development/sacproject/game/rfcs/RFC-055-human-first-refactor.md`


---

# Plan RFC-058, revisión 2: el cielo ahora puede cambiar

Esta revisión aplica la decisión del usuario del 2026-10-26: el día, la noche y la tormenta pueden cambiar el cielo mientras la estética se parezca a la del original; el cielo legacy hasta puede desaparecer. Se sigue prohibiendo el bloom fuerte. Sigue sin escribir nada en el repo.

El plan es el que ya te mandé salvo lo que se lista acá: cada sección de abajo reemplaza a la del mismo número. Lo que no aparece (§3, §5, §6, §8, §10, §12, §14, §16 y §17) queda igual, con dos ajustes:
- donde se nombra `LookGlobals`, ahora solo publica `fx_fog_*`;
- `Atmosphere.update_hz` sigue en 10 para la luz y suma `sky_hz` = 2 para el cubemap del cielo.

## 1. Contradicciones (filas nuevas y cambiadas)

| # | Choque | Gana |
|---|---|---|
| 8 | La memoria «conservar el cielo original» y VISUAL.md («Cielo: se conserva… nada de nubes nuevas ni saturación») contra la decisión del 2026-10-26 | **El usuario (2026-10-26), solo para RFC-058.** Hay que actualizar VISUAL.md §Sí (cielo) y la memoria `keep-original-sky`. No puedo editarlas; lo hacés vos. |
| 9 | RFC-029 §13 P2 = (a) «solo modular las capas originales, sin nubes nuevas» | **Queda reemplazada.** Ahora se permite más cobertura, nubes de tormenta más oscuras, estrellas y luna. |
| 2 | Bloom fuerte | Sin cambio: sigue prohibido. Ningún `GlowLook` cambia, el destello sube el ambiente y el cielo pero no el glow, y el haz del rayo tiene tope. |

Lo que sigue mandando del original es la composición: una paleta por mapa, el horizonte fundido con el cielo y las bandas pintadas como base (memoria `original-look-is-target`). El cielo no se reemplaza por otro sistema: el mismo `sacrifice_sky.gdshader` gana capas de noche y tormenta (pregunta P8).

## 2. Criterios (cambian 2 y 6; se agrega 11)

- **Criterio 1 (identidad en neutro):** queda igual. A la hora de inicio y con Clear, la luz aprobada no cambia (0 px).
- **Criterio 2 (noche):**
  - Con `frozen_hour = 0`, cámara `rts` y Persephone: luminancia media del suelo entre 0,05 y 0,45 × la del día; cuerpo del mago ≥ 0,40 × el día.
  - El cielo sí puede cambiar: luminancia media del cielo entre 0,10 y 0,70 × la del día; estrellas visibles (≥ 30 píxeles por encima de 2 × la media local en la cámara `horizonte`); disco de luna presente.
  - Una sola paleta: el matiz medio del cielo cerca del horizonte y el de la niebla difieren ≤ 15°.
  - Se sacan los topes de saturación y de piso del cielo.
- **Criterio 6 (tormenta):** se suman dos mediciones.
  - En storm, la cobertura de nubes (fracción de píxeles del cielo con alfa de nube > 0,5) es ≥ 1,5 × la de clear y la luminancia del cielo es ≤ 0,6 × la de clear.
  - El destello sube la luminancia del cielo entre ×1,3 y ×2 durante ≤ 150 ms.
  - Se mantienen: glow igual, `energy_scale` del haz con tope y ≥ 4 s entre destellos.
- **Criterio 11 (nuevo, costo del cielo):** el cubemap de radiancia (64) se re-hornea a ≤ `sky_hz` (2 Hz) fuera de un destello; CPU de cuadro ≤ +0,3 ms medido en el lab.

## 4. Árbol de archivos (cambios)

```
scenes/look/sky/sacrifice_sky.gdshader      [~] new groups: night (night_amount, star_density, star_brightness), storm (cloud_cover, cloud_darken, cloud_speed_mul, sky_grey), flash (flash_amount); all neutral at 0/1 (exact identity)
scenes/look/sky/sky_stars.gdshaderinc       [+] procedural stars (port of a CC0/MIT shader from Godot Shaders; source in the header), only above the horizon and behind the clouds
scenes/look/sky/sky_clouds.gdshaderinc      [~] cover = linear remap of the same texture's alpha (lo/hi), darkening by cloud_darken
scenes/look/sky/environment_layer.gd        [~] works on a PRIVATE copy of SkyLook.material (like the Environment today) and writes the sky's uniforms from the sample: background_color × tint, energy, cloud_*, moon_intensity, night/stars, flash; ambient_* of the cubemap at ≤ sky_hz
scenes/look/sky/look_globals.gd             [~] fx_fog_* only (out: look_sky_tint/look_sky_grey)
project.godot                               [-] the planned globals look_sky_tint and look_sky_grey are no longer added
```

Cambian estos Resources:
- **`DayCycle`:** se suman las Curves `stars` y `moon_intensity` (0 a 24 h). `sky_tint` queda sin tope. Las dos nuevas avisan si en `start_hour` no valen 0.
- **`WeatherState`:**
  - Se suman `cloud_cover`, `cloud_darken` y `cloud_speed_mul`.
  - `sky_grey` admite ahora de 0 a 1.
  - `sky_tint` queda sin tope.
  - `flash_strength` también actúa sobre el cielo.

## 7. Dueño del cielo

`EnvironmentLayer` sigue siendo el único que escribe cielo, entorno y niebla. Ahora escribe uniforms en su copia privada del material, en lugar de globals de shader: es lo estándar de Godot, el `.tres` compartido no se muta y el cubemap puede seguir la noche.

- **Ventaja:** a la noche, el ambiente y los reflejos también bajan. Así se cierra el riesgo 2 del plan anterior.
- **Edición en vivo:** si se edita el `SkyLook` en el inspector, la capa rehace la copia, igual que hoy rehace el `Environment`.

## 9. Contratos (cambios)

`AtmosphereSample` suma `stars`, `moon_intensity`, `cloud_cover`, `cloud_darken` y `cloud_speed_mul`. Reglas de `mix`: producto en los multiplicadores, `max` en `stars` y `cover`, suma con tope en `flash`. `sky_grey` y `sky_tint` dejan de tener tope en `AtmosphereRules`.

Para que la deriva de las nubes no salte cuando cambia `cloud_speed_mul`, el shader usa un acumulador de fase: un uniform `cloud_phase` que avanza la capa. Con `cloud_speed_mul = 1` da exactamente lo mismo que hoy.

## 11. Pruebas (cambios)

- Se reemplaza el caso (e) por: «todos los uniforms nuevos del cielo valen su neutro en `start_hour` y con Clear».
- Se agrega el caso (g): «`mix` es conmutativa y la neutra es su identidad».
- Capturas nuevas: noche con estrellas y luna, storm contra clear (cobertura y luminancia) y la secuencia del destello.

## 13. Riesgos (cambios)

- **Se va el riesgo 2** (cubemap de día de noche).
- **Nuevo: costo del re-horneado** si los uniforms del cubemap cambian a cada cuadro. Mitigación: `sky_hz` = 2; durante un destello solo cambia la pasada visible.
- **Nuevo: «estética parecida» es subjetiva.** Se ata a números: la misma paleta (≤ 15° entre cielo y niebla) y las capturas en las 4 horas que ve el usuario antes de cerrar 058-1.
- **Nuevo: estrellas que titilan entre cuadros.** Se fijan al cielo (dirección y rotación de las bandas) y no al tiempo de pantalla.

## 15. Preguntas (cambian P5 y se agrega P8)

- **P5. Nieve en Stratos.** Igual que antes: sí, como `WeatherState` solo de datos. Además, ahora la tormenta de Stratos puede oscurecer el cielo como la del resto.
- **P8. ¿Hasta dónde cambia el cielo?**
  - **Recomiendo:** mantener `sacrifice_sky.gdshader` como base con las bandas y nubes originales, y sumarle noche (estrellas, luna y tinte) y tormenta (más cobertura, nubes más oscuras, gris y destello). Conserva la estética sin un sistema nuevo.
  - **La alternativa:** reemplazarlo por un cielo procedural nuevo. Esa va como RFC propio y no entra en el 058.

Archivos tocados por este cambio:
- `/Users/joelsartori/Development/sacproject/game/scenes/look/sky/sacrifice_sky.gdshader`
- `/Users/joelsartori/Development/sacproject/game/scenes/look/sky/sky_clouds.gdshaderinc`
- `/Users/joelsartori/Development/sacproject/game/scenes/look/sky/environment_layer.gd`
- `/Users/joelsartori/Development/sacproject/game/VISUAL.md` (desactualizado)
- `/Users/joelsartori/.claude/projects/-Users-joelsartori-Development-sacproject/memory/keep-original-sky.md` (desactualizado)
