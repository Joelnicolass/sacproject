// The original sky's cloud layer: a square plane, 10240 m wide, at SKY_CLOUD_HEIGHT_M above the sky
// base (sky.gd: 0.25 * 0.7 * 10240), UV x4 across it, fading to nothing toward its edge.

const float SKY_CLOUD_SIZE_M = 10240.0;
const float SKY_CLOUD_HEIGHT_M = 1792.0;
const float SKY_CLOUD_UV_REPEATS = 4.0;

// xy = cloud UV, z = radial fade (1 at the centre, 0 at the edge), w = 1 when the ray reaches the plane.
vec4 sky_cloud_uv(vec3 dir, float eye_height_m, vec2 offset) {
	float rise = SKY_CLOUD_HEIGHT_M - eye_height_m;
	float rise_rate = abs(dir.y) < 1e-5 ? 1e-5 : dir.y;
	float t = rise / rise_rate;
	vec2 p = t * dir.xz;
	vec2 loc = p / (SKY_CLOUD_SIZE_M * 0.5);
	vec2 uv = (p / SKY_CLOUD_SIZE_M + 0.5) * SKY_CLOUD_UV_REPEATS;
	float hit = step(0.0, t);
	return vec4(uv - offset, 1.0 - dot(loc, loc), hit);
}

vec3 sky_cloud_blend(vec3 color, sampler2D clouds, vec4 uv_fade, vec2 dx, vec2 dy, float energy, float max_alpha) {
	if (uv_fade.w > 0.5 && uv_fade.z > 0.0) {
		vec4 texel = textureGrad(clouds, uv_fade.xy, dx, dy);
		float alpha = clamp(texel.a * max_alpha * uv_fade.z, 0.0, 1.0);
		color = mix(color, min(texel.rgb * energy, vec3(1.0)), alpha);
	}
	return color;
}
