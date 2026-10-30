shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

#include "res://scenes/fx/noisy_sphere.gdshaderinc"

// Explosion's ball: a sphere of radius 0.5 with a skin of noise that wears the atlas of lava (exeg, 4 x 4 cells, a new cell every two ticks)
// and turns half a turn a second. Three of them overlap, each twenty frames later in the loop (`phase_frames`). Additive, as the original.

uniform sampler2D skin : source_color, filter_linear_mipmap, repeat_enable;
uniform vec2 cells = vec2(4.0, 4.0);
uniform float frame_s = 0.0333;
uniform float energy = 8.0;
uniform float layer_alpha = 0.5;
uniform float noise_amount = 0.06;
uniform float morph_s = 0.5;
uniform float turns_per_s = 0.5;
#include "res://scenes/look/compat/per_instance.gdshaderinc"
PER_INSTANCE uniform float phase_frames = 0.0;
// 1 = whole; the burst's spheres fade out with it.
PER_INSTANCE uniform float fade = 1.0;

varying vec3 sphere_normal;

void vertex() {
	sphere_normal = normalize(VERTEX);
	VERTEX = noisy_skin(VERTEX, TIME / morph_s + phase_frames * 0.1, noise_amount);
}

void fragment() {
	float u = atan(sphere_normal.z, sphere_normal.x) / 6.2831853 + 0.5 + TIME * turns_per_s;
	float v = asin(clamp(sphere_normal.y, -1.0, 1.0)) / 3.1415927 + 0.5;
	float index = mod(floor(TIME / frame_s) + phase_frames, cells.x * cells.y);
	vec2 inside = vec2(mix(0.02, 0.98, fract(u)), mix(0.02, 0.98, v));
	vec4 tex = texture(skin, (inside + atlas_cell(index, cells)) / cells);
	ALBEDO = tex.rgb * energy;
	ALPHA = clamp(layer_alpha * fade, 0.0, 1.0);
}
