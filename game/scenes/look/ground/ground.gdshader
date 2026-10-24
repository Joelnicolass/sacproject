shader_type spatial;
// Two sided: the map has faces seen from behind (cliffs, hole edges, the void walls).
// Godot flips NORMAL on back faces before fragment(), so they light like the front.
render_mode cull_disabled;

// The ground of a god on any map: the map says which kind of ground (role) lies where (ground_roles.png), the god says what each
// kind looks like (GodGround), and the map's baked light shades it like the original's flat ground:
//   brightness = albedo * (light_base + light map * light_gain)
// The albedo is used as the land paints it (no sRGB decode), the way the original's ground was calibrated (RFC-059).
// Normal and ORM maps, three-sided projection and offset taps come in with the quality preset. `GroundMaterial` fills it.

#include "res://scenes/look/ground/ground_roles.gdshaderinc"
#include "res://scenes/look/ground/ground_sample.gdshaderinc"
// The far grass paint: where the grass grows the ground takes the colour of the field (amount 0 = off).
#include "res://scenes/look/ground/grass_paint.gdshaderinc"
// The ground can move after the map loaded (RFC-057): the vertices are moved here, the mesh is never rebuilt.
#include "res://scenes/look/ground/terrain_deform.gdshaderinc"
// The marks on the ground (burns, cracks), over the ground and under the light.
#include "res://scenes/look/ground/ground_scars.gdshaderinc"

uniform sampler2D lightmap : filter_linear, repeat_disable, hint_default_white;
uniform float light_base : hint_range(0.0, 2.0, 0.01) = 0.3;
uniform float light_gain : hint_range(0.0, 4.0, 0.01) = 0.55;
// The walls under the edge of the land wear the god's cliff texture, not the ground roles.
#include "res://scenes/look/ground/ground_edge.gdshaderinc"

// Map coordinates of the fragment. The terrain mesh is stored in map coordinates, so the local vertex is used: the maps stay
// put when the editor preview shifts the scene root.
varying vec3 map_pos;

void vertex() {
	map_pos = VERTEX;
	deform_hole = 0.0;
	if (terrain_deform_on > 0.5 && deform_follow > 0.5) {
		vec2 shift = deform_at(VERTEX.xz);
		NORMAL = deform_normal(NORMAL, VERTEX.xz);
		VERTEX.y += shift.x;
		deform_hole = shift.y;
	}
}

void fragment() {
	if (deform_hole > 0.0001) {
		discard;
	}
	vec3 g = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float slope = degrees(acos(clamp(g.y, -1.0, 1.0)));
	vec3 dpx = dFdx(map_pos);
	vec3 dpy = dFdy(map_pos);
	bool wall = ground_edge_is_wall(COLOR);
	vec3 albedo = vec3(0.0);
	vec3 world_n = g;
	vec3 orm = vec3(1.0, 1.0, 0.0);
	if (wall) {
		vec2 wall_uv = ground_edge_uv(UV);
		albedo = ground_edge_albedo(wall_uv, dFdx(wall_uv), dFdy(wall_uv));
	} else {
		vec4 w = role_weights(map_pos.xz, slope);
		RoleTap taps[4];
		vec4 heights = vec4(0.0);
		for (int i = 0; i < 4; i++) {
			taps[i].albedo = vec3(0.0);
			taps[i].normal = vec3(0.0);
			taps[i].orm = vec3(0.0);
			if (w[i] > 0.002) {
				taps[i] = role_sample(i, map_pos, g, dpx, dpy);
				heights[i] = taps[i].orm.b;
			}
		}
		w = role_height_blend(w, heights);
		vec3 n = vec3(0.0);
		orm = vec3(0.0);
		for (int i = 0; i < 4; i++) {
			albedo += taps[i].albedo * w[i];
			n += taps[i].normal * w[i];
			orm += taps[i].orm * w[i];
		}
		world_n = normalize(n);
		albedo = grass_paint_textured(albedo, w, map_pos.xz, TIME, slope);
		albedo *= role_macro(map_pos.xz);
	}
	albedo = ground_scar_mix(albedo, map_pos.xz, false);
	vec3 light = texture(lightmap, map_pos.xz / roles_map_size).rgb;
	ALBEDO = albedo * (light_base + light * light_gain);
	ROUGHNESS = orm.g;
	if (use_maps && !wall) {
		// `g` came from the NORMAL Godot already flipped on a back face, so the rebuilt one needs no flip.
		NORMAL = normalize((VIEW_MATRIX * vec4(world_n, 0.0)).xyz);
		AO = orm.r;
		AO_LIGHT_AFFECT = 0.6;
	}
}
