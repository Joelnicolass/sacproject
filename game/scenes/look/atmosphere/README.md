# look/atmosphere

The hour and the weather of now, sent as one `AtmosphereSample` (`Atmosphere.changed`) to the sun, environment and
ambient life layers. Presentation only: at the start hour with clear weather it is neutral.
Every peer derives the same state from `MatchSky` (server clock + sky seed): `AtmosphereRules.hour_at`, `is_night`,
`state_at` and `strikes_between` give the same answer on the server, so a future rules node can use them.
`time_scale` and `frozen_hour` are for debugging only: in a networked match they must stay 1 and -1.
Edit: `scenes/look/<god>.tres` (Day curves), `scenes/look/weather/*.tres` (states, `plan.tres`); in a map, `Look/Layers/Atmosphere`
→ `preview_hour` / `preview_weather`.
