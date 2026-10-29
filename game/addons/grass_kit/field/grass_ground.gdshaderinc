// For the game's ground shader, so the ground and the grass meet without a seam. Include it with
//   #include "res://addons/grass_kit/field/grass_ground.gdshaderinc"
// GrassKit's far grass fades to a colour between the ground's and the grass's; this gives the
// ground that same colour where the drawn grass ends and beyond it, so the edge never shows, and
// the grass's colour under the drawn blades. It also says where the ground's painted map grows
// grass, so the ground can show its own soil on a painted path. The wind's gusts can cross the
// ground too, as pale bands. The values are global uniforms a GrassField3D writes.

#include "res://addons/grass_kit/field/grass_wind.gdshaderinc"

// x, y: the field's centre (x, z). z: its radius. w: where its blades start fading to the colour.
global uniform vec4 grasskit_field;
// rgb: the colour the grass reads as from afar (linear). a: how much of it the far grass keeps
// (GrassLook.far_grass).
global uniform vec4 grasskit_grass;
// x: how much the ground under the drawn blades takes the grass's colour (GrassLook.under_grass).
// y: how much of its own light and dark it keeps (under_relief). z: the brightness that counts as
// neither (the look's ground_color, linear).
global uniform vec4 grasskit_under;
// Where grass grows (red), the ground's painted density map, over grasskit_area (x, z, width,
// depth).
global uniform sampler2D grasskit_density;
global uniform vec4 grasskit_area;

// Where the ground's painted map grows grass at `xz` (1 where nothing is painted, 0 outside the
// grass's ground): what to pass as `grass_here`, and where to show the ground's own soil.
float grasskit_painted_grass(vec2 xz) {
	vec2 uv = (xz - grasskit_area.xy) / grasskit_area.zw;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return 0.0;
	}
	return texture(grasskit_density, uv).r;
}

// The ground's colour `ground_rgb` (linear) at `xz`, where grass grows by `grass_here` (0..1, from
// the game's own map). Under the drawn blades it takes the grass's colour (so the ground between
// them reads as grass); from where the blades fade, it goes to the colour the far grass fades to.
vec3 grasskit_ground_color(vec3 ground_rgb, vec2 xz, float grass_here) {
	float d = distance(xz, grasskit_field.xy);
	float far = smoothstep(grasskit_field.w, grasskit_field.z, d);
	float light = dot(ground_rgb, vec3(0.2126, 0.7152, 0.0722)) / max(grasskit_under.z, 0.001);
	vec3 under = grasskit_grass.rgb * mix(1.0, clamp(light, 0.3, 2.0), grasskit_under.y);
	vec3 near = mix(ground_rgb, under, grasskit_under.x);
	vec3 meet = mix(ground_rgb, grasskit_grass.rgb, grasskit_grass.a);
	return mix(ground_rgb, mix(near, meet, far), clamp(grass_here, 0.0, 1.0));
}

// Pale bands where the wind's gusts cross the ground (bigger than on the grass, as from afar):
// multiply the ground's colour by 1.0 + this.
float grasskit_ground_bands(vec2 xz, float amount) {
	return grasskit_wind_gust(xz * 0.5) * grasskit_wind.z * amount;
}
