// Swirl sky: the original Sacrifice sky rebuilt in a shader, from its own textures.
// Colors come from the original band (skyt) and cloud (sky) textures of the biome, so the
// palette is the original's; what is new is depth: two cloud layers that drift at different
// speeds, a slow domain warp that stretches and curls them, a darker underside where they
// overlap and a warm glow toward the sun.
// Technique notes (written from scratch, nothing copied): domain-warped lookups and layered
// parallax planes are the usual cloud-sky approach (see godotshaders.com / shadertoy sky shaders).
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

#include "res://scenes/look/sky/sky_view.gdshaderinc"

uniform sampler2D clouds : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D band : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 background = vec3(0.0, 0.9, 0.6);
uniform vec3 sun_dir = vec3(0.0, 0.6, 0.8);
uniform float energy = 1.7;
uniform float max_alpha = 1.0;
uniform float scale = 0.9;
uniform vec2 wind = vec2(0.0);
uniform float warp = 0.25;
uniform float brightness = 1.0;
uniform float far_opacity = 0.6;
uniform float depth_shade = 0.25;
uniform float sun_glow = 0.35;
uniform vec3 glow_color = vec3(1.0, 0.7, 0.4);

vec4 cloud_layer(vec2 p, float s, vec2 drift, float warp_amount) {
	vec2 q = p * s;
	vec2 w = texture(clouds, q * 0.23 + drift * 0.4).rg - 0.5;
	q += w * warp_amount * 1.4 + drift;
	return texture(clouds, q);
}

void fragment() {
	vec3 dir = sky_dir(SCREEN_UV, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
	float elev = asin(clamp(dir.y, -1.0, 1.0));
	// Background: the original band (horizon to its top edge), then the biome's background color.
	float az = atan(dir.x, dir.z) / TAU;
	float u = 1.0 - abs(fract(az * 8.0) * 2.0 - 1.0);
	float v = clamp(1.0 - elev / 0.38, 0.0, 1.0);
	vec4 b = texture(band, vec2(u, v));
	vec3 sky_col = mix(background, min(b.rgb * energy, vec3(1.0)), b.a * (1.0 - smoothstep(0.3, 0.5, elev)));
	// Cloud planes: far clouds bunch toward the horizon.
	float fade = smoothstep(0.0, 0.2, dir.y);
	vec2 p = dir.xz / (dir.y * 0.8 + 0.16);
	vec4 far_c = cloud_layer(p, scale * 0.6, wind * TIME * 0.5 + vec2(0.37, 0.11), warp);
	vec4 near_c = cloud_layer(p, scale, wind * TIME, warp);
	vec3 col = sky_col;
	float far_a = clamp(far_c.a * max_alpha * far_opacity * fade, 0.0, 1.0);
	col = mix(col, min(far_c.rgb * energy * brightness, vec3(1.0)) * 0.9, far_a);
	// Near layer: darker where the far layer sits behind it, as if it were lower and thicker.
	float near_a = clamp(near_c.a * max_alpha * fade * 0.8, 0.0, 1.0);
	vec3 near_col = min(near_c.rgb * energy * brightness, vec3(1.0));
	near_col *= 1.0 - depth_shade * far_a;
	col = mix(col, near_col, near_a);
	// Warm glow toward the sun, over everything.
	float s = max(dot(dir, normalize(sun_dir)), 0.0);
	col += glow_color * sun_glow * (pow(s, 6.0) * 0.5 + pow(s, 40.0));
	ALBEDO = col;
	ALPHA = smoothstep(-0.02, 0.03, dir.y + 0.0);
}
