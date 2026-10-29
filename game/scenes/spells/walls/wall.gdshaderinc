// What the wall shaders share: they bend the unit strip (assets/custom/walls/wall_strip.obj: x -0.5 to 0.5 along the wall, y 0 to 1 up the
// gable, z -0.5 to 0.5 across it) into the wall: stretched to its length and thickness, as tall as it stands now (its ends sloping down
// over 5 m, its height swaying by a tenth), laid over the land, and with the atlas of flames or faces mirrored along it frame by frame.
// WallLook feeds the uniforms.
uniform float left = 0.0;
uniform float right = 0.0;
// The height of the wall now, in metres.
uniform float top = 0.0;
uniform float thickness = 5.0;
// Metres the strip spans along the wall.
uniform float reach = 110.0;
uniform float wave_amount = 0.1;
uniform float wave_per_m = 0.125;
// Sways per second (Firewall 1; Wailing Wall a quarter as fast).
uniform float wave_speed = 1.0;
// How far the base sinks under the land, so a slope does not show a gap.
uniform float skirt_m = 1.5;
// Metres of wall one picture of the atlas covers (every other one is mirrored).
uniform float tile_m = 7.0;
uniform ivec2 grid = ivec2(4, 4);
uniform float frame_s = 0.0667;
// Land height along the wall (R, 129 texels) over the wall's own origin.
uniform sampler2D ground : filter_linear, repeat_disable;

varying float along_m;

// The caller sets `along_m` (a varying cannot be assigned in a helper) to vertex.x * reach and passes it as `along`.
void wall_vertex(inout vec3 vertex, float along) {
	float land = texture(ground, vec2(vertex.x + 0.5, 0.5)).r;
	float slope = clamp(min(0.2 * (along - left), 0.2 * (right - along)), 0.0, 1.0);
	float sway = 1.0 + wave_amount * sin(TAU * (wave_per_m * along - TIME * wave_speed));
	float p = vertex.y;
	vertex = vec3(along, land - skirt_m * (1.0 - p) + p * top * slope * sway, vertex.z * thickness);
}

// The atlas cell of now, the picture mirrored on every other tile of the wall.
vec2 wall_uv(vec2 uv) {
	float tile = along_m / tile_m;
	float across = fract(tile);
	across = mod(floor(tile), 2.0) < 1.0 ? across : 1.0 - across;
	int cells = grid.x * grid.y;
	int cell = int(floor(TIME / frame_s)) % cells;
	vec2 size = 1.0 / vec2(grid);
	vec2 origin = vec2(float(cell % grid.x), float(cell / grid.x)) * size;
	vec2 inside = clamp(vec2(across, uv.y), vec2(0.01), vec2(0.99));
	return origin + inside * size;
}
