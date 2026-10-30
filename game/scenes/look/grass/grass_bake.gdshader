shader_type canvas_item;

// Bakes, in memory, where the grass grows and how tall over the whole map, from the map's
// ground_roles.png with the ground's own rule (ground_roles.gdshaderinc, the slope takeover left
// out) and the slope of GrassKit's ground heights. GrassLayer reads the two passes back into the
// ground's density_texture and size_texture (red channel, stretched over the map).
// mode 0, density: by the kind of ground, raised to `hill_density` on the slopes of every kind where
// grass grows at all (earth slopes get covered; the slope does NOT thin it out: a field that thins
// into loose blades reads as spikes).
// mode 1, size (0.5 = the look's height): by the kind of ground, times what the slope leaves, from 1
// on flat ground to `slope_height_floor` from the full slope up, smooth, never 0: steep ground has
// grass, only shorter, so no island of taller or shorter blades forms.

#include "res://scenes/look/ground/ground_roles.gdshaderinc"

// GrassGround's data (r = height), `height_texel_m` metres per texel over the map.
uniform sampler2D height_tex : filter_linear, repeat_disable, hint_default_black;
uniform float height_texel_m;
uniform int mode = 0;
// Per kind of ground (x..w = open, earth, rock, path).
uniform vec4 density_by_role = vec4(1.0, 0.35, 0.0, 0.3);
uniform vec4 height_by_role = vec4(1.0, 0.5, 0.0, 0.0);
// Slope (deg) where the grass starts to lose height and where it has lost all it will lose.
uniform vec2 slope_range = vec2(10.0, 40.0);
uniform float slope_height_floor = 0.55;
// Slope (deg) where a hillside starts and where it is full.
uniform vec2 hill_slope = vec2(10.0, 36.0);
// Density on a full hillside, on the kinds of ground where grass grows at all.
uniform float hill_density = 0.9;

void fragment() {
	vec2 pos = UV * roles_map_size;
	float step_uv = height_texel_m / roles_map_size;
	float hx = texture(height_tex, UV + vec2(step_uv, 0.0)).r - texture(height_tex, UV - vec2(step_uv, 0.0)).r;
	float hz = texture(height_tex, UV + vec2(0.0, step_uv)).r - texture(height_tex, UV - vec2(0.0, step_uv)).r;
	float slope_deg = degrees(atan(length(vec2(hx, hz)) / (2.0 * height_texel_m)));
	vec4 w = role_weights(pos, 0.0);
	if (mode == 1) {
		float by_slope = mix(1.0, slope_height_floor, smoothstep(slope_range.x, slope_range.y, slope_deg));
		COLOR = vec4(vec3(clamp(dot(w, height_by_role), 0.0, 1.0) * by_slope * 0.5), 1.0);
	} else {
		float hill = smoothstep(hill_slope.x, hill_slope.y, slope_deg);
		float density = clamp(dot(w, density_by_role), 0.0, 1.0);
		float grows = clamp(dot(w, step(vec4(0.001), density_by_role)), 0.0, 1.0);
		COLOR = vec4(vec3(max(density, grows * hill_density * hill)), 1.0);
	}
}
