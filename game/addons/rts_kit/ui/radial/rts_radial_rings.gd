@tool
class_name RtsRadialRings
extends Control

## The icons of a radial menu: one RtsRadialSlot per entry of each ring of the layout, placed around
## the center of the menu. It builds them and says which one is lit; it knows no pointer and no signal
## (the menu feeds it the hovered entry).

const SLOT_SCENE := preload("res://addons/rts_kit/ui/radial/rts_radial_slot.tscn")

## Seconds a slot takes to grow / dim when the hovered entry changes.
@export var hover_s := 0.12

var _slots: Array[RtsRadialSlot] = []


## Replaces the slots by the ones of `layout`, ring by ring from the inside out.
func build(layout: RtsRadialLayout) -> void:
	for slot in _slots:
		slot.queue_free()
	_slots.clear()
	var entries := layout.ring_entries()
	for k in entries.size():
		_add_ring(layout, entries[k], layout.ring_mid(k))


## The slot of `entry` grows and the rest dim; null leaves them all idle. `animate` false snaps.
func show_hover(entry: RtsMenuEntry, animate: bool) -> void:
	for slot in _slots:
		slot.set_state(entry != null and slot.entry == entry, entry != null, animate)


func _add_ring(layout: RtsRadialLayout, entries: Array, radius: float) -> void:
	var middle := Vector2.ONE * layout.outer_radius()
	for i in entries.size():
		var slot: RtsRadialSlot = SLOT_SCENE.instantiate()
		add_child(slot)
		slot.setup(entries[i], layout.icon_px)
		slot.hover_s = hover_s
		slot.position = (
			middle + RtsRadialLayout.slot_offset(entries.size(), i, radius) - slot.size * 0.5
		)
		_slots.append(slot)
