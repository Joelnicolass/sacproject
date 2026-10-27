extends Node3D

const _POOL := preload("res://debug/fx/fx_pool_count.gd")

## Each child of %Slots is an FxSlot: its `fx` (a ParticleType from data/fx) is what it plays from where it stands.
## Missing types (every ParticleType under data/fx and its folders) get a slot of their own when `auto_fill_missing_slots` is on.

@export var autoplay_delay_s: float = 0.75
@export var auto_fill_missing_slots := true
@export var columns := 9
@export var spacing := 4.0
## Seconds after a round when the pool line prints again (every burst idle and hidden by then).
@export var pool_report_after_s := 4.0

@onready var _slots: Node3D = %Slots


func _ready() -> void:
	if auto_fill_missing_slots:
		_fill_missing_slots()
	get_tree().create_timer(autoplay_delay_s).timeout.connect(play_all)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("check_tick"):
		play_all()


func play_all() -> void:
	for slot: FxSlot in _slots.get_children():
		if slot.fx == null:
			continue
		print("fx %s %dx%d" % [FxWire.label_of(slot.fx), slot.fx.h_frames, slot.fx.v_frames])
		slot.play()
	## RFC-029 029b: FxBus's pool right after this round and `pool_report_after_s` later, from its children.
	print(_POOL.line(FxBus))
	## RFC-029 029c: the rig's effect lights right after the round (none without the FxLight layer).
	var lights := get_tree().get_first_node_in_group(&"fx_light_pool")
	if lights != null:
		print(lights.call(&"report"))
	get_tree().create_timer(pool_report_after_s).timeout.connect(func() -> void: print("%.0f s: %s" % [pool_report_after_s, _POOL.line(FxBus)]))


func _fill_missing_slots() -> void:
	var existing: Dictionary[ParticleType, bool] = {}
	for slot: FxSlot in _slots.get_children():
		if slot.fx != null:
			existing[slot.fx] = true
	var base_count := _slots.get_child_count()
	var offset := 0
	for found: Resource in FxWire.all_in(FxWire.PARTICLES_DIR):
		var type := found as ParticleType
		if type == null or existing.has(type):
			continue
		var slot := FxSlot.new()
		slot.name = FxWire.label_of(type)
		slot.fx = type
		var index := base_count + offset
		slot.position = Vector3((float(index % columns) - float(columns - 1) * 0.5) * spacing, 1.2, floori(index / columns) * 4.0)
		var label := Label3D.new()
		label.name = "Label"
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.pixel_size = 0.008
		label.position = Vector3(0.0, -0.95, 2.0)
		label.font_size = 48
		label.outline_size = 10
		label.text = slot.name
		slot.add_child(label)
		_slots.add_child(slot)
		offset += 1
