class_name GameplayTab
extends VBoxContainer

## Options → Jugabilidad. Friendly fire, dropping souls with P and the starting souls.
## - In the boot (no match in the tree) it edits the player's GameplayPrefs, saved at once; the next
##   match the player creates takes them (the boot's MatchSetup).
## - In a match it is read only: it shows the rules of this match from MatchState (the server's on a
##   client, through the snapshot) and says who decides them. It never reads the preferences there.
## CheckButton (like Gráficos) and SpinBox: AgentKit drives them with click / range. Below, the
## player's combat feel (FeelPrefs): «Sacudida de cámara» 0-100 % (0 = off), «Números de daño» «Info
## al pasar el puntero» and «Sangre» (blood, its marks and the hit flash). A local preference, so it
## is editable in a match too, and saved at once.

## Tab title in the OptionsMenu.
@export var tab_title := "UI_OPTIONS_TAB_GAMEPLAY"
## The shared instance (data/ui/gameplay_prefs.tres).
@export var prefs: GameplayPrefs
## The shared instance (data/ui/feel_prefs.tres).
@export var feel: FeelPrefs
## The group MatchState joins (one per match).
@export var match_state_group: StringName = &"match_state"

var _state: MatchState
## _sync is writing the SpinBox (its text follows `value` only through the signal path).
var _syncing := false


func _ready() -> void:
	if prefs == null:
		push_warning("GameplayTab: prefs is missing.")
		return
	var souls: SpinBox = %StartingSouls
	souls.min_value = prefs.min_starting_souls
	souls.max_value = prefs.max_starting_souls
	souls.step = 1
	%FriendlyFire.toggled.connect(_on_friendly_fire)
	%DropSoul.toggled.connect(_on_drop_soul)
	souls.value_changed.connect(_on_starting_souls)
	prefs.changed.connect(_sync)
	visibility_changed.connect(_sync)
	if feel:
		%ShakeScale.value_changed.connect(_on_shake_scale)
		%DamageNumbers.toggled.connect(feel.set_damage_numbers)
		%HoverInfo.toggled.connect(feel.set_hover_info)
		%Blood.toggled.connect(feel.set_blood)
		feel.changed.connect(_sync_feel)
		visibility_changed.connect(_sync_feel)
	_sync()
	_sync_feel()


## In a match: the MatchState of the tree (cached while it lives).
func _match_state() -> MatchState:
	if _state and is_instance_valid(_state) and _state.is_inside_tree():
		return _state
	_state = (
		get_tree().get_first_node_in_group(match_state_group) as MatchState
		if is_inside_tree()
		else null
	)
	if _state and not _state.rules_changed.is_connected(_sync):
		_state.rules_changed.connect(_sync)
	return _state


func is_read_only() -> bool:
	return _match_state() != null


## Shows the match's rules (read only) or the preference (editable), without echoing them back.
func _sync() -> void:
	var state := _match_state()
	var read_only := state != null
	%RulesNote.visible = read_only
	for control: BaseButton in [%FriendlyFire, %DropSoul]:
		control.disabled = read_only
	(%StartingSouls as SpinBox).editable = not read_only
	if read_only:
		%FriendlyFire.set_pressed_no_signal(state.friendly_fire)
		%DropSoul.set_pressed_no_signal(state.drop_soul)
		_show_souls(state.starting_souls)
	else:
		%FriendlyFire.set_pressed_no_signal(prefs.friendly_fire())
		%DropSoul.set_pressed_no_signal(prefs.drop_soul())
		_show_souls(prefs.starting_souls())


func _show_souls(count: int) -> void:
	_syncing = true
	(%StartingSouls as SpinBox).value = count
	_syncing = false


func _on_friendly_fire(on: bool) -> void:
	if is_read_only():
		_sync()
		return
	prefs.set_friendly_fire(on)


func _on_drop_soul(on: bool) -> void:
	if is_read_only():
		_sync()
		return
	prefs.set_drop_soul(on)


func _on_starting_souls(value: float) -> void:
	if _syncing:
		return
	if is_read_only():
		_sync()
		return
	prefs.set_starting_souls(roundi(value))


## The feel rows show the preference (never the match's: it is the player's own), without echoing it
## back.
func _sync_feel() -> void:
	if feel == null:
		for row: Control in [%ShakeScale.get_parent(), %DamageNumbers, %HoverInfo, %Blood]:
			row.visible = false
		return
	_syncing = true
	(%ShakeScale as HSlider).value = roundf(feel.shake_scale() * 100.0)
	_syncing = false
	(%ShakeValue as Label).text = "%d %%" % roundi(feel.shake_scale() * 100.0)
	%DamageNumbers.set_pressed_no_signal(feel.damage_numbers())
	%HoverInfo.set_pressed_no_signal(feel.hover_info())
	%Blood.set_pressed_no_signal(feel.blood())


func _on_shake_scale(value: float) -> void:
	if _syncing or feel == null:
		return
	feel.set_shake_scale(value / 100.0)
	(%ShakeValue as Label).text = "%d %%" % roundi(value)
