// Stars of the night sky, fixed to the sky: the view direction (already turned with the bands) is cut into a grid of
// cells and some cells hold one star at a point of their own. Nothing reads TIME, so a star never crawls or blinks
// from one frame to the next; it only turns with the bands.
//
// Source: no catalog shader fitted. Godot Shaders' "Starfield" (starfield-2, by cob, CC0) is a 2D volumetric field
// animated with TIME (its stars would crawl over a sky), so this is the plain cell-hash method; the float hash is the
// one in Inigo Quilez's 3D value-noise shaders on Shadertoy (MIT).

// Cells across a whole turn of the sky (about 0.3 degrees each): a star is a little over a pixel at 1080p.
const float SKY_STAR_CELLS = 180.0;

float sky_star_hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

// `density` 0..1 = share of the cells with a star (times 0.15); `brightness` = the brightest star's light.
vec3 sky_stars(vec3 dir, float density, float brightness) {
	vec3 p = dir * SKY_STAR_CELLS;
	vec3 cell = floor(p);
	float pick = sky_star_hash(cell);
	if (pick > density * 0.15) {
		return vec3(0.0);
	}
	vec3 jitter = vec3(sky_star_hash(cell + 11.0), sky_star_hash(cell + 23.0), sky_star_hash(cell + 37.0));
	vec3 star = cell + 0.2 + 0.6 * jitter;
	float glow = smoothstep(0.3, 0.05, length(p - star));
	float size = 0.35 + 0.65 * sky_star_hash(cell + 51.0);
	vec3 tint = mix(vec3(0.78, 0.85, 1.0), vec3(1.0, 0.92, 0.78), sky_star_hash(cell + 67.0));
	// Only above the horizon, fading in over the first degrees.
	return tint * glow * size * brightness * smoothstep(0.02, 0.2, dir.y);
}
