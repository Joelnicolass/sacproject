shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

// A sprite of the original drawn with light added (Charm's big heart: sacengine Additive, energy 24).
#include "res://scenes/spells/carrier/atlas_quad.gdshaderinc"

void fragment() {
	vec4 tex = atlas_color(UV);
	ALBEDO = tex.rgb * energy;
	ALPHA = clamp(fade, 0.0, 1.0);
}
