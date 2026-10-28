// Cloud shadows: soft dark patches that drift over the land like clouds under the sun (strength 0 = off).
// Included by the ground shader (ground.gdshader). `GroundMaterial.update` fills the uniforms from the god's `GodGround`.

uniform float cloud_shadow_strength = 0.0;
uniform float cloud_shadow_scale_m = 140.0;
uniform float cloud_shadow_speed = 2.5;
uniform vec2 cloud_shadow_dir = vec2(0.82, 0.57);
uniform float cloud_shadow_softness = 0.35;

// Light factor (1 = full sun, 1 - strength = deepest shadow) at map position `xz`, drifting with `time`.
float cloud_shadow(vec2 xz, float time) {
	vec2 q = (xz - normalize(cloud_shadow_dir) * time * cloud_shadow_speed) / cloud_shadow_scale_m;
	// Two taps at unrelated scales so one noise tile never reads as a repeating pattern.
	float n = mix(texture(ground_noise, q).g, texture(ground_noise, q * 2.31 + vec2(0.37, 0.71)).b, 0.3);
	float cover = smoothstep(0.5 - cloud_shadow_softness * 0.5, 0.5 + cloud_shadow_softness * 0.5, n);
	return 1.0 - cover * cloud_shadow_strength;
}
