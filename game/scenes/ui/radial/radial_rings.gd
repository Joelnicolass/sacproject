@tool
class_name RadialRings
extends Control

## The icons of a radial menu: one `RadialSlot` per entry of the layout, placed around the center of the menu.
## It builds them and says which one is lit; it knows no pointer and no signal (the menu feeds it the hovered entry).

const SLOT_SCENE := preload("res://scenes/ui/radial/radial_slot.tscn")

## Seconds a slot takes to grow / dim when the hovered entry changes.
@export var hover_s := 0.12

var _slots: Array[RadialSlot] = []


## Replaces the slots by the ones of `layout`: the inner ring, then the outer ring.
func build(layout: RadialLayout) -> void:
	for slot in _slots:
		slot.queue_free()
	_slots.clear()
	_add_ring(layout, layout.inner, layout.inner_mid())
	_add_ring(layout, layout.outer, layout.outer_mid())


## The slot of `ring_entry` grows and the rest dim; null (nothing hovered, or the center) leaves them all idle.
## `animate` false snaps.
func show_hover(ring_entry: RadialEntry, animate: bool) -> void:
	for slot in _slots:
		slot.set_state(ring_entry != null and slot.entry == ring_entry, ring_entry != null, animate)


func _add_ring(layout: RadialLayout, entries: Array[RadialEntry], radius: float) -> void:
	var middle := Vector2.ONE * layout.outer_radius_px
	for i in entries.size():
		var slot: RadialSlot = SLOT_SCENE.instantiate()
		add_child(slot)
		slot.setup(entries[i], layout.icon_px)
		slot.hover_s = hover_s
		slot.position = middle + RadialLayout.slot_offset(entries.size(), i, radius) - slot.size * 0.5
		_slots.append(slot)
