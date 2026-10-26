# RFC-058: ambiente (día y noche, clima, vida ambiental)

Estado: en implementación (058-1, 058-2, 058-4). 058-3 (rayos de tormenta) espera a que entre el plan 065. Plan aprobado: `rfcs/plans/058-ambience-plan.md` (revisión 2 + bloque «Estado: aprobado»).

## Qué es

Contenido nuevo, solo presentación: el original no tiene hora ni clima en partida (`envi.d:55-65`, `renderer.d:1136-1141`). Cada dios arranca en su luz aprobada y el día pasa en 24 min: atardecer, noche fría con luna y estrellas (nunca negra), amanecer. El clima cambia por segmentos (despejado, niebla, lluvia, tormenta, nieve) con el mismo plan para los cinco dioses. Insectos, polen, luciérnagas, brasas y esporas acompañan a la cámara y viven en spots del mapa.

## Reglas

- **Identidad.** A la hora de inicio y con Clear, todo es neutro: la captura es la de antes, byte a byte. `Atmosphere` oculta = neutro.
- **Un dueño por objeto.** El sol lo escribe `SunLayer`; el `Environment`, el cielo y la niebla, `EnvironmentLayer` (el cielo en una copia privada del material vía `SkyDresser`, a ≤ `sky_hz`). `Atmosphere` no escribe nada: emite `changed(sample)`.
- **Todos ven lo mismo, sin RPC.** El mensaje `biome` que ya existe suma `at_s` y `sky_seed` (`MatchSky`). La hora y el clima salen de (semilla, segundos) con `AtmosphereRules`, en cualquier peer.
- **Eventos.** El clima no afecta el juego, pero emite: `Atmosphere.hour_changed`, `night_changed`, `Weather.weather_changed(from, to)`, `Weather.strike(at)` (058-3). Un nodo de reglas futuro deriva lo mismo en el servidor con `AtmosphereRules` + `MatchSky`, sin rediseño (ver `scenes/look/atmosphere/README.md`).
- **Nieve igual para todos.** Los cinco dioses comparten un solo plan de clima (`data/look/weather/plan.tres`) con los mismos pesos.
- **Sin bloom.** Ningún `GlowLook` cambia; el destello (058-3) sube cielo y ambiente, no el glow.
- **Sin azar global.** `grep -nE '\brandf|\brandi|randomize\(|\bseed\(' scenes/look/atmosphere scenes/look/life` = 0; el azar del clima es `AtmosphereRules.hash_int`.

## Dónde se edita

| Qué | Dónde |
|---|---|
| Curvas del día (energía, elevación, noche, estrellas, luna, atardecer) y colores de atardecer/noche | `data/look/<dios>.tres` → Day |
| Estados del clima | `data/look/weather/<estado>.tres` (la lluvia y la nieve embeben su `PrecipitationLook`) |
| Plan del clima (pesos, segmento, mezcla) | `data/look/weather/plan.tres`, compartido por los cinco looks |
| Enjambres | `data/look/life/<enjambre>.tres`; cuáles usa cada dios: `data/look/<dios>.tres` → Life |
| Spots de vida | `map.tscn` → `LifeSpots` (arrastrar `life_spot.tscn`, elegir hábitat, escalar la caja) |
| Densidades por calidad | `data/look/quality_*.tres` → Ambience (058) |
| Vista previa en el editor | `map.tscn` → `Look` (`preview_god`) → `Layers/Atmosphere` (`preview_hour`, `preview_weather`) |

## Cómo se verifica

- F6 `debug/look/ambience_lab.tscn`: el día en 24 s y el clima recorriendo `weather_walk.tres` (20 s por estado, 5 s de mezcla). KP0 apaga `Atmosphere`.
- `rules_suite`: casos ATMOSPHERE (a, b, d, e, f, g; el c llega con 058-3).
- `--log=atmosphere`: `atmosfera t=… hora=… clima=…` cada 10 s; `atmosfera semilla <n>` en el servidor y en cada cliente.
- Capturas con cámara fija y criterio numérico: plan §2 (revisión 2), criterios 1-4, 8, 9 y 11.
