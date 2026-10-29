// A PS1 look over the whole 3D view: the picture drops to a low resolution (sharp, nearest pixels), each channel to a few
// levels (the console's 15 bit color is 32 levels), and a 4x4 ordered (Bayer) dither hides the bands between levels. Screen
// space only: it does not wobble vertices or warp textures (that needs the materials). Lives on PsxScreen's ColorRect.
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_nearest;
/** Lines of the low resolution picture (the PS1 drew 240). The width follows the window's aspect. */
uniform float virtual_height : hint_range(120.0, 1080.0, 1.0) = 240.0;
/** Levels per color channel (32 = the PS1's 15 bit color; lower is cruder). */
uniform float color_levels : hint_range(2.0, 256.0, 1.0) = 32.0;
/** How much the ordered dither moves a pixel between two levels (0 = plain bands). */
uniform float dither_amount : hint_range(0.0, 2.0, 0.05) = 1.0;
/** Mixes the effect with the untouched picture (0 = off, 1 = full). */
uniform float strength : hint_range(0.0, 1.0, 0.05) = 1.0;

// The 4x4 Bayer matrix, as thresholds from 0 to 15.
const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void fragment() {
	vec2 screen_px = 1.0 / SCREEN_PIXEL_SIZE;
	float block = max(screen_px.y / virtual_height, 1.0);
	vec2 cell = floor(SCREEN_UV * screen_px / block);
	vec2 uv = (cell + 0.5) * block / screen_px;
	vec3 color = texture(screen, uv).rgb;
	ivec2 b = ivec2(mod(cell, 4.0));
	float threshold = (BAYER[b.y * 4 + b.x] + 0.5) / 16.0 - 0.5;
	float steps = color_levels - 1.0;
	vec3 crushed = floor(color * steps + threshold * dither_amount + 0.5) / steps;
	COLOR = vec4(mix(texture(screen, SCREEN_UV).rgb, clamp(crushed, 0.0, 1.0), strength), 1.0);
}
