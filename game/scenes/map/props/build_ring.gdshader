shader_type spatial;
// The ring a structure spell draws around a manafount (BuildRing). Unshaded, drawn over the ground and the hills: it is a
// preview, not part of the world. The mesh is a 2 x 2 PlaneMesh scaled to the radius, so the line width is measured in
// metres from the node's scale. Colour and width are per instance (set_instance_shader_parameter): one material for all.
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled, fog_disabled;

instance uniform vec4 ring_color : source_color = vec4(0.35, 0.95, 0.45, 0.85);
instance uniform float width_m = 0.8;

varying vec2 local_xz;

void vertex() {
	local_xz = VERTEX.xz;
}

void fragment() {
	float d = length(local_xz);
	float radius_m = max(length(MODEL_MATRIX[0].xyz), 0.001);
	float inner = 1.0 - clamp(width_m / radius_m, 0.0, 1.0);
	float aa = max(fwidth(d), 0.0001);
	float band = smoothstep(inner - aa, inner, d) * (1.0 - smoothstep(1.0 - aa, 1.0, d));
	ALBEDO = ring_color.rgb;
	ALPHA = ring_color.a * band;
}
