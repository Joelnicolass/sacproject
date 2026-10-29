# spells/tornado

Tornado: a `GroundZone` (`tornado.tscn`). `TornadoDrift` is the only writer of the zone's position and size, `TornadoLift`
throws bodies near the funnel through `Tumbling`, and `TornadoLook` draws it. The winds come from each peer's ticks and a
seed, so only phase, position and size are replicated.
