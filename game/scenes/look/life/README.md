# look/life

What: ambient life by hour and weather: the god's swarms in the air around the camera (pool `Air1..Air3`) and, in the map's `LifeSpot`s, the swarm of each spot's habitat (meadow, water, woods, rock), drawn only while its box is on screen. In low quality (`life_density_scale` 0) nothing shows.
Not: where the spots are (nodes of each `map.tscn`), the hour or the weather (look/atmosphere), the night sounds (AmbienceDirector plays `AmbienceSet.night_one_shots` by the same hour).
Talks to: `Atmosphere.changed(sample)` -> `AmbientLifeLayer` -> `LifeSpot.show_swarm(swarm, density)`; the map's `Look/Layers/AmbientLife.spots` points at its `LifeSpots`. Loading screen (069): the `WarmHook` child -> `AmbientLifeLayer.warm` flies every swarm of the look for a frame in the air slots; their `Follow` always processes (the start gate pauses the tree while loading and waiting), so they surround the camera then too.
Edit: a swarm = `data/look/life/<name>.tres` (motion, mesh, amount, by_day / by_night / in_rain) · which swarms a god uses = `data/look/<god>.tres` -> Life (air and one list per habitat; the first that shows wins) · a spot = drag `life_spot.tscn` under the map's `LifeSpots`, pick its habitat, scale the `OnScreen` box.
Check: the tutorial map with `--log=life`: `vida spots activos a/n` every 10 s (a ≤ spots on screen).
