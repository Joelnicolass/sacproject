class_name AiSenses
extends Resource

## How often the AI looks again at what it already knows, in seconds at Normal pace: a body's
## rating, its mana and state, the own wizard's souls and his threat (the groups within
## threat_near_m..threat_far_m of him). The tracks count these in ages (runs of the perception job,
## AiPlay.ages_for), so a difficulty that slows its clock stretches them the same. It does not say
## what the side sees (Vision does). Embedded in each data/ai/tactics_*.tres; never changed while
## playing. The numbers are the original's.

@export_group("How often")
## A creature or a wizard is rated again (16 ages at Normal).
@export_range(0.0, 60.0, 0.0001, "suffix:s") var rerate_s := 1.6
## The mana and state of a body (a Manahoar ready, a structure's owner) (8 ages).
@export_range(0.0, 60.0, 0.0001, "suffix:s") var status_s := 0.8
## The own wizard's soul count (32 ages).
@export_range(0.0, 60.0, 0.0001, "suffix:s") var souls_snapshot_s := 3.2
## The own wizard's threat (8 ages).
@export_range(0.0, 60.0, 0.0001, "suffix:s") var threat_s := 0.8

@export_group("Threat")
## The groups between these two distances of the wizard weigh in his threat (1 at near, falling to
## 0 at far).
@export var threat_near_m := 10.0
## See threat_near_m.
@export var threat_far_m := 280.0

@export_group("Minimap")
## With AiDifficulty.Knowledge.SIGHT_AND_MAP: the AI knows where the bodies within this flat
## distance of its wizard are (never their health or mana), as a human reads them on the minimap.
## Equal to the minimap's starting view radius (data/ui/minimap/view.tres,
## MinimapView.view_radius_m); ai_knowledge_cases compares the two. It also bounds the foe creatures
## of the first scan.
@export_range(0.0, 2000.0, 1.0, "suffix:m") var map_sight_m := 216.0
