// What the ground shader and the grass shader share, so a blade's root has the color of the ground
// under it: the zone mask (splat of the original map's 10 m cells), the slope / altitude / patch
// rules per layer, and the macro color drift. Extracted from ground_pbr.gdshader in 022e1 with no
// change to the ground. `GroundMaterial` fills these uniforms from a `GroundSet`.

uniform sampler2D splat : filter_linear, repeat_disable, hint_default_black;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable, hint_default_white;
uniform sampler2D lightmap : filter_linear, repeat_disable, hint_default_white;

uniform float map_size = 2560.0;
uniform int layer_count : hint_range(1, 4) = 4;
uniform bool use_macro = true;

// Per layer (index = slot).
uniform vec4 tint[4];
uniform float height_contrast[4];
// x: slope min (deg), y: slope max, z: soft width, w: tile weight
uniform vec4 slope_rule[4];
// x: altitude min, y: altitude max, z: soft width, w: patchiness
uniform vec4 alt_rule[4];
// x: triplanar, y: stochastic, z: roughness offset, w: priority
uniform vec4 layer_flags[4];

uniform float blend_depth = 0.18;
uniform float zone_edge_noise = 0.55;
uniform float macro_scale_m = 200.0;
uniform float macro_strength = 0.28;
uniform float macro_roughness = 0.15;
uniform float patch_scale_m = 26.0;
uniform float patch_softness = 0.32;
uniform float lightmap_tint = 0.0;

vec4 noise4(vec2 p, float scale_m) {
	return texture(noise_tex, p / scale_m);
}

float rule_weight(int i, float slope, float alt, float splat_w, float patch_n) {
	vec4 s = slope_rule[i];
	vec4 h = alt_rule[i];
	float by_slope = smoothstep(s.x - s.z, s.x, slope) * (1.0 - smoothstep(s.y, s.y + s.z, slope));
	if (s.x <= 0.0) {
		by_slope = 1.0 - smoothstep(s.y, s.y + s.z, slope);
	}
	float by_alt = smoothstep(h.x - h.z, h.x, alt) * (1.0 - smoothstep(h.y, h.y + h.z, alt));
	float zone = mix(1.0, splat_w, s.w);
	float patches = mix(1.0, smoothstep(0.5 - patch_softness * 0.5, 0.5 + patch_softness * 0.5, patch_n), h.w);
	return by_slope * by_alt * zone * patches * layer_flags[i].w;
}

// Rule weight of each layer (x..w = slots 0..3) at a map position. `geo_slope_deg` is the angle of
// the surface from the horizontal; `alt` the height above the map's zero.
vec4 ground_rules(vec2 xz, float geo_slope_deg, float alt) {
	vec4 n_fine = noise4(xz, 6.5);
	vec4 n_patch = noise4(xz, patch_scale_m);
	float slope = geo_slope_deg + (n_fine.g - 0.5) * 10.0;

	// Zone mask from the original map, broken up so the 10 m cells do not read.
	float n_zone = (n_fine.r * 0.6 + n_patch.a * 0.4 - 0.5) * zone_edge_noise;
	vec4 sp = texture(splat, xz / map_size);
	sp = clamp((sp - 0.5 + n_zone) * 2.6 + 0.5, 0.0, 1.0);
	float spl[4] = float[4](sp.r, sp.g, sp.b, sp.a);

	float rule[4];
	for (int i = 0; i < 4; i++) {
		rule[i] = 0.0;
		if (i < layer_count) {
			rule[i] = rule_weight(i, slope, alt, spl[i], n_patch[i]);
		}
	}
	return vec4(rule[0], rule[1], rule[2], rule[3]);
}

// Low and mid frequency drift of the ground's brightness (about -1..1).
float ground_drift(vec2 xz) {
	float m_low = noise4(xz, macro_scale_m).r;
	float m_hi = noise4(xz + vec2(517.0, 233.0), macro_scale_m * 0.23).g;
	return (m_low - 0.5) * 1.6 + (m_hi - 0.5) * 0.6;
}

vec3 ground_macro_mul(float drift) {
	return vec3(1.0 + drift * macro_strength, 1.0 + drift * macro_strength * 0.8, 1.0 + drift * macro_strength * 0.55);
}

vec3 ground_lightmap_mul(vec2 xz) {
	vec3 lm = texture(lightmap, xz / map_size).rgb;
	return mix(vec3(1.0), lm * 1.6, lightmap_tint);
}

// The far grass paint (shared with the classic ground).
#include "res://scenes/world/look/ground/grass_paint.gdshaderinc"
