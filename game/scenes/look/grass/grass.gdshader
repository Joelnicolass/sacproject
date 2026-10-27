shader_type spatial;
// Opaque blades, two sided, soft wrapped diffuse: no alpha, no discard (tile GPUs and the render
// scale love that). The blades do not cast shadows (set on the instances) but receive them.
render_mode cull_disabled, diffuse_lambert_wrap;

// Stylized grass of a biome: a ring of 16 m cells around the camera, every cell the same MultiMesh
// (a prefix of low-discrepancy points, so the far cells hold the same blades, fewer of them). All
// placement happens here: the world position of a blade comes from its cell, the height from the
// baked height map, and a blade is drawn only if its rank is under the density at that spot,
// otherwise it collapses to a point. Density and width move with ONE parameter of the distance
// (`blend`, geometric: the density down, the width up): the coverage of the ground goes from the near
// value to the far one with no valley, so there is no visible density LOD and no loose blades. Past
// the blend the density is constant; the field disappears only by HEIGHT (every blade gets shorter
// together, measured from near the eye: `fade_center`) while each blade turns into the ground it
// stands on: its albedo, normal, roughness, specular and diffuse model (light() below). The root has the exact color of the ground below (baked by
// grass_bake.gdshader with the ground's own rules, ground_roles.gdshaderinc).
//
// Technique notes (ideas only, no code copied): Nintendo CEDEC 2017 (BotW grass: geometry blades
// around the camera, density falling with distance, ground of the same color, wind waves that
// lighten the tips); E. Wohllaib, "Procedural Grass in Ghost of Tsushima", GDC 2021 (grid of cells
// around the camera, curved normals, color by tuft); 2Retr0/GodotGrass (MIT, MultiMesh tiles,
// rounded normals). The cell-noise tufts are a standard Worley noise written for this shader.
// Written by `GrassField`, which fills the uniforms from a `GrassType`; nothing here is a look.


/** RG float, 2.5 m per texel over the map: R = height, G = 1 over land. Baked by tools/bake_grass_height.gd. */
uniform sampler2D height_tex : filter_linear, repeat_disable, hint_default_black;
uniform float height_texel_m = 2.5;

// Map coordinates = the layer's local space; the layer may sit away from the world origin (editor).
uniform vec3 map_origin = vec3(0.0);
uniform vec2 field_center = vec2(0.0);
uniform vec2 camera_xz = vec2(0.0);
// Where the distance fade is measured from: under the camera, led toward where it looks only by its
// height over the ground (a game camera: ~its height; a high RTS camera: the ground point it looks at).
uniform vec2 fade_center = vec2(0.0);
uniform float camera_y = 100.0;
uniform float cell_m = 16.0;
/** >= 0 replaces TIME (agent bench: frozen wind). The game never sets it. */
uniform float time_override = -1.0;
uniform float radius_m = 45.0;
// The grass is gone (height 0) at this fraction of the radius (`R`); it starts to go down at
// `fade_start` of R (type: "Distance fade").
uniform float fade_end = 0.85;
uniform float fade_start = 0.35;
// The color (and the shading) is the ground's from this fraction of R on, BEFORE the height is gone:
// what is left of a blade at the end is already camouflaged.
uniform float color_fade_start = 0.7;
uniform float color_fade_end = 0.9;
// Density and width go from the near ones to the far ones between these two distances (the same
// smoothstep for both); past `far_start_m` the density is `far_ratio` of the near one, constant.
uniform float near_radius_m = 15.0;
uniform float far_start_m = 33.0;
uniform float far_ratio = 0.1;
// Zone density (0..1) from which a zone gets the whole far density.
uniform float zone_full_far = 0.25;
// A blade is never thinner than this on the screen (pixels of the 3D render): seen from far or from
// high up (RTS) the blades get wider instead of turning into sub-pixel grain. Depends on the distance only.
uniform float min_blade_px = 1.5;
uniform bool use_clumps = true;
uniform bool use_trample = true;

/** The ground as the terrain draws it, seen from above (GrassField renders it): sRGB color without light. */
uniform sampler2D ground_data : filter_linear, repeat_disable, hint_default_white;
/** Baked by grass_bake.gdshader: r = zone height multiplier, g = hillside (0 flat .. 1 steep), b = density. */
uniform sampler2D zone_data : filter_linear, repeat_disable, hint_default_white;
/** r = height left on a slope (1 flat .. the type's floor on a steep one; never 0); g = share of the
ground's grass paint there (where its wind bands show). */
uniform sampler2D slope_data : filter_linear, repeat_disable, hint_default_white;
uniform float map_size;  // metres per side of the map, set by GrassField from the ground's bounds
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable, hint_default_white;

uniform float width_m = 0.09;
uniform float tip_width = 0.07;
uniform float far_width_scale = 3.0;
uniform float far_height_scale = 1.5;
uniform float specular_amount = 0.5;
uniform float roughness_amount = 0.55;
uniform float short_height_m = 0.3;
uniform float tall_height_m = 0.7;
uniform float height_variation = 0.3;
uniform float lean = 0.3;
uniform float view_thicken = 0.6;
uniform float open_scale_m = 70.0;
uniform float clear_falloff_m = 10.0;
uniform float near_fade_m = 2.5;

uniform vec3 color_mid : source_color = vec3(0.12, 0.42, 0.06);
uniform vec3 color_tip : source_color = vec3(0.42, 0.62, 0.14);
uniform float ground_mix = 0.3;
uniform float clump_scale_m = 1.6;
uniform float clump_tint = 0.5;
uniform float clump_height = 0.35;
uniform float normal_roundness = 0.7;
uniform float translucency = 0.5;
uniform float root_ao = 0.45;
// The root darkening is full only on blades this tall (m): short blades at the fade are not dark dots.
uniform float root_ao_full_m = 0.5;
// On hillsides the blades take the ground's color and lean more; their height comes from slope_data (type: "Hillsides").
uniform float slope_color_mix = 0.7;
uniform float slope_tip_keep = 0.4;
uniform float slope_width_scale = 1.0;
uniform float slope_lean_gain = 0.8;

uniform vec2 wind_dir = vec2(0.82, 0.57);
uniform float wind_strength = 0.22;
uniform float wind_speed = 2.2;
uniform float wind_scale_m = 55.0;
uniform float gust_lighten = 0.45;
// The ground the field fades into: its roughness and specular (the ground shader's: ROUGHNESS 1 without
// ORM maps, Godot's SPECULAR 0.5), and the strength of the pale wind bands of its grass paint. In the fade the
// blade is shaded with exactly the ground's model (burley, its normal, roughness and specular), so
// what is left of a blade is the ground's own pixel, never a loose dot.
uniform float fade_roughness = 1.0;
uniform float fade_specular = 0.5;
uniform float paint_waves = 0.0;

// x, z (map), radius, edge.
uniform vec4 clears[48];
uniform int clear_count = 0;
// x, z (map), radius, strength.
uniform vec4 stamps[48];
uniform int stamp_count = 0;

varying vec3 v_normal;
varying vec3 v_root;
varying vec3 v_mid;
varying vec3 v_tip;
varying float v_t;
varying float v_gust;
varying float v_height;
varying float v_fade;
varying vec3 v_ground;
varying float v_band;
varying vec3 v_ground_n;
varying float v_spec;

const float SINK_M = 0.05;

float hash11(float n) {
	return fract(sin(n * 127.1 + 31.7) * 43758.5453);
}

vec2 hash22(vec2 p) {
	vec2 q = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(q) * 43758.5453);
}

// Tuft: two cheap noise reads at the tuft scale (x = distance-like falloff, y and z = random per tuft).
vec3 tuft(vec2 p, float scale) {
	vec4 n = textureLod(noise_tex, p / scale, 0.0);
	vec4 m = textureLod(noise_tex, p / (scale * 3.1) + vec2(0.37, 0.71), 0.0);
	return vec3(0.5, clamp((n.g - 0.5) * 1.7 + 0.5 + (m.a - 0.5) * 0.6, 0.0, 1.0), n.b);
}

// A seamless noise channel read at two unrelated scales and orientations, so its tile never shows:
// one tile alone repeats every `scale_m` and reads as a pattern across a far field.
float wide_noise(vec2 p, float scale_m, vec4 mask_a, vec4 mask_b) {
	float a = dot(textureLod(noise_tex, p / scale_m, 0.0), mask_a);
	vec2 r = vec2(p.x * 0.8 - p.y * 0.6, p.x * 0.6 + p.y * 0.8);
	float b = dot(textureLod(noise_tex, r / (scale_m * 2.37) + vec2(0.31, 0.77), 0.0), mask_b);
	return clamp((mix(a, b, 0.42) - 0.5) * 1.3 + 0.5, 0.0, 1.0);
}

struct Grown {
	vec3 vertex;
	vec3 normal;
	vec3 root;
	vec3 mid;
	vec3 tip;
	float gust;
	float height;
	float fade;
	vec3 ground;
	vec3 ground_n;
	float band;
};

// The ground's 8-bit sRGB color back to linear, exactly (the ground shader works in linear).
vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

// The terrain mesh's smooth normal (each vertex of its 10 m grid averages the faces around it),
// approximated from the baked height over +-10 m.
vec3 ground_normal(vec2 p) {
	float s = 10.0;
	float hx = textureLod(height_tex, (p + vec2(s, 0.0)) / map_size, 0.0).r - textureLod(height_tex, (p - vec2(s, 0.0)) / map_size, 0.0).r;
	float hz = textureLod(height_tex, (p + vec2(0.0, s)) / map_size, 0.0).r - textureLod(height_tex, (p - vec2(0.0, s)) / map_size, 0.0).r;
	return normalize(vec3(-hx, 2.0 * s, -hz));
}

// One vertex of one blade, in the instance's local space; vertex = 0 collapses the blade.
Grown grow(vec3 base_vertex, vec2 uv, vec4 custom, vec3 origin, vec3 camera_world, float time, float focal_px) {
	Grown o;
	o.vertex = vec3(0.0);
	o.normal = vec3(0.0, 1.0, 0.0);
	o.root = vec3(0.0);
	o.mid = vec3(0.0);
	o.tip = vec3(0.0);
	o.height = 0.0;
	o.fade = 1.0;
	o.ground = vec3(0.0);
	o.ground_n = vec3(0.0, 1.0, 0.0);
	o.band = 1.0;
	vec3 root = origin - map_origin;
	float t = uv.y;

	// Where this blade stands: the cell's pattern, flipped per cell so cells do not repeat.
	vec2 cell = floor(root.xz / cell_m);
	vec2 local = root.xz - cell * cell_m;
	vec2 ch = hash22(cell);
	if (ch.x > 0.5) {
		local.x = cell_m - local.x;
	}
	if (ch.y > 0.5) {
		local.y = cell_m - local.y;
	}
	if (hash11(cell.x * 7.0 + cell.y * 13.0) > 0.5) {
		local = local.yx;
	}
	// Shift the pattern around the cell (wrapping inside it) so no two cells hold the same layout:
	// the cells are the only thing that repeats, and far away that would read as a grid.
	local = mod(local + hash22(cell + vec2(17.3, 5.1)) * cell_m, cell_m);
	vec2 pos = cell * cell_m + local;

	// One parameter of the distance for density and width (see the header): between the near radius
	// and `far_start_m` both go from the near values to the far ones; past it nothing thins out.
	float dist = length(pos - field_center);
	float blend = smoothstep(near_radius_m, max(far_start_m, near_radius_m + 0.01), dist);
	// Geometric in `blend`, the density down and the width up: their product (the ground coverage)
	// goes from the near value to the far one monotonically, no valley and no bump, and the blades
	// thin out early where they are cheap to replace by wider ones.
	float frac_dist = pow(far_ratio, blend);
	// The fade (height goes down from fade_start to R, see below) is needed early: it also evens out the blades.
	float radius_eff = radius_m * fade_end;
	// The fade is measured from `fade_center` (near the eye; not from the field's center, which leads a
	// low view by the near radius): the grass at a given distance from a game camera is the same height
	// whichever way it turns.
	float cam_dist = length(pos - camera_xz);
	float fade_dist = length(pos - fade_center);
	float fade = smoothstep(fade_start * radius_eff, radius_eff, fade_dist);
	float color_fade = smoothstep(color_fade_start * radius_eff, max(color_fade_end, color_fade_start + 0.01) * radius_eff, fade_dist);
	float rank = custom.w;
	vec2 huv = pos / map_size;
	vec2 hl = textureLod(height_tex, huv, 0.0).rg;
	if (rank >= frac_dist || hl.g < 0.99 || huv.x < 0.0 || huv.y < 0.0 || huv.x > 1.0 || huv.y > 1.0) {
		return o;
	}
	float ground_y = hl.r;

	// Zone: baked from the ground's own role rules; then the clearings.
	vec4 zone = textureLod(ground_data, huv, 0.0);
	vec4 zone_info = textureLod(zone_data, huv, 0.0);
	float zone_density = zone_info.b;
	float zone_height = zone_info.r;
	float hill = zone_info.g;
	float clear_density = 1.0;
	float clear_height = 1.0;
	for (int i = 0; i < clear_count; i++) {
		vec4 c = clears[i];
		float dc = length(pos - c.xy);
		clear_density = min(clear_density, smoothstep(c.z, c.z + c.w, dc));
		clear_height = min(clear_height, smoothstep(c.z, c.z + c.w + clear_falloff_m, dc));
	}
	// The zone thins out the near field (paths, soil); the far density is a floor that keeps the
	// ground covered wherever grass grows at all, so through the blend the zone's own thinning gives
	// way to it (coverage never has a valley on a thin zone either).
	float zone_far = smoothstep(0.0, zone_full_far, zone_density);
	float frac_total = frac_dist * mix(zone_density, zone_far, blend) * clear_density;
	if (rank >= frac_total) {
		return o;
	}

	// Height: short on paths, around clearings and near the camera; tall in the open, by patches.
	vec3 tf = use_clumps ? tuft(pos, clump_scale_m) : vec3(0.5, 0.5, 0.5);
	float open_n = wide_noise(pos + vec2(311.0, 97.0), open_scale_m, vec4(0, 0, 1, 0), vec4(0, 1, 0, 0));
	float openness = clamp(zone_height * clear_height * (0.5 + 0.5 * smoothstep(0.15, 0.6, open_n)), 0.0, 1.0);
	float h = mix(short_height_m, tall_height_m, openness);
	// The differences between blades (per blade, per tuft, and the rank's growth below) fade out with
	// the distance fade: in the fade every blade is the same height and they get shorter together, so
	// no few tall tips are left over a lowered field.
	float uneven = (1.0 + (custom.y - 0.5) * 2.0 * height_variation) * (1.0 + (tf.y - 0.5) * 2.0 * clump_height);
	// A blade grows from nothing as the density passes its rank: no pop at the edge of the field,
	// at a clearing or where the density thins out.
	uneven *= smoothstep(0.0, 0.5, (frac_total - rank) / max(frac_total, 0.0001));
	h *= mix(uneven, 1.0, fade);
	// Taller far blades with the same parameter as the density and the width.
	h *= mix(1.0, far_height_scale, blend);
	// The only way the grass disappears: its height goes down from fade_start to R (all blades together).
	h *= 1.0 - fade;
	// Slopes: shorter (the baked floor), never bare.
	h *= textureLod(slope_data, huv, 0.0).r;
	// Width of this blade at this distance: the same for every blade here (no per-instance factor).
	float width_here = width_m * pow(far_width_scale, blend);
	// No sub-pixel blades: one thinner than `min_blade_px` on the screen is widened to it (never
	// removed), the same for every blade at that distance, so a far or high view (RTS) shows a field,
	// not grain. In the game view the near blades are wider than that already.
	vec3 root_world = vec3(pos.x, ground_y, pos.y) + map_origin;
	width_here = max(width_here, min_blade_px * max(distance(root_world, camera_world), 0.5) / focal_px);
	// Near the camera the grass never rises above the lens (so the camera is not inside the grass),
	// and only the last `near_fade_m` right under it fades out: no hole that travels with the camera.
	float cap = max(camera_y - ground_y - 0.3, 0.2);
	h = mix(min(h, cap), h, smoothstep(1.5, 5.0, cam_dist));
	h *= smoothstep(0.0, max(near_fade_m, 0.01), cam_dist);

	// Trample: units flatten the blades under and around them.
	float press = 0.0;
	vec2 push = vec2(0.0);
	if (use_trample) {
		for (int i = 0; i < stamp_count; i++) {
			vec4 s = stamps[i];
			vec2 dv = pos - s.xy;
			float r_out = s.z * 1.7;
			float d2 = dot(dv, dv);
			if (d2 < r_out * r_out && s.w > 0.0) {
				float d = sqrt(d2);
				float k = (1.0 - smoothstep(s.z * 0.55, r_out, d)) * s.w;
				press = max(press, k);
				push += (dv / max(d, 0.05)) * k;
			}
		}
	}
	// Several overlapping stamps (the trail) must not add up into a throw: cap the push at 1.
	if (length(push) > 1.0) {
		push = normalize(push);
	}
	// Trodden blades bend away and keep at least ~38 % of their height: they never vanish.
	h *= 1.0 - press * 0.62;

	// Wind: global waves that cross the field, the tips lean and the gusts lighten them.
	vec2 wd = normalize(wind_dir);
	float wave = wide_noise(pos - wd * time * wind_speed, wind_scale_m, vec4(1, 0, 0, 0), vec4(0, 0, 0, 1));
	float gust = smoothstep(0.45, 0.8, wave);
	float flutter = sin(time * 2.6 + custom.x * 40.0 + pos.x * 0.9) * 0.5 + sin(time * 4.1 + custom.z * 30.0) * 0.5;
	vec2 wind_push = wd * (0.35 + gust * 1.1) + vec2(-wd.y, wd.x) * flutter * 0.25;
	float bend = t * t;

	// Blade frame: yaw by instance, edge-on blades turned toward the camera.
	float yaw = custom.x * 6.2831853;
	vec2 side = vec2(cos(yaw), sin(yaw));
	vec3 cam_map = camera_world - map_origin;
	vec2 to_cam = normalize(cam_map.xz - pos + vec2(0.0001));
	vec2 perp = vec2(-to_cam.y, to_cam.x);
	float edge_on = 1.0 - abs(dot(side, perp));
	side = normalize(side + perp * (dot(side, perp) >= 0.0 ? 1.0 : -1.0) * edge_on * view_thicken * 1.4);

	float lean_yaw = custom.z * 6.2831853;
	vec2 natural = vec2(cos(lean_yaw), sin(lean_yaw)) * lean * (1.0 + hill * slope_lean_gain) * h;
	vec2 sway = wind_push * wind_strength * h + natural + push * h * 1.0 * press;
	vec3 wp = vec3(pos.x, ground_y - SINK_M, pos.y);
	// Width profile: 1 at the root down to `tip_width` of it near the tip (the mesh stores 1 - 0.93 t^0.9).
	// Far blades are blunter: wide tufts, not spikes.
	float tip_w = mix(tip_width, 0.55, blend);
	float profile = (1.0 - (1.0 - tip_w) * pow(t, 0.9)) / max(1.0 - 0.93 * pow(t, 0.9), 0.05);
	wp.xz += side * base_vertex.x * width_here * mix(1.0, slope_width_scale, hill) * (t > 0.99 ? 1.0 : profile);
	wp.y += t * h;
	wp.xz += sway * bend;
	wp.y -= 0.5 * dot(sway, sway) * bend / max(h, 0.05) * 0.5;
	o.vertex = wp - root;

	// Rounded normal: across the blade it curves, leaning over to the tip.
	vec2 face = vec2(-side.y, side.x);
	o.normal = normalize(vec3(face.x, 0.35, face.y) + vec3(side.x, 0.0, side.y) * (uv.x - 0.5) * 1.3);

	// Colors. The root is the ground's; body and tip come from the type, tinted by macro drift and
	// by tuft, and everything converges on the ground toward the edge of the field.
	vec3 ground_col = pow(zone.rgb, vec3(2.2));
	vec3 body = mix(color_mid, ground_col * 1.6, ground_mix);
	vec3 tip = mix(color_tip, ground_col * 2.4, ground_mix * 0.6);
	// Hillsides: the body takes the ground's color more the steeper it is, the tips keep some green.
	float on_hill = hill * slope_color_mix;
	body = mix(body, ground_col * 1.25, on_hill);
	tip = mix(tip, ground_col * 1.7, on_hill * (1.0 - slope_tip_keep));
	vec3 warm = vec3(1.18, 1.02, 0.62);
	float tone = (tf.y - 0.5) * 2.0 * clump_tint;
	body *= mix(vec3(1.0), warm, max(tone, 0.0) * 0.8) * (1.0 - max(-tone, 0.0) * 0.35);
	tip *= mix(vec3(1.0), warm, max(tone, 0.0)) * (1.0 - max(-tone, 0.0) * 0.25);
	tip = mix(tip, tip * 1.35 + vec3(0.03, 0.05, 0.0), gust * gust_lighten);
	// Far away the blades read as broad tufts of one color, varying slowly (~20 m), not as a texture.
	float far_mass = smoothstep(near_radius_m * 1.2, near_radius_m * 4.0, dist);
	float low_tone = (textureLod(noise_tex, pos / (clump_scale_m * 14.0) + vec2(0.13, 0.52), 0.0).a - 0.5) * 2.0;
	body *= 1.0 + low_tone * 0.3 * far_mass * clump_tint;
	tip *= 1.0 + low_tone * 0.3 * far_mass * clump_tint;
	// The ground as the terrain shows it here: its exact albedo plus the pale wind bands its paint
	// carries (the same waves, scale and speed: grass_paint.gdshaderinc), and its normal (the map's
	// height over 10 m, like the terrain mesh's smooth normals).
	vec4 slope_info = textureLod(slope_data, huv, 0.0);
	float band_wave = wide_noise(pos - wd * time * wind_speed, wind_scale_m * 2.0, vec4(1, 0, 0, 0), vec4(0, 0, 0, 1));
	o.band = 1.0 + slope_info.g * smoothstep(0.45, 0.8, band_wave) * paint_waves;
	vec3 ground_exact = srgb_to_linear(zone.rgb) * o.band;
	o.ground_n = ground_normal(pos);
	o.ground = ground_exact;
	o.root = ground_col;
	o.mid = mix(body, ground_exact, color_fade);
	o.tip = mix(tip, ground_exact, color_fade);
	o.gust = gust;
	o.height = h;
	o.fade = color_fade;
	return o;
}

void vertex() {
	float focal_px = abs(PROJECTION_MATRIX[1][1]) * VIEWPORT_SIZE.y * 0.5;
	Grown g = grow(VERTEX, UV, INSTANCE_CUSTOM, MODEL_MATRIX[3].xyz, INV_VIEW_MATRIX[3].xyz, time_override >= 0.0 ? time_override : TIME, focal_px);
	VERTEX = g.vertex;
	v_t = UV.y;
	v_normal = g.normal;
	v_root = g.root;
	v_mid = g.mid;
	v_tip = g.tip;
	v_gust = g.gust;
	v_height = g.height;
	v_fade = g.fade;
	v_ground = g.ground;
	v_ground_n = g.ground_n;
	v_band = g.band;
}


void fragment() {
	vec3 col = mix(v_root, v_mid, smoothstep(0.0, 0.35, v_t));
	col = mix(col, v_tip, smoothstep(0.35, 1.0, v_t));
	// In the fade the whole blade, root included, is the ground's albedo.
	// It is read here, per pixel where the blade stands (1.25 m bake), so it follows the ground's tones.
	vec3 ground_here = v_ground;
	if (v_fade > 0.0) {
		vec2 map_xz = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz - map_origin.xz;
		ground_here = srgb_to_linear(texture(ground_data, map_xz / map_size).rgb) * v_band;
	}
	ALBEDO = mix(col, ground_here, v_fade);
	// Round, ground-like lighting: the blade's own normal is pulled toward up, facing the viewer.
	vec3 view_world = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	vec3 nb = v_normal;
	if (dot(nb, view_world) < 0.0) {
		nb = vec3(-nb.x, nb.y, -nb.z);
	}
	// In the fade the blade is lit exactly like the ground below (the ground's normal).
	vec3 n = normalize(mix(normalize(mix(nb, vec3(0.0, 1.0, 0.0), normal_roundness)), v_ground_n, v_fade));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	// Glossier at the tips, and the gust waves catch the light: highlights, not a veil. At grazing
	// angles (low sun reflecting toward the camera) Fresnel would turn every blade white, so the
	// lobe widens and weakens there: that was the pale frost on the sun side.
	float tipness = smoothstep(0.3, 1.0, v_t);
	float graze = pow(1.0 - clamp(dot(n, view_world), 0.0, 1.0), 2.0);
	ROUGHNESS = mix(clamp(roughness_amount - tipness * 0.1 + graze * 0.35, 0.05, 1.0), fade_roughness, v_fade);
	// Highlights, root darkness and backlight become the ground's with the distance fade: the far blade is the ground's color and shading.
	SPECULAR = mix(clamp(specular_amount * (0.5 + tipness * 0.5) * (1.0 + v_gust * 0.3) * (1.0 - 0.6 * graze), 0.0, 1.0), fade_specular, v_fade);
	v_spec = SPECULAR;
	AO = mix(1.0 - root_ao * smoothstep(0.0, max(root_ao_full_m, 0.01), v_height) * (1.0 - v_fade), 1.0, smoothstep(0.0, 0.6, v_t));
	AO_LIGHT_AFFECT = 0.5;
	BACKLIGHT = v_tip * translucency * 0.6 * smoothstep(0.2, 1.0, v_t) * (1.0 - v_fade);
}

float schlick_fresnel(float u) {
	float m = 1.0 - u;
	float m2 = m * m;
	return m2 * m2 * m;
}

// Godot's own direct light (servers/rendering/renderer_rd/shaders/scene_forward_lights_inc.glsl,
// MIT): the blade's soft wrapped diffuse near the camera and, through the distance fade, the default
// burley diffuse the terrain uses, with the same Schlick-GGX specular. Near the camera (v_fade 0) it is
// the built-in lambert_wrap result; at the end of the fade it is the ground's.
void light() {
	float NdotL = dot(NORMAL, LIGHT);
	float cNdotL = max(NdotL, 0.0);
	float cNdotV = max(dot(NORMAL, VIEW), 1e-4);
	vec3 H = normalize(VIEW + LIGHT);
	float cLdotH = clamp(dot(LIGHT, H), 0.0, 1.0);
	float r = ROUGHNESS;
	float op = 1.0 + r;
	float wrap = max(0.0, (NdotL + r) / (op * op)) * (1.0 / PI);
	float fd90 = 2.0 * cLdotH * cLdotH * r - 0.5;
	float burley = (1.0 / PI) * (1.0 + fd90 * schlick_fresnel(cNdotV)) * (1.0 + fd90 * schlick_fresnel(cNdotL)) * cNdotL;
	float diffuse_brdf = mix(wrap, burley, v_fade);
	DIFFUSE_LIGHT += LIGHT_COLOR * diffuse_brdf * ATTENUATION;
	DIFFUSE_LIGHT += LIGHT_COLOR * (vec3(1.0 / PI) - diffuse_brdf) * BACKLIGHT * ATTENUATION;
	if (r > 0.0) {
		float cNdotH = clamp(dot(NORMAL, H), 0.0, 1.0);
		float alpha_ggx = r * r;
		float a = cNdotH * alpha_ggx;
		float k = alpha_ggx / (1.0 - cNdotH * cNdotH + a * a);
		float d = clamp(k * k * (1.0 / PI), 0.0, 65504.0);
		float g = clamp(0.5 / mix(2.0 * cNdotL * cNdotV, cNdotL + cNdotV, alpha_ggx), 0.0, 65504.0);
		float f0 = 0.16 * v_spec * v_spec;
		float f90 = clamp(f0 * 50.0 * 0.33 * 3.0, 0.0, 1.0);
		float f = f0 + (f90 - f0) * schlick_fresnel(cLdotH);
		SPECULAR_LIGHT += cNdotL * d * f * g * LIGHT_COLOR * ATTENUATION * SPECULAR_AMOUNT;
	}
}
