shader_type spatial;
// Dragonfire's dragon (dfir): no lighting, alpha blend, very bright, drawn from both sides and never writing depth, as the original
// draws it (energy 20, transparency 0.5). One material per surface: the body (M000) and the wings (M001).
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform float energy : hint_range(0.0, 40.0) = 20.0;
uniform float opacity : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	vec4 texel = texture(albedo_texture, UV);
	ALBEDO = texel.rgb * energy;
	ALPHA = texel.a * opacity;
}
