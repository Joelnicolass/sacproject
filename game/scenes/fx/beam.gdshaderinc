// Ribbon of a BeamFx (sacengine shadelessBoneMaterial with Blending.Additive, renderer.d:264-272), shared by
// beam.gdshader (blend_add, the default) and beam_mix.gdshader (blend_mix, BeamType.blend MIX). With BEAM_MIX the
// atlas is a straight-alpha overlay (export_particles glow_to_alpha, *_a.png): the colour as is, and its alpha times
// `energy` (clamped to 1) is the coverage, so the beam keeps its hue over a bright ground (snow).
// UV comes from beam_fx.gd in cell fractions (0..1): the axis at the bottom of the cell (bright row of
// ltn2), the fin's edge at the top. The cell and the brightness are per beam (instance uniforms), so
// every pooled beam shares this material.

uniform sampler2D atlas : source_color, filter_linear, repeat_disable;
uniform bool use_textures = false;
uniform vec3 fallback_color : source_color = vec3(0.45, 0.7, 1.0);
uniform int h_frames = 4;
uniform int v_frames = 4;
// Meters over which the ribbon fades in front of the scene depth. 0 = hard edge.
uniform float soft_distance_m = 0.3;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;

instance uniform float cell = 0.0;
instance uniform float energy = 1.0;

global uniform float fx_soft_particles;
global uniform float fx_fog_density;
global uniform float fx_fog_begin;
global uniform float fx_fog_end;

void fragment() {
	float h = float(h_frames);
	float v = float(v_frames);
	vec2 corner = vec2(mod(cell, h) / h, floor((cell + 0.5) / h) / v);
	vec4 texel;
	if (use_textures) {
		texel = textureLod(atlas, corner + UV / vec2(h, v), 0.0);
	} else {
		texel = vec4(fallback_color * pow(UV.y, 2.0), pow(UV.y, 2.0));
	}
#ifdef BEAM_MIX
	ALBEDO = texel.rgb;
	ALPHA = texel.a * clamp(energy, 0.0, 1.0);
#else
	ALBEDO = texel.rgb * energy;
	ALPHA = 1.0;
#endif
	if (soft_distance_m > 0.0 && fx_soft_particles > 0.5) {
		float depth = textureLod(depth_texture, SCREEN_UV, 0.0).r;
		float scene_z = (depth * INV_PROJECTION_MATRIX[2].z + INV_PROJECTION_MATRIX[3].z)
				/ (depth * INV_PROJECTION_MATRIX[2].w + INV_PROJECTION_MATRIX[3].w);
		ALPHA *= clamp((VERTEX.z - scene_z) / soft_distance_m, 0.0, 1.0);
	}
	if (fx_fog_density > 0.0 && fx_fog_end > fx_fog_begin) {
		float fog = smoothstep(fx_fog_begin, fx_fog_end, length(VERTEX)) * fx_fog_density;
		ALPHA *= 1.0 - clamp(fog, 0.0, 1.0);
	}
}
