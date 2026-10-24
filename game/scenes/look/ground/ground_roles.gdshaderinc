// Where each kind of ground (role) shows: the map's ground_roles.png (R open, G earth, B rock, A path; 1 px = one 10 m cell),
// broken up with noise so the cells do not read as squares, taken over by a role on steep slopes, and blended by height so the
// bright (high) parts of one ground poke through the other. `GroundMaterial` fills these uniforms from a `GodGround`.

uniform sampler2D ground_roles : filter_linear, repeat_disable, hint_default_black;
uniform sampler2D ground_noise : filter_linear_mipmap, repeat_enable, hint_default_white;
uniform float roles_map_size = 2560.0;
uniform float edge_noise = 0.55;
uniform float blend_depth = 0.18;
// Per role (x..w = open, earth, rock, path).
uniform vec4 role_takes_slope = vec4(90.0);
uniform vec4 role_height_contrast = vec4(0.6);
uniform bool use_macro = false;
uniform float macro_strength = 0.0;
uniform float macro_scale_m = 200.0;

// Weight of each role at a map position (sum 1). `slope_deg` is the angle of the surface from the horizontal.
vec4 role_weights(vec2 xz, float slope_deg) {
	vec4 n_fine = texture(ground_noise, xz / 6.5);
	vec4 n_patch = texture(ground_noise, xz / 26.0);
	float n = (n_fine.r * 0.6 + n_patch.a * 0.4 - 0.5) * edge_noise;
	vec4 w = texture(ground_roles, xz / roles_map_size);
	w = clamp((w - 0.5 + n) * 2.6 + 0.5, 0.0, 1.0);
	vec4 takes = smoothstep(role_takes_slope - 4.0, role_takes_slope + 4.0, vec4(slope_deg + (n_fine.g - 0.5) * 10.0));
	takes *= step(role_takes_slope, vec4(89.9));
	for (int i = 0; i < 4; i++) {
		vec4 only = vec4(0.0);
		only[i] = 1.0;
		w = mix(w, only, takes[i]);
	}
	float total = w.x + w.y + w.z + w.w;
	if (total < 0.002) {
		return vec4(1.0, 0.0, 0.0, 0.0);
	}
	return w / total;
}

// The weights after the height blend: `heights` (0..1) of each role at this pixel. Sum 1.
vec4 role_height_blend(vec4 w, vec4 heights) {
	vec4 used = step(vec4(0.002), w);
	vec4 score = (w + heights * role_height_contrast * 0.5) * used;
	float top = max(max(score.x, score.y), max(score.z, score.w));
	vec4 f = max(score - (top - blend_depth), vec4(0.0)) * used;
	float total = f.x + f.y + f.z + f.w;
	return total < 0.0001 ? w : f / total;
}

// Low and mid frequency brightness drift of the ground (presets with macro on).
float role_macro(vec2 xz) {
	if (!use_macro || macro_strength <= 0.0) {
		return 1.0;
	}
	float low = texture(ground_noise, xz / macro_scale_m).r;
	float mid = texture(ground_noise, (xz + vec2(517.0, 233.0)) / (macro_scale_m * 0.23)).g;
	return 1.0 + ((low - 0.5) * 1.6 + (mid - 0.5) * 0.6) * macro_strength;
}
