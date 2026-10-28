# sacrifice

The sacrifice ritual: a Sac Doctor drops from a vortex, carries a creature to the site and four doctors run the ritual.
Entry point: `sacrifice_system.tscn` (its children `Spawns`, `Targets`, `Casts`, `Starter` do the work). `Ritual` and
the doctor are replicated actors. Its places (ring, push, reach, vortex) are nodes of `sacrifice_places.tscn`; times are
in `data/match_rules.tres`.
