shader_type spatial;
// What is seen under the island through the void and through the pits: the god's picture under the world (undr.png)
// on a wide plane far below the map, unlit and out of the fog, turning slowly with the sky. Every number is a uniform.
// Ref: sacobject.d:1101-1107 (a 10240 m quad, texture once over it), renderer.d:1203-1223 (unlit, energy 1.7, turns with
// the sky: one turn every 512 s).
render_mode unshaded, fog_disabled, shadows_disabled, cull_disabled;

// The god's picture under the world. Laid once over the whole plane.
uniform sampler2D picture : source_color, filter_linear_mipmap, repeat_disable, hint_default_black;
// Brightness multiplier of the picture (the original uses 1.7), clamped to white.
uniform float energy : hint_range(0.0, 4.0, 0.01) = 1.7;
// Seconds for a full turn (the sky's bands use the same, 512).
uniform float rotation_period_s : hint_range(1.0, 2048.0, 1.0) = 512.0;
// -1 = the engine's TIME. 0 or more freezes the turn at that second (captures and comparisons).
uniform float time_override_s : hint_range(-1.0, 4096.0, 0.01) = -1.0;

void fragment() {
	float t = time_override_s >= 0.0 ? time_override_s : TIME;
	float angle = TAU * t / rotation_period_s;
	vec2 centred = UV - 0.5;
	// The picture turns from +x toward +z, as the sky's bands do (they sample azimuth - spin).
	vec2 turned = vec2(centred.x * cos(angle) + centred.y * sin(angle), -centred.x * sin(angle) + centred.y * cos(angle));
	ALBEDO = min(texture(picture, turned + 0.5).rgb * energy, vec3(1.0));
}
