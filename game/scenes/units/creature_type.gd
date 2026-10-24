@tool
class_name CreatureType
extends Resource

@export var tag: String = ""
@export var display_name: String = ""
@export var god: String = ""
@export var model: String = ""
## F335: the HUD icon (the roster, the book). Empty: HudIcons looks for assets/custom/icons/<tag>.png (tools/bake/new_creature.gd draws
## one from the model) and then for the original's. A creature of your own can set it here, in the inspector.
@export var icon: Texture2D
## A scene the creature carries (CreatureFx adds it, tinted with the side's mana color): the Manahoar's mana flame. Empty: none.
@export var carried_fx: PackedScene
@export var health: int = 0
@export var regeneration_per_s: float = 0.0
## Regenerates in any mode that can heal, also walking, fighting and being hit (the Troll); the rest only at rest, once a hit is over.
@export var regenerates_always := false
## CRE8 `drain` (file word / 1000): the AI's rater adds 2x drain to the regeneration (shiny.d:241 `fillStats`).
@export var drain: float = 0.0
@export var running_speed: float = 0.0
@export var flying_speed: float = 0.0
@export var melee_strength: int = 0
@export var melee_accuracy: int = 0
@export var melee_evasion: int = 0
@export var ranged_accuracy: int = 0
@export var aggressiveness: int = 0
@export var sight_range: float = 0.0
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
@export var ability_tags: PackedStringArray = PackedStringArray()
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
## nttData `ranged` (sacobject.d:424 isRanged).
@export var is_ranged := false
## AbilityType tag of the ranged attack (abilities[0] if ranged), "" = melee only.
@export var ranged_attack_tag: String = ""
## AbilityType tag of the active ability (abilities[1] if ranged, else abilities[0]).
@export var active_ability_tag: String = ""
## sacengine passiveOnDamage = abilities[2] (sacobject.d:426): korq (Taurock), ahtf (Firefist), rifl, gcil... "" = none.
## DamagePassive looks it up among its DamagePassiveType resources; a tag without one there does nothing.
@export var passive_on_damage: String = ""
## CRE8 passiveAbility / passiveAbility2 (bytes 440/452, sacobject.d:607-610): goc@ (Cog, Phoenix), cen@ (Necryl),
## tum@ (Mutant, Dragon), eniv... sacengine kill() runs the death clouds among them (state.d:8274-8278); DeathCloudSpawner
## looks each one up in its DeathCloudType resources.
@export var passive_abilities: PackedStringArray = PackedStringArray()
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


func is_flying() -> bool:
	return running_speed <= 0.0 and flying_speed > 0.0


## sacengine canFly && !mustFly (sacobject.d:81-83, 113-115): walks and flies (the hybrids). It flies when that arrives
## first (Flight). A creature that must fly (is_flying) is not a hybrid.
func is_hybrid_flier() -> bool:
	return running_speed > 0.0 and flying_speed > 0.0 and flight_animations.has("fly")


## sacengine takeoffTime (sacobject.d:125-128): takeoff frames / animFPS (30); 0 without a takeoff clip.
func takeoff_time_s() -> float:
	var clip: Dictionary = flight_animations.get("takeoff", {})
	return float(clip.get("frames", 0)) / 30.0


## sacengine landing: the land clip lasts numFrames·updateAnimFactor ticks (state.d:14155-14160); 0 without one.
func land_time_s() -> float:
	var clip: Dictionary = flight_animations.get("land", {})
	return float(clip.get("frames", 0)) / 30.0


func level() -> int:
	return spell_order / 100
