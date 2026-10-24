shader_type spatial;
// The Firewall: the atlas of flames added to the world without shading or light (the glow is the original's, not a light of the scene).
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

#include "res://scenes/spells/walls/wall.gdshaderinc"

uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
// Brightness (the original adds it at 15; under the filmic tonemap that burns it white).
uniform float energy = 2.0;

void vertex() {
	float along = VERTEX.x * reach;
	along_m = along;
	wall_vertex(VERTEX, along);
}

void fragment() {
	vec4 texel = texture(atlas, wall_uv(UV));
	ALBEDO = texel.rgb * energy;
	ALPHA = 1.0;
}
