shader_type spatial;
// Two sided: the map has faces seen from behind (cliffs, hole edges, the void walls).
// Godot flips NORMAL on back faces before fragment(), so they light like the front.
render_mode cull_disabled;

uniform sampler2D atlas : filter_linear_mipmap, repeat_enable;
// Pixels per tile side in the atlas (16x16 tiles). The lookup stays half a pixel inside the tile so the filter never
// reads the tile next to it in the atlas: each tile is clamped to its own edge, like a texture of its own.
const float TILE_PX = 64.0;
// The fine grain of the ground (stones, leaves, cracks): one grey layer per kind of ground, stretched over each
// 10 m cell, 4x the atlas resolution. `detail_ids` says the layer of each atlas tile (one pixel per tile, id in R).
// Brightness *= (1 + detail) / (1 + mean of the layer): the grain changes the texture, not the calibrated colour.
// No layers (the default white) = no grain.
uniform sampler2DArray detail : filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
uniform sampler2D detail_ids : filter_nearest, repeat_disable, hint_default_black;
/** 0 = no grain, 1 = as strong as the original's grain. */
uniform float detail_strength : hint_range(0.0, 2.0, 0.01) = 0.0;
/** How many times the grain repeats over one 10 m cell. */
uniform float detail_repeat : hint_range(1.0, 8.0, 1.0) = 1.0;
// Ref: sacmap.d:196-206 (DT layers per MAPG group, mirrored-repeat tiles), sacmap.d:887-888 (texcoords 0..1 per cell),
// renderer.d:1262-1300 (detail bound per tile), dagon terrain2.d fragment (0.5 * diffuse * (1 + detail) * lightmap).
uniform sampler2D lightmap : filter_linear, repeat_disable;
// The walls under the edge of the land wear the god's cliff texture, not the cell's tile.
#include "res://scenes/look/ground/ground_edge.gdshaderinc"
// A map in its own land (NativeGround): the tile of each 10 m cell comes from this 256x256 index (id in R) instead of the
// mesh colors, so the atlas can hold the land's tiles at the ids the map stores. Off = the mesh colors, as every map.
uniform sampler2D tile_index : filter_nearest, repeat_disable, hint_default_black;
uniform bool use_tile_index = false;
// The map's baked light is a multiplier; these two shape how strongly it reads.
// Brightness = albedo * (light_base + light * light_gain).
/** Light left where the light map is black. */
uniform float light_base : hint_range(0.0, 2.0, 0.01) = 0.3;
/** How much the light map adds on top of light_base. */
uniform float light_gain : hint_range(0.0, 4.0, 0.01) = 0.55;

// The far grass paint (022e4): where the grass grows the ground takes the color of the field, so far
// from the camera it fades into it. `GrassField` fills it; grass_paint_amount 0 (the default) = this
// shader is the same as before. The zone mask comes from the map's TileLayerMap.
#include "res://scenes/look/ground/zone_splat.gdshaderinc"
#include "res://scenes/look/ground/grass_paint.gdshaderinc"
// The ground can move after the map loaded (RFC-057): the vertices are moved here, the mesh is never rebuilt.
#include "res://scenes/look/ground/terrain_deform.gdshaderinc"
// The marks on the ground (burns, cracks), over the ground and under the light.
#include "res://scenes/look/ground/ground_scars.gdshaderinc"

// Map coordinates of the fragment. The terrain mesh is stored in map coordinates, so the local
// vertex is used: the light map stays put when the editor preview shifts the scene root.
varying vec3 map_pos;
varying float slope_deg;

void vertex() {
	map_pos = VERTEX;
	deform_hole = 0.0;
	if (terrain_deform_on > 0.5 && deform_follow > 0.5) {
		vec2 shift = deform_at(VERTEX.xz);
		NORMAL = deform_normal(NORMAL, VERTEX.xz);
		VERTEX.y += shift.x;
		deform_hole = shift.y;
	}
	slope_deg = degrees(acos(clamp(NORMAL.y, -1.0, 1.0)));
}

void fragment() {
	if (deform_hole > 0.0001) {
		discard;
	}
	vec3 albedo;
	if (ground_edge_is_wall(COLOR)) {
		vec2 wall = ground_edge_uv(UV);
		albedo = ground_edge_albedo(wall, dFdx(wall), dFdy(wall));
	} else {
		float id = COLOR.r * 255.0;
		if (use_tile_index) {
			id = floor(texture(tile_index, (floor(map_pos.xz / 10.0) + 0.5) / 256.0).r * 255.0 + 0.5);
		}
		vec2 cell = vec2(mod(id, 16.0), floor(id / 16.0));
		vec2 in_tile = clamp(COLOR.gb, vec2(0.5 / TILE_PX), vec2(1.0 - 0.5 / TILE_PX));
		albedo = texture(atlas, (cell + in_tile) / 16.0).rgb;
		if (detail_strength > 0.0) {
			float layer = floor(texelFetch(detail_ids, ivec2(cell), 0).r * 255.0 + 0.5);
			vec3 duv = vec3(COLOR.gb * detail_repeat, layer);
			float grain = texture(detail, duv).r;
			float grain_mean = textureLod(detail, duv, 8.0).r;
			albedo *= mix(1.0, (1.0 + grain) / (1.0 + grain_mean), detail_strength);
		}
	}
	if (grass_paint_amount > 0.0 && !ground_edge_is_wall(COLOR)) {
		albedo = grass_paint_textured(albedo, zone_splat_weights(map_pos.xz), map_pos.xz, TIME, slope_deg);
	}
	albedo = ground_scar_mix(albedo, map_pos.xz, false);
	vec2 light_uv = vec2(map_pos.x, map_pos.z) / 2560.0;
	vec3 light = texture(lightmap, light_uv).rgb;
	ALBEDO = albedo * (light_base + light * light_gain);
	ROUGHNESS = 1.0;
}
