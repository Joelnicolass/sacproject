class_name AiSenses
extends Resource

## How often the AI looks again at what it already knows, in seconds at Normal pace: a body's rating, its mana and state, the own
## wizard's souls and his threat (the groups within threat_near_m..threat_far_m of him). The tracks count these in ages (runs of the
## perception job, AiPlay.ages_for), so a difficulty that slows its clock stretches them the same. It does not say what the side
## sees (Vision does). Embedded in each data/ai/tactics_*.tres; never changed while playing.
## Ref: shiny.d:1044, 1053, 1065-1072, 1080, 1089, 1095 (16, 8, 32 and 8 ages of 6 ticks). Según [S].

@export_group("Cada cuánto")
## A creature or a wizard is rated again.
@export_range(0.0, 60.0, 0.0001, "suffix:s") var rerate_s := 1.6
## The mana and state of a body (a Manahoar ready, a structure's owner).
@export_range(0.0, 60.0, 0.0001, "suffix:s") var status_s := 0.8
## The own wizard's soul count.
@export_range(0.0, 60.0, 0.0001, "suffix:s") var souls_snapshot_s := 3.2
## The own wizard's threat.
@export_range(0.0, 60.0, 0.0001, "suffix:s") var threat_s := 0.8

@export_group("Amenaza")
## The groups between these two distances of the wizard weigh in his threat (1 at near, falling to 0 at far).
@export var threat_near_m := 10.0
@export var threat_far_m := 280.0
