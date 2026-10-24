shader_type spatial;
// A Meanstalk's body: a tube whose rings the shader lays along two cubic curves (eight control points, relative to the root) and sizes by
// the radius of the original (2 m at the root, 1.8 m at the middle, 0 at the tip). The baked mesh only holds the unit ring of each vertex
// (VERTEX.xz, also its normal) and UV = (around, t along the stalk).
render_mode cull_disabled, shadows_disabled;

// Control points: the first four are the root half, the last four the tip half.
uniform vec3 pts[8];
// The skin of the stalk (the SPEL's ttex, dark green) and the tip's (ttx2, green fading to orange).
uniform sampler2D skin : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D tip_skin : source_color, filter_linear_mipmap, repeat_enable;
// How much of the second skin shows at the tip, and from which `t` along the stalk it begins.
uniform float tip_mix : hint_range(0.0, 1.0) = 0.6;
uniform float tip_from : hint_range(0.0, 1.0) = 0.55;
// Times the skin repeats around and along the stalk (the original: once each).
uniform vec2 repeat = vec2(1.0, 1.0);
uniform float roughness_value : hint_range(0.0, 1.0) = 1.0;
uniform float metallic_value : hint_range(0.0, 1.0) = 0.1;

vec3 bezier(vec3 a, vec3 b, vec3 c, vec3 d, float u) {
	float v = 1.0 - u;
	return v * v * v * a + 3.0 * v * v * u * b + 3.0 * v * u * u * c + u * u * u * d;
}

vec3 bezier_tangent(vec3 a, vec3 b, vec3 c, vec3 d, float u) {
	float v = 1.0 - u;
	return 3.0 * v * v * (b - a) + 6.0 * v * u * (c - b) + 3.0 * u * u * (d - c);
}

float bezier_1d(float a, float b, float c, float d, float u) {
	float v = 1.0 - u;
	return v * v * v * a + 3.0 * v * v * u * b + 3.0 * v * u * u * c + u * u * u * d;
}

// The rotation that takes +Y to the unit vector `t` (Rodrigues); when it points straight down, a half turn around X.
mat3 turn_up_to(vec3 t) {
	float c = t.y;
	if (c < -0.9999) {
		return mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, -1.0, 0.0), vec3(0.0, 0.0, -1.0));
	}
	vec3 v = cross(vec3(0.0, 1.0, 0.0), t);
	mat3 k = mat3(vec3(0.0, v.z, -v.y), vec3(-v.z, 0.0, v.x), vec3(v.y, -v.x, 0.0));
	return mat3(1.0) + k + k * k / (1.0 + c);
}

void vertex() {
	float t = UV.y;
	bool first = t <= 0.5;
	float u = first ? 2.0 * t : 2.0 * t - 1.0;
	vec3 centre = first ? bezier(pts[0], pts[1], pts[2], pts[3], u) : bezier(pts[4], pts[5], pts[6], pts[7], u);
	vec3 slope = first ? bezier_tangent(pts[0], pts[1], pts[2], pts[3], u) : bezier_tangent(pts[4], pts[5], pts[6], pts[7], u);
	float radius = first ? bezier_1d(2.0, 2.0, 2.0, 1.8, u) : bezier_1d(1.8, 1.6, 1.0, 0.0, u);
	mat3 frame = turn_up_to(normalize(slope + vec3(0.0, 0.00001, 0.0)));
	VERTEX = centre + frame * (vec3(VERTEX.x, 0.0, VERTEX.z) * radius);
	NORMAL = frame * vec3(NORMAL.x, 0.0, NORMAL.z);
}

void fragment() {
	vec2 uv = UV * repeat;
	vec3 base = texture(skin, uv).rgb;
	vec3 tip_colour = texture(tip_skin, uv).rgb;
	ALBEDO = mix(base, tip_colour, tip_mix * smoothstep(tip_from, 1.0, UV.y));
	ROUGHNESS = roughness_value;
	METALLIC = metallic_value;
}
