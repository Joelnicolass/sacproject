# structures/reveal
What: `BuildReveal` (`build_reveal.tscn`): while a cast tower rises, a line climbs from its base to its top with `CastTower.build_progress` (0 to 1); the tower is whole below it and dissolves with noise and a glowing edge above it; when it is done the tower's own materials come back.
Not: when or how fast the tower rises, nor whether it can be hit while it does (StructureAction, CastTower); it changes nothing of the match and does nothing in a headless process.
Talks to: reads `tower.build_progress` (replicated) and swaps the surface materials of the MeshInstance3D under `visuals` for copies of `build_reveal.gdshader`.
Edit: open `build_reveal.tscn` (edge colour, energy, band width in metres, the noise texture and its scale, the glowing part); a tower scene instances it with `tower` = its root and `visuals` = its `Visuals`.
Check: `debug/spells/manalith_build_area.tscn` (F6, cast the Manalith and watch it rise) · flow `agent/flows/f388_build_area.json` (shots `f388_04` to `f388_08`).
