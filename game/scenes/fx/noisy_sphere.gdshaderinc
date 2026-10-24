// What the spheres of a ball of noise share (Explosion's balls and burst, Healing Aura's veil): a sphere of radius 0.5 whose skin is pushed in
// and out by smooth 3D noise (the original morphs sixteen noisy copies of the sphere), and the atlas cell an animation shows at a time.

float hash31(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float value_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash31(i), hash31(i + vec3(1, 0, 0)), f.x), mix(hash31(i + vec3(0, 1, 0)), hash31(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash31(i + vec3(0, 0, 1)), hash31(i + vec3(1, 0, 1)), f.x), mix(hash31(i + vec3(0, 1, 1)), hash31(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

// The vertex of a unit-diameter sphere with its skin moved along its normal by the noise of the moment `t`.
vec3 noisy_skin(vec3 vertex, float t, float amount) {
	vec3 n = normalize(vertex);
	float bump = value_noise(n * 2.5 + vec3(t * 0.35, t * 0.2, -t * 0.3)) - 0.5;
	return n * (0.5 + bump * 2.0 * amount);
}

// The top-left corner of cell `index` of an atlas of `cells` columns and rows, in atlas uv units.
vec2 atlas_cell(float index, vec2 cells) {
	return vec2(mod(index, cells.x), floor(index / cells.x));
}
