@tool
class_name SacrificeSpawns
extends Node

## Builds and replicates what the sacrifice puts in the world: the doctors, the red vortices and the rituals. Each has its
## MultiplayerSpawner and its root (they stay where the network paths expect them) and one counter that names its nodes
## (Doctor%d, Vortex%d, Ritual%d). The server (or solo) spawns; clients only receive through the spawners.
## What it does not do: decide where or when something spawns (SacrificeCasts and RitualStarter do) or hold the rules.

const CARRIER := preload("res://scenes/sacrifice/carrier_doctor.tscn")
const RITUAL_DOCTOR := preload("res://scenes/sacrifice/ritual_doctor.tscn")
const RITUAL := preload("res://scenes/sacrifice/ritual.tscn")
const VORTEX := preload("res://scenes/sacrifice/red_vortex.tscn")

## The system that owns the rules the new nodes get.
@export var system: SacrificeSystem
@export var doctors_root: Node3D
@export var doctor_spawner: MpSpawner
@export var vortices_root: Node3D
@export var vortex_spawner: MpSpawner
@export var rituals_root: Node3D
@export var ritual_spawner: MpSpawner

var _doctor_serial := 0
var _vortex_serial := 0
var _ritual_serial := 0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	doctor_spawner.spawn_function = _make_doctor
	vortex_spawner.spawn_function = _make_vortex
	ritual_spawner.spawn_function = _make_ritual


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if system == null:
		warnings.append("Assign `system` (the SacrificeSystem that gives the rules).")
	if doctors_root == null:
		warnings.append("Assign `doctors_root` (the Node3D where the doctors spawn).")
	if doctor_spawner == null:
		warnings.append("Assign `doctor_spawner` (the MpSpawner of carrier_doctor.tscn).")
	if vortices_root == null:
		warnings.append("Assign `vortices_root` (the Node3D where the vortices spawn).")
	if vortex_spawner == null:
		warnings.append("Assign `vortex_spawner` (the MpSpawner of red_vortex.tscn).")
	if rituals_root == null:
		warnings.append("Assign `rituals_root` (the Node3D where the rituals spawn).")
	if ritual_spawner == null:
		warnings.append("Assign `ritual_spawner` (the MpSpawner of ritual.tscn).")
	return warnings


## Does this peer run the simulation (solo, or the server of a networked match)? The sacrifice asks here instead of the network kit.
func simulates() -> bool:
	return not MpKit.is_networked() or MpKit.is_server()


## The name the next doctor gets (counts every doctor, carrier or ring).
func next_doctor_name() -> String:
	_doctor_serial += 1
	return "Doctor%d" % _doctor_serial


## The name the next ritual gets.
func next_ritual_name() -> String:
	_ritual_serial += 1
	return "Ritual%d" % _ritual_serial


func spawn_vortex(at: Vector3, life_s: float) -> RedVortex:
	_vortex_serial += 1
	var data := {
		"name": "Vortex%d" % _vortex_serial, "x": at.x, "y": at.y, "z": at.z, "life": life_s
	}
	if MpKit.is_networked():
		if not MpKit.is_server():
			return null
		return vortex_spawner.spawn(data) as RedVortex
	var vortex := _make_vortex(data) as RedVortex
	vortices_root.add_child(vortex)
	return vortex


func spawn_doctor(data: Dictionary) -> DoctorBody:
	if MpKit.is_networked():
		if not MpKit.is_server():
			return null
		return doctor_spawner.spawn(data) as DoctorBody
	var doctor := _make_doctor(data) as DoctorBody
	doctors_root.add_child(doctor)
	return doctor


func spawn_ritual(data: Dictionary) -> Ritual:
	if MpKit.is_networked():
		if not MpKit.is_server():
			return null
		return ritual_spawner.spawn(data) as Ritual
	var ritual := _make_ritual(data) as Ritual
	rituals_root.add_child(ritual)
	return ritual


func _make_vortex(data: Variant) -> Node:
	var info: Dictionary = data
	var vortex := VORTEX.instantiate() as RedVortex
	vortex.name = str(info["name"])
	vortex.position = Vector3(float(info["x"]), float(info["y"]), float(info["z"]))
	vortex.max_life_s = float(info.get("life", 0.0))
	return vortex


func _make_ritual(data: Variant) -> Node:
	var info: Dictionary = data
	var ritual := RITUAL.instantiate() as Ritual
	ritual.name = str(info["name"])
	ritual.position = Vector3(float(info["x"]), float(info["y"]), float(info["z"]))
	ritual.kind = int(info.get("kind", 0)) as Ritual.Kind
	ritual.caster_slot = int(info.get("caster", 0))
	ritual.target_slot = int(info.get("target", 0))
	ritual.creature_path = NodePath(str(info.get("creature", "")))
	ritual.rules = system.active_rules()
	# The ritual asks its system what a finished Convert announces. set() until the ritual declares `system`.
	ritual.set(&"system", system)
	return ritual


func _make_doctor(data: Variant) -> Node:
	var info: Dictionary = data
	var scene := RITUAL_DOCTOR if bool(info.get("ritual", false)) else CARRIER
	var doctor := scene.instantiate() as DoctorBody
	doctor.name = str(info["name"])
	doctor.owner_slot = int(info.get("slot", 0))
	doctor.rules = system.active_rules()
	doctor.position = Vector3(float(info["x"]), float(info["y"]), float(info["z"]))
	doctor.rotation.y = float(info.get("yaw", 0.0))
	return doctor
