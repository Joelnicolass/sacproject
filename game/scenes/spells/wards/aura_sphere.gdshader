shader_type spatial;
render_mode unshaded, blend_add, cull_front, depth_draw_never, shadows_disabled;

#include "res://scenes/fx/noisy_sphere.gdshaderinc"

// Healing Aura's veil: a sphere of radius 0.5 seen from the inside (only its far faces draw), whose skin moves with noise and wears the gold
// atlas haur (4 x 4 cells, a new one every four ticks), projected from above: the middle of the picture on the poles. Three of them overlap,
// each twenty frames later in the loop (`phase_frames`). Additive and very faint, as the original: a golden mist around the carrier.

uniform sampler2D veil : source_color, filter_linear_mipmap, repeat_enable;
uniform vec2 cells = vec2(4.0, 4.0);
uniform float cell_s = 0.0667;
uniform float energy = 5.0;
uniform float layer_alpha = 0.075;
uniform float noise_amount = 0.06;
uniform float morph_s = 0.5;
#include "res://scenes/look/compat/per_instance.gdshaderinc"
PER_INSTANCE uniform float phase_frames = 0.0;

varying vec3 sphere_normal;

void vertex() {
	sphere_normal = normalize(VERTEX);
	VERTEX = noisy_skin(VERTEX, TIME / morph_s + phase_frames * 0.1, noise_amount);
}

void fragment() {
	vec2 polar = clamp(0.5 + 0.5 * sphere_normal.xz, vec2(0.02), vec2(0.98));
	float index = mod(floor(TIME / cell_s) + phase_frames, cells.x * cells.y);
	vec4 tex = texture(veil, (polar + atlas_cell(index, cells)) / cells);
	ALBEDO = tex.rgb * energy;
	ALPHA = clamp(layer_alpha, 0.0, 1.0);
}
