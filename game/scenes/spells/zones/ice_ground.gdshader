shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

// The ice that Frozen Ground lays on the land: a ring of ground (IcePatch builds it, 32 sides by 32 rings, each vertex on the land under it)
// wearing the ice texture icec, seen through alpha. The part of the ring that shows is a band: from `inner` (what already broke, from the
// centre out) to `radius` (how far the ice has grown). Both are set per instance by IcePatch.

uniform sampler2D ice : source_color, filter_linear_mipmap, repeat_enable;
uniform float energy = 1.2;
uniform float opacity = 0.7;
// Soft edge of the band, in metres.
uniform float edge_m = 0.8;
instance uniform float radius = 0.0;
instance uniform float inner = 0.0;

varying float distance_m;

void vertex() {
	distance_m = length(VERTEX.xz);
}

void fragment() {
	float outer_fade = 1.0 - smoothstep(radius - edge_m, radius, distance_m);
	float inner_fade = smoothstep(inner, inner + edge_m, distance_m);
	ALBEDO = texture(ice, UV).rgb * energy;
	ALPHA = clamp(opacity * outer_fade * inner_fade, 0.0, 1.0);
}
