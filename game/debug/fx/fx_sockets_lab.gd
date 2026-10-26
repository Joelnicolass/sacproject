extends Node

## Lab of 055x (F6): three real creatures of very different sizes in a row, a fixed camera at `camera_distance_m` and `camera_pitch_deg`, and one
## step per `check_tick`. Each step is a case (`_cases`): it fires the real component on each creature, and every effect FxBus plays meanwhile is
## printed as `FX_LAB case=<name> fx=<label> at=<where> body=<nearest creature> socket=<nearest socket> off=<meters>`, so a capture
## (agent/harness/fx_sockets_capture.gd) can compare the place with the socket and with where the pixels are. `off` must be ~0.
## Cases: sockets (x1), and from x4 Rockform, Play Dead, Stealth, Run Away (the Speedup burst), Firewalking, Frozen, Petrified, Burning, Heal
## and the break of the Pull. Summon (x2/x3) and the fall of the altar (x5) are appended by their sub-cuts.
## What it does not do: judge the look (the capture does), or edit the product (it only spawns and fires).

@export var world: MatchWorld
@export var unit_scene: PackedScene
@export var arena: Node3D
@export var camera: Camera3D
@export var log_label: Label

@export_group("Subjects")
## The creatures in a row, small to big (the gnome, the earthfling, the jabberocky).
@export var creatures: Array[CreatureType] = []
@export var slot := 1
## Meters ahead of the wizard where the row is centered, and between two creatures.
@export var ahead_m := 14.0
@export var spacing_m := 6.0

@export_group("Camera")
@export var camera_distance_m := 12.0
@export_range(0.0, 85.0, 1.0, "suffix:deg") var camera_pitch_deg := 35.0
@export var camera_look_up_m := 1.0

@export_group("Effects")
## The burst the `sockets` case plays at each socket.
@export var socket_fx: ParticleType
## Frames the world gets to settle before the row spawns and between two plays.
@export var settle_frames := 4
## Seconds between two creatures of a case.
@export var case_gap_s := 1.5

@export_group("Cases")
## Abilities whose own effect (AbilityType.effect) each case fires on every creature.
@export var rockform: AbilityType
@export var play_dead: AbilityType
@export var stealth: AbilityType
@export var run_away: AbilityType
## The pull: the first creature pulls each of the others (same side, so the pull breaks at once and shows its break burst).
@export var web_pull: AbilityType
@export var freeze: SpellType
## Seconds a creature stays petrified or burning before the end burst.
@export var petrify_s := 1.0
@export var burn_s := 1.0
@export var burn_fx: ParticleType
## Meters a firewalk goes ahead.
@export var firewalk_m := 4.0

var _subjects: Array[Node3D] = []
var _step := 0
var _case := ""
var _cases: Array[Dictionary] = [
	{"name": "sockets", "run": _sockets},
	{"name": "rockform", "run": _ability.bind(&"rockform")},
	{"name": "play_dead", "run": _ability.bind(&"play_dead")},
	{"name": "stealth", "run": _ability.bind(&"stealth")},
	{"name": "speedup", "run": _ability.bind(&"run_away")},
	{"name": "firewalking", "run": _firewalking},
	{"name": "frozen", "run": _frozen},
	{"name": "petrified", "run": _petrified},
	{"name": "burning", "run": _burning},
	{"name": "heal", "run": _heal},
	{"name": "pull_break", "run": _pull_break},
]


func _ready() -> void:
	world.local_wizard_changed.connect(func(_wizard: Node3D) -> void: _start.call_deferred())
	if world.local_wizard() != null:
		_start.call_deferred()
	FxBus.played.connect(_on_played)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("check_tick"):
		_run_next()


## Spawns the row and puts the camera in front of it.
func _start() -> void:
	var wizard := world.local_wizard() as WizardBody
	if wizard == null:
		return
	for _frame in settle_frames:
		await get_tree().physics_frame
	for old in arena.get_children():
		old.queue_free()
	_subjects.clear()
	var ahead := wizard.facing_flat()
	var right := ahead.cross(Vector3.UP).normalized()
	var middle := wizard.global_position + ahead * ahead_m
	for index in creatures.size():
		var at := middle + right * (float(index) - float(creatures.size() - 1) * 0.5) * spacing_m
		_subjects.append(_spawn(creatures[index], at, -ahead))
	camera.current = true
	var pitch := deg_to_rad(camera_pitch_deg)
	camera.global_position = middle + (-ahead * cos(pitch) + Vector3.UP * sin(pitch)) * camera_distance_m
	camera.look_at(middle + Vector3.UP * camera_look_up_m)
	_say("listo: %d criaturas, pulsá check_tick para el caso %s" % [_subjects.size(), _cases[0]["name"]])


## The next case (check_tick). After the last one, the first again.
func _run_next() -> void:
	if _subjects.is_empty():
		return
	var entry: Dictionary = _cases[_step % _cases.size()]
	_step += 1
	_case = str(entry["name"])
	_say("caso %s" % _case)
	var run: Callable = entry["run"]
	run.call()


## One burst at each socket (feet, center, top, muzzle) of each creature, one body at a time.
func _sockets() -> void:
	for body in _subjects:
		for index in 4:
			var socket := index as BodyFacts.Socket
			FxBus.play(socket_fx, BodyFacts.point(body, socket))
		await get_tree().create_timer(case_gap_s).timeout


## The effect of the ability named by the export `field` (rockform, play_dead, stealth, run_away), fired on each creature in turn.
func _ability(field: StringName) -> void:
	var type := get(field) as AbilityType
	for body in _subjects:
		_say("caso %s %s: %s" % [_case, body.name, "ok" if _fire(type, body, null) else "rechazado"])
		await get_tree().create_timer(case_gap_s).timeout


func _firewalking() -> void:
	for body in _subjects:
		var walk := Firewalking.of(body)
		var ahead := (body as UnitBody).facing_flat() if body is UnitBody else Vector3.FORWARD
		_report(walk != null and walk.walk(body.global_position + ahead * firewalk_m), body)
		await get_tree().create_timer(case_gap_s).timeout


func _frozen() -> void:
	for body in _subjects:
		var frozen := Frozen.of(body)
		_report(frozen != null and frozen.freeze(freeze, 0), body)
		await get_tree().create_timer(case_gap_s).timeout


func _petrified() -> void:
	for body in _subjects:
		var stone := body.get_node_or_null(^"Afflictions/Petrified") as Petrified
		_report(stone != null and stone.petrify(MatchClock.ticks_for(petrify_s)), body)
		await get_tree().create_timer(case_gap_s).timeout


func _burning() -> void:
	for body in _subjects:
		_report(Burning.ignite(body, 0.0, MatchClock.ticks_for(burn_s), Health.DIRECT_SPELL, 0, 0.0, false, burn_fx) != null, body)
		await get_tree().create_timer(case_gap_s).timeout


## Half the health off (from nobody), then a full heal: its puffs show where the heal leaves the body.
func _heal() -> void:
	for body in _subjects:
		var health := Health.of(body)
		if health != null:
			health.damage_typed(health.maximum * 0.5, Health.DIRECT_SPELL, 0)
		_report(HealEffect.heal_full(body) != null, body)
		await get_tree().create_timer(case_gap_s).timeout


func _pull_break() -> void:
	var user := _subjects[0]
	for index in range(1, _subjects.size()):
		_report(_fire(web_pull, user, _subjects[index]), _subjects[index])
		await get_tree().create_timer(case_gap_s * 2.0).timeout


## The real effect of `type` (its AbilityType.effect scene), set up for `body` and fired once. Freed after the case.
func _fire(type: AbilityType, body: Node3D, target: Node3D) -> bool:
	var unit := body as UnitBody
	if type == null or type.effect == null or unit == null:
		return false
	var effect := type.effect.instantiate() as AbilityEffect
	if effect == null:
		return false
	effect.setup(unit, type)
	add_child(effect)
	var target_pos := target.global_position if target != null else body.global_position
	var fired := effect.status(target_pos, target).is_empty() and effect.fire(target_pos, target)
	get_tree().create_timer(case_gap_s * 8.0).timeout.connect(effect.queue_free)
	return fired


func _report(ok: bool, body: Node3D) -> void:
	_say("caso %s %s: %s" % [_case, body.name, "ok" if ok else "rechazado"])


## Every effect played while a case runs: where, and how far from the nearest socket of the nearest creature.
func _on_played(kind: StringName, fx: Resource, at: Vector3) -> void:
	if _case.is_empty() or _subjects.is_empty():
		return
	var best_body: Node3D = null
	var best_socket := 0
	var best := INF
	for body in _subjects:
		if not is_instance_valid(body):
			continue
		for index in 4:
			var d := at.distance_to(BodyFacts.point(body, index as BodyFacts.Socket))
			if d < best:
				best = d
				best_body = body
				best_socket = index
	if best_body == null:
		return
	print("FX_LAB case=%s kind=%s fx=%s at=%s body=%s socket=%s off=%.3f" % [_case, kind, FxWire.label_of(fx), at, best_body.name,
		BodyFacts.Socket.keys()[best_socket], best])


func _spawn(type: CreatureType, at: Vector3, facing: Vector3) -> Node3D:
	var unit: Node3D = unit_scene.instantiate()
	unit.name = "%s%d" % [type.tag.capitalize(), _subjects.size()]
	unit.set("type", type)
	unit.set("owner_slot", slot)
	arena.add_child(unit)
	unit.global_position = at
	unit.rotation.y = atan2(facing.x, facing.z)
	return unit


func _say(text: String) -> void:
	print("FX_LAB %s" % text)
	if log_label != null:
		log_label.text = text
