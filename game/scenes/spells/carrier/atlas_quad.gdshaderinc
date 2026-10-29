// What the sprites of the level-8 spells share: a quad that always faces the camera (it keeps the node's scale) and wears the cell of an atlas that
// changes every `frame_s` seconds. `offset` (per instance) puts each sprite of a swarm at its own point of the loop. The caller picks the blend
// (alpha or additive) with its own render_mode and says how bright the sprite is with `energy`.

uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform vec2 cells = vec2(4.0, 4.0);
uniform float frame_s = 0.0667;
uniform float energy = 1.0;
uniform vec4 tint : source_color = vec4(1.0);
instance uniform float offset = 0.0;
// 0 to 1, from the node's script: the sprite fades out with it.
instance uniform float fade = 1.0;

void vertex() {
	mat4 mat_world = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat_world * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

vec4 atlas_color(vec2 uv) {
	float total = cells.x * cells.y;
	float index = mod(floor(TIME / frame_s) + offset, total);
	vec2 cell = vec2(mod(index, cells.x), floor(index / cells.x));
	return texture(atlas, (uv + cell) / cells) * tint;
}
