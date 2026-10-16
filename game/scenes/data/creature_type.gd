class_name CreatureType
extends Resource

@export var tag: String = ""
@export var display_name: String = ""
@export var god: String = ""
@export var model: String = ""
@export var health: int = 0
@export var regeneration_per_s: float = 0.0
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
## shoot0, shoot1 from the SXSK/SKEL: {tag, frames, framerate, shoot_ticks}.
@export var shoot_animations: Array[Dictionary] = []
## Peasant clips (CRE8 animation slots 32/33/35/37, RFC-028c): role -> {tag, frames, framerate}, with roles
## cower, pull, work (dig) and talk_cower. Empty for every creature that is not a peasant.
@export var extra_animations: Dictionary = {}


func is_flying() -> bool:
	return running_speed <= 0.0 and flying_speed > 0.0


func level() -> int:
	return spell_order / 100
