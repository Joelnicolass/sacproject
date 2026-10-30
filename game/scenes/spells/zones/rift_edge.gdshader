shader_type spatial;
render_mode unshaded, blend_sub, cull_disabled, depth_draw_never, shadows_disabled;

// The wall of a Demonic Rift: a cylinder wearing the strips of flame of rif2 (8 strips, a new one every four ticks) drawn with a subtracting
// blend, so the flames are dark where they cover the ground: a black mouth, not a glow. `emerge` (0 to 1) is how much of the mouth is out;
// its square is the opacity.

uniform sampler2D edge : source_color, filter_linear_mipmap, repeat_enable;
uniform float strips = 8.0;
uniform float strip_s = 0.0667;
uniform float energy = 3.0;
#include "res://scenes/look/compat/per_instance.gdshaderinc"
PER_INSTANCE uniform float emerge = 0.0;

void fragment() {
	float strip = mod(floor(TIME / strip_s), strips);
	vec4 tex = texture(edge, vec2(UV.x * 2.0, (strip + UV.y) / strips));
	ALBEDO = tex.rgb * energy;
	ALPHA = clamp(tex.a * emerge * emerge, 0.0, 1.0);
}
