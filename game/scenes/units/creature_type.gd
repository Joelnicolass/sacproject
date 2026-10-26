@tool
class_name CreatureType
extends Resource

@export var tag: String = ""
@export var display_name: String = ""
## The body the creature wears: its size, capsule and sockets (scenes/units/bodies/<name>.tscn, a BodyFrame). Drag the scene here.
## Its look (model, sounds, carried effect) is the `<name>_look.tscn` behind the placeholder of that scene: a client builds it, the server never does.
@export var body: PackedScene
## What the model plays and how long each role lasts (scenes/bodies/models/<model>_clips.tres): the same library the body draws,
## read by the rules through ClipFacts.
@export var clips: AnimationLibrary
## The picture of the creature in the roster, the book and the info box. Drag any PNG here to change it. A creature of your own gets one
## drawn from its model (tools/bake/creature_icon.gd); the original's come from tools/bake/fill_type_icons.gd. Empty: the tag is written.
@export var icon: Texture2D
@export var health: int = 0
@export var regeneration_per_s: float = 0.0
## Regenerates in any mode that can heal, also walking, fighting and being hit (the Troll); the rest only at rest, once a hit is over.
@export var regenerates_always := false
## CRE8 `drain` (file word / 1000): the AI's rater adds 2x drain to the regeneration (shiny.d:241 `fillStats`).
@export var drain: float = 0.0
@export var run_speed_m_s: float = 0.0
@export var fly_speed_m_s: float = 0.0
@export var melee_strength: int = 0
## Scales where 1.0 is a normal creature: blows that land, blows dodged, aim and readiness to fight (aggressiveness 0 = a pacifist).
@export_range(0.0, 5.0, 0.001) var melee_accuracy := 0.0
@export_range(0.0, 5.0, 0.001) var melee_evasion := 0.0
@export_range(0.0, 5.0, 0.001) var ranged_accuracy := 0.0
@export_range(0.0, 5.0, 0.001) var aggressiveness := 0.0
@export_group("Senses")
## How far it sees, in metres: the range of its Vision (units/vision/). The cylinder in the viewport follows it.
@export var vision_m: float = 0.0
@export_group("")
@export var melee_resistance: float = 1.0
@export var direct_spell_resistance: float = 1.0
@export var splash_spell_resistance: float = 1.0
@export var direct_ranged_resistance: float = 1.0
@export var splash_ranged_resistance: float = 1.0
@export var mana: int = 0
@export var mana_cost: int = 0
@export var souls: int = 0
@export var cooldown_s: float = 0.0
@export var casting_time_s: float = 0.0
@export var spell_order: int = 0
## Widens the box of its melee swing (the Druid is 1.3); 1 = the creature's own box.
@export var melee_width_scale := 1.0
## A villager: gets the villager scene (it digs, cowers and holds a grudge) and never attacks (VillagerBrain).
@export var peasant := false
@export_group("Abilities")
## The ranged attack of the creature (data/catalog/abilities/), or empty for one that only fights in melee.
@export var ranged_attack: AbilityType
## The ability the player triggers with Ctrl+Q while the creature is selected (Rhinok's halo, Dragon's breath of life), or empty.
@export var active_ability: AbilityType
## What happens to the creature when it is hurt (Taurock's hide, Firefist's fury, Phoenix's shield, Storm Giant's charge), or empty.
## DamagePassive, FireShield and LightningCharge are the components that act on it; a passive no component knows does nothing.
@export var on_damage: AbilityType
## What the creature does without being asked: the clouds it leaves when it dies (Cog, Necryl, Mutant) and the effects its blows
## add (Yeti's freeze, Dragon's vines). DeathCloudSpawner and MeleeOnHit walk this list.
@export var passives: Array[CreaturePassive] = []
@export_group("")


## The model id that travels with the creature on the network (what the original calls its body): the one saved in its body scene.
func model_id() -> String:
	return BodyFacts.of(body).model_id


## The id of this creature on the network and in the catalog: its `tag`, or the file name when the tag is empty (new content).
func id() -> String:
	return tag if not tag.is_empty() else resource_path.get_file().get_basename()


## True when the creature has a ranged attack.
func is_ranged() -> bool:
	return ranged_attack != null


## The abilities the creature has, in the order the AI rates them: ranged attack, active ability, on-damage passive. An empty slot is left out.
func abilities() -> Array[AbilityType]:
	var found: Array[AbilityType] = []
	for slot: AbilityType in [ranged_attack, active_ability, on_damage]:
		if slot != null:
			found.append(slot)
	return found


func is_flying() -> bool:
	return run_speed_m_s <= 0.0 and fly_speed_m_s > 0.0


## sacengine canFly && !mustFly (sacobject.d:81-83, 113-115): walks and flies (the hybrids). It flies when that arrives
## first (Flight). A creature that must fly (is_flying) is not a hybrid.
func is_hybrid_flier() -> bool:
	return run_speed_m_s > 0.0 and fly_speed_m_s > 0.0 and clip_facts().has(&"fly")


## What the rules know about the clips of its model: how long each role lasts and where its blow lands. Built once per library.
func clip_facts() -> ClipFacts:
	return ClipFacts.of(clips)


## The scales below as the whole thousandths the simulation counts in (1.1 -> 1100): exact for any value with up to three decimals.
func melee_accuracy_milli() -> int:
	return roundi(melee_accuracy * 1000.0)


func melee_evasion_milli() -> int:
	return roundi(melee_evasion * 1000.0)


func ranged_accuracy_milli() -> int:
	return roundi(ranged_accuracy * 1000.0)


func level() -> int:
	return spell_order / 100


## The icon of the type a creature body runs on (its `type`, as UnitBody and DoctorBody have), or null.
static func icon_of(body: Node) -> Texture2D:
	var type: CreatureType = body.get("type")
	return type.icon if type else null
