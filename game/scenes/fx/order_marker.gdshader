shader_type spatial;
// Order marker cone (F220): additive, shadeless. SacCommandCone draws its cone and shells with an additive
// shadeless material whose energy is 0.4 * (3 / (r + g + b))^4, so every color reads about as bright.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

// The aura sheet on the cone; the shells leave it empty and read white.
uniform sampler2D aura : source_color, filter_linear_mipmap, repeat_disable, hint_default_white;
uniform vec3 tint : source_color = vec3(1.0);
uniform float energy = 0.4;
uniform float alpha = 1.0;

void fragment() {
	ALBEDO = texture(aura, UV).rgb * tint * energy;
	ALPHA = alpha;
}
