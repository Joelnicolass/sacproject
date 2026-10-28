@tool
class_name GodGround
extends Resource

## The ground of one god: its four kinds of ground (`GroundRole`, embedded) and how they meet, and
## how the map's baked light reads on them. Which kind lies where is each map's `ground_roles.png`
## (Terrain.ground_roles); the baked light is the map's own (Terrain.light_map). `TerrainLayer`
## shows it; editing a role refreshes the editor preview.

## Open ground (grass): the red channel of ground_roles.png.
@export var open: GroundRole:
	set(value):
		open = _watch(open, value)
## Earth (dirt, banks): green.
@export var earth: GroundRole:
	set(value):
		earth = _watch(earth, value)
## Rock (stone, cliffs): blue.
@export var rock: GroundRole:
	set(value):
		rock = _watch(rock, value)
## Paths and low ground: alpha.
@export var path: GroundRole:
	set(value):
		path = _watch(path, value)
## The wall of the void at the map's edge (sides of the holes).
@export var edge: Texture2D:
	set(value):
		edge = value
		emit_changed()

@export_group("Borders")
## Width of the blend where two kinds meet: smaller = sharper, more of the height contrast shows.
@export_range(0.02, 0.6, 0.01) var blend_depth := 0.18:
	set(value):
		blend_depth = value
		emit_changed()
## Breaks the 10 m cells of the map's roles with noise so the borders do not read as squares. 0 =
## smooth gradient.
@export_range(0.0, 1.0, 0.01) var edge_noise := 0.55:
	set(value):
		edge_noise = value
		emit_changed()
## Brightness drift of the ground over hundreds of metres (presets with macro on). 0 = none.
@export_range(0.0, 0.8, 0.01) var macro_strength := 0.0:
	set(value):
		macro_strength = value
		emit_changed()

@export_group("Baked light")
## Brightness = albedo * (light_base + light map * light_gain). Light left where the light map is
## black.
@export_range(0.0, 2.0, 0.01) var light_base := 0.3:
	set(value):
		light_base = value
		emit_changed()
## How much the light map adds on top of light_base.
@export_range(0.0, 4.0, 0.01) var light_gain := 0.55:
	set(value):
		light_gain = value
		emit_changed()

@export_group("Cloud shadows")
## How dark the shadow of a cloud makes the sun-lit part of the ground. 0 = no cloud shadows.
@export_range(0.0, 1.0, 0.01) var cloud_shadow_strength := 0.45:
	set(value):
		cloud_shadow_strength = value
		emit_changed()
## Size of one cloud pattern over the land, in metres.
@export_range(20.0, 600.0, 1.0, "suffix:m") var cloud_shadow_scale_m := 140.0:
	set(value):
		cloud_shadow_scale_m = value
		emit_changed()
## Speed the shadows drift at, in metres per second.
@export_range(0.0, 20.0, 0.1, "suffix:m/s") var cloud_shadow_speed_m_s := 2.5:
	set(value):
		cloud_shadow_speed_m_s = value
		emit_changed()
## Direction the wind carries the shadows (x, z on the map).
@export var cloud_shadow_wind := Vector2(0.82, 0.57):
	set(value):
		cloud_shadow_wind = value
		emit_changed()
## Softness of the shadow edge: 0 = hard, 1 = a smooth gradient.
@export_range(0.05, 1.0, 0.01) var cloud_shadow_softness := 0.35:
	set(value):
		cloud_shadow_softness = value
		emit_changed()


## The four roles in the order of the channels of ground_roles.png (R open, G earth, B rock, A
## path); a slot may be null.
func roles() -> Array[GroundRole]:
	return [open, earth, rock, path]


func _watch(old: GroundRole, new: GroundRole) -> GroundRole:
	if old != null and old.changed.is_connected(emit_changed):
		old.changed.disconnect(emit_changed)
	if new != null and not new.changed.is_connected(emit_changed):
		new.changed.connect(emit_changed)
	emit_changed()
	return new
