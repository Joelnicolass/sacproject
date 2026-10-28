@tool
class_name SprayMarks
extends Node

## A creature that bursts leaves a pool of blood: when one of `sprays` plays (the gib's spray, on
## every peer), `marks` marks of `blood.mark` are painted on the ground within `radius_m` of it. One
## per match, next to DamageNumbers. The marks are drawn from the match seed and the burst's place,
## so every peer paints the same pool.
## Presentation only: nothing headless (the dedicated server), never a write to the simulation.
## What it does not do: decide who bursts (Gib), throw the spray (FxBus) or own the marks
## (GroundScars).

## The bursts that leave a pool (scenes/fx/effects/blood.tres).
@export var sprays: Array[ParticleType] = []
## Whose mark is painted (scenes/fx/effects/blood/red.tres).
@export var blood: BloodType:
	set(value):
		blood = value
		update_configuration_warnings()
## The player's «Sangre» (scenes/ui/feel_prefs.tres): off, nothing shows.
@export var prefs: FeelPrefs:
	set(value):
		prefs = value
		update_configuration_warnings()
@export_range(0, 64) var marks := 12
@export_range(0.0, 20.0, 0.1, "suffix:m") var radius_m := 4.0
## No mark when the ground is this far under the burst (it bursts at the body's center, over a hole
## it paints nothing).
@export_range(0.0, 20.0, 0.1, "suffix:m") var max_height_m := 4.0

## How many marks were painted (the checks read it).
var painted := 0

var _active := false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_active = BodyLook.loads_meshes()
	if not _active:
		return
	FxBus.played.connect(_on_played)


## False headless, or with «Sangre» off.
func is_active() -> bool:
	return _active and (prefs == null or prefs.blood())


func _on_played(kind: StringName, fx: Resource, at: Vector3) -> void:
	if kind != FxBus.KIND_BURST or not is_active() or blood == null or blood.mark == null:
		return
	if not sprays.has(fx as ParticleType):
		return
	var scars := GroundScars.of(self)
	if scars == null:
		return
	for point in BloodRules.mark_points(at, marks, radius_m, MatchSeed.rng(["spray_marks", at])):
		if scars.stamp(blood.mark, point, max_height_m):
			painted += 1


func _get_configuration_warnings() -> PackedStringArray:
	var out := PackedStringArray()
	if blood == null:
		out.append("Assign `blood` (scenes/fx/effects/blood/red.tres).")
	var prefs_warning := FeelPrefs.socket_warning(prefs)
	if not prefs_warning.is_empty():
		out.append(prefs_warning)
	return out
