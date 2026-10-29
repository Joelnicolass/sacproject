// The marks on the ground (burns, cracks, craters), painted by GroundScars (scenes/map/terrain/ground_scars.gd).
// An index (one texel per 10 m tile of the map) says which layer of the array holds the 10 m tile (R = layer, B = 0.5 when the tile has a mark); each layer
// is the 64 x 64 picture painted on that tile, straight (not premultiplied) alpha. Both are globals GroundScars fills. A scene
// without that node leaves them at the engine's default (white or black, never B = 0.5), so the ground is the same as before.

global uniform sampler2D scar_index;
global uniform sampler2DArray scar_tiles;

const float SCAR_TILE_M = 10.0;

// The mark over the ground at `map_xz` (map meters): rgb = its colour, a = how much of it covers the ground.
vec4 ground_scar(vec2 map_xz) {
	vec2 tile = floor(map_xz / SCAR_TILE_M);
	ivec2 cell = ivec2(tile);
	ivec2 grid = textureSize(scar_index, 0);
	if (cell.x < 0 || cell.y < 0 || cell.x >= grid.x || cell.y >= grid.y) {
		return vec4(0.0);
	}
	vec3 slot = texelFetch(scar_index, cell, 0).rgb;
	if (abs(slot.b - 0.5) > 0.05) {
		return vec4(0.0);
	}
	return textureLod(scar_tiles, vec3(map_xz / SCAR_TILE_M - tile, floor(slot.r * 255.0 + 0.5)), 0.0);
}

// `ground` with the mark over it. `to_linear`: the ground's albedo is linear (the PBR ground) while the mark's pixels are
// stored as the original painted them (the classic ground uses them the same way, so it passes false).
vec3 ground_scar_mix(vec3 ground, vec2 map_xz, bool to_linear) {
	vec4 mark = ground_scar(map_xz);
	vec3 color = to_linear ? pow(mark.rgb, vec3(2.2)) : mark.rgb;
	return mix(ground, color, mark.a);
}
