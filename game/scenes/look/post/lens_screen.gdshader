// A camera lens over the whole 3D view: a vignette (the borders go darker, so the eye stays in the middle) and a chromatic
// aberration (red and blue split apart towards the borders, as a cheap lens does; the middle stays clean). Screen space
// only. Lives on LensScreen's ColorRect; each part is off at 0.
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear;
/** How dark the corners get (0 = no vignette, 1 = black corners). */
uniform float vignette_strength : hint_range(0.0, 1.0, 0.01) = 0.35;
/** Where the darkening starts, from the middle (0) to a corner (1). */
uniform float vignette_start : hint_range(0.0, 1.0, 0.01) = 0.45;
/** The color the borders go to. */
uniform vec4 vignette_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
/** How far red and blue split at a corner, in pixels of a 1080 line picture (0 = no aberration). */
uniform float aberration_px : hint_range(0.0, 20.0, 0.1) = 2.5;
/** How fast the split grows towards the borders: higher keeps more of the middle clean. */
uniform float aberration_falloff : hint_range(0.5, 4.0, 0.05) = 2.0;

void fragment() {
	vec2 aspect = vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	vec2 from_middle = SCREEN_UV - 0.5;
	// 0 in the middle, 1 at a corner, the same on any window shape.
	float edge = length(from_middle * aspect) / length(0.5 * aspect);
	vec2 split = vec2(0.0);
	if (aberration_px > 0.0 && edge > 0.0) {
		float lines = 1.0 / SCREEN_PIXEL_SIZE.y;
		split = normalize(from_middle) * aberration_px * (lines / 1080.0) * pow(edge, aberration_falloff) * SCREEN_PIXEL_SIZE;
	}
	vec3 color = vec3(
		texture(screen, SCREEN_UV - split).r,
		texture(screen, SCREEN_UV).g,
		texture(screen, SCREEN_UV + split).b
	);
	float shade = smoothstep(vignette_start, 1.0, edge) * vignette_strength;
	COLOR = vec4(mix(color, vignette_color.rgb, shade), 1.0);
}
