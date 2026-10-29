shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, fog_disabled, shadows_disabled;

#include "res://scenes/fx/noisy_sphere.gdshaderinc"

// One layer of a storm cloud. The original builds it from a sphere of 24 x 25 vertices, each pushed off its place by a random vector (the
// sphere's radius is 0.676 and the push 0.324, smoothed with the four neighbours), and keeps twenty of those lumpy spheres, each a
// different shape, drawn one over the other through a veil only `layer_alpha` thick: where the shapes agree the cloud is nearly solid,
// where they differ its edge frays. Here the push is a smooth 3D noise of the vertex's direction in every axis (not along the normal), with
// another place in the noise for every layer (INSTANCE_CUSTOM.x) that slides through it as time goes, as the original morphs between its
// shapes. Black, or wearing an atlas (Cloudkill's blue veins, one cell every `frame_s`). `size` (0 to 1) is how much of the cloud exists.
// Not in the original, so the volume reads against a bright sky: a pale rim where the skin turns away and a pale top (`rim_color`, `top_color`;
// black = the original's flat veil).

uniform vec4 tint : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 rim_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 top_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float rim_power = 2.0;
// A light from `light_dir` (world) on the lumps, and a mottling of the skin: what makes the inside of the cloud readable (not in the original).
uniform vec3 light_dir = vec3(0.3, 0.8, 0.3);
uniform vec4 light_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 mottle_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float mottle_scale = 5.0;
// The veil is this share as thick where the skin faces the camera (the middle of the cloud) as where it turns away (its edge), so the
// layers behind show through the middle (1 = the original's even veil).
uniform float core_alpha = 1.0;
uniform sampler2D skin : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_skin = false;
uniform vec2 cells = vec2(4.0, 4.0);
uniform float frame_s = 0.1333;
uniform float energy = 1.0;
uniform float layer_alpha = 0.15;
// How far each vertex is pushed, as a share of the radius (0.324 in the original), and the size of the lumps (lumps across the sphere's
// circumference, about 2 pi times this).
uniform float noise_amount = 0.324;
uniform float noise_scale = 2.5;
// Seconds that take the noise through one lump.
uniform float morph_s = 8.0;
instance uniform float size = 1.0;

varying vec3 sphere_normal;
varying float layer_seed;

vec3 rough_skin(vec3 vertex, float seed, float t) {
	vec3 n = normalize(vertex);
	vec3 p = n * noise_scale + vec3(seed, seed * 0.37, seed * 0.71) + vec3(t);
	vec3 push = vec3(value_noise(p), value_noise(p + vec3(31.4, 17.1, 5.7)), value_noise(p + vec3(7.3, 47.9, 23.1))) * 2.0 - 1.0;
	return 0.5 * ((1.0 - noise_amount) * n + noise_amount * push);
}

void vertex() {
	sphere_normal = normalize(VERTEX);
	layer_seed = INSTANCE_CUSTOM.x;
	VERTEX = rough_skin(VERTEX, INSTANCE_CUSTOM.x, TIME / morph_s);
}

void fragment() {
	vec3 color = tint.rgb;
	if (use_skin) {
		float u = atan(sphere_normal.z, sphere_normal.x) / 6.2831853 + 0.5;
		float v = asin(clamp(sphere_normal.y, -1.0, 1.0)) / 3.1415927 + 0.5;
		float index = mod(floor(TIME / frame_s), cells.x * cells.y);
		vec2 inside = vec2(mix(0.02, 0.98, fract(u)), mix(0.02, 0.98, v));
		color = texture(skin, (inside + atlas_cell(index, cells)) / cells).rgb * energy;
	}
	vec3 skin_normal = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	if (dot(skin_normal, NORMAL) < 0.0) {
		skin_normal = -skin_normal;
	}
	float facing = abs(dot(skin_normal, normalize(-VERTEX)));
	float up = max((INV_VIEW_MATRIX * vec4(skin_normal, 0.0)).y, 0.0);
	vec3 world_normal = (INV_VIEW_MATRIX * vec4(skin_normal, 0.0)).xyz;
	float lit = clamp(dot(world_normal, normalize(light_dir)) * 0.5 + 0.5, 0.0, 1.0);
	float mottle = value_noise(sphere_normal * mottle_scale + vec3(layer_seed));
	color += rim_color.rgb * pow(1.0 - facing, rim_power) + top_color.rgb * up + light_color.rgb * lit * lit + mottle_color.rgb * mottle;
	ALBEDO = color;
	ALPHA = clamp(layer_alpha * size * mix(core_alpha, 1.0, 1.0 - facing), 0.0, 1.0);
}
