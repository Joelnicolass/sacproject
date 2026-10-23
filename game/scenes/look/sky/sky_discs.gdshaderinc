// Sun and moon discs plus the sun's halo, added over the sky (the old sky_discs.gdshader pass).
// `sun_dir` / `moon_dir` point toward the body. A disc is a smoothstep between two angles:
// radius and radius * edge_softness (1.25 for the sun, 1.12 for the moon as in SkyLook).

vec3 sky_disc_add(vec3 color, vec3 dir, vec3 sun_dir, vec3 sun_rgb, float sun_radius_deg, vec3 halo_rgb, float halo_power,
		vec3 moon_dir, vec3 moon_rgb, float moon_radius_deg) {
	float s = dot(dir, normalize(sun_dir));
	float sun_r = radians(sun_radius_deg);
	color += sun_rgb * smoothstep(cos(sun_r * 1.25), cos(sun_r), s);
	color += halo_rgb * pow(max(s, 0.0), halo_power);
	float m = dot(dir, normalize(moon_dir));
	float moon_r = radians(moon_radius_deg);
	color += moon_rgb * smoothstep(cos(moon_r * 1.12), cos(moon_r), m);
	return color;
}

// Direction toward a body from a compass azimuth (0 = +Z, 90 = +X) and an elevation, in degrees.
vec3 sky_direction_from_angles(float azimuth_deg, float elevation_deg) {
	float az = radians(azimuth_deg);
	float el = radians(elevation_deg);
	return vec3(sin(az) * cos(el), sin(el), cos(az) * cos(el));
}
