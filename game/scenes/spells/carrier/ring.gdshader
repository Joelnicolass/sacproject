shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

// The ring of Blind Rage's blast on a flat quad of diameter 2: only the band between `inner` and 1 of the radius is drawn, wearing a cell of the
// 4 x 4 atlas (per2) that changes with `progress` (one pass over the 16 cells in a life). The picture is mirrored along the circle, as the
// original's ring. Additive, bright (energy 10).

uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform vec2 cells = vec2(4.0, 4.0);
uniform float energy = 10.0;
uniform float inner = 0.6;
// How many mirrored repeats of the picture go round the circle.
uniform float repeats = 16.0;
instance uniform float progress = 0.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0 || r < inner) {
		discard;
	}
	float turns = atan(p.y, p.x) / 6.2831853 + 0.5;
	float wave = abs(fract(turns * repeats * 0.5) * 2.0 - 1.0);
	float index = min(floor(progress * cells.x * cells.y), cells.x * cells.y - 1.0);
	vec2 cell = vec2(mod(index, cells.x), floor(index / cells.x));
	vec2 inside = vec2(mix(0.015, 0.985, wave), mix(0.015, 0.985, (r - inner) / (1.0 - inner)));
	vec4 tex = texture(atlas, (inside + cell) / cells);
	ALBEDO = tex.rgb * energy;
	ALPHA = 1.0;
}
