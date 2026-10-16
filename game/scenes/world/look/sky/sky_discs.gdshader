shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

#include "res://scenes/world/look/sky/sky_view.gdshaderinc"

uniform vec3 sun_dir = vec3(0.0, 0.6, 0.8);
uniform vec3 sun_color = vec3(0.0);
uniform vec2 sun_cos = vec2(0.999, 0.998);
uniform vec3 halo_color = vec3(0.0);
uniform float halo_power = 24.0;
uniform vec3 moon_dir = vec3(0.0, 0.6, -0.8);
uniform vec3 moon_color = vec3(0.0);
uniform vec2 moon_cos = vec2(0.998, 0.997);

void fragment() {
	if (sun_color + halo_color + moon_color == vec3(0.0)) {
		discard;
	}
	vec3 dir = sky_dir(SCREEN_UV, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
	float s = dot(dir, normalize(sun_dir));
	vec3 col = sun_color * smoothstep(sun_cos.y, sun_cos.x, s);
	col += halo_color * pow(max(s, 0.0), halo_power);
	float m = dot(dir, normalize(moon_dir));
	col += moon_color * smoothstep(moon_cos.y, moon_cos.x, m);
	ALBEDO = col;
}
