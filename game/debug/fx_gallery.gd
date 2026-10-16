extends Node3D

const _POOL := preload("res://debug/fx_pool_count.gd")

## Each child of %Slots is named after a res://data/fx/<name>.tres and marks where it plays.

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
	for slot in _slots.get_children():
		var type_name := String(slot.name)
		var type := FxBus.particle_type(type_name)
		if type == null:
			continue
		print("fx %s %dx%d" % [type_name, type.h_frames, type.v_frames])
		FxBus.play(type_name, slot.global_position, Vector3.UP)
	## RFC-029 029b: FxBus's pool right after this round and `pool_report_after_s` later, from its children.
	print(_POOL.line(FxBus))
	## RFC-029 029c: the rig's effect lights right after the round (none without the FxLight layer).
	var lights := get_tree().get_first_node_in_group(&"fx_light_pool")
	if lights != null:
		print(lights.call(&"report"))
	get_tree().create_timer(pool_report_after_s).timeout.connect(func() -> void: print("%.0f s: %s" % [pool_report_after_s, _POOL.line(FxBus)]))


func _fill_missing_slots() -> void:
	var names := _fx_names()
	if names.is_empty():
		return
	var existing := {}
	for child in _slots.get_children():
		existing[String(child.name)] = true
	var base_count := _slots.get_child_count()
	var offset := 0
	for name in names:
		if existing.has(name):
			continue
		var marker := Marker3D.new()
		marker.name = name
		var index := base_count + offset
		marker.position = Vector3((float(index % columns) - float(columns - 1) * 0.5) * spacing, 1.2, floori(index / columns) * 4.0)
		var label := Label3D.new()
		label.name = "Label"
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.pixel_size = 0.008
		label.position = Vector3(0.0, -0.95, 2.0)
		label.font_size = 48
		label.outline_size = 10
		label.text = name
		marker.add_child(label)
		_slots.add_child(marker)
		offset += 1


func _fx_names() -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open("res://data/fx")
	if dir == null:
		return out
	dir.list_dir_begin()
	while true:
		var file := dir.get_next()
		if file.is_empty():
			break
		if dir.current_is_dir() or not file.ends_with(".tres"):
			continue
		out.append(file.get_basename())
	dir.list_dir_end()
	out.sort()
	return out
