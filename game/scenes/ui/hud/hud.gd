extends Control

## Local wizard readout: the stats block in the top-right corner (WizardStats: soul count,
## mana and health bars), then name · god and «Fantasma» while the wizard is see-through
## (GhostForm) as text under it. `%Stats` keeps the old «Vida/Maná/Almas» line as an undrawn readout
## for the flows. The selection lives in SelectionRoster.

const STATS_TEXT := "UI_HUD_STATS_FORMAT"

var _wizard: Node


func _ready() -> void:
	visible = false
	%GhostState.visible = false


func bind(wizard: Node) -> void:
	if _wizard == wizard:
		return
	_unbind()
	_wizard = wizard
	if wizard == null:
		visible = false
		return
	wizard.pick_changed.connect(_refresh)
	wizard.health.changed.connect(_on_value_changed)
	wizard.mana.changed.connect(_on_value_changed)
	wizard.souls.changed.connect(_on_souls_changed)
	wizard.ghost.stage_changed.connect(_on_stage_changed)
	wizard.tree_exiting.connect(_on_wizard_gone)
	visible = true
	_refresh()


func _unbind() -> void:
	if _wizard == null or not is_instance_valid(_wizard):
		_wizard = null
		return
	_wizard.pick_changed.disconnect(_refresh)
	_wizard.health.changed.disconnect(_on_value_changed)
	_wizard.mana.changed.disconnect(_on_value_changed)
	_wizard.souls.changed.disconnect(_on_souls_changed)
	_wizard.ghost.stage_changed.disconnect(_on_stage_changed)
	_wizard.tree_exiting.disconnect(_on_wizard_gone)
	_wizard = null


func _on_wizard_gone() -> void:
	bind(null)


func _on_value_changed(_current: float, _maximum: float) -> void:
	_refresh()


func _on_souls_changed(_count: int) -> void:
	_refresh()


func _on_stage_changed(_stage: int) -> void:
	_refresh()


func _refresh() -> void:
	if _wizard == null:
		return
	var god_type: GodType = (_wizard as WizardBody).god_type
	%Title.text = "%s · %s" % [_wizard.display_name(), god_type.display_name if god_type != null else "?"]
	%Stats.text = tr(STATS_TEXT) % [
		roundi(_wizard.health.current), roundi(_wizard.health.maximum),
		roundi(_wizard.mana.current), roundi(_wizard.mana.maximum),
		_wizard.souls.count,
	]
	%GhostState.visible = (_wizard as WizardBody).ghost.shows_ghost()
	%WizardStats.show_values(
		_fraction(_wizard.health.current, _wizard.health.maximum),
		_fraction(_wizard.mana.current, _wizard.mana.maximum),
		_wizard.souls.count,
	)


## The filled fraction of a bar: 0 when the maximum is 0.
static func _fraction(current: float, maximum: float) -> float:
	return current / maximum if maximum > 0.0 else 0.0
