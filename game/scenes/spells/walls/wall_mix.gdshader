shader_type spatial;
// The Wailing Wall: the atlas of faces drawn over the world with its alpha, without shading or light.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

#include "res://scenes/spells/walls/wall.gdshaderinc"

uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform float energy = 1.0;
// How much of the faces shows: the original draws them at 160 of 255.
uniform float opacity : hint_range(0.0, 1.0) = 0.63;

void vertex() {
	float along = VERTEX.x * reach;
	along_m = along;
	wall_vertex(VERTEX, along);
}

void fragment() {
	vec4 texel = texture(atlas, wall_uv(UV));
	ALBEDO = texel.rgb * energy;
	ALPHA = texel.a * opacity;
}
