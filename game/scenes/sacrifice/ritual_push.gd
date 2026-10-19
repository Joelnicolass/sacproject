@tool
class_name RitualPush
extends Node

## What keeps melee creatures from reaching the doctors (RFC-020: the ReadMe's «barrier of magical
## energy»; sacengine pushAll, state.d:16046-16051, 8606-8628). Every frame, everything alive within
## rules.ritual_push_radius of the site is pushed out along the ground, except the ritual's doctors and
## creature: `ritual_push_speed` m/s inside `ritual_push_inner`, less and less out to the edge. The
## doctors of someone else are pushed hard (superpush: 1.1 times their pace, state.d:8623-8627).
## Move bodies with move_and_collide, like a hit would; ground and holes are respected. Server only.
## Take this node out of ritual.tscn and nothing is pushed: then melee creatures can kill doctors.

@export var ritual: Ritual

const GROUPS: Array[StringName] = [&"unit", &"wizard", &"doctor"]


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if ritual == null:
		warnings.append("Asigná en `ritual` el Ritual que empuja.")
	return warnings


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or ritual == null or not ritual.is_running() or ritual.rules == null:
		return
	if MpKit.is_networked() and not MpKit.is_server():
		return
	var rules := ritual.rules
	var center := ritual.center()
	var terrain := FallCheck.terrain_of(self)
	var seen: Dictionary = {}
	for group in GROUPS:
		for node in get_tree().get_nodes_in_group(group):
			var body := node as CharacterBody3D
			if body == null or seen.has(body) or ritual.is_part(body) or not _alive(body):
				continue
			seen[body] = true
			_push(body, center, rules, terrain, delta)


func _push(body: CharacterBody3D, center: Vector3, rules: MatchRules, terrain: Terrain, delta: float) -> void:
	var flat := Vector3(body.global_position.x - center.x, 0.0, body.global_position.z - center.z)
	var distance := (body.global_position + Vector3.UP - center).length()
	if flat.length_squared() < 0.000001 or distance >= rules.ritual_push_radius:
		return
	var speed := SacrificeMath.push_speed(distance, rules.ritual_push_inner, rules.ritual_push_radius, rules.ritual_push_speed, rules.ritual_push_edge_speed)
	var doctor := body as DoctorBody
	if doctor != null and distance < rules.ritual_push_radius - 0.1:
		speed = 1.1 * doctor.pace()
	var step := flat.normalized() * speed * delta
	var target := body.global_position + step
	if terrain != null:
		if not terrain.is_on_ground(target.x, target.z):
			return
		if body.is_on_floor():
			step.y = terrain.ground_height(target.x, target.z) - body.global_position.y
	body.move_and_collide(step)


func _alive(body: Node) -> bool:
	if body.is_in_group(Attackable.CORPSE):
		return false
	if body is UnitBody:
		return not (body as UnitBody).is_dead()
	if body is DoctorBody:
		return (body as DoctorBody).is_alive()
	if body is WizardBody:
		var ghost := (body as WizardBody).ghost as GhostForm
		return ghost == null or ghost.is_obstacle()
	return true
