extends Node3D

signal local_wizard_changed(wizard: Node3D)

@export var rules: MatchRules

var _entered_ms := 0
var _local_wizard: Node3D


func _enter_tree() -> void:
	_entered_ms = Time.get_ticks_msec()
	## The one who simulates applies the match setup (level, friendly fire; RFC-031 031a2) and draws (or takes) the match
	## seed before any child is ready (RFC-024 §5.1). The setup returns a copy when it overrides something (an empty setup returns `rules` itself): never mutate world.rules at runtime.
	if not MpKit.is_networked() or MpKit.is_server():
		rules = SacrificeFlow.setup.apply_to(rules)
		MatchSeed.begin(rules)


func _ready() -> void:
	print("en high noon slot ", MpKit.local_slot())
	var match_state := get_node_or_null("%Match") as MatchState
	if match_state:
		match_state.result_changed.connect(_on_result_changed)
	%Wizards.child_entered_tree.connect(_on_wizard_entered)
	for wizard in %Wizards.get_children():
		_check_local(wizard)
	print("mundo listo %d ms" % (Time.get_ticks_msec() - _entered_ms))


## The wizard of MpKit.local_slot(); null on the dedicated server or before the spawn arrives.
func local_wizard() -> Node3D:
	if _local_wizard and is_instance_valid(_local_wizard):
		return _local_wizard
	return null


func _on_wizard_entered(node: Node) -> void:
	if not node.is_node_ready():
		node.ready.connect(_check_local.bind(node), CONNECT_ONE_SHOT)


func _check_local(node: Node) -> void:
	if not node.has_method("is_local") or not node.call("is_local"):
		return
	_local_wizard = node as Node3D
	%Camera.set_follow(_local_wizard)
	%WizardHud.bind(_local_wizard)
	%SpellBook.bind(_local_wizard)
	_place_creature.call_deferred()
	local_wizard_changed.emit(_local_wizard)


## The match has a result (the banner shows it): the world no longer takes clicks.
func _on_result_changed() -> void:
	if MpKit.local_slot() <= 0:
		return
	var view := get_node_or_null("%View") as Button
	if view:
		view.disabled = true


func _place_creature() -> void:
	var wizard := local_wizard()
	if wizard == null:
		return
	for _attempt in 3:
		await get_tree().physics_frame
	var creature: Node3D = %Creature
	creature.position = wizard.position + Vector3(6, 0, 0)
	creature.visible = false
