# spells/walls

The five walls (Firewall, Wall of Spikes, Wailing Wall, Vinewall, Fence). `SpellWall` grows both ends from the click,
rises, stands and sinks; the server replicates its age and ends and every peer derives the height. `WallTouch` is what it
does to bodies inside; the other children are the look. Another wall = another `SpellWall` scene with other children,
added to `SpellSpawner.zones` in `match.tscn`.
