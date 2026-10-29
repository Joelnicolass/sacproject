# spells/stalks

Meanstalks: a `GroundZone` (`meanstalks.tscn`) with four `Stalk` children that catch, lift and throw bodies. Each stalk
writes only its own tip, growth and mode; the tube is drawn by `stalk.gdshader` from those replicated values.
One more stalk = one more `Stalk` child with its `index`, the spell's `ring_count` and its `synced` paths.
