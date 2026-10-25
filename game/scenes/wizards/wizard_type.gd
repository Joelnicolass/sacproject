class_name WizardType
extends Resource

@export var tag: String = ""
@export var spell_tag: String = ""
@export var display_name: String = ""
@export var model: String = ""
@export var health: int = 0
@export var mana: int = 0
@export var running_speed: float = 0.0
@export var regeneration_per_s: float = 0.0
@export var melee_evasion: int = 0
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
## F138 (RFC-030i-c): knock and get_up clips (WIZD slots 9, 10), role -> {tag, frames, framerate}, like
## CreatureType.stun_animations. A stunned wizard lies (knock + get_up)·2 ticks (state.d:8138-8146, 14170-14212).
@export var stun_animations: Dictionary = {}
## RFC-023 023d: the spellcast loops, role -> {tag, frames, framerate}: `cast` (standing, WIZD slot 27) and `run_cast` (moving,
## slot 30). Presentation only: the cast lasts what the spell says, not the clip.
@export var cast_animations: Dictionary = {}

## Lobby (055i-a): false takes this wizard out of the menu and the rooms without deleting the file.
@export var offered := true


## The id of this wizard on the network and in the catalog: its `tag`, or the file name when the tag is empty (new content).
func id() -> String:
	return tag if not tag.is_empty() else resource_path.get_file().get_basename()
