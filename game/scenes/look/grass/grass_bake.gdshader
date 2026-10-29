shader_type canvas_item;

// Bakes once per type / map change, only in memory, the zone data the grass shader reads per blade
// (the same for every biome): 1024x1024 over the map.
// mode 0: r = height multiplier of the zone, g = how much of a hillside it is (0 flat .. 1 steep),
// b = density of the zone (by the kind of ground, raised to `hill_density` on the slopes of every kind where
// grass grows; the slope does NOT thin it out: a field that thins into
// loose blades reads as spikes).
// mode 1: g = the share of the ground's grass paint (where its wind bands show);
// r = how much height is left on the slope: 1 on flat ground, `slope_height_floor` from the
// full slope up, smooth, with no noise and never 0: steep ground has grass, only shorter, so no island of
// taller or shorter blades forms. Where each kind of ground is comes from the map's ground_roles.png with the ground's own
// rule (ground_roles.gdshaderinc, the slope takeover left out), the slope from the baked height map. The color of the ground is not here: it is rendered
// from the terrain itself (GrassField), so it is whatever the ground shows.

#include "res://scenes/look/ground/ground_roles.gdshaderinc"

uniform sampler2D height_tex : filter_linear, repeat_disable, hint_default_black;
uniform float height_texel_m;  // metres per texel of the height image, set by GrassField
uniform int mode = 0;
// Per kind of ground (x..w = open, earth, rock, path), from the GrassType.
uniform vec4 density_by_role = vec4(1.0, 0.35, 0.0, 0.3);
uniform vec4 height_by_role = vec4(1.0, 0.5, 0.0, 0.0);
// Slope (deg) where the grass starts to lose height and where it has lost all it will lose.
uniform vec2 slope_range = vec2(10.0, 40.0);
uniform float slope_height_floor = 0.55;
// Slope (deg) where a hillside starts and where it is full (the color of the blades takes the ground's).
uniform vec2 hill_slope = vec2(10.0, 36.0);
// Density on a full hillside, on the kinds of ground where grass grows at all (earth slopes get covered).
uniform float hill_density = 0.9;
// The ground's grass paint (grass_paint.gdshaderinc, the same rule): its amount per kind of ground and
// the slope where it goes. mode 1 g = the share of paint, where the ground shows its wind bands.
uniform float paint_amount = 0.0;
uniform vec4 paint_by_role = vec4(1.0, 0.75, 0.0, 0.65);
uniform vec2 paint_slope = vec2(10.0, 36.0);

void fragment() {
	vec2 pos = UV * roles_map_size;
	float step_uv = height_texel_m / roles_map_size;
	float hx = texture(height_tex, UV + vec2(step_uv, 0.0)).r - texture(height_tex, UV - vec2(step_uv, 0.0)).r;
	float hz = texture(height_tex, UV + vec2(0.0, step_uv)).r - texture(height_tex, UV - vec2(0.0, step_uv)).r;
	float slope_deg = degrees(atan(length(vec2(hx, hz)) / (2.0 * height_texel_m)));
	if (mode == 1) {
		float paint = clamp(paint_amount * dot(role_weights(pos, 0.0), paint_by_role) * (1.0 - smoothstep(paint_slope.x, paint_slope.y, slope_deg)), 0.0, 1.0);
		COLOR = vec4(mix(1.0, slope_height_floor, smoothstep(slope_range.x, slope_range.y, slope_deg)), paint, 0.0, 1.0);
	} else {
		vec4 w = role_weights(pos, 0.0);
		float hill = smoothstep(hill_slope.x, hill_slope.y, slope_deg);
		float density = clamp(dot(w, density_by_role), 0.0, 1.0);
		float grows = clamp(dot(w, step(vec4(0.001), density_by_role)), 0.0, 1.0);
		density = max(density, grows * hill_density * hill);
		COLOR = vec4(clamp(dot(w, height_by_role), 0.0, 1.0), hill, density, 1.0);
	}
}
