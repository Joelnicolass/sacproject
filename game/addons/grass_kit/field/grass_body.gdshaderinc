// The body of GrassKit's blade shader (grass.gdshader, grass_cut.gdshader). Every cell is a
// MultiMeshInstance3D of one kind of blade; its instances are blade roots on the ground plane
// (y 0) carrying their rank in the cell's sequence and their mesh's segments. This stands each one
// on the ground, sizes, bends, colours and thins it.
//
// A blade not drawn collapses to a point (degenerate triangles, nothing rasterised), decided by
// the cheapest tests first: distance and rank, the ground's area, then (one read of the ground)
// whether there is ground, its slope, the density, the kind's mask and the clearings. Only the
// blades left go on to the clumps, the wind and the trampling.
//
// Every change with distance is a blend, never a step:
// - the density (a blade goes when its rank passes the density, the same blade in every tier);
// - a mesh with fewer segments (a blade blends into the coarser shape before its cell switches);
// - the edge (blades shorten to nothing);
// - the colour (towards a colour between the ground's and the grass's, where the ground meets it).
//
// The kit's blade is a cubic Bézier: its base leaves the ground along the ground's normal, its tip
// is tilted by the rest lean, the wind and the trampling, and an arch bends it, keeping its length.

#include "res://addons/grass_kit/field/grass_wind.gdshaderinc"
#include "res://addons/grass_kit/field/grass_color.gdshaderinc"

// The ground (GrassGround), stretched over ground_area (x, z, width, depth): height (red), the
// normal's x and z (green, blue), 1 where there is ground (alpha). One read gives it all.
uniform sampler2D ground_data : filter_linear, repeat_disable;
uniform sampler2D density_map : filter_linear, repeat_disable, hint_default_white;
// How tall the blades grow there: 0.5 = as the look says.
uniform sampler2D size_map : filter_linear, repeat_disable;
uniform bool has_size_map = false;
uniform sampler2D ground_colors : source_color, filter_linear, repeat_disable, hint_default_white;
uniform bool has_ground_colors = false;
uniform vec4 ground_area = vec4(-50.0, -50.0, 100.0, 100.0);
// Cosines of the slopes where grass starts thinning and shortening (x) and is gone (y).
uniform vec2 slope_fade_cos = vec2(0.819, 0.574);

// The ring (GrassQuality), around field_center (x, z).
uniform vec2 field_center = vec2(0.0);
uniform float radius = 45.0;
uniform float near_radius = 15.0;
uniform float far_density = 0.12;
uniform float min_blade_pixels = 1.5;
uniform float near_fade = 1.5;
// Metres a root moves at random from its place in the shared pattern (about the room between two
// blades), so the same pattern in every cell shows no rows.
uniform float jitter = 0.18;
// For blades of 2^k segments: the distance by which they have blended into half as many.
uniform float morph_ends[4];
uniform float morph_band = 6.0;

// The look (GrassLook).
uniform vec2 height_range = vec2(0.25, 0.8);
uniform float blade_width = 0.06;
uniform float tip_width = 0.15;
uniform float lean = 0.35;
uniform float align_to_normal = 0.7;
uniform float clump_size = 1.6;
uniform vec3 base_color : source_color = vec3(0.13, 0.33, 0.07);
uniform vec3 tip_color : source_color = vec3(0.45, 0.62, 0.18);
uniform float color_variation = 0.2;
uniform float ground_tint = 0.35;
uniform vec3 ground_color : source_color = vec3(0.26, 0.3, 0.13);
uniform float fade_to_ground = 0.6;
uniform float roughness_value = 0.6;
uniform vec3 translucency : source_color = vec3(0.35, 0.45, 0.1);
uniform float root_shade = 0.45;
uniform float roundness = 0.6;
uniform float view_thicken = 0.6;
uniform float wind_response = 1.0;
uniform float flutter = 0.15;
uniform float gust_lighten = 0.4;
uniform float far_grass = 0.5;
// The colour the field reads as from afar (linear: GrassLook.average_color()).
uniform vec3 grass_average = vec3(0.05, 0.12, 0.01);

// The kind of blade (GrassMesh).
uniform float kind_size = 1.0;
uniform float mesh_height = 1.0;
uniform bool bend_from_color = false;
uniform float palette = 1.0;
uniform vec3 tint : source_color = vec3(1.0);
uniform sampler2D mask_map : filter_linear, repeat_disable, hint_default_white;
uniform sampler2D albedo_map : source_color, filter_linear_mipmap, repeat_enable,
	hint_default_white;
uniform bool has_albedo = false;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap, repeat_enable;
uniform bool has_normal_map = false;
uniform sampler2D orm_map : filter_linear_mipmap, repeat_enable, hint_default_white;
uniform bool has_orm = false;
uniform float alpha_scissor = 0.5;

// Clearings: (x, z, radius, soft). Trampling: (x, z, radius, strength).
uniform vec4 clearings[48];
uniform int clearing_count = 0;
uniform vec4 stamps[48];
uniform int stamp_count = 0;

varying vec3 v_color;
varying float v_t;
varying float v_gust;

float hash12(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

vec2 hash22(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	q += dot(q, q.yzx + 33.33);
	return fract((q.xx + q.yz) * q.zy);
}

// The part of the full density kept at `d` from the centre (GrassQuality.density_at).
float density_at(float d) {
	if (d > radius) {
		return 0.0;
	}
	float start = min(near_radius, radius);
	if (d <= start) {
		return 1.0;
	}
	return mix(1.0, far_density, smoothstep(start, radius, d));
}

vec3 bezier(vec3 p0, vec3 p1, vec3 p2, vec3 p3, float t) {
	float u = 1.0 - t;
	return u * u * u * p0 + 3.0 * u * u * t * p1 + 3.0 * u * t * t * p2 + t * t * t * p3;
}

vec3 bezier_tangent(vec3 p0, vec3 p1, vec3 p2, vec3 p3, float t) {
	float u = 1.0 - t;
	return 3.0 * u * u * (p1 - p0) + 6.0 * u * t * (p2 - p1) + 3.0 * t * t * (p3 - p2);
}

// `v` turned by the rotation that takes up (0, 1, 0) to `axis` (Rodrigues).
vec3 turn_up_to(vec3 v, vec3 axis) {
	vec3 k = vec3(axis.z, 0.0, -axis.x);
	float s = length(k);
	if (s < 0.0001) {
		return v;
	}
	k /= s;
	float c = axis.y;
	return v * c + cross(k, v) * s + k * dot(k, v) * (1.0 - c);
}

void vertex() {
	vec3 local = VERTEX;
	vec3 root = MODEL_MATRIX[3].xyz;
	vec2 xz = root.xz + (hash22(root.xz * 3.17) - 0.5) * jitter;
	float rank = INSTANCE_CUSTOM.x;
	float segments = INSTANCE_CUSTOM.y;
	float d = distance(xz, field_center);
	float keep = density_at(d);
	vec2 uv = (xz - ground_area.xy) / ground_area.zw;
	bool outside = uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0;
	vec3 world = root;
	v_color = vec3(0.0);
	v_t = 0.0;
	v_gust = 0.0;
	if (!(rank >= keep || outside)) {
		vec4 ground = texture(ground_data, uv);
		float ny = sqrt(max(1.0 - ground.g * ground.g - ground.b * ground.b, 0.0));
		vec3 ground_normal = vec3(ground.g, ny, ground.b);
		float slope_keep = smoothstep(slope_fade_cos.y, slope_fade_cos.x, ground_normal.y);
		float cover = ground.a * texture(density_map, uv).r * slope_keep;
		cover *= texture(mask_map, uv).r;
		for (int i = 0; i < clearing_count; i++) {
			vec4 c = clearings[i];
			cover *= smoothstep(c.z, c.z + max(c.w, 0.001), distance(xz, c.xy));
		}
		if (rank < keep * cover) {
			float ground_y = ground.r;
			vec2 seed = hash22(xz * 7.31);
			// Clumps: the nearest of the jittered points of the 2 x 2 cells around the blade (their
			// points kept off the cells' edges, so the nearest is always among them); blades lean
			// out of it, taller near it, with its own shade.
			float clump_scale = 1.0;
			vec2 lean_dir = normalize(seed - 0.5 + 0.001);
			float shade = seed.y;
			if (clump_size > 0.0) {
				vec2 cell = floor(xz / clump_size - 0.5);
				float best = 1e9;
				vec2 heart = xz;
				for (int y = 0; y <= 1; y++) {
					for (int x = 0; x <= 1; x++) {
						vec2 c = cell + vec2(float(x), float(y));
						vec2 p = (c + 0.25 + hash22(c) * 0.5) * clump_size;
						float dd = distance(xz, p);
						if (dd < best) {
							best = dd;
							heart = p;
						}
					}
				}
				float near_heart = 1.0 - clamp(best / clump_size, 0.0, 1.0);
				clump_scale = mix(0.75, 1.15, near_heart);
				if (best > 0.001) {
					lean_dir = normalize(mix(lean_dir, (xz - heart) / best, 0.35));
				}
				shade = mix(seed.y, hash12(heart), 0.6);
			}
			float h = mix(height_range.x, height_range.y, seed.x) * clump_scale * kind_size;
			if (has_size_map) {
				h *= texture(size_map, uv).r * 2.0;
			}
			// Shorter towards the edge (it ends without a step), on steep ground, and at the lens.
			h *= 1.0 - smoothstep(radius * 0.85, radius, d);
			h *= mix(0.45, 1.0, slope_keep);
			vec3 ground_point = vec3(xz.x, ground_y, xz.y);
			float to_camera = distance(CAMERA_POSITION_WORLD, ground_point);
			h *= smoothstep(near_fade * 0.4, near_fade, to_camera);
			// The wind (shared with the world), the rest lean, and the trampling tilt the tip.
			float gust = grasskit_wind_gust(xz);
			vec2 across = vec2(-grasskit_wind.y, grasskit_wind.x);
			float shiver = sin(grasskit_wind_time * 6.3 + seed.x * 6.2832) * 0.6
				+ sin(grasskit_wind_time * 10.7 + seed.y * 6.2832) * 0.4;
			vec2 tilt = lean_dir * lean * 0.6 + grasskit_wind_push(xz) * wind_response;
			tilt += across * flutter * grasskit_wind.z * shiver * (0.3 + gust);
			for (int i = 0; i < stamp_count; i++) {
				vec4 s = stamps[i];
				vec2 away = xz - s.xy;
				float dd = length(away);
				if (dd < s.z) {
					float press = (1.0 - dd / s.z) * s.w;
					tilt += (dd > 0.001 ? away / dd : lean_dir) * press * 1.4;
				}
			}
			tilt *= h;
			float bent = min(length(tilt), h * 0.95);
			tilt = bent > 0.0 ? normalize(tilt) * bent : tilt;
			// The tip comes down as it tilts: the blade bends, it never stretches.
			float rise = sqrt(max(h * h - bent * bent, 0.0));
			vec3 up = vec3(0.0, 1.0, 0.0);
			vec3 axis = normalize(mix(up, ground_normal, align_to_normal));
			vec3 tilt3 = vec3(tilt.x, 0.0, tilt.y);
			vec3 p3 = ground_point + up * rise + tilt3;
			vec3 p1 = ground_point + axis * h * 0.33;
			vec3 p2 = ground_point + (p3 - ground_point) * 0.66 + up * h * (0.08 + 0.12 * lean);
			vec3 side_flat = vec3(-lean_dir.y, 0.0, lean_dir.x);
			// The width lies on the ground's plane: neither edge of the base sinks into a slope.
			vec3 side = normalize(side_flat - ground_normal * dot(side_flat, ground_normal));
			// Far blades take the ground's normal: less shimmer.
			float far = smoothstep(near_radius, radius, d);
			float t;
			if (segments > 0.5) {
				t = local.y;
				vec3 spine = bezier(ground_point, p1, p2, p3, t);
				// LOD: a row that a mesh of half as many segments lacks blends into the chord of its
				// neighbours before the cell switches to that mesh.
				int k = int(round(log2(segments)));
				float row = round(t * segments);
				if (k > 0 && k < 4 && mod(row, 2.0) > 0.5 && morph_ends[k] > 0.0) {
					float m = smoothstep(morph_ends[k] - morph_band, morph_ends[k], d);
					// Only the blades in the band pay for the neighbours' points.
					if (m > 0.0) {
						float step = 1.0 / segments;
						vec3 a = bezier(ground_point, p1, p2, p3, t - step);
						vec3 b = bezier(ground_point, p1, p2, p3, t + step);
						spine = mix(spine, (a + b) * 0.5, m);
					}
				}
				vec3 along = normalize(bezier_tangent(ground_point, p1, p2, p3, max(t, 0.02)));
				vec3 facing = normalize(cross(side, along));
				// Fewer blades farther: wider ones cover as much; never thinner than a few pixels;
				// wider seen edge-on, so the field never looks thin from the side.
				float width = blade_width * clamp(inversesqrt(max(keep, 0.05)), 1.0, 3.0);
				float pixels_per_m = PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y * 0.5
					/ max(to_camera, 0.01);
				width = max(width, min_blade_pixels / pixels_per_m);
				vec3 to_eye = normalize(CAMERA_POSITION_WORLD - spine);
				width *= 1.0 + view_thicken * (1.0 - abs(dot(facing, to_eye)));
				float w = mix(1.0, tip_width, t) * width;
				world = spine + side * local.x * w;
				// Round across the width, then towards the ground's normal far away.
				vec3 n = normalize(facing + side * local.x * 2.0 * roundness);
				NORMAL = normalize(mix(n, ground_normal, mix(0.55, 0.95, far)));
				TANGENT = side;
				BINORMAL = along;
			} else {
				// A kind's own mesh: scaled to the blade's height, turned at random, its base
				// along the axis and its tip upright, bent by the same tilt.
				float s = h / max(mesh_height, 0.001);
				t = bend_from_color ? COLOR.r : clamp(local.y / max(mesh_height, 0.001), 0.0, 1.0);
				float angle = seed.x * 6.2832;
				float ca = cos(angle);
				float sa = sin(angle);
				vec3 q = vec3(local.x * ca - local.z * sa, local.y, local.x * sa + local.z * ca) * s;
				vec3 p = mix(turn_up_to(q, axis), q, t);
				p.y *= rise / max(h, 0.001);
				world = ground_point + p + tilt3 * t * t;
				vec3 n = NORMAL;
				n = vec3(n.x * ca - n.z * sa, n.y, n.x * sa + n.z * ca);
				NORMAL = normalize(mix(turn_up_to(n, axis), ground_normal, far * 0.8));
				vec3 tg = TANGENT;
				TANGENT = turn_up_to(vec3(tg.x * ca - tg.z * sa, tg.y, tg.x * sa + tg.z * ca), axis);
				vec3 bn = BINORMAL;
				BINORMAL = turn_up_to(vec3(bn.x * ca - bn.z * sa, bn.y, bn.x * sa + bn.z * ca), axis);
			}
			// Colour: the palette base to tip with the clump's shade, the ground at the base, the
			// root in shade, gusts lighting the tips; far away, towards where the ground's colour
			// and the grass's meet.
			// The ground's colour map covers the look's ground colour by its alpha.
			vec3 ground_rgb = ground_color;
			if (has_ground_colors) {
				vec4 painted = texture(ground_colors, uv);
				ground_rgb = mix(ground_color, painted.rgb, painted.a);
			}
			float variation = 1.0 + (shade - 0.5) * 2.0 * color_variation;
			vec3 color = mix(base_color, tip_color, t) * variation;
			color = mix(color, ground_rgb, ground_tint * (1.0 - t));
			color *= mix(1.0 - root_shade, 1.0, t);
			color *= 1.0 + gust * gust_lighten * t * grasskit_wind.z;
			color = mix(vec3(1.0), color, palette) * tint;
			// Mixed in linear as the game's ground does (grass_ground.gdshaderinc), so they meet.
			vec3 meet = grasskit_from_linear(mix(grasskit_to_linear(ground_rgb), grass_average, far_grass));
			v_color = mix(color, meet, smoothstep(fade_to_ground * radius, radius, d));
			v_t = t;
			v_gust = gust * grasskit_wind.z;
		}
	}
	VERTEX = world - root;
}

void fragment() {
	vec4 albedo = has_albedo ? texture(albedo_map, UV) : vec4(1.0);
	ALBEDO = albedo.rgb * v_color;
#ifdef ALPHA_CUT
	ALPHA = albedo.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor;
#endif
	if (has_normal_map) {
		NORMAL_MAP = texture(normal_map, UV).rgb;
	}
	float rough = roughness_value;
	float metal = 0.0;
	if (has_orm) {
		vec3 orm = texture(orm_map, UV).rgb;
		ALBEDO *= mix(1.0, orm.r, 0.8);
		rough = orm.g;
		metal = orm.b;
	}
	ROUGHNESS = rough;
	METALLIC = metal;
	// A gust raises the shine on the tips it passes.
	SPECULAR = 0.25 + v_gust * 0.25 * v_t;
	// Light through the blades from behind, more towards the thin tip.
	BACKLIGHT = translucency * (0.3 + 0.7 * v_t);
}
