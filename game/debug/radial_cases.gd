extends RefCounted

## RFC-038 038c case of rules_suite: the angle -> entry mapping of data/ui/radial/orders_layout.tres, headless.
## Entry 0 of a ring is at the top and the rest follow clockwise. Checks, for both rings: the icon's own spot gives its entry;
## a hair either side of a sector boundary gives the neighbors; the dead zone is the center; past the outer ring and an empty ring
## are null. Also that the outer ring holds exactly the formations of the catalog, in its order, and that every entry has a
## label and an icon.

const LAYOUT := preload("res://data/ui/radial/orders_layout.tres")
const CATALOG := preload("res://data/orders/formations.tres")
const EDGE := 0.01


func run(_host: Node3D) -> Dictionary:
	return {"radial_layout": layout_case()}


func layout_case() -> Dictionary:
	var failures: PackedStringArray = []
	var checked := 0
	var rings := [[LAYOUT.inner, LAYOUT.inner_mid()], [LAYOUT.outer, LAYOUT.outer_mid()]]
	for ring in rings:
		var entries: Array = ring[0]
		var radius: float = ring[1]
		var step := TAU / entries.size()
		for i in entries.size():
			var spot := RadialLayout.slot_offset(entries.size(), i, radius)
			checked += 1
			if LAYOUT.entry_at(spot) != entries[i]:
				failures.append("%s: spot %d gives %s" % [entries[i].id, i, _id(LAYOUT.entry_at(spot))])
			var before := Vector2(sin(step * (i + 0.5) - EDGE), -cos(step * (i + 0.5) - EDGE)) * radius
			var after := Vector2(sin(step * (i + 0.5) + EDGE), -cos(step * (i + 0.5) + EDGE)) * radius
			var next: int = (i + 1) % entries.size()
			checked += 2
			if LAYOUT.entry_at(before) != entries[i]:
				failures.append("%s: just before the boundary gives %s" % [entries[i].id, _id(LAYOUT.entry_at(before))])
			if LAYOUT.entry_at(after) != entries[next]:
				failures.append("%s: just after the boundary gives %s, want %s" % [entries[i].id, _id(LAYOUT.entry_at(after)), entries[next].id])
	checked += 5
	if LAYOUT.entry_at(Vector2.ZERO) != LAYOUT.center:
		failures.append("origin is not the center")
	if LAYOUT.entry_at(Vector2(0.0, -LAYOUT.dead_zone_px + 0.5)) != LAYOUT.center:
		failures.append("inside the dead zone is not the center")
	if LAYOUT.entry_at(Vector2(LAYOUT.outer_radius_px + 1.0, 0.0)) != null:
		failures.append("past the outer ring is not null")
	if LAYOUT.entry_at(Vector2(0.0, -LAYOUT.outer_radius_px + 0.5)) != LAYOUT.outer[0]:
		failures.append("top of the outer ring is not entry 0")
	if RadialLayout.sector_index(0, Vector2.UP) != -1:
		failures.append("an empty ring gives an index")
	# The rings hold what the catalog has.
	var formations := LAYOUT.outer.filter(func(e: RadialEntry) -> bool: return e.action == RadialEntry.Action.FORMATION)
	if formations.size() != CATALOG.formations.size():
		failures.append("outer ring has %d formations, catalog %d" % [formations.size(), CATALOG.formations.size()])
	else:
		for i in formations.size():
			if formations[i].formation != CATALOG.formations[i]:
				failures.append("outer %d is %s, catalog has %s" % [i, _id(formations[i]), CATALOG.formations[i].id])
	for entry: RadialEntry in LAYOUT.inner + LAYOUT.outer + [LAYOUT.center]:
		checked += 1
		if entry.display_label().is_empty() or entry.display_icon() == null:
			failures.append("%s lacks a label or an icon" % entry.id)
	return {"ok": failures.is_empty(), "checked": checked, "failures": failures.slice(0, 6)}


func _id(entry: RadialEntry) -> String:
	return str(entry.id) if entry else "null"
