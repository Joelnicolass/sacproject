shader_type spatial;
render_mode unshaded, blend_mix, cull_back, depth_draw_never, shadows_disabled;

// Air Shield's bubble: a sphere of radius 0.5 whose skin is pushed in and out by smooth 3D noise (the original morphs 16 noisy
// meshes), wearing one cell of an atlas projected polar: the middle of the picture on the poles, its edge on the equator.
// Three of these overlap, each a little later in the morph (`phase`). Alpha blended, not additive.

uniform sampler2D swirl : source_color, repeat_enable, filter_linear_mipmap;
// Cells of the atlas: shld (the bubble of the original) is 4 x 2; a single picture is (1, 1).
uniform vec2 cells = vec2(4.0, 2.0);
uniform float cell_s = 0.1333;
uniform float energy = 5.0;
uniform float layer_alpha = 0.075;
uniform float noise_amount = 0.12;
uniform float morph_s = 0.5;
uniform float pulse_amount = 0.05;
uniform float pulse_hz = 2.0;
#include "res://scenes/look/compat/per_instance.gdshaderinc"
PER_INSTANCE uniform float phase : hint_range(0.0, 1.0) = 0.0;

varying vec3 sphere_normal;

float hash31(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float value_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash31(i), hash31(i + vec3(1, 0, 0)), f.x), mix(hash31(i + vec3(0, 1, 0)), hash31(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash31(i + vec3(0, 0, 1)), hash31(i + vec3(1, 0, 1)), f.x), mix(hash31(i + vec3(0, 1, 1)), hash31(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	sphere_normal = normalize(VERTEX);
	float t = TIME / morph_s + phase * 3.0;
	float bump = value_noise(sphere_normal * 2.5 + vec3(t * 0.35, t * 0.2, -t * 0.3)) - 0.5;
	float pulse = 1.0 + pulse_amount * sin(TIME * 6.2831853 * pulse_hz);
	VERTEX = sphere_normal * (0.5 + bump * 2.0 * noise_amount) * pulse;
}

void fragment() {
	vec2 polar = 0.5 + 0.5 * sphere_normal.xz;
	float count = cells.x * cells.y;
	float index = mod(floor(TIME / cell_s + phase * count), count);
	vec2 cell = vec2(mod(index, cells.x), floor(index / cells.x));
	vec4 tex = texture(swirl, (polar + cell) / cells);
	ALBEDO = tex.rgb * energy;
	ALPHA = clamp(layer_alpha * tex.a, 0.0, 1.0);
}
