shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, shadows_disabled, blend_mix;

instance uniform float fraction : hint_range(0.0, 1.0) = 1.0;
instance uniform vec4 fill_color : source_color = vec4(0.2, 0.85, 0.25, 1.0);
uniform vec4 back_color : source_color = vec4(0.05, 0.05, 0.05, 0.75);
uniform float border = 0.12;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 edge = min(UV, 1.0 - UV) * vec2(1.0, 8.0);
	bool inner = edge.x > border * 0.125 && edge.y > border;
	bool filled = inner && UV.x <= fraction;
	vec4 color = filled ? fill_color : back_color;
	ALBEDO = color.rgb;
	ALPHA = color.a;
}
