// Cloud shadows: dark patches that drift over the land like clouds under the sun (strength 0 = off). The ground's light()
// dims only the sun with them, found where the sun's ray through the point crosses the cloud layer.
// Included by the ground shader (ground.gdshader). `GroundMaterial.update` fills the uniforms from the god's `GodGround`.

uniform float cloud_shadow_strength = 0.0;
uniform float cloud_shadow_scale_m = 140.0;
uniform float cloud_shadow_speed = 2.5;
uniform vec2 cloud_shadow_dir = vec2(0.82, 0.57);
uniform float cloud_shadow_softness = 0.35;
// Noise level the cloud edge sits at: lower = more of the land under clouds.
uniform float cloud_shadow_cover = 0.5;
// Height (m) of the cloud layer over the land: a low sun throws the shadows farther along its light.
uniform float cloud_shadow_height_m = 250.0;

// Light factor (1 = full sun, 1 - strength = deepest shadow) at map position `xz`, drifting with `time`.
float cloud_shadow(vec2 xz, float time) {
	vec2 q = (xz - normalize(cloud_shadow_dir) * time * cloud_shadow_speed) / cloud_shadow_scale_m;
	// Three octaves at unrelated scales and offsets: lumpy cloud shapes, never one repeating tile.
	float n = texture(ground_noise, q).g * 0.55
			+ texture(ground_noise, q * 2.17 + vec2(0.37, 0.71)).b * 0.3
			+ texture(ground_noise, q * 4.63 + vec2(0.13, 0.29)).g * 0.15;
	float cover = smoothstep(cloud_shadow_cover - cloud_shadow_softness * 0.5, cloud_shadow_cover + cloud_shadow_softness * 0.5, n);
	return 1.0 - cover * cloud_shadow_strength;
}

// The light factor of the sun at `p` (map space): the cloud where the ray toward the sun crosses the layer.
float cloud_shadow_along(vec3 p, vec3 to_sun, float time) {
	vec2 at = p.xz + to_sun.xz / max(to_sun.y, 0.1) * max(cloud_shadow_height_m - p.y, 0.0);
	return cloud_shadow(at, time);
}
