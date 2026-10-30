// Editor only: a painted map of GrassKit's ground drawn over it while a brush is up.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;

uniform sampler2D map : filter_linear, repeat_disable;
// 0 where grass grows, 1 how tall, 2 the ground's colour, 3 a kind.
uniform int kind = 0;

void fragment() {
	vec4 m = texture(map, UV);
	vec3 c = vec3(1.0);
	float a = 0.0;
	if (kind == 0) {
		// Green where grass grows, red where it does not.
		c = mix(vec3(0.9, 0.2, 0.12), vec3(0.25, 0.9, 0.35), m.r);
		a = mix(0.55, 0.12, m.r);
	} else if (kind == 1) {
		// Blue shorter than the look, orange taller.
		float s = m.r * 2.0;
		c = s < 1.0 ? mix(vec3(0.15, 0.4, 1.0), vec3(1.0), s) : mix(vec3(1.0), vec3(1.0, 0.55, 0.1), s - 1.0);
		a = abs(m.r - 0.5) * 1.2;
	} else if (kind == 2) {
		c = pow(m.rgb, vec3(2.2));
		a = m.a * 0.75;
	} else {
		c = vec3(0.95, 0.3, 0.9);
		a = m.r * 0.55;
	}
	ALBEDO = c;
	ALPHA = a;
}
