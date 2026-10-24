shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, fog_disabled, shadows_disabled;

#include "res://scenes/fx/noisy_sphere.gdshaderinc"

// One layer of a storm cloud: a sphere of radius 0.5 whose skin is pushed in and out by noise that drifts, seen through a veil that is only
// `layer_alpha` thick. Twenty of them, each in another moment of the drift (INSTANCE_CUSTOM.x), pile up into a cloud that is nearly solid at
// its middle. Black, or wearing an atlas (Cloudkill's blue veins, one cell every `frame_s`). `size` (0 to 1) is how much of the cloud exists.

uniform vec4 tint : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform sampler2D skin : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_skin = false;
uniform vec2 cells = vec2(4.0, 4.0);
uniform float frame_s = 0.1333;
uniform float energy = 1.0;
uniform float layer_alpha = 0.15;
uniform float noise_amount = 0.1;
uniform float morph_s = 8.0;
instance uniform float size = 1.0;

varying vec3 sphere_normal;

void vertex() {
	sphere_normal = normalize(VERTEX);
	VERTEX = noisy_skin(VERTEX, TIME / morph_s + INSTANCE_CUSTOM.x, noise_amount);
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
	ALBEDO = color;
	ALPHA = clamp(layer_alpha * size, 0.0, 1.0);
}
