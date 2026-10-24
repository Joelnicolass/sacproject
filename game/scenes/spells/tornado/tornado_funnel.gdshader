shader_type spatial;
// The Tornado's funnel: a wall of rings laid on a curved axis (seven points and seven radii, relative to the tornado's node), turning as it goes.
// One shader, three parts of the same funnel: the upper half (part 0, fading in from the top), the lower half (part 1, the other skin, the
// texture upside down) and the ragged edge on both sides of the lower half (part 2, strips that face the camera). The baked meshes only
// hold the rings and the strips (tools/bake/make_tornado_funnel.gd); drawn over the world without shading or lighting.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

uniform vec3 axis[7];
uniform float radii[7];
uniform int part = 0;
// Turn of the funnel around its axis, radians.
uniform float spin = 0.0;
// The frame of the edge strip's four (0 to 3).
uniform float edge_frame = 0.0;
// 0 to 1: the whole funnel fades in as it grows.
uniform float alpha_scale = 1.0;
uniform sampler2D skin : source_color, filter_linear_mipmap, repeat_enable;
// Brightness of the skin (the original shades it at 10, 8 for the edge; under the filmic tonemap that burns it white).
uniform float energy = 3.2;
// How much of it shows through: the original draws it 90 % opaque.
uniform float opacity : hint_range(0.0, 1.0) = 0.9;

varying float v_alpha;
varying vec2 v_uv;

vec3 bezier(vec3 a, vec3 b, vec3 c, vec3 d, float u) {
	float v = 1.0 - u;
	return v * v * v * a + 3.0 * v * v * u * b + 3.0 * v * u * u * c + u * u * u * d;
}

float bezier_1d(float a, float b, float c, float d, float u) {
	float v = 1.0 - u;
	return v * v * v * a + 3.0 * v * v * u * b + 3.0 * v * u * u * c + u * u * u * d;
}

void vertex() {
	if (part == 2) {
		float t = UV2.y;
		vec3 centre = bezier(axis[3], axis[4], axis[5], axis[6], t);
		float radius = bezier_1d(radii[3], radii[4], radii[5], radii[6], t);
		vec3 world = (MODEL_MATRIX * vec4(centre, 1.0)).xyz;
		vec2 away = normalize(world.xz - INV_VIEW_MATRIX[3].xz);
		vec2 right = normalize(INV_VIEW_MATRIX[0].xz);
		vec2 side = 0.5 * vec2(away.y + right.x, -away.x + right.y);
		float slot = UV2.x;
		float reach = slot < 0.5 ? 0.9 : (slot < 1.5 ? 2.0 : (slot < 2.5 ? -2.0 : -0.9));
		VERTEX = centre + reach * radius * vec3(side.x, 0.0, side.y);
		v_uv = vec2((edge_frame + mix(0.5 / 64.0, 1.0 - 0.5 / 64.0, UV.x)) / 4.0, UV.y);
		v_alpha = COLOR.a;
	} else {
		float t = UV.y;
		int i = part == 1 ? 3 : 0;
		vec3 centre = bezier(axis[i], axis[i + 1], axis[i + 2], axis[i + 3], t);
		float radius = bezier_1d(radii[i], radii[i + 1], radii[i + 2], radii[i + 3], t);
		float angle = spin - TAU * UV.x;
		VERTEX = centre + radius * vec3(sin(angle), 0.0, cos(angle));
		v_uv = vec2(UV.x, part == 1 ? 1.0 - t : t);
		v_alpha = part == 1 ? 1.0 : t * (3.0 - t) * (3.0 - t) / 4.0;
	}
}

void fragment() {
	vec4 texel = texture(skin, v_uv);
	ALBEDO = texel.rgb * energy;
	ALPHA = opacity * alpha_scale * v_alpha * (part == 2 ? texel.a : 1.0);
}
