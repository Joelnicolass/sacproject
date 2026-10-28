# look

How a map looks for a god. `look_rig.tscn` (the map's `Look` node) hands the god's `LookProfile` (`data/look/<god>.tres`)
and the quality preset to its layers (sun, ground, environment, grass, flora, lights, atmosphere…). Each layer is the
only writer of its object.
In the editor, select a map's `Look` and set `Preview god` to see that god's look live (the running game ignores it).
Normal maps: each material in `scenes/bodies/materials/` owns its own; `SurfaceReliefLayer` is the one global switch.
