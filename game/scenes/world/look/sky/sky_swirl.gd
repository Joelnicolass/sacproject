@tool
extends SkyPiece

## Swirl sky (the "new" sky): the original's palette and textures with depth. Its textures are
## the legacy sky's own (handed in by `SkyLayer`), so it follows the biome's cached files.


func apply_sky(look: SkyLook, sun_dir: Vector3) -> void:
	_uniform(&"sun_dir", sun_dir)
	_uniform(&"scale", look.swirl_scale)
	var wind := deg_to_rad(look.swirl_wind_deg)
	_uniform(&"wind", Vector2(sin(wind), cos(wind)) * look.swirl_speed)
	_uniform(&"warp", look.swirl_warp)
	_uniform(&"brightness", look.swirl_energy)
	_uniform(&"far_opacity", look.swirl_far_opacity)
	_uniform(&"depth_shade", look.swirl_depth_shade)
	_uniform(&"sun_glow", look.swirl_sun_glow)
	_uniform(&"glow_color", Vector3(look.halo_color.r, look.halo_color.g, look.halo_color.b))


## Textures and base values of the legacy sky (runtime only: never saved in a scene).
func bind_legacy(clouds: Texture2D, band: Texture2D, background: Color, energy: float, max_alpha: float) -> void:
	_uniform(&"clouds", clouds)
	_uniform(&"band", band)
	_uniform(&"background", Vector3(background.r, background.g, background.b))
	_uniform(&"energy", energy)
	_uniform(&"max_alpha", max_alpha)


func clear_legacy() -> void:
	_uniform(&"clouds", null)
	_uniform(&"band", null)
