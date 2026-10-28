# spells/drops

What a cloud lets go (frogs, fire, plague, meteorites, lava balls). A `ZoneDrop` falls, lands or sticks to a body, and its
children say what happens (`DropBlast`, `DropPoison`, `FrogHop`, `DropDent`). The server moves it; every peer draws it.
New drop: a scene with a `ZoneDrop` root, a kind in `SpellSpawner.projectiles` and a `DropLauncher` in a cloud.
