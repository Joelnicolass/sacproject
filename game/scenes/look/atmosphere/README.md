# look/atmosphere

What: the hour and the weather of now, as one `AtmosphereSample` (`Atmosphere.changed`): the sun turns into the moon at night, the ambient, fog and sky dim and tint, stars and moon show. At the start hour, with Clear, it is neutral: the approved look, byte for byte.
Not: who writes the light (SunLayer), the Environment and the sky (EnvironmentLayer, through SkyDresser), the ambient life (look/life); nothing here touches the simulation.
Talks to: MatchBiome sends `MatchSky.message()` (server seconds + sky seed) in the biome message -> `Atmosphere` reads `MatchSky.now_s()` -> `TimeOfDay` (DayCycle) -> `changed(sample)` -> SunLayer / EnvironmentLayer / AmbientLifeLayer. Events: `hour_changed(hour)`, `night_changed(is_night)`.
Edit: `data/look/<god>.tres` -> Day (curves over 0..24 h; at `start_hour` multipliers 1 and amounts 0); in a `map.tscn` select `Look/Layers/Atmosphere` and move `preview_hour` (with `Look.preview_god` set). Hide `Atmosphere` = neutral.
Check: F6 `debug/look/ambience_lab.tscn` (a day in 24 s; KP0 toggles the layer) · `rules_suite` ATMOSPHERE cases · `--log=atmosphere` prints `atmosfera t=… hora=… clima=…` every 10 s and `atmosfera semilla <n>`.

---

Events for a future rules node. The weather is presentation only, but its state is not hidden in the look: the dedicated server builds no `Atmosphere`, yet `MatchSky` runs there too (MatchBiome begins it), so a rules node subscribes without a redesign by deriving the same state on any peer:

- hour: `AtmosphereRules.hour_at(god.look.day, MatchSky.now_s())`, night: `AtmosphereRules.is_night(...)`;
- weather (058-2): `AtmosphereRules.state_at(god.look.weather, MatchSky.sky_seed(), MatchSky.now_s())`.

On a peer with a screen the same moments arrive as signals: `Atmosphere.hour_changed`, `Atmosphere.night_changed`, and on `Weather` (058-2) `weather_changed(from, to)` and `strike(at)` (058-3). `time_scale` and `frozen_hour` are debug only: in a networked match they must stay 1 and -1, or the peers disagree.
