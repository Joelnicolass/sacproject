@tool
class_name RitualPush
extends Node

## The barrier that keeps melee creatures from reaching the doctors. Every frame, everything alive within the push radius of
## the site (`Push` in sacrifice_places.tscn, SacrificeFacts.push_m) is pushed out along the ground, except the ritual's doctors
## and creature: `ritual_push_speed` m/s inside the core (`PushCore`), less and less out to the edge. The doctors of someone else
## are pushed hard (superpush: 1.1 times their pace). Bodies move with move_and_collide, like a hit would; ground and holes are
## respected (SacrificeGround). Server only.
## Take this node out of ritual.tscn and nothing is pushed: then melee creatures can kill doctors.
## Ref: sacengine pushAll, state.d:16046-16051, 8606-8628, 8623-8627.

@export var ritual: Ritual

const GROUPS: Array[StringName] = [UnitBody.GROUP, WizardBody.GROUP, DoctorBody.GROUP]


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if ritual == null:
		warnings.append("Asigná en `ritual` el Ritual que empuja.")
	return warnings


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or ritual == null or not ritual.is_running() or ritual.rules == null:
		return
	if not ritual.simulates():
		return
	var rules := ritual.rules
	var facts := SacrificeFacts.of_rules(rules)
	var center := ritual.center()
	var seen: Dictionary = {}
	for group in GROUPS:
		for node in get_tree().get_nodes_in_group(group):
			var body := node as CharacterBody3D
			if body == null or seen.has(body) or ritual.is_part(body) or not _alive(body):
				continue
			seen[body] = true
			_push(body, center, rules, facts, delta)


func _push(body: CharacterBody3D, center: Vector3, rules: MatchRules, facts: SacrificeFacts, delta: float) -> void:
	var flat := Vector3(body.global_position.x - center.x, 0.0, body.global_position.z - center.z)
	var distance := (body.global_position + Vector3.UP - center).length()
	if flat.length_squared() < 0.000001 or distance >= facts.push_m:
		return
	var speed := BodyNudge.push_speed(distance, facts.push_core_m, facts.push_m, rules.ritual_push_speed, rules.ritual_push_edge_speed)
	var doctor := body as DoctorBody
	if doctor != null and distance < facts.push_m - 0.1:
		speed = 1.1 * doctor.pace()
	var step := flat.normalized() * speed * delta
	var target := body.global_position + step
	if not SacrificeGround.is_on(self, target):
		return
	if body.is_on_floor():
		step.y = SacrificeGround.height(self, target) - body.global_position.y
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
