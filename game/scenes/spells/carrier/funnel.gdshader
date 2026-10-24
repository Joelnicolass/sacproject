shader_type spatial;
// The Soul Wind's whirlwind: streaks of wind that climb the funnel while it turns, drawn over the world without shading or lighting.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

uniform sampler2D streaks : source_color, filter_linear_mipmap, repeat_enable;
// Brightness of the streaks (the original shades them at 5; under the filmic tonemap that burns them white).
uniform float energy = 1.6;
// How much of the streaks shows through: the original draws the funnel 75 % opaque.
uniform float opacity : hint_range(0.0, 1.0) = 0.75;
// Texture repeats the wind climbs per second (one every 32 ticks).
uniform float climb_per_s = 1.875;
// Seconds the funnel takes to turn once around its axis.
uniform float turn_s = 4.0;

void vertex() {
	float angle = TIME * TAU / turn_s;
	float s = sin(angle);
	float c = cos(angle);
	VERTEX = vec3(c * VERTEX.x + s * VERTEX.z, VERTEX.y, -s * VERTEX.x + c * VERTEX.z);
}

void fragment() {
	vec4 texel = texture(streaks, vec2(UV.x, UV.y + TIME * climb_per_s));
	ALBEDO = texel.rgb * energy;
	ALPHA = opacity * texel.a;
}
