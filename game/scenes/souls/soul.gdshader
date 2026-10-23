shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// sacengine soul material (dagonBackend.d createMaterial(SacSoul)): shadeless, transparent,
// no depth write. One atlas cell per instance, always facing the camera.
uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
// Above the glow threshold of every biome (data/look/glow/), so souls bloom.
uniform float energy = 3.5;
uniform int h_frames = 4;
uniform int v_frames = 4;
instance uniform int frame = 0;

void vertex() {
	mat4 mat_world = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat_world;
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	float h = float(h_frames);
	float v = float(v_frames);
	UV /= vec2(h, v);
	UV += vec2(mod(float(frame), h) / h, floor(float(frame) / h) / v);
}

void fragment() {
	vec4 tex = texture(atlas, UV);
	ALBEDO = tex.rgb * energy;
	ALPHA = tex.a;
}
