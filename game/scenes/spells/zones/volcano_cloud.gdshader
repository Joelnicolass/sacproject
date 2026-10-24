shader_type spatial;
// The Volcano's smoke umbrella: a fat tube of rings laid along a short curve over the column (four heights and four radii), skinned with a
// mirrored frame of the smoke atlas (4 x 4). The baked mesh only holds the rings (UV.x the turn, UV.y the ring); this puts every vertex
// in place. Drawn over the world without shading or lighting, as dark smoke that fades in as the volcano erupts and out as it dies.
// Ref: sacengine SacVolcanoCloud (sacobject.d:3436-3460).
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

uniform vec4 heights = vec4(318.0, 293.0, 325.0, 268.0);
uniform vec4 radii = vec4(246.0, 190.0, 137.0, 52.0);
uniform sampler2D skin : source_color, filter_linear_mipmap, repeat_disable;
// Which frame of the atlas (0 to 15, row by row) and its layout.
uniform int frame = 0;
uniform ivec2 frames = ivec2(4, 4);
uniform float turns = 4.0;
uniform float energy = 1.0;
// 0 to 1: how much of the smoke shows (it grows in at the start and thins out at the end).
uniform float alpha_scale : hint_range(0.0, 1.0) = 1.0;

varying vec2 v_uv;

float bezier_1d(vec4 k, float u) {
	float v = 1.0 - u;
	return v * v * v * k.x + 3.0 * v * v * u * k.y + 3.0 * v * u * u * k.z + u * u * u * k.w;
}

void vertex() {
	float s = UV.y;
	float radius = bezier_1d(radii, s);
	float angle = 0.5 * PI + TAU * UV.x;
	VERTEX = vec3(radius * cos(angle), bezier_1d(heights, s), radius * sin(angle));
	float x = UV.x * turns;
	float k = floor(x);
	float across = mod(k, 2.0) < 0.5 ? x - k : 1.0 - (x - k);
	vec2 grid = vec2(frames);
	vec2 cell = vec2(float(frame % frames.x), float(frame / frames.x));
	vec2 inset = 0.5 / (vec2(256.0) / grid);
	vec2 low = cell / grid + inset;
	vec2 high = (cell + 1.0) / grid - inset;
	v_uv = vec2(mix(low.x, high.x, across), mix(low.y, high.y, s));
}

void fragment() {
	vec4 texel = texture(skin, v_uv);
	ALBEDO = texel.rgb * energy;
	ALPHA = texel.a * alpha_scale;
}
