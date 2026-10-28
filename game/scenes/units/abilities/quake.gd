class_name Quake
extends AbilityEffect

## The Jabberocky's Quake: a stunning wave from its feet. The body prepares (192 ticks), the
## mana is paid when it starts (pays_upfront) and at the shoot tick the effect is added; the cooldown is set then if
## it was 0. No target: the wave leaves the user's feet. What the wave does is QuakeWave's.
## No sound.

## The wave (abilities/quake_wave.tscn), put in the shot container at the user's feet.
@export var wave_scene: PackedScene


func status(_target_pos: Vector3, _target: Node3D) -> String:
	return "" if user != null and ability != null else Refusal.BAD_TARGET


## quake: server (or solo) only. The wave is born on the shoot tick.
func fire(_target_pos: Vector3, _target: Node3D) -> bool:
	if not is_multiplayer_authority() or user == null or wave_scene == null:
		return false
	if DebugLog.on(&"effects"):
		print("quake %s (tick %d)" % [who(user), MatchClock.now()])
	return QuakeWave.launch(wave_scene, user, user.global_position, ability.tag) != null
