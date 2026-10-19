@tool
extends SkyPiece

## Sun disc (aligned with the map's Sun) and moon disc (its own direction; the night uses it).


func apply_sky(look: SkyLook, sun_dir: Vector3) -> void:
	_uniform(&"sun_dir", sun_dir)
	_uniform(&"sun_color", Vector3(look.sun_color.r, look.sun_color.g, look.sun_color.b) * look.sun_intensity)
	var sun_r := deg_to_rad(look.sun_radius_deg)
	_uniform(&"sun_cos", Vector2(cos(sun_r), cos(sun_r * 1.25)))
	_uniform(&"halo_color", Vector3(look.halo_color.r, look.halo_color.g, look.halo_color.b) * look.halo_strength)
	_uniform(&"halo_power", look.halo_power)
	_uniform(&"moon_dir", look.moon_direction())
	_uniform(&"moon_color", Vector3(look.moon_color.r, look.moon_color.g, look.moon_color.b) * look.moon_intensity)
	var moon_r := deg_to_rad(look.moon_radius_deg)
	_uniform(&"moon_cos", Vector2(cos(moon_r), cos(moon_r * 1.12)))
