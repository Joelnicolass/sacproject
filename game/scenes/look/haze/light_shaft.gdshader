// A faked shaft of sunlight (the original's trick: lit planes, not volumes). Each instance of the
// MultiMesh is one shaft: a 1 x 1 quad stretched along the sun's light from its top point down to the
// ground, turned about that axis to face the camera, so it reads from any side. Brightest at the top,
// gone at both ends, soft at the sides, a few slow stripes; it fades where it meets the land and near
// the camera. INSTANCE_CUSTOM: x = width (m), y = length (m), z = phase, w = strength.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, world_vertex_coords, fog_disabled;

uniform sampler2D depth_texture : hint_depth_texture, filter_linear;
// Direction toward the sun (world space): the shafts lean along the light coming from there.
uniform vec3 sun_direction = vec3(0.3, 0.8, 0.4);
uniform vec3 sun_color : source_color = vec3(1.0, 0.9, 0.7);
uniform float intensity : hint_range(0.0, 4.0, 0.01) = 0.35;
// Share of the strength kept while the camera looks away from the sun.
uniform float away_share : hint_range(0.0, 1.0, 0.01) = 0.55;
// Metres over which a shaft fades where it meets the land (no hard line on the ground).
uniform float ground_fade_m : hint_range(0.1, 20.0, 0.1) = 4.0;
// Closer than this (m) to the camera a shaft fades out (no flat card in the face).
uniform float near_fade_m : hint_range(1.0, 100.0, 0.5) = 35.0;
uniform float stripes : hint_range(0.0, 1.0, 0.01) = 0.35;

varying float v_strength;
varying float v_phase;
varying vec2 v_uv;

void vertex() {
	vec3 top = MODEL_MATRIX[3].xyz;
	vec3 axis = -normalize(sun_direction);
	vec3 to_cam = CAMERA_POSITION_WORLD - top;
	vec3 side = cross(axis, to_cam);
	side = length(side) > 0.001 ? normalize(side) : vec3(1.0, 0.0, 0.0);
	float width = INSTANCE_CUSTOM.x;
	float len = INSTANCE_CUSTOM.y;
	// world_vertex_coords: VERTEX comes in world space; the quad is 1 x 1 centred on the instance's
	// origin (x across, y along, 0.5 at the top).
	vec3 local = VERTEX - top;
	VERTEX = top + side * local.x * width + axis * (0.5 - local.y) * len;
	v_strength = INSTANCE_CUSTOM.w;
	v_phase = INSTANCE_CUSTOM.z;
	v_uv = UV;
}

void fragment() {
	float across = 1.0 - pow(abs(v_uv.x * 2.0 - 1.0), 1.6);
	float along = smoothstep(0.0, 0.12, v_uv.y) * (1.0 - smoothstep(0.55, 1.0, v_uv.y));
	float band = 1.0 - stripes * (0.5 + 0.5 * sin(v_uv.x * 17.0 + v_phase + TIME * 0.3));
	float breathe = 0.75 + 0.25 * sin(TIME * 0.35 + v_phase * 3.1);
	// Where the shaft meets the land: linear depth of the scene against this fragment's.
	float scene_depth = texture(depth_texture, SCREEN_UV).r;
	vec4 scene_view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, scene_depth, 1.0);
	float gap = -scene_view.z / scene_view.w - (-VERTEX.z);
	float ground = clamp(gap / ground_fade_m, 0.0, 1.0);
	float dist = length(VERTEX);
	float near = smoothstep(near_fade_m * 0.5, near_fade_m, dist);
	vec3 view_dir = normalize((INV_VIEW_MATRIX * vec4(0.0, 0.0, -1.0, 0.0)).xyz);
	float facing = clamp(dot(view_dir, normalize(sun_direction)) * 0.5 + 0.5, 0.0, 1.0);
	float look = mix(away_share, 1.0, facing);
	ALBEDO = sun_color * intensity * v_strength * across * along * band * breathe * ground * near * look;
}
