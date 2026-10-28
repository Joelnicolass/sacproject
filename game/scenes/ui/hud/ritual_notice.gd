@tool
class_name RitualNotice
extends Label

## The notices of the ritual for the player of this process, from Events.ritual_started / ritual_ended (every peer
## tells them) and nothing else: no RPC. «Están profanando tu altar» while a Desecrate ritual runs on
## your altar; «Ritual interrumpido» (to the caster and the owner of the altar) and «Altar profanado» (to
## everybody) for a few seconds when one ends. Nothing on the dedicated server (slot 0). `%Battle` is
## taken by the next order, this has its own place. Remove the node and the notices are gone.

@export var profaning_text := "UI_RITUAL_PROFANING"
@export var interrupted_text := "UI_RITUAL_INTERRUPTED"
@export var profaned_text := "UI_RITUAL_PROFANED"
@export var flash_s := 4.0

## Slot of the player of this process; 0 until `bind` (the dedicated server never binds: nothing shows).
var local_slot := 0
var _flash_left := 0.0
var _flash_text := ""
## The rituals running on this peer (Events.ritual_started until ritual_ended).
var _running: Array[Ritual] = []


func _ready() -> void:
	visible = false
	if Engine.is_editor_hint():
		return
	Events.ritual_started.connect(_on_ritual_started)
	Events.ritual_ended.connect(_on_ritual_ended)


## The local wizard arrived (MatchWorld.local_wizard_changed).
func bind(wizard: WizardBody) -> void:
	local_slot = wizard.owner_slot if wizard != null else 0


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var slot := local_slot
	if slot <= 0:
		visible = false
		return
	var profaning := false
	for ritual in _running:
		if ritual.is_running() and ritual.kind == Ritual.Kind.DESECRATE \
				and ritual.target_slot == slot:
			profaning = true
	_flash_left = maxf(_flash_left - delta, 0.0)
	if _flash_left > 0.0:
		text = _flash_text
	elif profaning:
		text = tr(profaning_text)
	else:
		text = ""
	visible = not text.is_empty()


func _on_ritual_started(ritual: Ritual) -> void:
	if not _running.has(ritual):
		_running.append(ritual)
		ritual.tree_exiting.connect(func() -> void: _running.erase(ritual), CONNECT_ONE_SHOT)


func _on_ritual_ended(ritual: Ritual, completed: bool) -> void:
	_running.erase(ritual)
	if local_slot > 0:
		_announce(ritual, completed, local_slot)


func _announce(ritual: Ritual, completed: bool, slot: int) -> void:
	if completed:
		if ritual.kind != Ritual.Kind.DESECRATE:
			return
		_flash_text = tr(profaned_text)
	elif slot == ritual.caster_slot or slot == ritual.target_slot:
		_flash_text = tr(interrupted_text)
	else:
		return
	_flash_left = flash_s
