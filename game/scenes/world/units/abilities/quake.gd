class_name QuakeAbility
extends AbilityEffect

## F132 (RFC-030 030u-a): the Jabberocky's Quake (kauq). sacengine useAbility → act() (state.d:13495-13510): shoot0 (192 ticks), the
## mana is paid when it starts (pays_upfront) and at the shoot tick quake (13204-13207) adds the effect; the cooldown is set then if
## it was 0. No target: the wave leaves the user's feet. What the wave does is QuakeWave's.
## Divergence (declared): none in the rule; no sound.

## The wave (abilities/quake_wave.tscn), put in the shot container at the user's feet.
@export var wave_scene: PackedScene


func status(_target_pos: Vector3, _target: Node3D) -> String:
	return "" if user != null and ability != null else ActiveAbility.BAD_TARGET


## quake: server (or solo) only. The wave is born on the shoot tick.
func fire(_target_pos: Vector3, _target: Node3D) -> bool:
	if not _has_authority() or user == null or wave_scene == null:
		return false
	if DebugLog.on(&"effects"):
		print("sacudida %s (tick %d)" % [who(user), MatchClock.now()])
	return QuakeWave.launch(wave_scene, user, user.global_position, ability.tag) != null
