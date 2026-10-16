shader_type spatial;
// Two sided: the map has faces seen from behind (cliffs, hole edges, the void walls).
// Godot flips NORMAL on back faces before fragment(), so they light like the front.
render_mode cull_disabled;

uniform sampler2D atlas : filter_linear_mipmap, repeat_enable;
uniform sampler2D lightmap : filter_linear, repeat_disable;
// ENVI EDGE: sacmap.d draws the void walls with meshes[edgeIndex], not the cell's tile.
uniform sampler2D edge : filter_linear_mipmap, repeat_enable;
uniform bool has_edge = false;
// The map's baked light is a multiplier; these two shape how strongly it reads.
// Brightness = albedo * (light_base + light * light_gain).
/** Light left where the light map is black. */
uniform float light_base : hint_range(0.0, 2.0, 0.01) = 0.3;
/** How much the light map adds on top of light_base. */
uniform float light_gain : hint_range(0.0, 4.0, 0.01) = 0.55;

// The far grass paint (022e4): where the grass grows the ground takes the color of the field, so far
// from the camera it fades into it. `GrassField` fills it; grass_paint_amount 0 (the default) = this
// shader is the same as before. The zone mask comes from the map's TileLayerMap.
#include "res://scenes/world/look/ground/zone_splat.gdshaderinc"
#include "res://scenes/world/look/ground/grass_paint.gdshaderinc"

// Map coordinates of the fragment. The terrain mesh is stored in map coordinates, so the local
// vertex is used: the light map stays put when the editor preview shifts the scene root.
varying vec3 map_pos;
varying float slope_deg;

void vertex() {
	map_pos = VERTEX;
	slope_deg = degrees(acos(clamp(NORMAL.y, -1.0, 1.0)));
}

void fragment() {
	vec3 albedo;
	if (COLOR.a < 0.5 && has_edge) {
		albedo = texture(edge, COLOR.gb).rgb;
	} else {
		float id = COLOR.r * 255.0;
		vec2 cell = vec2(mod(id, 16.0), floor(id / 16.0));
		vec2 uv = (cell + clamp(COLOR.gb, vec2(0.001), vec2(0.999))) / 16.0;
		albedo = texture(atlas, uv).rgb;
	}
	if (grass_paint_amount > 0.0 && !(COLOR.a < 0.5 && has_edge)) {
		albedo = grass_paint_textured(albedo, zone_splat_weights(map_pos.xz), map_pos.xz, TIME, slope_deg);
	}
	vec2 light_uv = vec2(map_pos.x, map_pos.z) / 2560.0;
	vec3 light = texture(lightmap, light_uv).rgb;
	ALBEDO = albedo * (light_base + light * light_gain);
	ROUGHNESS = 1.0;
}
