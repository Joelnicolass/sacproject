@tool
class_name AdvisorWatch
extends Node

## The game's warnings for the advisor (child of AdvisorVoice). It hears what every peer already tells game-wide
## (Events.body_hurt, ritual_started, ritual_ended) and asks `advisor.say(line)`; the line carries its priority and quiet
## time and the advisor decides the queue. Only the side of the seat that looks at this screen (0 on a dedicated: nothing).
## Remove the node and only the refusals speak.
## - The local wizard (MatchWorld.local_wizard_changed, or `wizard` set by hand) hurt -> `wizard_attacked`;
##   below `low_health_ratio` of its bar -> `wizard_low_health`.
## - Own creatures (UnitBody) hurt -> `creatures_attacked`; health to 0 -> `creature_died`.
## - Own buildings (group «structure»: Manaliths, map buildings) hurt -> `building_attacked`; to 0 -> `building_destroyed`.
## - Rituals: a Desecrate that starts on this side's altar -> `desecrated`; one this side cast ends completed ->
##   `sacrifice_complete`.
## The owner is checked when the event comes (a converted creature changes side). Reads only: no RPC, nothing written to
## the simulation.
## Ref: RFC-052 052e (F364).

@export var advisor: AdvisorVoice:
	set(value):
		advisor = value
		update_configuration_warnings()
## The match: its `local_wizard_changed` moves this to the local wizard. Optional: the lab sets `wizard`.
@export var world: MatchWorld
@export var wizard: Node3D
## Who looks at this screen: only this seat's side is warned.
@export var seat: MpLocalSeat:
	set(value):
		seat = value
		update_configuration_warnings()
@export_range(0.0, 1.0, 0.01) var low_health_ratio := 0.25

@export_group("Lines")
@export var wizard_attacked: AdvisorLine
@export var wizard_low_health: AdvisorLine
@export var creatures_attacked: AdvisorLine
@export var creature_died: AdvisorLine
@export var building_attacked: AdvisorLine
@export var building_destroyed: AdvisorLine
@export var desecrated: AdvisorLine
@export var sacrifice_complete: AdvisorLine

var _open := false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_open = AudioGate.is_open() and advisor != null
	if not _open:
		return
	if world != null:
		world.local_wizard_changed.connect(bind_wizard)
		if wizard == null:
			wizard = world.local_wizard()
	Events.body_hurt.connect(_on_body_hurt)
	Events.ritual_started.connect(_on_ritual_started)
	Events.ritual_ended.connect(_on_ritual_ended)


## The local wizard whose hits it tells (MatchWorld.local_wizard_changed; the lab calls it).
func bind_wizard(node: Node3D) -> void:
	wizard = node


func _on_body_hurt(body: Node3D, _lost: float, current: float, maximum: float) -> void:
	if body == null:
		return
	if body == wizard:
		if current <= 0.0:
			return
		advisor.say(wizard_attacked)
		if maximum > 0.0 and current / maximum < low_health_ratio:
			advisor.say(wizard_low_health)
	elif not _is_ours(body):
		return
	elif body is UnitBody:
		advisor.say(creature_died if current <= 0.0 else creatures_attacked)
	elif body.is_in_group(MapBuilding.STRUCTURE_GROUP):
		advisor.say(building_destroyed if current <= 0.0 else building_attacked)


func _on_ritual_started(ritual: Ritual) -> void:
	var slot := _slot()
	if slot > 0 and ritual.kind == Ritual.Kind.DESECRATE and ritual.target_slot == slot:
		advisor.say(desecrated)


func _on_ritual_ended(ritual: Ritual, completed: bool) -> void:
	var slot := _slot()
	if slot > 0 and completed and ritual.caster_slot == slot:
		advisor.say(sacrifice_complete)


func _is_ours(body: Node) -> bool:
	return seat != null and seat.is_mine(int(body.get("owner_slot")))


func _slot() -> int:
	return seat.slot if seat != null else 0


func _get_configuration_warnings() -> PackedStringArray:
	var out := PackedStringArray()
	if advisor == null:
		out.append("Asigná `advisor` (el AdvisorVoice padre).")
	if seat == null:
		out.append("Asigná `seat` (el MpLocalSeat): sin él no avisa.")
	return out
