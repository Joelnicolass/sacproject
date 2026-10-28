# fx/blood

Bleeding and the hit blink. `BloodFx` (child of every unit, wizard and doctor) decides the wound on the server and
replicates it; every peer then plays the spray and paints the ground marks from the match seed, so all peers paint the same.
`HitFlash` blinks the body's meshes. Nothing here writes the simulation.
Edit: `data/fx/blood/red.tres` (thresholds, marks), `data/fx/blood_hit*.tres`; Options → Jugabilidad → «Sangre» turns it off.
