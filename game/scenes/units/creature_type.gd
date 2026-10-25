@tool
class_name CreatureType
extends Resource

@export var tag: String = ""
@export var display_name: String = ""
@export var model: String = ""
## The picture of the creature in the roster, the book and the info box. Drag any PNG here to change it. A creature of your own gets one
## drawn from its model (tools/bake/creature_icon.gd); the original's come from tools/bake/fill_type_icons.gd. Empty: the tag is written.
@export var icon: Texture2D
## What the creature sounds like: its voice, swing, hurt and death (data/audio/creatures/<name>.tres). Empty: silent, but
## its summon sound (UnitSounds.summon) still plays.
@export var sounds: SoundSet
## A scene the creature carries (CreatureFx adds it, tinted with the side's mana color): the Manahoar's mana flame. Empty: none.
@export var carried_fx: PackedScene
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
@export var sight_m: float = 0.0
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
## A villager: gets the peasant scene (it digs, cowers and holds a grudge) and never attacks (PeasantBehavior).
@export var peasant := false
## stance1 (slot 0): the rest pose sacengine plays between gestures (state.d:7957-7992). RFC-023: the idle role plays it.
@export var stance_animation: Dictionary = {}
## idle0 from SXSK/SKEL: baseline breathing/stance loop for presentation timing.
@export var idle_animation: Dictionary = {}
## run from SXSK/SKEL: locomotion loop (most creatures use this while moving).
@export var run_animation: Dictionary = {}
## walk from SXSK/SKEL: only differs from run on some creatures (e.g. Eldred in sacengine).
@export var walk_animation: Dictionary = {}
## attack0..attack2 from the SXSK/SKEL: {tag, frames, framerate, attack_ticks}. Empty dict = missing.
@export var melee_animations: Array[Dictionary] = []
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
## shoot0, shoot1 from the SXSK/SKEL: {tag, frames, framerate, shoot_ticks}.
@export var shoot_animations: Array[Dictionary] = []
## Peasant clips (CRE8 animation slots 32/33/35/37, RFC-028c): role -> {tag, frames, framerate}, with roles
## cower, pull, work (dig) and talk_cower. Empty for every creature that is not a peasant.
@export var extra_animations: Dictionary = {}
## F116 (RFC-030e): takeoff, fly and land clips (CRE8 slots 32-34) as sacengine loads them: a slot that repeats stance1
## or ends in "00" is left out (Phoenix has only fly; Rhinok none). role -> {tag, frames, framerate}.
@export var flight_animations: Dictionary = {}
## RFC-023f: hover joins them (slot 38, the pose in the air; a hybrid flier idles on it). role -> {tag, frames, framerate}.
## F120 (RFC-030i-a): knock, get_up and fly_damage clips (CRE8 slots 9, 10, 35) by the same rule: role -> {tag, frames,
## framerate}. Stunned lasts (knock + get_up)·2 ticks on the ground and fly_damage·2 in the air (state.d:8138-8150, 14170-14212).
## Peasants have no fly_damage (slot 35 is their dig).
@export var stun_animations: Dictionary = {}
## RFC-023f: the dying clips (death0 at slot 19, flyDeath at 36 for a body in the air): role "death" / "fly_death" ->
## {tag, frames, framerate}. A role the SXSK has no clip for is left out (the corpse then tips over with a Tween).
@export var death_animations: Dictionary = {}
## RFC-023 023e: what the creature plays while a Sac Doctor holds it (CreatureMode.thrashing, CRE8 slots 46, 49, 25): rise
## (once), held (float2Thrash, once) and thrash (loop), by the same rule: role -> {tag, frames, framerate}.
@export var captive_animations: Dictionary = {}


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
	return run_speed_m_s > 0.0 and fly_speed_m_s > 0.0 and flight_animations.has("fly")


## sacengine takeoffTime (sacobject.d:125-128): takeoff frames / animFPS (30); 0 without a takeoff clip.
func takeoff_time_s() -> float:
	var clip: Dictionary = flight_animations.get("takeoff", {})
	return float(clip.get("frames", 0)) / 30.0


## sacengine landing: the land clip lasts numFrames·updateAnimFactor ticks (state.d:14155-14160); 0 without one.
func land_time_s() -> float:
	var clip: Dictionary = flight_animations.get("land", {})
	return float(clip.get("frames", 0)) / 30.0


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
