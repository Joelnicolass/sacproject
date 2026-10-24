shader_type spatial;
// The Volcano's column of lava: a tube of rings laid along a curve (four heights and four radii, from the top of the column to its foot),
// skinned with a mirrored frame of the lava atlas (4 x 2). It grows out of the ground: `extend` (0 to 1) is how much of the curve, from
// the foot up, the tube covers. The baked mesh (tools/bake/bake_volcano_meshes.gd) only holds the rings: UV.x is the turn, UV.y the
// ring (0 at the top); this puts every vertex in place. Drawn over the world without shading or lighting; the lava is opaque.
// Ref: sacengine SacVolcanoLava (sacobject.d:3401-3434).
render_mode unshaded, cull_disabled, fog_disabled, shadows_disabled;

// Height of the four bezier knots of the column's axis, metres over the foot (top first), and the radius at each.
uniform vec4 heights = vec4(310.0, 262.0, 265.0, -5.0);
uniform vec4 radii = vec4(140.0, 2.0, 20.0, 10.0);
// How much of the column has grown, from its foot: 0 nothing, 1 all of it.
uniform float extend : hint_range(0.0, 1.0) = 1.0;
uniform sampler2D skin : source_color, filter_linear_mipmap, repeat_disable;
// Which frame of the atlas (0 to 7, row by row) and its layout.
uniform int frame = 0;
uniform ivec2 frames = ivec2(4, 2);
// How many times the skin goes (and comes back, mirrored) around the column.
uniform float turns = 2.0;
// Brightness of the skin (the original shades it at 10; under the filmic tonemap that burns it white).
uniform float energy = 3.2;

varying vec2 v_uv;

float bezier_1d(vec4 k, float u) {
	float v = 1.0 - u;
	return v * v * v * k.x + 3.0 * v * v * u * k.y + 3.0 * v * u * u * k.z + u * u * u * k.w;
}

void vertex() {
	float s = UV.y;
	float t = (1.0 - extend) + extend * s;
	float radius = bezier_1d(radii, t);
	float angle = 0.5 * PI + TAU * UV.x;
	VERTEX = vec3(radius * cos(angle), bezier_1d(heights, t), radius * sin(angle));
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
	ALBEDO = texture(skin, v_uv).rgb * energy;
}
