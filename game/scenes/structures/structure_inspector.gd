class_name StructureInspector
extends Node

## RFC-028b (F93): the building, cactus or Manalith the local player clicked shows its health bar over
## the model, one at a time, without touching the selection (a port extension: sacengine only has the
## mouse-over box, renderer.d:5036-5230). Local presentation: no RPC. The body must carry a `HealthBar`
## (unit_health_bar.tscn with `only_when_selected`) and a `Health` with maximum > 0; an altar or an
## indestructible building has no bar and just clears the inspection.

signal inspected_changed(body: Node3D)

## Name of the bar child the inspected body carries.
@export var bar_name := &"HealthBar"

## The body whose bar is shown, or null.
var inspected: Node3D
## Read-only views for flows (AgentKit reads properties, not methods).
var inspected_name: String:
	get:
		return str(inspected.name) if inspected and is_instance_valid(inspected) else ""
var inspected_fraction: float:
	get:
		return _fraction()
var visible_bar_count: int:
	get:
		return visible_bars()


## Shows `body`'s bar and hides the last one. Returns false (and clears) when the body has no bar to show.
func inspect(body: Node3D) -> bool:
	if body == inspected:
		return true
	clear()
	var bar := _bar_of(body)
	var health := body.get_node_or_null("Health") as Health if body else null
	if bar == null or health == null or health.maximum <= 0.0 or health.is_dead():
		return false
	inspected = body
	bar.set_selected(true)
	health.changed.connect(_on_health_changed)
	body.tree_exiting.connect(clear)
	inspected_changed.emit(inspected)
	return true


func clear() -> void:
	if inspected == null:
		return
	var body := inspected
	inspected = null
	if is_instance_valid(body):
		var bar := _bar_of(body)
		if bar:
			bar.set_selected(false)
		var health := body.get_node_or_null("Health")
		if health and health.changed.is_connected(_on_health_changed):
			health.changed.disconnect(_on_health_changed)
		if body.tree_exiting.is_connected(clear):
			body.tree_exiting.disconnect(clear)
	inspected_changed.emit(null)


## How many inspection bars are on screen (flows and the playtest read it).
func visible_bars() -> int:
	var seen := {}
	for group in [&"structure", &"map_building"]:
		for node in get_tree().get_nodes_in_group(group):
			var bar := _bar_of(node as Node3D)
			if bar and bar.is_visible_in_tree() and bool(bar.get("only_when_selected")):
				seen[bar] = true
	return seen.size()


## The inspected body's health fraction, -1 when nothing is inspected.
func _fraction() -> float:
	if inspected == null or not is_instance_valid(inspected):
		return -1.0
	var health := inspected.get_node("Health")
	return float(health.get("current")) / maxf(float(health.get("maximum")), 0.001)


func _on_health_changed(_current: float, _maximum: float) -> void:
	if inspected and is_instance_valid(inspected) and (inspected.get_node("Health") as Health).is_dead():
		clear()


func _bar_of(body: Node3D) -> UnitHealthBar:
	if body == null or not is_instance_valid(body):
		return null
	return body.get_node_or_null(NodePath(bar_name)) as UnitHealthBar
