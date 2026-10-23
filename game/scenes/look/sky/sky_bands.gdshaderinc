// The original sky's two bands, as a ray cast from the eye (no geometry in the scene).
//
// Space: origin on the camera's x/z at the sky base height, +Y up. The upper band is a cylinder of
// radius SKY_BAND_RADIUS_M from height 0 to SKY_BAND_TOP_M; the lower band is a cone from that same
// ring down to SKY_BAND_BOTTOM_M, narrowing to 80 % of the radius. Both spin together around +Y and
// repeat their texture SKY_BAND_REPEATS times around, mirrored so the seams match.
//
// The original draws both as a 64-sided mesh (two triangles per side, texture coordinates only at the
// corners). The ray hits those flat sides and interpolates inside the same two triangles, so the
// texture lands where the mesh puts it: on the cone a side is a trapezoid, and the two triangles bend
// the texture by up to half a pixel against a perfect circle. Numbers as in the original sky:
// 10240 m wide, 0.25 high, 8 repeats.

const float SKY_BAND_RADIUS_M = 5120.0;
const float SKY_BAND_TOP_M = 2560.0;
const float SKY_BAND_BOTTOM_M = -2560.0;
const float SKY_BAND_REPEATS = 8.0;
// The cone narrows by 20 % of the radius over its height.
const float SKY_BAND_CONE_RADIUS_RATIO = 0.8;
const float SKY_BAND_SIDES = 64.0;
// One side spans 2 * pi / 64 radians; its middle is cos / sin of half of that away from a corner.
const float SKY_BAND_SIDE_RAD = 0.09817477;
const float SKY_BAND_HALF_COS = 0.99879546;
const float SKY_BAND_HALF_SIN = 0.04906767;

float sky_band_mirror(float u) {
	return 1.0 - abs(mod(u, 2.0) - 1.0);
}

// Where the ray leaves a band made of flat sides between two rings.
// Rings: (y_low, r_low, v_low) and (y_high, r_high, v_high) = height, radius, texture v. `spin` turns the band.
// Returns xy = texture coordinate, z = hit height, w = 1 when the ray crosses the band.
// `u_unfolded` is the same u before mirroring (0..8 around): derive the mip level from it, not from xy.
vec4 sky_band_hit(vec3 dir, float eye_height_m, float spin, float y_low, float r_low, float v_low,
		float y_high, float r_high, float v_high, out float u_unfolded) {
	float azimuth = mod(atan(dir.z, dir.x) - spin, TAU);
	float side = min(floor(azimuth / SKY_BAND_SIDE_RAD), SKY_BAND_SIDES - 1.0);
	// Angle from the middle of that side, where its flat face is closest to the axis.
	float offset = azimuth - (side + 0.5) * SKY_BAND_SIDE_RAD;
	float horizontal = length(dir.xz);
	float slope = (r_high - r_low) / (y_high - y_low);
	float eye_radius = r_low + slope * (eye_height_m - y_low);
	float denominator = horizontal * cos(offset) - SKY_BAND_HALF_COS * slope * dir.y;
	float t = SKY_BAND_HALF_COS * eye_radius / max(denominator, 1e-5);
	float y = eye_height_m + t * dir.y;
	// Position across the face, and how far up it the ray is (0 at the low ring, 1 at the high ring).
	float across = t * horizontal * sin(offset);
	float up = (y - y_low) / (y_high - y_low);
	float half_low = r_low * SKY_BAND_HALF_SIN;
	float half_high = r_high * SKY_BAND_HALF_SIN;

	// First triangle: low-left, high-left, low-right. Second: low-right, high-left, high-right.
	float c = (across + half_low - up * (half_low - half_high)) / (2.0 * half_low);
	float along = c;
	if (up + c > 1.0) {
		float lean = (across - half_low * (1.0 - up)) / half_high;
		along = 1.0 - 0.5 * (up - lean);
	}
	u_unfolded = (side + along) * SKY_BAND_REPEATS / SKY_BAND_SIDES;
	float hit = step(1e-5, denominator) * step(0.0, t) * step(y_low, y) * step(y, y_high);
	return vec4(sky_band_mirror(u_unfolded), mix(v_low, v_high, up), y, hit);
}

vec4 sky_band_top_uv(vec3 dir, float eye_height_m, float spin, out float u_unfolded) {
	return sky_band_hit(dir, eye_height_m, spin, 0.0, SKY_BAND_RADIUS_M, 1.0,
			SKY_BAND_TOP_M, SKY_BAND_RADIUS_M, 0.0, u_unfolded);
}

vec4 sky_band_bottom_uv(vec3 dir, float eye_height_m, float spin, out float u_unfolded) {
	return sky_band_hit(dir, eye_height_m, spin, SKY_BAND_BOTTOM_M, SKY_BAND_RADIUS_M * SKY_BAND_CONE_RADIUS_RATIO, 0.0,
			0.0, SKY_BAND_RADIUS_M, 1.0, u_unfolded);
}

// Screen-space change of (u, v) for the mip level, from the derivatives the caller takes (dFdx / dFdy are
// fragment built-ins, so they stay in sky()). u is differentiated before mirroring so a fold in the middle
// of a pixel pair does not read as "no change"; around the 0 / 8 wrap the mirrored one is the continuous one.
vec2 sky_band_grad(float du_unfolded, float du_mirrored, float dv) {
	return vec2(abs(du_unfolded) > 1.0 ? du_mirrored : du_unfolded, dv);
}

// Lays a band texel over `color`: unshaded, brightened by `energy` and clamped, blended by its alpha.
vec3 sky_band_blend(vec3 color, sampler2D band, vec4 uv_hit, vec2 dx, vec2 dy, float energy) {
	if (uv_hit.w > 0.5) {
		vec4 texel = textureGrad(band, uv_hit.xy, dx, dy);
		color = mix(color, min(texel.rgb * energy, vec3(1.0)), texel.a);
	}
	return color;
}
