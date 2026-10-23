// The original sky's two bands, as a ray cast from the eye (no geometry).
//
// Space: origin on the camera's x/z at the sky base height, +Y up. The upper band is a cylinder of
// radius SKY_BAND_RADIUS_M from height 0 to SKY_BAND_TOP_M; the lower band is a cone from that same
// ring down to SKY_BAND_BOTTOM_M, narrowing to 80 % of the radius. Both spin together around +Y and
// repeat their texture SKY_BAND_REPEATS times around, mirrored so the seams match.
// Same numbers as sky.gd (SCALING 10240, SKY_Z 0.25, UNDER_Z -0.25, TEXTURE_REPEATS 8).

const float SKY_BAND_RADIUS_M = 5120.0;
const float SKY_BAND_TOP_M = 2560.0;
const float SKY_BAND_BOTTOM_M = -2560.0;
const float SKY_BAND_REPEATS = 8.0;
// The cone narrows by 20 % of the radius over its height.
const float SKY_BAND_CONE_SLOPE = 0.4;

float sky_band_mirror(float u) {
	return 1.0 - abs(mod(u, 2.0) - 1.0);
}

// Texture coordinate where the ray leaves the upper band: xy = uv, z = hit height (relative to the
// origin), w = 1 when the ray crosses the band. `spin` is the band's rotation in radians.
vec4 sky_band_top_uv(vec3 dir, float eye_height_m, float spin) {
	float horizontal = length(dir.xz);
	float t = SKY_BAND_RADIUS_M / max(horizontal, 1e-5);
	float y = eye_height_m + t * dir.y;
	float u = sky_band_mirror(SKY_BAND_REPEATS * (atan(dir.z, dir.x) - spin) / TAU);
	float hit = step(0.0, y) * step(y, SKY_BAND_TOP_M);
	return vec4(u, 1.0 - y / SKY_BAND_TOP_M, y, hit);
}

vec4 sky_band_bottom_uv(vec3 dir, float eye_height_m, float spin) {
	float horizontal = length(dir.xz);
	float denominator = horizontal - SKY_BAND_CONE_SLOPE * dir.y;
	float t = (SKY_BAND_RADIUS_M + SKY_BAND_CONE_SLOPE * eye_height_m) / max(denominator, 1e-5);
	float y = eye_height_m + t * dir.y;
	float u = sky_band_mirror(SKY_BAND_REPEATS * (atan(dir.z, dir.x) - spin) / TAU);
	float hit = step(1e-5, denominator) * step(SKY_BAND_BOTTOM_M, y) * step(y, 0.0);
	return vec4(u, 1.0 + y / -SKY_BAND_BOTTOM_M, y, hit);
}

// Lays a band texel over `color`: unshaded, brightened by `energy` and clamped, blended by its alpha.
vec3 sky_band_blend(vec3 color, sampler2D band, vec4 uv_hit, vec2 dx, vec2 dy, float energy) {
	if (uv_hit.w > 0.5) {
		vec4 texel = textureGrad(band, uv_hit.xy, dx, dy);
		color = mix(color, min(texel.rgb * energy, vec3(1.0)), texel.a);
	}
	return color;
}
