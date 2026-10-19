@tool
class_name AdvisorWatch
extends Node

## RFC-052 052e (F364): the game's warnings for the advisor (child of AdvisorVoice). It reads what every peer already has
## (replicated Health of the bodies, the Ritual nodes) and asks `advisor.say(code)`; the advisor decides priority, queue and
## cooldown. Only the side of this process (MpKit.local_slot(); 0 on a dedicated: nothing). Remove the node and only the
## refusals speak.
## - The local wizard (MatchWorld.local_wizard_changed, or `wizard` set by hand): its health goes down -> `wizard_attacked`;
##   below `low_health_ratio` of its bar -> `wizard_low_health`.
## - Own creatures (group «unit»): health down -> `creatures_attacked`; health to 0 -> `creature_died`.
## - Own buildings (group «structure»: Manaliths, map buildings): health down -> `building_attacked`; to 0 -> `building_destroyed`.
## - Rituals (group «ritual»): a Desecrate running on this side's altar -> `desecrated` (once per ritual); one this side cast
##   ends completed -> `sacrifice_complete`.
## Bodies and rituals are looked up every `scan_every_s` (a client gets them from spawners at any time); the owner is checked
## when the event comes (a converted creature changes side). Reads only: no RPC, nothing written to the simulation.

@export var advisor: AdvisorVoice:
	set(value):
		advisor = value
		update_configuration_warnings()
## Emits `local_wizard_changed(wizard)` and answers `local_wizard()` (MatchWorld). Optional: the lab sets `wizard`.
@export var world: Node
@export var wizard: Node3D
@export_range(0.05, 5.0, 0.05, "suffix:s") var scan_every_s := 0.25
@export_range(0.0, 1.0, 0.01) var low_health_ratio := 0.25

@export_group("Codes")
@export var wizard_attacked := &"watt"
@export var wizard_low_health := &"whlt"
@export var creatures_attacked := &"uatt"
@export var creature_died := &"cdie"
@export var building_attacked := &"bdam"
@export var building_destroyed := &"bdst"
@export var desecrated := &"dese"
@export var sacrifice_complete := &"sacc"

enum Kind { WIZARD, CREATURE, BUILDING }

var _open := false
var _scan_left := 0.0
## Health instance id -> its last `current` (a drop is a hit).
var _last: Dictionary = {}
## Ritual instance id -> true while seen running (each start and each end is told once).
var _rituals: Dictionary = {}
var _desecrations: Dictionary = {}
var _wizard_health: Health


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_open = AudioGate.is_open() and advisor != null
	if not _open:
		set_process(false)
		return
	if world != null:
		if world.has_signal("local_wizard_changed"):
			world.connect("local_wizard_changed", bind_wizard)
		if wizard == null and world.has_method("local_wizard"):
			wizard = world.call("local_wizard") as Node3D
	if wizard != null:
		bind_wizard(wizard)


func _process(delta: float) -> void:
	_scan_left -= delta
	if _scan_left > 0.0:
		return
	_scan_left = scan_every_s
	scan()


## The local wizard whose health it watches (MatchWorld.local_wizard_changed; the lab calls it).
func bind_wizard(node: Node3D) -> void:
	if _wizard_health != null and is_instance_valid(_wizard_health) and _wizard_health.changed.is_connected(_on_health):
		_wizard_health.changed.disconnect(_on_health)
	wizard = node
	_wizard_health = _health_of(node)
	if _wizard_health != null:
		_last[_wizard_health.get_instance_id()] = _wizard_health.current
		_wizard_health.changed.connect(_on_health.bind(_wizard_health, node, Kind.WIZARD))


## Connects the bodies and rituals that appeared since the last look (the lab calls it to not wait).
func scan() -> void:
	if not _open:
		return
	for node in get_tree().get_nodes_in_group(&"unit"):
		_watch(node as Node3D, Kind.CREATURE)
	for node in get_tree().get_nodes_in_group(&"structure"):
		_watch(node as Node3D, Kind.BUILDING)
	_scan_rituals()


func _watch(body: Node3D, kind: Kind) -> void:
	var health := _health_of(body)
	if health == null or _last.has(health.get_instance_id()):
		return
	var id := health.get_instance_id()
	_last[id] = health.current
	health.changed.connect(_on_health.bind(health, body, kind))
	health.tree_exiting.connect(func() -> void: _last.erase(id), CONNECT_ONE_SHOT)


func _on_health(current: float, maximum: float, health: Health, body: Node3D, kind: Kind) -> void:
	var id := health.get_instance_id()
	var before := float(_last.get(id, current))
	_last[id] = current
	## The wizard was bound as the local one; the others are checked now (a converted creature changes side).
	if current >= before or not is_instance_valid(body) or (kind != Kind.WIZARD and not _is_ours(body)):
		return
	match kind:
		Kind.WIZARD:
			if current <= 0.0:
				return
			advisor.say(wizard_attacked)
			if maximum > 0.0 and current / maximum < low_health_ratio:
				advisor.say(wizard_low_health)
		Kind.CREATURE:
			advisor.say(creature_died if current <= 0.0 else creatures_attacked)
		Kind.BUILDING:
			advisor.say(building_destroyed if current <= 0.0 else building_attacked)


func _scan_rituals() -> void:
	var slot := MpKit.local_slot()
	if slot <= 0:
		return
	for node in get_tree().get_nodes_in_group(Ritual.GROUP):
		var ritual := node as Ritual
		if ritual == null:
			continue
		var id := ritual.get_instance_id()
		if ritual.outcome == Ritual.Outcome.RUNNING:
			_rituals[id] = true
			if ritual.kind == Ritual.Kind.DESECRATE and ritual.target_slot == slot and ritual.phase != Ritual.Phase.OFF \
					and not _desecrations.has(id):
				_desecrations[id] = true
				advisor.say(desecrated)
		elif _rituals.get(id, false):
			_rituals[id] = false
			if ritual.outcome == Ritual.Outcome.COMPLETED and ritual.caster_slot == slot:
				advisor.say(sacrifice_complete)


func _is_ours(body: Node) -> bool:
	var slot := MpKit.local_slot()
	return slot > 0 and int(body.get("owner_slot")) == slot


static func _health_of(body: Node) -> Health:
	return body.get_node_or_null("Health") as Health if body != null else null


func _get_configuration_warnings() -> PackedStringArray:
	return PackedStringArray() if advisor != null else PackedStringArray(["Asigná `advisor` (el AdvisorVoice padre)."])
