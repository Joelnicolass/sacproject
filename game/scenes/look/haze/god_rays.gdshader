// Screen-space god rays (light scattering as a post-process, GPU Gems 3 ch. 13): every pixel marches
// `samples` steps toward the sun on the screen and adds the sky it finds on the way, so the sky behind
// rocks and trunks pours out as shafts. One full-screen pass with `samples` reads of the depth buffer:
// cheap, and nothing when the sun is behind the camera or far off the screen. Drawn by a 2 x 2 quad
// that covers the screen (vertex() writes clip space); HazeLayer feeds sun_direction and sun_color.
shader_type spatial;
render_mode unshaded, blend_add, depth_test_disabled, depth_draw_never, cull_disabled, fog_disabled;

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
// Direction toward the sun, world space (the opposite of the DirectionalLight3D's forward).
uniform vec3 sun_direction = vec3(0.0, 0.6, 0.8);
uniform vec3 sun_color : source_color = vec3(1.0, 0.85, 0.6);
// How bright the shafts are.
uniform float intensity : hint_range(0.0, 4.0, 0.01) = 0.6;
// Steps toward the sun (the cost is one depth read per step and pixel).
uniform int samples : hint_range(4, 64) = 24;
// Share of the way to the sun the march covers (longer shafts with a higher value).
uniform float reach : hint_range(0.05, 1.0, 0.01) = 0.55;
// How fast each step weighs less (shorter shafts with a lower value).
uniform float decay : hint_range(0.8, 1.0, 0.001) = 0.95;
// The sun this far off the screen (in screens) still casts rays; beyond, they fade out.
uniform float off_screen_fade : hint_range(0.0, 2.0, 0.01) = 0.6;

void vertex() {
	POSITION = vec4(VERTEX.xy, 0.0, 1.0);
}

// Sky: nothing was drawn there (reverse Z: the far plane is depth 0).
float sky_at(vec2 uv) {
	return texture(depth_texture, uv).r <= 0.000001 ? 1.0 : 0.0;
}

void fragment() {
	vec4 clip = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(normalize(sun_direction), 0.0));
	if (clip.w <= 0.0) {
		discard;
	}
	vec2 ndc = clip.xy / clip.w;
	vec2 sun_uv = vec2(ndc.x * 0.5 + 0.5, 0.5 - ndc.y * 0.5);
	vec2 off = max(abs(sun_uv - 0.5) - 0.5, vec2(0.0));
	float visible = 1.0 - smoothstep(0.0, off_screen_fade, max(off.x, off.y));
	if (visible <= 0.0) {
		discard;
	}
	vec2 step_uv = (sun_uv - SCREEN_UV) * reach / float(samples);
	vec2 uv = SCREEN_UV;
	float weight = 1.0;
	float light = 0.0;
	for (int i = 0; i < samples; i++) {
		uv += step_uv;
		if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
			break;
		}
		light += sky_at(uv) * weight;
		weight *= decay;
	}
	light /= float(samples);
	// Facing the sun more lights the shafts more.
	vec3 forward = -INV_VIEW_MATRIX[2].xyz;
	float facing = clamp(dot(forward, normalize(sun_direction)), 0.0, 1.0);
	ALBEDO = sun_color * light * intensity * visible * (0.35 + 0.65 * facing);
}
