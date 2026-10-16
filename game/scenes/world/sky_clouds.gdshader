shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform sampler2D clouds : source_color, filter_linear_mipmap, repeat_enable;
uniform float energy = 1.7;
uniform float max_alpha = 1.0;
uniform float max_tex_coord = 4.0;
uniform vec2 offset = vec2(0.0);

void fragment() {
	vec2 loc = 2.0 * UV / max_tex_coord - vec2(1.0);
	vec4 texel = texture(clouds, UV - offset);
	ALBEDO = min(texel.rgb * energy, vec3(1.0));
	ALPHA = clamp(texel.a * max_alpha * (1.0 - dot(loc, loc)), 0.0, 1.0);
}
