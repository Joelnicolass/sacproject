shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// A sprite of the original drawn with its own alpha (Intestinal Vaporization's shot and guts: sacengine Transparent, energy 3).
#include "res://scenes/spells/carrier/atlas_quad.gdshaderinc"

void fragment() {
	vec4 tex = atlas_color(UV);
	ALBEDO = tex.rgb * energy;
	ALPHA = clamp(tex.a * fade, 0.0, 1.0);
}
