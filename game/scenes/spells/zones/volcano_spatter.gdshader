shader_type spatial;
// The splash of lava on the ground around the Volcano's mouth: a sheet of rings that pulses out from the center every 1.5 s. Each ring has
// a radius and a lift that depend on how far through the pulse it is (`pulse`, 0 to 1) and on the ring; the ground under every vertex comes
// from `ground`, a small picture of the land around the center (one row per angle, one column per step of `ground_step_m`; red = height
// over the world), so the sheet lies on the mound without asking the terrain once per vertex. The baked mesh only holds the rings (UV.x the
// turn, UV.y the ring); this puts every vertex in place. Drawn without shading, lighting or depth writes.
// Ref: sacengine SacVolcanoSpatter (sacobject.d:3462-3562).
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

uniform sampler2D skin : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D ground : filter_linear, repeat_enable;
// Metres between two columns of `ground`, how many columns it has, and the height of the node (the picture holds heights over the world).
uniform float ground_step_m = 2.0;
uniform int ground_steps = 15;
uniform float origin_y = 0.0;
// How far through the pulse it is (0 to 1), and which frame of the 4 x 4 atlas it shows.
uniform float pulse : hint_range(0.0, 1.0) = 0.0;
uniform int frame = 0;
uniform float turns = 8.0;
uniform float energy = 2.0;

varying vec2 v_uv;

float bezier_1d(float a, float b, float c, float d, float u) {
	float v = 1.0 - u;
	return v * v * v * a + 3.0 * v * v * u * b + 3.0 * v * u * u * c + u * u * u * d;
}

void vertex() {
	float s = UV.y;
	float q = bezier_1d(0.0, 0.6, 1.0, 1.0, pulse);
	float radius = bezier_1d(bezier_1d(9.0, 9.0, 9.0, 9.0, q), bezier_1d(10.0, 13.0, 17.0, 14.0, q), bezier_1d(12.0, 14.0, 18.0, 18.0, q), bezier_1d(13.0, 17.0, 20.0, 23.0, q), s) * 1.1;
	float lift = bezier_1d(bezier_1d(0.0, 0.0, 0.0, 0.0, q), bezier_1d(4.0, 0.0, 0.0, 0.0, q), bezier_1d(4.0, 10.0, 6.0, 0.0, q), bezier_1d(0.0, 0.0, 0.0, 0.0, q), s) * 1.1 + 0.25;
	float angle = 0.5 * PI + TAU * UV.x;
	float column = clamp(radius / ground_step_m, 0.0, float(ground_steps - 1));
	float land = textureLod(ground, vec2((column + 0.5) / float(ground_steps), UV.x), 0.0).r;
	VERTEX = vec3(radius * cos(angle), land - origin_y + lift, radius * sin(angle));
	float x = UV.x * turns;
	float k = floor(x);
	float across = mod(k, 2.0) < 0.5 ? x - k : 1.0 - (x - k);
	vec2 cell = vec2(float(frame % 4), float(frame / 4));
	vec2 inset = vec2(0.5 / 64.0);
	vec2 low = cell / 4.0 + inset;
	vec2 high = (cell + 1.0) / 4.0 - inset;
	v_uv = vec2(mix(low.x, high.x, across), mix(low.y, high.y, 1.0 - s));
}

void fragment() {
	vec4 texel = texture(skin, v_uv);
	ALBEDO = texel.rgb * energy;
	ALPHA = texel.a;
}
