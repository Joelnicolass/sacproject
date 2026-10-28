# spells/zones

A place on the ground with a clock. `GroundZone` goes through CASTING, ARMING, ACTIVE and ENDING; its children do and
draw what the spell does there (Explosion, Frozen Ground, Demonic Rift, Erupt, Volcano, Bore and the clouds: Rain of Frogs,
Rain of Fire, Plague, Cloudkill, Bombardment). The server's `phase` is replicated and every peer draws from `phase_changed`;
`ZonePulse` children act on the server only.
New zone: a scene with a `GroundZone` root, a kind in `SpellSpawner.zones` (`match.tscn`) and a spell with a `ZoneAction` scene.
Zones that bend the land carry `TerrainStamp` children (see `map/terrain/`).
