// Grass paint: in the zones where grass grows, the ground takes the average color of the blades,
// so far from the camera the ground "is" the grass and the field fades into it with no edge.
// Included by the ground shader (ground.gdshader). `GroundMaterial.set_grass_paint` fills the uniforms; amount 0 = no paint.

uniform sampler2D grass_wave_noise : filter_linear_mipmap, repeat_enable, hint_default_white;
uniform vec3 grass_paint_color = vec3(0.3, 0.5, 0.1);
uniform float grass_paint_amount = 0.0;
// Share of the paint per role (x..w = open, earth, rock, path): open ground all of it, earth and path partly, rock none.
uniform vec4 grass_paint_roles = vec4(1.0, 0.3, 0.0, 0.3);
// Luminance of the open ground's own albedo, to keep its texture detail under the paint.
uniform float grass_paint_ref = 0.15;
// Slope (deg) where the paint starts to fade and where it is gone: the valley floor is painted, its
// hills turn gradually into the soil's own color instead of a hard green/brown cut.
uniform vec2 grass_paint_slope = vec2(10.0, 36.0);
// The same waves the blades use (direction, scale m, speed m/s, strength): pale bands across the ground.
uniform vec2 grass_wave_dir = vec2(0.82, 0.57);
uniform float grass_wave_scale_m = 55.0;
uniform float grass_wave_speed = 2.2;
uniform float grass_wave_strength = 0.0;
// >= 0 replaces the time of the wave bands (agent bench: frozen). The game never sets it.
uniform float grass_time_override = -1.0;

// `w` = the role weights after the height blend (sum 1).
float grass_paint_k(vec4 w, float slope_deg) {
	float by_slope = 1.0 - smoothstep(grass_paint_slope.x, grass_paint_slope.y, slope_deg);
	return clamp(grass_paint_amount * dot(w, grass_paint_roles) * by_slope, 0.0, 1.0);
}

// Textured ground: the paint keeps the role's relief in luminance and carries the wind bands.
vec3 grass_paint_textured(vec3 alb, vec4 w, vec2 xz, float time, float slope_deg) {
	float k = grass_paint_k(w, slope_deg);
	if (k <= 0.0) {
		return alb;
	}
	float lum = dot(alb, vec3(0.3, 0.59, 0.11));
	// Only a little of the ground's own relief shows under the paint: from above it must read as one field.
	vec3 painted = grass_paint_color * mix(1.0, clamp(lum / max(grass_paint_ref, 0.01), 0.6, 1.5), 0.35);
	if (grass_wave_strength > 0.0) {
		vec2 q = xz - normalize(grass_wave_dir) * (grass_time_override >= 0.0 ? grass_time_override : time) * grass_wave_speed;
		// Two unrelated scales and orientations: one noise tile alone repeats and reads as a pattern.
		float wa = texture(grass_wave_noise, q / grass_wave_scale_m).r;
		float wb = texture(grass_wave_noise, vec2(q.x * 0.8 - q.y * 0.6, q.x * 0.6 + q.y * 0.8) / (grass_wave_scale_m * 2.37) + vec2(0.31, 0.77)).a;
		float wave = clamp((mix(wa, wb, 0.42) - 0.5) * 1.3 + 0.5, 0.0, 1.0);
		painted *= 1.0 + smoothstep(0.45, 0.8, wave) * grass_wave_strength;
	}
	return mix(alb, painted, k);
}
