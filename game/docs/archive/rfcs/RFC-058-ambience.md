# RFC-058: ambiente (día y noche, clima, vida ambiental)

Estado: implementado (058-1 hora, 058-2 clima, 058-3 rayos de tormenta, 058-4 vida); falta la pasada única de pruebas. Plan aprobado: `docs/archive/rfcs/plans/058-ambience-plan.md` (revisión 2 + bloque «Estado: aprobado»).

## Qué es

Contenido nuevo, solo presentación: el original no tiene hora ni clima en partida (`envi.d:55-65`, `renderer.d:1136-1141`). Cada dios arranca en su luz aprobada y el día pasa en 24 min: atardecer, noche fría con luna y estrellas (nunca negra), amanecer. El clima cambia por segmentos (despejado, niebla, lluvia, tormenta, nieve) con el mismo plan para los cinco dioses. En tormenta caen rayos lejos de la cámara, con un destello corto del cielo y el trueno que llega después. Insectos, polen, luciérnagas, brasas y esporas acompañan a la cámara y viven en spots del mapa.

## Reglas

- **Identidad.** A la hora de inicio y con Clear, todo es neutro: la captura es la de antes, byte a byte. `Atmosphere` oculta = neutro.
- **Un dueño por objeto.** El sol lo escribe `SunLayer`; el `Environment`, el cielo y la niebla, `EnvironmentLayer` (el cielo en una copia privada del material vía `SkyDresser`, a ≤ `sky_hz`). `Atmosphere` no escribe nada: emite `changed(sample)`.
- **Todos ven lo mismo, sin RPC.** El mensaje `biome` que ya existe suma `at_s` y `sky_seed` (`MatchSky`). La hora y el clima salen de (semilla, segundos) con `AtmosphereRules`, en cualquier peer.
- **Eventos.** El clima no afecta el juego, pero emite: `Atmosphere.hour_changed`, `night_changed`, `Weather.weather_changed(from, to)`, `Weather.strike(at)`. Un nodo de reglas futuro deriva lo mismo en el servidor con `AtmosphereRules` + `MatchSky`, sin rediseño (ver `scenes/look/atmosphere/README.md`).
- **Nieve igual para todos.** Los cinco dioses comparten un solo plan de clima (`data/look/weather/plan.tres`) con los mismos pesos.
- **Sin bloom.** Ningún `GlowLook` cambia; el destello sube cielo y ambiente (cielo × 1 + `flash_strength` × `flash_scale`, a lo sumo × 2, durante ≤ 150 ms), no el glow. El haz `storm_bolt` tiene `energy_scale` 0,6 (≤ el de `lightning.tres`).
- **Rayos iguales para todos.** `AtmosphereRules.strikes_between(semilla, t0, t1, por_min)` da (segundo, rumbo, distancia): el mismo instante, rumbo y distancia respecto de la cámara de cada jugador (150-600 m), igual para cualquier partición del tiempo. El tiempo se corta en ranuras de 2 × `min_gap_s` (8 s) y el rayo cae en la mitad central de su ranura: nunca dos a menos de 4 s (fotosensibilidad). Un rayo no hace daño: es solo presentación.
- **Trueno.** `thunder.tres` (thn1-6 del original, bus Ambience) suena `distancia / 343` s después del destello, sin posición (está a cientos de metros).
- **Sin azar global.** `grep -nE '\brandf|\brandi|randomize\(|\bseed\(' scenes/look/atmosphere scenes/look/life` = 0; el azar del clima es `AtmosphereRules.hash_int`.

## Dónde se edita

| Qué | Dónde |
|---|---|
| Curvas del día (energía, elevación, noche, estrellas, luna, atardecer) y colores de atardecer/noche | `data/look/<dios>.tres` → Day |
| Estados del clima | `data/look/weather/<estado>.tres` (la lluvia y la nieve embeben su `PrecipitationLook`) |
| Plan del clima (pesos, segmento, mezcla) | `data/look/weather/plan.tres`, compartido por los cinco looks |
| Enjambres | `data/look/life/<enjambre>.tres`; cuáles usa cada dios: `data/look/<dios>.tres` → Life |
| Spots de vida | `map.tscn` → `LifeSpots` (arrastrar `life_spot.tscn`, elegir hábitat, escalar la caja) |
| Rayos (cuántos, cuán fuerte el destello) | `data/look/weather/storm.tres` → Storm (`strikes_per_min`, `flash_strength`) |
| Rayos (distancias, separación, largo del haz, destello) | `scenes/look/atmosphere/atmosphere.tscn` → `Weather/Storm`; el haz `data/fx/beams/storm_bolt.tres`, el destello con su luz `data/fx/storm_flash.tres`, el trueno `data/audio/cues/thunder.tres` |
| Densidades por calidad | `data/look/quality_*.tres` → Ambience (058) |
| Vista previa en el editor | `map.tscn` → `Look` (`preview_god`) → `Layers/Atmosphere` (`preview_hour`, `preview_weather`) |

## Cómo se verifica

- F6 `debug/look/ambience_lab.tscn`: el día en 24 s y el clima recorriendo `weather_walk.tres` (20 s por estado, 5 s de mezcla). KP0 apaga `Atmosphere`.
- F6 `debug/look/storm_lab.tscn`: el laboratorio con tormenta todo el tiempo (`debug/look/storm_only.tres`) y la hora real; con `--log=atmosphere`, una línea `rayo t=… rumbo=… dist=…` por rayo.
- `rules_suite`: casos ATMOSPHERE (a, b, c `strikes_split`, d, e, f, g).
- Red: `bash agent/runs/run_058_sync.sh` (dedicado + A + B, B se cae y vuelve al mismo asiento; 5 min en tiempo real): misma semilla, el mismo segundo de partida (±0,5 s) y los mismos rayos; el dedicado no tiene `Atmosphere`. Los clientes son headless, así que la sonda (`agent/fixtures/sky_sync_client`) pregunta lo mismo que `Atmosphere`/`StormStrikes` (MatchSky + AtmosphereRules) en vez de leer el rig, que un proceso headless libera. `debug/rules/ambience_storm.tres` guarda la tierra y la semilla de esa prueba (charnel, 58) para las escenas que toman un `MatchRules`; el dedicado las recibe como `--biome=charnel --match-seed=58`.
- `--log=atmosphere`: `atmosfera t=… hora=… clima=…` cada 10 s; `atmosfera semilla <n>` en el servidor y en cada cliente.
- Capturas con cámara fija y criterio numérico: plan §2 (revisión 2), criterios 1-4, 6, 8, 9 y 11.
