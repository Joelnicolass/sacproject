class_name SpellAim
extends Node3D

## While a spell waits for its target, what the player sees on the ground: the ring of its area at
## the point under the pointer (`area`, SpellType.aim_radius; a spell with no area shows a small
## mark) and the ring of how far the wizard reaches (`range_ring`, SpellType.cast_range_m), both
## projected on the land (Decal). The area is `ok_color` within reach and `blocked_color` out of it.
## Presentation only, on the player's own screen: it casts nothing and decides nothing (the server
## still answers the click). Structures keep their own ring (BuildRing, ArmedPreview).

@export var armed: ArmedCommand
@export var ray: PointerRay
## The ring of the area at the pointer.
@export var area: Decal
## The ring of the cast range around the wizard.
@export var range_ring: Decal
@export var ok_color := Color(0.45, 0.85, 1.0, 0.9)
@export var blocked_color := Color(1.0, 0.25, 0.2, 0.9)
@export var range_color := Color(1.0, 1.0, 1.0, 0.35)
## The radius (m) of the mark of a spell with no area.
@export_range(0.1, 10.0, 0.1, "suffix:m") var mark_radius_m := 1.5
## A cast range wider than this (m) draws no ring (a teleport reaches the whole map).
@export_range(10.0, 1000.0, 1.0, "suffix:m") var max_range_ring_m := 300.0
## How tall (m) the projection box is: it reaches the land on a slope.
@export_range(1.0, 200.0, 1.0, "suffix:m") var depth_m := 60.0


func _ready() -> void:
	if not BodyLook.loads_meshes():
		set_process(false)
		visible = false
		return
	_hide()


func _process(_delta: float) -> void:
	var spell := _armed_spell()
	var wizard := armed.caster.wizard if spell != null and armed.caster != null else null
	if spell == null or wizard == null:
		_hide()
		return
	var reach := spell.cast_range_m
	if range_ring != null:
		range_ring.visible = reach > 0.0 and reach <= max_range_ring_m
		if range_ring.visible:
			_place(range_ring, wizard.global_position, reach, range_color)
	var point: Variant = ray.ground(ray.pointer_now())
	if area == null:
		return
	area.visible = point != null
	if point == null:
		return
	var at := point as Vector3
	var flat := Vector2(at.x - wizard.global_position.x, at.z - wizard.global_position.z)
	var ok := reach <= 0.0 or flat.length() <= reach
	var radius := spell.aim_radius()
	_place(area, at, radius if radius > 0.0 else mark_radius_m, ok_color if ok else blocked_color)


func _armed_spell() -> SpellType:
	if armed == null or armed.mode != "spell" or armed.caster == null or armed.spell_index < 0:
		return null
	var book := armed.caster.spellbook
	return book.spell_at(armed.spell_index) if armed.spell_index < book.size() else null


func _place(decal: Decal, at: Vector3, radius: float, color: Color) -> void:
	decal.global_position = at
	decal.size = Vector3(radius * 2.0, depth_m, radius * 2.0)
	decal.modulate = color


func _hide() -> void:
	if area != null:
		area.visible = false
	if range_ring != null:
		range_ring.visible = false
