shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded, depth_draw_never, shadows_disabled;

// F126 (030o-a): Life Shield dome. sacengine draws it additive with an animated texture (ent1.TXTR); over snow additive
// washes out, so the silhouette is marked with a fresnel rim (MIX). The dome is a unit sphere scaled to the body's box.
uniform vec3 body_color : source_color = vec3(0.2, 0.5, 1.0);
uniform vec3 rim_color : source_color = vec3(0.1, 0.35, 1.0);
uniform float body_alpha : hint_range(0.0, 1.0) = 0.38;
uniform float rim_alpha : hint_range(0.0, 1.0) = 0.9;
uniform float rim_power : hint_range(0.5, 6.0) = 1.5;

void fragment() {
	float rim = pow(1.0 - clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0), rim_power);
	ALBEDO = mix(body_color, rim_color, rim);
	ALPHA = clamp(mix(body_alpha, rim_alpha, rim), 0.0, 1.0);
}
