shader_type spatial;
// A sprite that always faces the camera, from an atlas, added to the world, turning in its plane (the sparks round a post of the Fence).
// Per instance only its place and size (the instance's scale).
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform ivec2 grid = ivec2(4, 4);
uniform float frame_s = 0.0667;
uniform float energy = 5.0;
// Turns a second (the original's rods spin 0.0262 rad a tick, 1.5 turns a second).
uniform float spin_per_s = 1.5;

void vertex() {
	float angle = TIME * TAU * spin_per_s;
	mat4 world = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	world = world * mat4(vec4(cos(angle), -sin(angle), 0.0, 0.0), vec4(sin(angle), cos(angle), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * world * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	int cells = grid.x * grid.y;
	int cell = int(floor(TIME / frame_s)) % cells;
	vec2 size = 1.0 / vec2(grid);
	vec2 at = (vec2(float(cell % grid.x), float(cell / grid.x)) + UV) * size;
	vec4 texel = texture(atlas, at);
	ALBEDO = texel.rgb * energy;
	ALPHA = 1.0;
}
