@tool
class_name CarryRope
extends Node3D

## What joins a Sac Doctor to the creature it carries (sacengine SacDocTether + needle sparks, state.d:15556-15613):
## a rope (`tether`) from the needle to the center of the creature's ring, and sparks at the needle tip.
## Local presentation on every peer, drawn from replicated state only: `doctor.carried` (the creature's
## path) and the creature's own ring (Captive.portal, which exists while it is held). It changes no
## simulation. The dedicated server draws nothing. Remove the node from doctor.tscn to switch it off.

@export var doctor: DoctorBody
## Where the needle tip is, in the doctor's model. ESTIMADO: sacengine uses bone 16 of `sacd` with the
## offset (0, 0, 2.2) (sacobject.d:360-366); the port animates by meshes per frame, without a skeleton,
## so this marker is placed by eye at the syringe. Move it in doctor.tscn.
@export var needle: Marker3D
@export var tether: Tether
@export_group("Needle sparks")
## Sparks at the needle tip (data/fx/needle.tres). Empty = none. sacengine: 2 per tick (120/s).
@export var spark_type: ParticleType
## Seconds between bursts of `spark_count`. 120/s in the original; bursts of 4 every 1/30 s are about as many.
@export_range(0.01, 1.0, 0.0001, "suffix:s") var spark_period_s := 0.0333

var _spark_left := 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if not BodyLook.loads_meshes():
		set_process(false)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if doctor == null:
		warnings.append("Asigná en `doctor` el DoctorBody que lleva a la criatura.")
	if needle == null:
		warnings.append("Asigná en `needle` el Marker3D de la punta de la aguja.")
	if tether == null:
		warnings.append("Asigná en `tether` la cuerda (scenes/fx/tether.tscn).")
	return warnings


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or doctor == null or tether == null:
		return
	var portal := _portal()
	if portal == null:
		tether.end = null
		return
	tether.end = portal
	_spark(delta)


## The ring of the creature this doctor carries, or null.
func _portal() -> Node3D:
	if doctor.carried.is_empty():
		return null
	var creature := doctor.get_node_or_null(doctor.carried) as UnitBody
	if creature == null:
		return null
	var captive := Captive.of(creature)
	if captive == null or not captive.is_held() or captive.portal == null or not is_instance_valid(captive.portal):
		return null
	return captive.portal


func _spark(delta: float) -> void:
	if spark_type == null or needle == null:
		return
	_spark_left -= delta
	if _spark_left > 0.0:
		return
	_spark_left = spark_period_s
	var emitter: SpriteParticles = preload("res://scenes/fx/sprite_particles.tscn").instantiate()
	emitter.type = spark_type
	## The sparks stay where they were born, not on the doctor.
	var host := get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	host.add_child(emitter)
	emitter.global_position = needle.global_position
	emitter.direction = (needle.global_basis * tether.start_axis).normalized()
