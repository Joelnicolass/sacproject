@tool
class_name MapNavRegion
extends NavigationRegion3D

## The map's walkable surface (RFC-035 035f): NavRegion in high_noon.tscn, holding the versioned navmesh
## data/nav/high_noon_nav.res. Baked headless by tools/bake_nav.gd from the `nav_source` nodes of the map. Nothing queries
## it yet (NavService still uses NavGrid until 035g). The inspector warns when the navmesh no longer matches the map.

## The numbers the navmesh was baked with; also part of the source hash.
@export var bake_settings: NavBakeSettings


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if bake_settings == null:
		warnings.append("Asigná bake_settings (data/nav/nav_bake.tres).")
	if navigation_mesh == null or navigation_mesh.get_polygon_count() == 0:
		warnings.append("El navmesh está vacío: corré tools/bake_nav.gd.")
	elif bake_settings != null and get_parent() != null:
		var stored := str(navigation_mesh.get_meta(NavFingerprint.META_SOURCE, ""))
		if stored != NavFingerprint.source_hash(get_parent(), bake_settings):
			warnings.append("El navmesh está viejo (el mapa o nav_bake.tres cambiaron): corré tools/bake_nav.gd.")
	return warnings


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	## A client loads the region but does not log it (it never asks for a path).
	if MpKit.is_networked() and not MpKit.is_server():
		return
	var polygons := navigation_mesh.get_polygon_count() if navigation_mesh != null else 0
	print("nav: navmesh %d polígonos" % polygons)
