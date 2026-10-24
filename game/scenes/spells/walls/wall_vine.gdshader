shader_type spatial;
// A vine of the Vinewall: the unskinned tube (assets/custom/walls/vine_tube.obj: 1 m along +y, radius 0.1 tapering to 0) stood up from its
// root as tall as the wall, swaying and twisting without end, growing when it is born and shrinking back when the wall sinks. Lit and opaque
// with the vine texture. Per vine: INSTANCE_CUSTOM = (second it was born, scale, phase, 0). WallVines feeds the uniforms.
render_mode cull_disabled;

uniform sampler2D albedo : source_color, filter_linear_mipmap, repeat_enable;
// Seconds since the cast began, and the second the wall began to sink (a very large number until then).
uniform float age_s = 0.0;
uniform float vanish_at_s = 1000000.0;
uniform float grow_s = 1.0;
uniform float vanish_len_s = 1.0;
uniform float height_m = 7.5;
// How far the tip swings and how fast it twists.
uniform float sway_m = 0.9;
uniform float twist_per_s = 1.3;

void vertex() {
	float born = INSTANCE_CUSTOM.x;
	float scale_m = INSTANCE_CUSTOM.y;
	float phase = INSTANCE_CUSTOM.z;
	float live = min(age_s, vanish_at_s);
	float grown = clamp((live - born) / grow_s, 0.0, 1.0);
	grown = max(0.0, grown - max(0.0, age_s - vanish_at_s) / vanish_len_s);
	float t = VERTEX.y;
	float spin = TIME * twist_per_s + phase;
	vec3 centre = vec3(sway_m * grown * t * t * sin(spin + 2.0 * t), height_m * grown * t, sway_m * grown * t * t * cos(spin * 1.3 + 3.0 * t));
	VERTEX = centre + vec3(VERTEX.x, 0.0, VERTEX.z) * scale_m * min(1.0, grown * 3.0);
}

void fragment() {
	ALBEDO = texture(albedo, UV).rgb;
	METALLIC = 0.5;
	ROUGHNESS = 1.0;
}
