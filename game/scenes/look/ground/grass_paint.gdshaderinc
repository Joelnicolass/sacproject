// Grass paint: where grass grows, the ground takes GrassKit's grass colour under the drawn blades
// (so the ground between them reads as grass) and the colour the far grass fades to beyond them,
// with no edge; the wind's gusts cross it as pale bands. Included by the ground shader
// (ground.gdshader). `GroundMaterial.set_grass_paint` fills the uniforms; amount 0 = no paint. The
// colours, how much and the wind are GrassKit's (grass_ground.gdshaderinc, the god's GrassLook).

#include "res://addons/grass_kit/field/grass_ground.gdshaderinc"

uniform float grass_paint_amount = 0.0;
// Share of the paint per role (x..w = open, earth, rock, path): open ground all of it, earth and path partly, rock none.
uniform vec4 grass_paint_roles = vec4(1.0, 0.3, 0.0, 0.3);
// Slope (deg) where the paint starts to fade and where it is gone: the valley floor is painted, its
// hills turn gradually into the soil's own color instead of a hard green/brown cut.
uniform vec2 grass_paint_slope = vec2(10.0, 36.0);
// How strong the wind's pale bands are on the painted ground.
uniform float grass_paint_waves = 0.0;
// How much darker the ground gets under the drawn blades (their shade on it); it fades out with the
// blades, so the far grass meets the ground with no edge.
uniform float grass_paint_shade = 0.0;

// `w` = the role weights after the height blend (sum 1).
float grass_paint_k(vec4 w, float slope_deg) {
	float by_slope = 1.0 - smoothstep(grass_paint_slope.x, grass_paint_slope.y, slope_deg);
	return clamp(grass_paint_amount * dot(w, grass_paint_roles) * by_slope, 0.0, 1.0);
}

// Textured ground: GrassKit's colour where grass grows, and the wind bands.
vec3 grass_paint_textured(vec3 alb, vec4 w, vec2 xz, float slope_deg) {
	float k = grass_paint_k(w, slope_deg);
	if (k <= 0.0) {
		return alb;
	}
	float near = 1.0 - smoothstep(grasskit_field.w, grasskit_field.z, distance(xz, grasskit_field.xy));
	float shade = 1.0 - grass_paint_shade * k * near;
	return grasskit_ground_color(alb, xz, k) * shade * (1.0 + grasskit_ground_bands(xz, grass_paint_waves * k));
}
