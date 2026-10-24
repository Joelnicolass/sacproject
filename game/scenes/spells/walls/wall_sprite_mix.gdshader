shader_type spatial;
// A sprite that always faces the camera, drawn over the world with its alpha, shadeless (the violet bubble of a post of the Fence).
// Per instance only its place and size (the instance's scale).
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

uniform sampler2D picture : source_color, filter_linear_mipmap, repeat_disable;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;

void vertex() {
	mat4 world = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * world * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec4 texel = texture(picture, UV);
	ALBEDO = texel.rgb;
	ALPHA = texel.a * opacity;
}
