@tool
class_name PhaseSprite
extends MeshInstance3D

## A sprite (a quad that faces the camera, atlas_quad_*.gdshader) that shows only in some phases of its SpellCarrier: the vaporizing shot while it
## is cast and flies, the big heart over a charmed creature while the spirits linger. It can grow when it appears, shrink before it goes (`life_s`) and
## sit over the carrier's target instead of on the carrier. Presentation only: every peer decides from the replicated phase; a headless process
## draws none. It does not move the carrier nor affect the target.
## Ref: sacengine renderCharmHeart, CharmHeart.growTime / shrinkTime / lifetime (renderer.d:2898-2915, state.d:4218-4226).

@export var carrier: SpellCarrier
@export var shown_in: Array[SpellCarrier.Phase] = []
@export_range(0.05, 10.0, 0.05, "suffix:m") var size_m := 1.0
## It grows from nothing in this long when it appears, and (with `life_s`) shrinks to nothing in the same time at the end.
@export_range(0.0, 5.0, 0.01, "suffix:s") var grow_s := 0.0
## 0: it stays while the phase lasts. Above: it goes this long after it appeared.
@export_range(0.0, 60.0, 0.1, "suffix:s") var life_s := 0.0
## It sits over the top of the carrier's target (never on the carrier).
@export var over_target := false

var _age := -1.0


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray() if carrier != null else PackedStringArray(["Falta el SpellCarrier."])


func _ready() -> void:
	visible = false
	set_process(false)
	if Engine.is_editor_hint() or carrier == null or DisplayServer.get_name() == "headless":
		return
	top_level = over_target
	carrier.phase_changed.connect(_on_phase)
	_on_phase(carrier.phase)
	set_process(true)


func _on_phase(now: SpellCarrier.Phase) -> void:
	if shown_in.has(now) and _age < 0.0:
		_age = 0.0
	elif not shown_in.has(now):
		_age = -1.0
		visible = false


func _process(delta: float) -> void:
	if _age < 0.0:
		return
	_age += delta
	if life_s > 0.0 and _age >= life_s + grow_s:
		visible = false
		return
	visible = true
	var grow := 1.0 if grow_s <= 0.0 else clampf(_age / grow_s, 0.0, 1.0)
	var shrink := 1.0 if life_s <= 0.0 or grow_s <= 0.0 else clampf((life_s - _age) / grow_s, 0.0, 1.0)
	scale = Vector3.ONE * size_m * minf(grow, shrink)
	var target := carrier.target_body()
	if over_target and target != null and is_instance_valid(target):
		var box := BodyNudge.box(target)
		global_position = box.get_center() + Vector3(0.0, box.size.y * 0.5 + 0.4 * scale.x, 0.0)
