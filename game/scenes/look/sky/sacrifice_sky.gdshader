shader_type sky;

// Sacrifice's sky as a real Godot sky: the background colour, the original's two textured bands
// (rotating), its cloud plane (drifting), an optional aurora and optional sun / moon discs.
// Edit it through the material in the inspector; every number a human wants is a uniform below.
//
// Cost: the radiance cubemap (ambient light and reflections) only gets a cheap three-colour
// gradient, so it never re-bakes with the clouds. For that, set the Sky resource's
// `process_mode` to Quality: the shader uses TIME, which makes Automatic re-bake every frame.

#include "res://scenes/look/sky/sky_bands.gdshaderinc"
#include "res://scenes/look/sky/sky_clouds.gdshaderinc"
#include "res://scenes/look/sky/sky_discs.gdshaderinc"
#include "res://scenes/look/sky/aurora.gdshaderinc"
#include "res://scenes/look/sky/sky_stars.gdshaderinc"

group_uniforms background;
// Colour seen where no band or cloud covers the sky (the original's ENVI background).
uniform vec3 background_color : source_color = vec3(1.0, 0.706, 0.471);
// Brightness multiplier of the band and cloud textures (the original uses 1.7).
uniform float energy : hint_range(0.0, 4.0, 0.01) = 1.7;
// Height of the camera above the sky's base (a plane 511 m under the ground). Moves the horizon.
uniform float eye_height_m : hint_range(0.0, 2000.0, 1.0) = 551.0;

group_uniforms bands;
// Upper band, seen from the horizon up (skyt.png).
uniform sampler2D top_texture : source_color, hint_default_transparent, filter_linear_mipmap, repeat_enable;
// Lower band, seen below the horizon (skyb.png).
uniform sampler2D bottom_texture : source_color, hint_default_transparent, filter_linear_mipmap, repeat_enable;
// Copies of the texture around the sky (the original: 8).
uniform int band_repeats : hint_range(1, 32) = 8;
// true: every other copy is flipped, as in the original (a symmetry axis at each seam; needed only to compare with it).
// false: plain wrap-around; the texture must tile horizontally (tools/look/make_tileable.py).
uniform bool mirror_repeat = false;
// Soft cross-fade where the upper and the lower band meet, as a fraction of a band's height each side. 0 = a hard edge.
uniform float band_blend : hint_range(0.0, 0.2, 0.001) = 0.03;
// Seconds for a full turn of both bands.
uniform float rotation_period_s : hint_range(1.0, 2048.0, 1.0) = 512.0;

group_uniforms clouds;
uniform sampler2D clouds_texture : source_color, hint_default_transparent, filter_linear_mipmap, repeat_enable;
// Seconds for the clouds to drift one texture repeat.
uniform float cloud_period_s : hint_range(1.0, 1024.0, 1.0) = 64.0;
// 0 hides the clouds.
uniform float cloud_alpha : hint_range(0.0, 1.0, 0.01) = 1.0;

group_uniforms ambient_gradient;
// What the radiance cubemap sees: ambient light and reflections only. Not drawn on screen.
uniform vec3 ambient_top_color : source_color = vec3(0.38, 0.45, 0.55);
uniform vec3 ambient_horizon_color : source_color = vec3(0.65, 0.65, 0.7);
uniform vec3 ambient_ground_color : source_color = vec3(0.2, 0.17, 0.13);
uniform float ambient_energy : hint_range(0.0, 4.0, 0.01) = 1.0;
// Lower = the top colour reaches farther down toward the horizon.
uniform float ambient_curve : hint_range(0.05, 2.0, 0.01) = 0.5;

group_uniforms aurora;
// 0 = off (the aurora code does not run at all).
uniform float aurora_strength : hint_range(0.0, 1.0, 0.01) = 0.0;
// Colour from the lowest to the highest layer of the aurora (a 1D gradient).
uniform sampler2D aurora_gradient : source_color, filter_linear;
uniform float aurora_brightness : hint_range(0.0, 4.0, 0.01) = 1.7;
uniform float aurora_speed : hint_range(0.0, 1.0, 0.001) = 0.12;
uniform float aurora_height : hint_range(1.0, 100.0, 0.5) = 42.0;
uniform float aurora_scale : hint_range(0.1, 4.0, 0.01) = 0.8;

group_uniforms grade;
// A deeper colour toward the zenith over the textured bands (0 = the bands as they are).
uniform vec3 zenith_color : source_color = vec3(0.25, 0.45, 0.85);
uniform float zenith_strength : hint_range(0.0, 1.0, 0.01) = 0.0;
// A warm glow along the horizon (0 = none).
uniform vec3 horizon_color : source_color = vec3(1.0, 0.7, 0.45);
uniform float horizon_strength : hint_range(0.0, 1.0, 0.01) = 0.0;
// 1 = the colours as they are; above 1 more vivid.
uniform float saturation : hint_range(0.0, 2.0, 0.01) = 1.0;

group_uniforms discs;
// The sun disc follows the scene's first DirectionalLight3D. 0 = no disc.
uniform float sun_intensity : hint_range(0.0, 20.0, 0.05) = 0.0;
uniform vec3 sun_color : source_color = vec3(1.0, 0.9, 0.7);
uniform float sun_radius_deg : hint_range(0.1, 15.0, 0.1) = 2.2;
uniform float halo_strength : hint_range(0.0, 4.0, 0.01) = 0.0;
uniform vec3 halo_color : source_color = vec3(1.0, 0.7, 0.4);
// Higher = tighter halo around the sun.
uniform float halo_power : hint_range(2.0, 400.0, 1.0) = 24.0;
// 0 = no moon.
uniform float moon_intensity : hint_range(0.0, 20.0, 0.05) = 0.0;
uniform vec3 moon_color : source_color = vec3(0.75, 0.82, 1.0);
uniform float moon_radius_deg : hint_range(0.1, 15.0, 0.1) = 3.0;
// Compass azimuth of the moon: 0 = +Z, 90 = +X.
uniform float moon_azimuth_deg : hint_range(-180.0, 180.0, 1.0) = -40.0;
uniform float moon_elevation_deg : hint_range(-10.0, 89.0, 1.0) = 40.0;

// The groups below are the atmosphere's (day and night, weather): EnvironmentLayer writes them on its private copy of
// the material from the AtmosphereSample. All of them at their default change nothing, exactly.
group_uniforms night;
// How many of the stars show (0 = none: the stars code does not run).
uniform float night_amount : hint_range(0.0, 1.0, 0.01) = 0.0;
// Share of the sky with a star, and the brightest star's light.
uniform float star_density : hint_range(0.0, 1.0, 0.01) = 0.4;
uniform float star_brightness : hint_range(0.0, 8.0, 0.01) = 2.0;

group_uniforms storm;
// Extra cloud cover over the texture's own (0..1) and how much darker the clouds are.
uniform float cloud_cover : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float cloud_darken : hint_range(0.0, 1.0, 0.01) = 0.0;
// The clouds drift this many times faster. `cloud_phase` (texture repeats) keeps the drift continuous when it changes.
uniform float cloud_speed_mul : hint_range(0.0, 8.0, 0.01) = 1.0;
uniform float cloud_phase = 0.0;
// 0 = the sky's colors, 1 = grey.
uniform float sky_grey : hint_range(0.0, 1.0, 0.01) = 0.0;
// Multiplies the whole sky (night, storm) and the reflection cubemap.
uniform vec3 sky_tint : source_color = vec3(1.0);

group_uniforms flash;
// A storm's flash: the sky is (1 + flash_amount) times brighter.
uniform float flash_amount : hint_range(0.0, 1.0, 0.01) = 0.0;

group_uniforms time;
// -1 = the engine's TIME. 0 or more freezes the sky at that second (captures and comparisons).
uniform float time_override_s : hint_range(-1.0, 4096.0, 0.01) = -1.0;

#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
group_uniforms compatibility;
// The web (Compatibility) lifts the exposure of the whole scene (EnvironmentLayer) so models and
// ground read like the desktop; the sky seen behind them is brought back here, the ambient it
// lights with (the cubemap pass) is not.
uniform float compat_gain : hint_range(0.0, 2.0, 0.01) = 0.55;
uniform float compat_saturation : hint_range(0.0, 3.0, 0.01) = 1.0;
// Below 1 lifts the darks: the web's tone curve crushes them (the clouds' shadows went black).
uniform float compat_curve : hint_range(0.2, 1.5, 0.01) = 0.6;
group_uniforms;
#endif

void sky() {
	if (AT_CUBEMAP_PASS) {
		float up = EYEDIR.y;
		float amount = pow(clamp(abs(up), 0.0, 1.0), ambient_curve);
		vec3 far_color = up >= 0.0 ? ambient_top_color : ambient_ground_color;
		COLOR = mix(ambient_horizon_color, far_color, amount) * ambient_energy * sky_tint;
	} else {
		vec3 dir = normalize(EYEDIR);
		float t = time_override_s >= 0.0 ? time_override_s : TIME;
		float spin = TAU * t / rotation_period_s;
		vec2 cloud_offset = fract(t / cloud_period_s * cloud_speed_mul + cloud_phase) * vec2(1.0, -1.0);

		// Texture coordinates first, outside any branch, so their derivatives (the mip level) are valid.
		float bottom_u;
		float top_u;
		float repeats = float(band_repeats);
		float margin_m = band_blend * SKY_BAND_TOP_M;
		vec4 bottom = sky_band_bottom_uv(dir, eye_height_m, spin, margin_m, repeats, mirror_repeat, bottom_u);
		vec4 top = sky_band_top_uv(dir, eye_height_m, spin, margin_m, repeats, mirror_repeat, top_u);
		float top_weight = sky_band_top_weight(top.y, band_blend);
		if (band_blend <= 0.0) {
			bottom = sky_band_bottom_owns(bottom, top);
		}
		vec4 cloud = sky_cloud_uv(dir, eye_height_m, cloud_offset);
		vec2 bottom_dx = sky_band_grad(dFdx(bottom_u), dFdx(bottom.x), dFdx(bottom.y), repeats, mirror_repeat);
		vec2 bottom_dy = sky_band_grad(dFdy(bottom_u), dFdy(bottom.x), dFdy(bottom.y), repeats, mirror_repeat);
		vec2 top_dx = sky_band_grad(dFdx(top_u), dFdx(top.x), dFdx(top.y), repeats, mirror_repeat);
		vec2 top_dy = sky_band_grad(dFdy(top_u), dFdy(top.x), dFdy(top.y), repeats, mirror_repeat);
		vec2 cloud_dx = dFdx(cloud.xy);
		vec2 cloud_dy = dFdy(cloud.xy);

		vec3 color = background_color;
		color = sky_band_blend(color, bottom_texture, bottom, bottom_dx, bottom_dy, energy, 1.0);
		color = sky_band_blend(color, top_texture, top, top_dx, top_dy, energy, top_weight);
		if (night_amount > 0.0) {
			// Turned with the bands, so the stars stay put on the sky; behind the clouds.
			vec3 star_dir = vec3(dir.x * cos(spin) + dir.z * sin(spin), dir.y, dir.z * cos(spin) - dir.x * sin(spin));
			color += sky_stars(star_dir, star_density, star_brightness) * night_amount;
		}
		color = sky_cloud_blend(color, clouds_texture, cloud, cloud_dx, cloud_dy, energy, cloud_alpha, cloud_cover, cloud_darken);

		if (aurora_strength > 0.0 && dir.y > -0.1) {
			vec4 glow = aurora_color(dir, aurora_gradient, t, aurora_brightness, aurora_speed, aurora_height, aurora_scale);
			color = mix(color, glow.rgb, glow.a * aurora_strength);
		}

		if (zenith_strength > 0.0 || horizon_strength > 0.0 || saturation != 1.0) {
			float up = clamp(dir.y, 0.0, 1.0);
			color = mix(color, color * 0.35 + zenith_color * 0.85, zenith_strength * smoothstep(0.05, 0.9, up));
			color += horizon_color * horizon_strength * pow(1.0 - abs(dir.y), 6.0);
			float grey = dot(color, vec3(0.2126, 0.7152, 0.0722));
			color = max(mix(vec3(grey), color, saturation), vec3(0.0));
		}
		if (sun_intensity + halo_strength + moon_intensity > 0.0) {
			vec3 sun_dir = LIGHT0_ENABLED ? LIGHT0_DIRECTION : vec3(0.0, 0.6, 0.8);
			color = sky_disc_add(color, dir, sun_dir, sun_color * sun_intensity, sun_radius_deg, halo_color * halo_strength, halo_power,
					sky_direction_from_angles(moon_azimuth_deg, moon_elevation_deg), moon_color * moon_intensity, moon_radius_deg);
		}
		if (sky_grey > 0.0) {
			color = mix(color, vec3(dot(color, vec3(0.2126, 0.7152, 0.0722))), sky_grey);
		}
		color *= sky_tint;
		if (flash_amount > 0.0) {
			color *= 1.0 + flash_amount;
		}
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		color = max(mix(vec3(dot(color, vec3(0.2126, 0.7152, 0.0722))), color, compat_saturation), vec3(0.0));
		color = pow(color, vec3(compat_curve)) * compat_gain;
#endif
		COLOR = color;
	}
}
