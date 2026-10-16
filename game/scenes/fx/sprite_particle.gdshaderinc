// Sprite like sacengine's particle material: atlas * color * energy (HDR). Same atlases, colors and
// timing as the original; RFC-029 029a adds, behind two per-preset globals:
// - soft edge: the sprite fades near the scene depth (like BaseMaterial3D proximity_fade), so it
//   no longer cuts the ground along a straight line;
// - frame blend: frame n mixes into n + 1 over its `frame_s` (the atlas no longer jumps).
// Plus an optional per-life color ramp. Define FX_LIT before the include for the shaded variant.
uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform float energy = 1.0;
uniform int h_frames = 4;
uniform int v_frames = 4;
uniform bool billboard = true;
// Meters over which the sprite fades in front of the scene depth. 0 = hard edge.
uniform float soft_distance_m = 0.0;
uniform bool frame_blend = true;
// The atlas loops (several cycles per life or a random start frame): the last frame blends into the first.
uniform bool frame_wrap = true;
uniform bool use_color_ramp = false;
// Multiplies color and alpha over the normalized life (x = 0 born, 1 dead).
uniform sampler2D color_ramp : source_color, filter_linear, repeat_disable;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;

// Written by QualityApplier from the LookQuality preset (0 = off, the pre-029 look).
global uniform float fx_soft_particles;
global uniform float fx_frame_blend;
// Depth fog of the map (ThemeApplier writes them with the Environment). Only the additive variant
// (FX_FOG_FADE) uses them: Godot's own fog would add its light to an additive sprite.
global uniform float fx_fog_density;
global uniform float fx_fog_begin;
global uniform float fx_fog_end;

varying vec2 next_uv;
varying float blend_t;
varying float life_t;

vec2 frame_offset(float frame, float h, float v) {
	return vec2(mod(frame, h) / h, floor((frame + 0.5) / h) / v);
}

void vertex() {
	if (billboard) {
		mat4 mat_world = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
		mat_world = mat_world * mat4(vec4(cos(INSTANCE_CUSTOM.x), -sin(INSTANCE_CUSTOM.x), 0.0, 0.0), vec4(sin(INSTANCE_CUSTOM.x), cos(INSTANCE_CUSTOM.x), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
		MODELVIEW_MATRIX = VIEW_MATRIX * mat_world;
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
	float h = float(h_frames);
	float v = float(v_frames);
	float total = h * v;
	float raw = INSTANCE_CUSTOM.z * total;
	float frame = mod(floor(raw), total);
	float next = frame + 1.0;
	next = frame_wrap ? mod(next, total) : min(next, total - 1.0);
	blend_t = (frame_blend && fx_frame_blend > 0.5) ? fract(raw) : 0.0;
	life_t = clamp(INSTANCE_CUSTOM.y, 0.0, 1.0);
	vec2 base_uv = UV / vec2(h, v);
	UV = base_uv + frame_offset(frame, h, v);
	next_uv = base_uv + frame_offset(next, h, v);
}

void fragment() {
	vec4 tex = texture(atlas, UV);
	if (blend_t > 0.0) {
		tex = mix(tex, texture(atlas, next_uv), blend_t);
	}
	vec4 tint = COLOR;
	if (use_color_ramp) {
		tint *= texture(color_ramp, vec2(life_t, 0.5));
	}
	float soft = 1.0;
	if (soft_distance_m > 0.0 && fx_soft_particles > 0.5) {
		// View-space z of the scene behind: only the z and w rows of the inverse projection matter.
		float depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
		float scene_z = (depth * INV_PROJECTION_MATRIX[2].z + INV_PROJECTION_MATRIX[3].z)
				/ (depth * INV_PROJECTION_MATRIX[2].w + INV_PROJECTION_MATRIX[3].w);
		soft = clamp((VERTEX.z - scene_z) / soft_distance_m, 0.0, 1.0);
	}
	ALBEDO = tex.rgb * tint.rgb * energy;
	ALPHA = tex.a * tint.a * soft;
#ifdef FX_FOG_FADE
	// FOG_MODE_DEPTH with curve 1: amount = smoothstep(begin, end, distance) * density.
	if (fx_fog_density > 0.0 && fx_fog_end > fx_fog_begin) {
		float fog = smoothstep(fx_fog_begin, fx_fog_end, length(VERTEX)) * fx_fog_density;
		ALPHA *= 1.0 - clamp(fog, 0.0, 1.0);
	}
#endif
#ifdef FX_LIT
	// Matter (blood, dirt, dust) takes the light of the ground it comes from: the normal points up
	// instead of at the camera, so a sprite is not dark just because the sun is behind it.
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
#endif
}
