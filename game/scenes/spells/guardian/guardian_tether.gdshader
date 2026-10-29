shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

// Guardian beam (sacengine SacGuardianTether: shadelessBoneMaterial, additive, energy 5; renderer.d:253-261).
// UV comes from guardian_tether.gd in cell fractions (0..1) of the 4x4 `grdn` atlas; one cell per 2 ticks.

uniform sampler2D atlas : source_color, filter_linear, repeat_disable;
uniform bool use_textures = false;
uniform vec3 fallback_color : source_color = vec3(0.35, 1.0, 0.55);
uniform float energy = 5.0;
uniform float frame_s = 0.0333;

void fragment() {
	float frame = mod(floor(TIME / frame_s), 16.0);
	vec2 cell = vec2(mod(frame, 4.0), floor(frame / 4.0)) * 0.25;
	vec3 col = use_textures ? textureLod(atlas, cell + UV * 0.25, 0.0).rgb : fallback_color * pow(UV.y, 2.0);
	ALBEDO = col * energy;
	ALPHA = 1.0;
}
