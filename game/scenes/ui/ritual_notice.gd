@tool
class_name RitualNotice
extends Label

## The notices of the ritual for the player of this process, deduced from the replicated Ritual nodes
## (group «ritual») and nothing else: no RPC. «Están profanando tu altar» while a Desecrate ritual runs on
## your altar; «Ritual interrumpido» (to the caster and the owner of the altar) and «Altar profanado» (to
## everybody) for a few seconds when one ends. Nothing on the dedicated server (slot 0). `%Battle` is
## taken by the next order, this has its own place. Remove the node and the notices are gone.

@export var profaning_text := "Están profanando tu altar"
@export var interrupted_text := "Ritual interrumpido"
@export var profaned_text := "Altar profanado"
@export var flash_s := 4.0

var _flash_left := 0.0
var _flash_text := ""
## Rituals seen running, by instance id, so each end is announced once.
var _seen: Dictionary = {}


func _ready() -> void:
	visible = false


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var slot := MpKit.local_slot()
	if slot <= 0:
		visible = false
		return
	var profaning := false
	for node in get_tree().get_nodes_in_group(Ritual.GROUP):
		var ritual := node as Ritual
		if ritual == null:
			continue
		var id := ritual.get_instance_id()
		if ritual.outcome == Ritual.Outcome.RUNNING:
			_seen[id] = true
			if ritual.kind == Ritual.Kind.DESECRATE and ritual.target_slot == slot and ritual.phase != Ritual.Phase.OFF:
				profaning = true
		elif _seen.get(id, false):
			_seen[id] = false
			_announce(ritual, slot)
	_flash_left = maxf(_flash_left - delta, 0.0)
	if _flash_left > 0.0:
		text = _flash_text
	elif profaning:
		text = profaning_text
	else:
		text = ""
	visible = not text.is_empty()


func _announce(ritual: Ritual, slot: int) -> void:
	if ritual.outcome == Ritual.Outcome.COMPLETED:
		if ritual.kind != Ritual.Kind.DESECRATE:
			return
		_flash_text = profaned_text
	elif slot == ritual.caster_slot or slot == ritual.target_slot:
		_flash_text = interrupted_text
	else:
		return
	_flash_left = flash_s
