// The cliff texture on the walls that hang under the edge of the land: the map's rim, a Bore pit, a falling piece.
// The mesh says where (WallUvRules): COLOR.a < 0.5 marks a wall, UV.x = metres along the rim, UV.y = 0 at the rim and
// 1 at the wall's foot. Across, the texture repeats every `edge_repeat_m` metres with every other copy mirrored, so a
// wall of any length keeps the texture's width and the next wall goes on without a jump; down, it is laid once over the
// whole wall (its top rows are the grass fringe under the rim). A ground shader includes this file and calls
// ground_edge_is_wall / ground_edge_uv / ground_edge_albedo from fragment() (the derivatives are fragment built-ins).
// Ref: sacmap.d:204-205 (mirrored repeat), sacmap.d:780-813 (texture once down the 50 m wall).

// The god's cliff texture (themes/<god>/edge.png).
uniform sampler2D edge : filter_linear_mipmap, repeat_enable;
// Off: the walls wear the tile of their cell like the land.
uniform bool has_edge = false;
/** Metres of rim one copy of the cliff texture covers (the original: one copy per 10 m wall). */
uniform float edge_repeat_m : hint_range(1.0, 50.0, 0.5) = 10.0;

bool ground_edge_is_wall(vec4 color) {
	return color.a < 0.5 && has_edge;
}

// The wall's texture coordinate before mirroring: take dFdx / dFdy of this one (smooth across the folds).
vec2 ground_edge_uv(vec2 wall_uv) {
	return vec2(wall_uv.x / edge_repeat_m, wall_uv.y);
}

vec3 ground_edge_albedo(vec2 unfolded, vec2 dx, vec2 dy) {
	float half_texel = 0.5 / float(textureSize(edge, 0).y);
	vec2 folded = vec2(1.0 - abs(mod(unfolded.x, 2.0) - 1.0), clamp(unfolded.y, half_texel, 1.0 - half_texel));
	return textureGrad(edge, folded, dx, dy).rgb;
}
