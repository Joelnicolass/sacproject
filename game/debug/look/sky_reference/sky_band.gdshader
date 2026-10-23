shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform sampler2D band : source_color, filter_linear_mipmap, repeat_disable;
uniform float energy = 1.7;

void fragment() {
	vec4 texel = texture(band, UV);
	ALBEDO = min(texel.rgb * energy, vec3(1.0));
	ALPHA = texel.a;
}
