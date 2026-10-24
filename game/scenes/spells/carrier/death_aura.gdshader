shader_type spatial;
render_mode unshaded, blend_sub, cull_back, depth_draw_never, shadows_disabled;

#include "res://scenes/fx/noisy_sphere.gdshaderinc"

// The cloud that goes with Death: a sphere with a skin of noise that grows from nothing to `size` in `period_s` and starts again, and takes light
// OUT of what is behind it (the cloud's picture, dth2, with its colors turned over; sacengine draws it with a negative energy, -0.25 / 3 times
// the square of what is left to grow). Three of them overlap, each twenty frames later in the noise (`phase_frames`).

uniform sampler2D skin : source_color, filter_linear_mipmap, repeat_enable;
uniform vec2 cells = vec2(4.0, 4.0);
uniform float frame_s = 0.0667;
uniform float energy = 0.0833;
uniform float noise_amount = 0.06;
uniform float morph_s = 0.5;
uniform float period_s = 2.0;
// The diameter the cloud ends at, in meters (2.4 x 2.4 x 1.9 times Death's height).
uniform vec3 size = vec3(28.8, 28.8, 22.8);
instance uniform float phase_frames = 0.0;

varying vec3 sphere_normal;
varying float growth;

void vertex() {
	sphere_normal = normalize(VERTEX);
	growth = fract(TIME / period_s);
	VERTEX = noisy_skin(VERTEX, TIME / morph_s + phase_frames * 0.1, noise_amount) * size * growth;
}

void fragment() {
	float u = atan(sphere_normal.z, sphere_normal.x) / 6.2831853 + 0.5;
	float v = asin(clamp(sphere_normal.y, -1.0, 1.0)) / 3.1415927 + 0.5;
	float index = mod(floor(TIME / frame_s) + phase_frames, cells.x * cells.y);
	vec2 inside = vec2(mix(0.02, 0.98, fract(u)), mix(0.02, 0.98, v));
	vec3 tex = vec3(1.0) - texture(skin, (inside + atlas_cell(index, cells)) / cells).rgb;
	float left = 1.0 - growth;
	ALBEDO = tex * energy * left * left * 3.0;
	ALPHA = 1.0;
}
