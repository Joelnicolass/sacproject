// The ground moved after the map was loaded (a spell raised it, dug it or took vertices away): the ground shaders move
// the vertices of the mesh, which is never rebuilt. TerrainDeformTexture fills the global `terrain_deform_map`: one texel
// per 10 m vertex of the map, R = how high the vertex is raised, G = 1 when the vertex was taken away. Until something
// moves, `terrain_deform_on` is 0 and the ground costs nothing extra.
//
// In vertex():
//   deform_hole = 0.0;
//   if (terrain_deform_on > 0.5) { vec2 d = deform_at(VERTEX.xz); NORMAL = deform_normal(NORMAL, VERTEX.xz); VERTEX.y += d.x; deform_hole = d.y; }
// In fragment(): if (deform_hole > 0.0001) { discard; }

global uniform sampler2D terrain_deform_map;
global uniform float terrain_deform_on;
// 0 on a piece of ground that carries its own heights and falls (FallingChunk): it must not take the shift of the map again.
instance uniform float deform_follow = 1.0;

// The vertices of the map lie on a 10 m lattice.
const float DEFORM_CELL = 10.0;

// Passed to the fragment: above 0 in every triangle that touches a vertex taken away.
varying float deform_hole;

// x: how far the vertex at the ground point xz is raised; y: 1 when it was taken away.
vec2 deform_at(vec2 xz) {
	ivec2 lattice = ivec2(clamp(round(xz / DEFORM_CELL), vec2(0.0), vec2(255.0)));
	return texelFetch(terrain_deform_map, lattice, 0).rg;
}

// The normal of the moved ground: the slope of the shift (central differences over two lattice steps) tilts it.
vec3 deform_normal(vec3 normal, vec2 xz) {
	float slope_x = (deform_at(xz + vec2(DEFORM_CELL, 0.0)).x - deform_at(xz - vec2(DEFORM_CELL, 0.0)).x) / (2.0 * DEFORM_CELL);
	float slope_z = (deform_at(xz + vec2(0.0, DEFORM_CELL)).x - deform_at(xz - vec2(0.0, DEFORM_CELL)).x) / (2.0 * DEFORM_CELL);
	return normalize(normal - vec3(slope_x, 0.0, slope_z) * normal.y);
}
