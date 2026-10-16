// Shared by the sky passes: a quad over the whole screen at the far plane, and the world
// direction of each pixel (so the pass needs no geometry and works with any camera).
void vertex() {
	POSITION = vec4(VERTEX.xy, 1e-7, 1.0);
}

vec3 sky_dir(vec2 screen_uv, mat4 inv_projection, mat4 inv_view) {
	vec4 v = inv_projection * vec4(screen_uv * 2.0 - 1.0, 0.5, 1.0);
	return normalize((inv_view * vec4(v.xyz / v.w, 0.0)).xyz);
}
