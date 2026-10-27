extends Node

## 055c4 test bed of the villager's FSM: a Farmer with a hut 30 m away (its shelter), a Trogg of the enemy side and a lone Farmer with no
## shelter within 50 m. Drag any of them in the viewport and run again (F6). Headless it runs the checks, prints `VILLAGER_FSM PASS/FAIL {json}`
## and quits. The rules suite (debug/suite/village_cases.gd) instances this scene and calls run_checks().
## Checks: the Brain has one state node per thing a villager does, a calm villager near a shelter works, a scare within 50 m makes it flee
## and one at 51 m does not, a hit makes it run from the one who hit it even when it is far, and one with no shelter cowers.

const TAG := "VILLAGER_FSM "
const STATES: Array[String] = ["Idle", "Work", "Flee", "Cower"]

@export var farmer: UnitBody
@export var lone: UnitBody
@export var hunter: UnitBody


func _ready() -> void:
	if get_tree().current_scene != self:
		return
	var report := run_checks()
	print(TAG + ("PASS " if bool(report["ok"]) else "FAIL ") + JSON.stringify(report))
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if bool(report["ok"]) else 1)


## Runs every check and returns {ok, checks}. The bodies stand still: the checks make the Brain think, they do not wait for its clock.
func run_checks() -> Dictionary:
	SideRelations.use(ActiveMatch.map(), ActiveMatch.mode())
	for body: UnitBody in [farmer, lone, hunter]:
		body.set_physics_process(false)
	var brain := farmer.get_node("Brain") as VillagerBrain
	var lone_brain := lone.get_node("Brain") as VillagerBrain
	var senses := farmer.get_node("Senses") as VillagerSenses
	brain.set_physics_process(false)
	lone_brain.set_physics_process(false)
	var checks := {}
	var names: Array[String] = []
	for state in brain.get_children():
		names.append(String(state.name))
	checks["one_node_per_state"] = names == STATES
	checks["starts_idle"] = brain.state_name() == &"Idle"
	checks["calm_villager_plays_work"] = farmer.clips.idle_role == "work"

	var home := hunter.global_position
	hunter.global_position = Vector3(-70.0, 0.0, 0.0)
	brain.think()
	checks["shelter_and_no_scare_works"] = brain.state_name() == &"Work" and farmer.mode == UnitBody.Mode.IDLE and not farmer.is_cowering()

	hunter.global_position = home
	brain.think()
	var goal := farmer.locomotion.goal
	checks["scare_at_30_flees"] = brain.state_name() == &"Flee" and farmer.mode == UnitBody.Mode.MOVE and goal.x > 20.0 and absf(goal.z) < 1.0

	hunter.global_position = Vector3(-51.0, 0.0, 0.0)
	farmer.halt()
	brain.think()
	checks["scare_at_51_is_ignored"] = brain.state_name() == &"Work" and farmer.mode == UnitBody.Mode.IDLE

	hunter.global_position = Vector3(-70.0, 0.0, 0.0)
	farmer.health.damage(10.0, 1)
	checks["hit_starts_the_panic"] = senses.panic_left > 0.0 and senses.panic_from == 1
	brain.think()
	checks["panic_flees_from_far"] = brain.state_name() == &"Flee" and farmer.mode == UnitBody.Mode.MOVE
	senses.panic_left = 0.0
	farmer.halt()
	brain.think()
	checks["calm_after_the_panic"] = brain.state_name() == &"Work" and farmer.mode == UnitBody.Mode.IDLE

	lone_brain.think()
	checks["no_shelter_cowers"] = lone_brain.state_name() == &"Cower" and lone.is_cowering()
	hunter.global_position = home
	var ok := true
	for key in checks:
		ok = ok and bool(checks[key])
	return {"ok": ok, "checks": checks}
