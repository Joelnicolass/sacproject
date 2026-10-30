// GrassKit's wind, for any shader: the grass reads it, and so can the ground (bands of light
// crossing it), trees' leaves or particles, all with the same gusts. Include it with
//   #include "res://addons/grass_kit/field/grass_wind.gdshaderinc"
// The values are global uniforms a GrassWind writes every frame (a GrassField3D ticks it).

// x, y: where the wind blows to on the ground (x, z), normalised. z: its strength (0 calm, 1 a
// storm). w: the size of a band of wind (m).
global uniform vec4 grasskit_wind;
// How far the wind has carried its pattern so far (m): it moves on its own, with no jump when the
// direction or the speed changes.
global uniform vec2 grasskit_wind_offset;
// The wind's clock (s), frozen with the GrassWind's time_override.
global uniform float grasskit_wind_time;
// A seamless noise: the shape of the bands.
global uniform sampler2D grasskit_wind_noise;

// The wind's wave at a ground point (x, z), 0..1: bands of wind crossing the ground. The noise is
// read twice, at unrelated sizes and turns, so its tile never shows.
float grasskit_wind_wave(vec2 xz) {
	vec2 p = xz - grasskit_wind_offset;
	float size = max(grasskit_wind.w, 0.01);
	float a = textureLod(grasskit_wind_noise, fract(p / size), 0.0).r;
	vec2 turned = vec2(p.x * 0.8 - p.y * 0.6, p.x * 0.6 + p.y * 0.8) / (size * 2.37);
	float b = textureLod(grasskit_wind_noise, fract(turned + 0.37), 0.0).r;
	return clamp(a * 0.65 + b * 0.35, 0.0, 1.0);
}

// The gust at a ground point, 0..1: the wave's crests.
float grasskit_wind_gust(vec2 xz) {
	return smoothstep(0.45, 0.8, grasskit_wind_wave(xz));
}

// The wind's push on the ground plane at a point (x, z): a steady breeze plus the gusts, times the
// strength.
vec2 grasskit_wind_push(vec2 xz) {
	return grasskit_wind.xy * grasskit_wind.z * (0.35 + grasskit_wind_gust(xz) * 1.1);
}
