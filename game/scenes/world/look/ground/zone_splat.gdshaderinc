// The zone mask of the map (one mask for every biome): the splat of the original map's 10 m cells
// (tile id -> slot of the map's TileLayerMap), broken up with noise so the cells do not read. Used
// by the grass bake (where it grows, how tall) and by the classic ground shader (where the far grass
// paint goes). `GroundMaterial.splat_texture` builds the splat from the TileLayerMap.

uniform sampler2D splat : filter_linear, repeat_disable, hint_default_black;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable, hint_default_white;
uniform float zone_edge_noise = 0.55;
uniform float zone_map_size = 2560.0;

// Weight of each slot (x..w = slots 0..3) at a map position. A tile with no slot falls back to
// slot 0, like the PBR ground does when no layer applies.
vec4 zone_splat_weights(vec2 xz) {
	vec4 n_fine = texture(noise_tex, xz / 6.5);
	vec4 n_patch = texture(noise_tex, xz / 26.0);
	float n_zone = (n_fine.r * 0.6 + n_patch.a * 0.4 - 0.5) * zone_edge_noise;
	vec4 sp = texture(splat, xz / zone_map_size);
	sp = clamp((sp - 0.5 + n_zone) * 2.6 + 0.5, 0.0, 1.0);
	float total = sp.r + sp.g + sp.b + sp.a;
	if (total < 0.002) {
		return vec4(1.0, 0.0, 0.0, 0.0);
	}
	return sp / max(total, 1.0);
}
