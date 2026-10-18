extends StaticBody3D

## One placed structure instance (server-spawned, replicated through StructureSpawner).

const _MANA_SOURCE := preload("res://scenes/world/mana_source.gd")
const MANALITH := "htlm"
const FALLBACK_STRUCTURE_MODEL := "mana"
## sacengine BLDG regeneration for manalith/shrine is 75 per minute (1.25 per second).
const MANALITH_REGEN_PER_S := 1.25
## Matches the original structure's long time-to-kill in fights.
const MANALITH_MAX_HEALTH := 3000.0

@export var rules: MatchRules
@export var model := "":
	set(value):
		model = value
		_apply_model()
@export var owner_slot := 0
@export var spell_tag := "":
	set(value):
		spell_tag = value
		_apply_source()
		_apply_health()
## Path to the occupied map manafount; empty for non-fount structures.
@export var manafount_path := NodePath()
## RFC-028b: the bar StructureInspector shows over the model when the structure is clicked.
@export var health_bar: Node3D

var _regen_per_s := 0.0
var _released := false

@onready var _health: Node = $Health


func _ready() -> void:
	add_to_group("structure")
	_apply_model()
	_apply_source()
	_apply_health()
	if MpKit.is_networked() and not MpKit.is_server():
		set_physics_process(false)
	if _health:
		_health.died.connect(_on_died)
	if health_bar and _health:
		health_bar.call("bind", _health, owner_slot)
		_place_bar()
	if spell_tag == MANALITH:
		_claim_manafount()


func _exit_tree() -> void:
	_release_manafount()


func _apply_model() -> void:
	var mesh := get_node_or_null("Mesh")
	if mesh == null or not mesh.has_method("show_model"):
		return
	var visible_model := _resolved_model()
	if visible_model.is_empty():
		push_warning("Structure model '%s' is missing from data/catalog/body_sizes/ (BodySize). Visual uses placeholder." % model)
		mesh.call("show_model", model)
		return
	mesh.call("show_model", visible_model)
	var height := float(mesh.call("body_height"))
	var radius := maxf(1.0, float(mesh.call("body_radius")))
	var col := get_node_or_null("Collision") as CollisionShape3D
	if col == null:
		return
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = maxf(1.0, height)
	col.shape = shape
	col.position.y = shape.height * 0.5
	_place_bar()


func _place_bar() -> void:
	var col := get_node_or_null("Collision") as CollisionShape3D
	if health_bar == null or col == null or not (col.shape is CylinderShape3D):
		return
	health_bar.call("place_above", col.position.y + (col.shape as CylinderShape3D).height * 0.5)


func _fallback_model() -> String:
	if BodyLibrary.has_model(FALLBACK_STRUCTURE_MODEL):
		return FALLBACK_STRUCTURE_MODEL
	return model


func _resolved_model() -> String:
	if BodyLibrary.has_model(model):
		return model
	var fallback := _fallback_model()
	if BodyLibrary.has_model(fallback):
		return fallback
	return ""


func _apply_source() -> void:
	var source := get_node_or_null("ManaSource")
	if source == null:
		return
	source.set("owner_slot", owner_slot)
	source.set("rules", rules)
	if spell_tag == MANALITH:
		source.set("kind", _MANA_SOURCE.Kind.CUSTOM)
		source.set("rate", rules.manafount_rate if rules else 33.333)
		source.set("radius", rules.manafount_radius if rules else 50.0)
		source.set("target_groups", PackedStringArray(["wizard", "unit"]))
	else:
		source.set("kind", _MANA_SOURCE.Kind.CUSTOM)
		source.set("rate", 0.0)


func _apply_health() -> void:
	if _health == null:
		return
	## Clients get maximum and current from the synchronizer; setting them here would overwrite
	## the spawn state of a structure that is already damaged when the client joins.
	if MpKit.is_networked() and not MpKit.is_server():
		return
	var max_health := 1.0
	_regen_per_s = 0.0
	if spell_tag == MANALITH:
		max_health = MANALITH_MAX_HEALTH
		_regen_per_s = MANALITH_REGEN_PER_S
	if _health.has_method("setup"):
		_health.call("setup", max_health)
	else:
		_health.set("maximum", max_health)
		_health.set("current", max_health)


func _physics_process(delta: float) -> void:
	if _health == null or _regen_per_s <= 0.0:
		return
	if bool(_health.call("is_dead")) or bool(_health.call("is_full")):
		return
	_health.call("heal", _regen_per_s * delta)


func is_targetable() -> bool:
	return _health != null and not bool(_health.call("is_dead"))


func is_dead() -> bool:
	return _health != null and bool(_health.call("is_dead"))


func _on_died(_from_slot: int) -> void:
	_release_manafount()
	queue_free()


func _claim_manafount() -> void:
	var fount := _manafount()
	if fount == null:
		return
	var path := get_path()
	if fount.has_method("occupy"):
		fount.call("occupy", path)


func _release_manafount() -> void:
	if _released:
		return
	_released = true
	var fount := _manafount()
	if fount == null:
		return
	if fount.has_method("release"):
		fount.call("release", get_path())


func _manafount() -> Node:
	return get_node_or_null(manafount_path) if not manafount_path.is_empty() else null
