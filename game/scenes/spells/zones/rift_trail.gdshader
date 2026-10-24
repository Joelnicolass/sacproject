shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

// The ribbon behind a spirit of a Demonic Rift: the strips of `rift` (8, a new one every four ticks) stretched along the trail, the picture's
// tapering tail at the back. Additive, bright (energy 20 in the original).

uniform sampler2D trail : source_color, filter_linear_mipmap, repeat_disable;
uniform float strips = 8.0;
uniform float strip_s = 0.0667;
uniform float energy = 20.0;
uniform float opacity = 0.35;

void fragment() {
	float strip = mod(floor(TIME / strip_s), strips);
	vec4 tex = texture(trail, vec2(clamp(UV.x, 0.0, 1.0), (strip + UV.y) / strips));
	ALBEDO = tex.rgb * energy;
	ALPHA = clamp(tex.a * opacity * (1.0 - UV.x), 0.0, 1.0);
}
