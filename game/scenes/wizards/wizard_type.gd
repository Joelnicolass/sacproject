class_name WizardType
extends Resource

@export var tag: String = ""
@export var display_name: String = ""
@export var model: String = ""
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
## RFC-023 023d: the rest pose (stance1, WIZD slot 0). idle_animation (idle0) is the gesture played now and then on top of it.
@export var stance_animation: Dictionary = {}
## idle0/run/walk from SXSK/SKEL: locomotion/idle timing for local pose playback.
@export var idle_animation: Dictionary = {}
@export var run_animation: Dictionary = {}
@export var walk_animation: Dictionary = {}
## Animation frames at 30 fps (death0..2, corpseRise, float2Stance): how long dying,
## turning into a ghost and turning back last (state.d:14000, 14081, 14091).
@export var death_frames: PackedInt32Array = PackedInt32Array()
@export var corpse_rise_frames: int = 0
@export var float_to_stance_frames: int = 0

## What the wizard sounds like: damaged, incantation, death, ghost (data/audio/wizards/<name>.tres). Empty: silent.
@export var sounds: SoundSet

## F138 (RFC-030i-c): knock and get_up clips (WIZD slots 9, 10), role -> {tag, frames, framerate}, like
## CreatureType.stun_animations. A stunned wizard lies (knock + get_up)·2 ticks (state.d:8138-8146, 14170-14212).
@export var stun_animations: Dictionary = {}
## RFC-023 023d: the spellcast loops, role -> {tag, frames, framerate}: `cast` (standing, WIZD slot 27) and `run_cast` (moving,
## slot 30). Presentation only: the cast lasts what the spell says, not the clip.
@export var cast_animations: Dictionary = {}

## Lobby (055i-a): false takes this wizard out of the menu and the rooms without deleting the file.
@export var offered := true


## The evasion as the whole thousandths the simulation counts in (1.25 -> 1250): exact for any value with up to three decimals.
func melee_evasion_milli() -> int:
	return roundi(melee_evasion * 1000.0)


## The id of this wizard on the network and in the catalog: its `tag`, or the file name when the tag is empty (new content).
func id() -> String:
	return tag if not tag.is_empty() else resource_path.get_file().get_basename()
