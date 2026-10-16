shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

// Electric rope (sacengine SacDocTether: shadelessBoneMaterial, renderer.d:1688-1690).
// UV comes from tether.gd in cell fractions (0..1): centerline at the bottom of the cell, outer edge
// at the top. The 4x4 cell is picked by time: 2 ticks per cell, 16 cells.

uniform sampler2D atlas : source_color, filter_linear, repeat_disable;
uniform bool use_textures = false;
uniform vec3 fallback_color : source_color = vec3(0.4, 0.8, 1.0);
uniform float energy_min = 0.375;
uniform float energy_max = 15.0;
uniform float energy_scale = 1.0;
uniform bool pulse = true;
uniform float frame_s = 0.0333;

void fragment() {
	float frame = mod(floor(TIME / frame_s), 16.0);
	vec2 cell = vec2(mod(frame, 4.0), floor(frame / 4.0)) * 0.25;
	// sacengine: energy = 0.375 + 14.625 * (0.5 + 0.25 cos(7a) + 0.25 sin(11a)), a = pi * frame / 60.
	float a = 3.14159265 * TIME;
	float wave = 0.5 + 0.25 * cos(7.0 * a) + 0.25 * sin(11.0 * a);
	float energy = pulse ? mix(energy_min, energy_max, wave) : energy_max;
	vec3 col;
	if (use_textures) {
		col = textureLod(atlas, cell + UV * 0.25, 0.0).rgb;
	} else {
		col = fallback_color * pow(UV.y, 2.0);
	}
	ALBEDO = col * energy * energy_scale;
	ALPHA = 1.0;
}
