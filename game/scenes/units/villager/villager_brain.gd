class_name VillagerBrain
extends FsmMachine

## What a villager does with no order: with a shelter within reach it looks for the closest scare (an enemy, or a side it holds a grudge
## against) and runs the other way, and with none it stands still (Work); with no shelter near it crouches (Cower). A hit from another side
## makes it run from whoever hit it for a while (the panic), shelter or not. It thinks every `think_interval_s` and never attacks.
## Not: what it notices (VillagerSenses) nor what each state does (the states, one child each). Server or solo only.
## Ref: sacengine updateCreatureAI (state.d:13732-13760).

@export var senses: VillagerSenses
## Decision of the port: the original decides on the turn of its AI queue; this is a fixed period.
@export_range(0.0166, 5.0, 0.0001, "suffix:s") var think_interval_s := 0.25
@export_group("Run")
## Decision of the port (the original runs at a point mirrored through the enemy every tick): how far ahead of the villager the point it runs
## to lies, straight away from the scare.
@export var flee_leg_m := 30.0
## How far the panic leg reaches before it re-decides (longer than a calm flee: it is running for its life).
@export var panic_leg_m := 40.0
@export_group("Look")
## «Working the fields» is in the original's villager FSM with no rule decompiled, so a calm villager (mode IDLE) plays `work_role` instead of
## its idle clip. Off = the CRE8 idle. Presentation only, on every peer.
@export var work_when_calm := true
## Clip role of the calm villager ("work" = dig).
@export var work_role := "work"

var body: UnitBody:
	get: return actor as UnitBody

var _left := 0.0


func _ready() -> void:
	super._ready()
	set_process(false)
	set_process_unhandled_input(false)
	if work_when_calm:
		body.clips.idle_role = work_role  ## IDLE is the calm mode of a villager (flee = MOVE, cower = COWER): every peer shows it the same way.
	if not body.simulates():
		set_physics_process(false)
		return
	senses.panicked.connect(_on_panicked)


## One step: the panic wears off and, every `think_interval_s`, it thinks. Only an idle, walking or cowering villager thinks; a dead, held
## or revived one is somebody else's, and so is one under an order.
func _physics_process(delta: float) -> void:
	if body.ordered or not (body.mode == UnitBody.Mode.IDLE or body.mode == UnitBody.Mode.MOVE or body.mode == UnitBody.Mode.COWER):
		return
	senses.age(delta)
	_left -= delta
	if _left > 0.0:
		return
	_left = think_interval_s
	think()


## The state it is in: "Idle", "Work", "Flee" or "Cower".
func state_name() -> StringName:
	return current.name


func think() -> void:
	if senses.panic_left > 0.0 and _flee_from(senses.closest_of_slot(senses.panic_from), panic_leg_m):
		return
	if senses.closest_shelter() == null:
		transition(&"Cower")
		(current as VillagerState).act()
		return
	if body.is_cowering():
		body.halt()
	var scare := senses.closest_scare()
	if scare == null:
		transition(&"Work")
		(current as VillagerState).act()
		return
	_flee_from(scare, flee_leg_m)


## Runs from `threat`; false when there is none to run from.
func _flee_from(threat: Node3D, leg_m: float) -> bool:
	if threat == null:
		return false
	transition(&"Flee", {"threat": threat, "leg_m": leg_m})
	return true


func _on_panicked() -> void:
	_left = 0.0
