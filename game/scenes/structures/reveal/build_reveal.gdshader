shader_type spatial;
// A tower that is still rising (BuildReveal): below `line_y` it is drawn whole, above `line_y + edge_width_m` it is not drawn
// at all, and in between it dissolves with the noise, with a glowing edge. Opaque (discard), so it sorts and casts shadows
// like the tower itself; works in every renderer. The surface look (albedo, roughness, alpha scissor) is copied from the
// tower's own StandardMaterial3D, so the finished tower looks the same once BuildReveal gives its materials back.
// Ref: buildingSummon.d:155 and 465-470 (clip plane rising from the base with a 2 m fading band), state.d:15231 and 15253.
render_mode cull_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float roughness = 0.85;
// 0 = opaque surface; above 0 = alpha scissor threshold of the source material.
uniform float alpha_scissor = 0.0;

uniform sampler2D noise_tex : hint_default_white, repeat_enable, filter_linear;
// Noise cells per metre.
uniform float noise_scale = 0.25;
uniform vec4 edge_color : source_color = vec4(0.45, 0.7, 1.0, 1.0);
uniform float edge_energy = 1.5;
// Height of the dissolving band, in metres.
uniform float edge_width_m = 2.0;
// Fraction of the noise range that glows next to the cut.
uniform float glow_fraction = 0.2;
// World height where the band starts: everything below is whole.
uniform float line_y = 0.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec4 tex = texture(albedo_tex, UV) * albedo_color;
	if (alpha_scissor > 0.0 && tex.a < alpha_scissor) {
		discard;
	}
	float band = (world_pos.y - line_y) / max(edge_width_m, 0.001);
	// Two projections so no wall gets a stretched noise; their mean bunches around 0.5, so it is stretched back to 0..1.
	float n = 0.5 * (texture(noise_tex, world_pos.xy * noise_scale).r + texture(noise_tex, world_pos.zy * noise_scale).r);
	n = smoothstep(0.3, 0.7, n);
	if (n < band) {
		discard;
	}
	float glow = 1.0 - smoothstep(0.0, max(glow_fraction, 0.001), n - band);
	glow *= step(0.0, band);
	ALBEDO = mix(tex.rgb, edge_color.rgb, glow);
	ROUGHNESS = roughness;
	EMISSION = edge_color.rgb * edge_energy * glow;
}
