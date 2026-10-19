extends Node3D

const CYCLE := ["idle", "run", "attack"]

var _cycle_idx := 0

@onready var _wizard := $Wizard
@onready var _trogg := $Trogg
@onready var _label := %Debug as Label


func _ready() -> void:
	set_process(true)
	_apply_cycle()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_anim_cycle"):
		_cycle_idx = (_cycle_idx + 1) % CYCLE.size()
		_apply_cycle()


func _process(_delta: float) -> void:
	_refresh_label()


func _apply_cycle() -> void:
	var mode: String = CYCLE[_cycle_idx]
	if _wizard and _wizard.has_method("debug_set_clip_state"):
		_wizard.call("debug_set_clip_state", "run" if mode == "run" else "idle")
	if _trogg and _trogg.has_method("debug_set_clip_state"):
		_trogg.call("debug_set_clip_state", mode)
	_refresh_label()


func _refresh_label() -> void:
	if _label == null:
		return
	var wizard := _clip_info(_wizard)
	var trogg := _clip_info(_trogg)
	_label.text = "cycle %s\nwizard %s tag %s frame %d fps %d\ntrogg %s tag %s frame %d fps %d impact %d" % [
		CYCLE[_cycle_idx],
		wizard.get("role", ""),
		wizard.get("tag", ""),
		int(wizard.get("frame", 0)),
		int(wizard.get("fps", 0)),
		trogg.get("role", ""),
		trogg.get("tag", ""),
		int(trogg.get("frame", 0)),
		int(trogg.get("fps", 0)),
		int(trogg.get("impact_frame", -1)),
	]


func _clip_info(body: Node) -> Dictionary:
	if body and body.has_method("debug_clip_info"):
		var info: Variant = body.call("debug_clip_info")
		if info is Dictionary:
			return info
	return {}
