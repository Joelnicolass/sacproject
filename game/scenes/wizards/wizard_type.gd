class_name WizardType
extends Resource

@export var tag: String = ""
@export var display_name: String = ""
## The body the wizard wears: its size, capsule and sockets (scenes/wizards/bodies/<name>.tscn, a BodyFrame). Drag the scene here.
## Its look (model, sounds) is the `<name>_look.tscn` behind the placeholder of that scene: a client builds it, the server never does.
@export var body: PackedScene
## What the model plays and how long each role lasts (scenes/bodies/models/<model>_clips.tres): the same library the body draws,
## read by the rules through ClipFacts.
@export var clips: AnimationLibrary
@export var health: int = 0
@export var mana: int = 0
## How fast the wizard runs, in metres per second.
@export var run_speed_m_s: float = 0.0
@export var regeneration_per_s: float = 0.0
## How well he dodges blows; 1.0 is a normal creature, 1.25 is what a wizard is.
@export_range(0.0, 5.0, 0.001) var melee_evasion := 0.0
@export var melee_resistance: float = 1.0
@export var direct_spell_resistance: float = 1.0
@export var splash_spell_resistance: float = 1.0
@export var direct_ranged_resistance: float = 1.0
@export var splash_ranged_resistance: float = 1.0

## Lobby (055i-a): false takes this wizard out of the menu and the rooms without deleting the file.
@export var offered := true


## What the rules know about the clips of his model: how long each role lasts (knock, get_up, death, ghost_rise, unghost...).
## Built once per library.
func clip_facts() -> ClipFacts:
	return ClipFacts.of(clips)


## The clips he can die with, in order (death, death2, death3): those his model has. He plays one of them, picked at random.
func death_roles() -> Array[StringName]:
	var found: Array[StringName] = []
	for role: StringName in [&"death", &"death2", &"death3"]:
		if clip_facts().has(role):
			found.append(role)
	return found


## The evasion as the whole thousandths the simulation counts in (1.25 -> 1250): exact for any value with up to three decimals.
func melee_evasion_milli() -> int:
	return roundi(melee_evasion * 1000.0)


## The model id that travels with the wizard on the network (the pick, the replicated body): the one saved in his body scene.
func model_id() -> String:
	return BodyFacts.of(body).model_id


## The id of this wizard on the network and in the catalog: its `tag`, or the file name when the tag is empty (new content).
func id() -> String:
	return tag if not tag.is_empty() else resource_path.get_file().get_basename()
