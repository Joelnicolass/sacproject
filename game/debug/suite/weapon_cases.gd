extends RefCounted

## 055c3 cases of rules_suite: the live bed `debug/units/weapon_swap.tscn` (weapons added, removed and changed in the editor only:
## priority by child order, a weapon turned off or with nothing to fire is skipped, the weapon's own ability wins, the shot look follows
## it, `struck` reaches the container, the active ability comes from its AbilityType) and the arithmetic of a melee swing by hand.
## Prints nothing by itself: rules_suite prints the verdict.

const SWAP_SCENE := preload("res://debug/units/weapon_swap.tscn")
const SwapBed := preload("res://debug/units/weapon_swap.gd")


func run(host: Node3D) -> Dictionary:
	var out := {}
	out["weapon_swap"] = await _swap(host)
	out["melee_swing_rules"] = _swing()
	return out


func _swap(host: Node3D) -> Dictionary:
	var bed := SWAP_SCENE.instantiate() as SwapBed
	host.add_child(bed)
	var report := await bed.run_checks()
	bed.free()
	return report


## The swing of a clip by hand: its blows, the share each carries, the fallback without a clip, the end of the swing.
func _swing() -> Dictionary:
	var swing := MeleeSwing.new()
	swing.begin(ClipFacts.of(null), -1)
	var checks := {
		"fallback_is_24_frames": swing.frames == 24 and is_equal_approx(swing.rate, 30.0),
		"fallback_blow_on_15": swing.blows == PackedInt32Array([15]),
		"pending_is_the_whole_clip": is_equal_approx(swing.pending, 24.0 / 30.0),
		"no_blow_at_start": not swing.blow_due() and not swing.ended(),
	}
	swing.elapsed = 15.0 / 30.0
	checks["blow_due_on_its_frame"] = swing.blow_due()
	swing.next_tick = 1
	checks["one_blow_only"] = not swing.blow_due()
	swing.elapsed = 24.0 / 30.0
	checks["ended_after_the_clip"] = swing.ended()
	var shot := ShotClip.new()
	shot.begin(ClipFacts.of(null))
	checks["shot_without_clip_is_one_frame"] = shot.frames == 1 and shot.shots == PackedInt32Array([0])
	checks["shot_leaves_at_once"] = shot.advance(0.0) == 1 and shot.advance(1.0) == 0
	var verdict := true
	for key in checks:
		verdict = verdict and bool(checks[key])
	return {"ok": verdict, "checks": checks}
