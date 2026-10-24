// A sprite of the original that is one thing and not a particle (a frog, a drop of fire): a quad that always faces the camera and shows one
// cell of an atlas, chosen by the instance's `frame`. The sprite shaders include it and say how it blends.
uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform vec2 cells = vec2(4.0, 4.0);
uniform float energy = 1.0;
// The cell shown (left to right, then down) and how much of the sprite shows (1 = all).
instance uniform float frame = 0.0;
instance uniform float fade = 1.0;

void vertex() {
	mat4 face = mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	face = face * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * face;
	float cell = floor(frame + 0.5);
	UV = (UV + vec2(mod(cell, cells.x), floor(cell / cells.x))) / cells;
}

void fragment() {
	vec4 tex = texture(atlas, UV);
	ALBEDO = tex.rgb * energy;
	ALPHA = tex.a * fade;
}
