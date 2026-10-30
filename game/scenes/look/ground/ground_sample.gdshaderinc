// How one kind of ground (role) is read at a point: one variant of its albedo sheet per tile (picked by a hash of the tile, kept
// half a pixel inside its own cell of the sheet so the filter never reads the variant next to it), its normal and ORM maps when
// the preset allows them, a three-sided projection on cliffs, two offset taps against repetition for a one-picture albedo, and
// the grey grain of the role over it. `GroundTextures` packs the four roles into one Texture2DArray per kind of map.
// Stochastic taps after Inigo Quilez, "Texture Repetition" (iquilezles.org/articles/texturerepetition), MIT; only the idea of
// the two offset taps is used, the code is rewritten here.

uniform sampler2DArray role_albedo : filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
#ifndef GROUND_LEAN
uniform sampler2DArray role_normal : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray role_orm : filter_linear_mipmap, repeat_enable, hint_default_white;
uniform sampler2DArray role_detail : filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
#endif
// x: tile_m, y: variants per side, z: grain strength, w: grain repeat
uniform vec4 role_layout[4];
// rgb: tint, a: roughness without an ORM map
uniform vec4 role_tint[4];
// x: normal strength, y: has a normal map, z: has an ORM map, w: triplanar
uniform vec4 role_relief[4];
uniform vec4 role_stochastic = vec4(0.0);
uniform bool use_maps = true;
uniform bool use_triplanar = true;
uniform bool use_stochastic = false;

struct RoleTap {
	vec3 albedo;
	vec3 normal;   // world space, unnormalized
	vec3 orm;      // occlusion, roughness, height
};

float role_hash(vec2 tile, float salt) {
	return fract(52.9829189 * fract(dot(tile + salt * 17.0, vec2(0.06711056, 0.00583715))));
}

// Where the role's maps are read: (u, v) in the sheet, and the derivatives of a continuous coordinate for the mip level.
vec2 role_uv(int i, vec2 p, float pixels) {
	float side = role_layout[i].y;
	if (side < 1.5) {
		return p;
	}
	vec2 tile = floor(p);
	float pick = floor(role_hash(tile, float(i)) * side * side);
	vec2 cell = vec2(mod(pick, side), floor(pick / side));
	float margin = 0.5 * side / pixels;
	return (cell + clamp(p - tile, vec2(margin), vec2(1.0 - margin))) / side;
}

vec3 role_decode_normal(vec3 encoded, float strength) {
	vec3 n = encoded * 2.0 - 1.0;
	n.xy *= strength;
	n.z = sqrt(max(1.0 - dot(n.xy, n.xy), 0.0));
	return n;
}

// One projection of role i: plane coordinate `q` in metres, its screen derivatives, and the world normal `g` as seen in that plane.
RoleTap role_plane(int i, vec2 q, vec2 qdx, vec2 qdy, float pixels) {
	float tile_m = role_layout[i].x;
	float side = role_layout[i].y;
	vec2 p = q / tile_m;
	vec2 uv = role_uv(i, p, pixels);
	vec2 dx = qdx / tile_m / side;
	vec2 dy = qdy / tile_m / side;
	if (use_stochastic && role_stochastic[i] > 0.5 && side < 1.5) {
		float k = textureLod(ground_noise, p * 0.07, 0.0).b * 8.0;
		uv += sin(vec2(3.0, 7.0) * floor(k));
	}
	RoleTap t;
	t.albedo = textureGrad(role_albedo, vec3(uv, float(i)), dx, dy).rgb;
	t.normal = vec3(0.5, 0.5, 1.0);
	t.orm = vec3(1.0, role_tint[i].a, dot(t.albedo, vec3(0.3, 0.59, 0.11)));
#ifndef GROUND_LEAN
	if (use_maps && role_relief[i].y > 0.5) {
		t.normal = textureGrad(role_normal, vec3(uv, float(i)), dx, dy).rgb;
	}
	if (use_maps && role_relief[i].z > 0.5) {
		t.orm = textureGrad(role_orm, vec3(uv, float(i)), dx, dy).rgb;
	}
	float strength = role_layout[i].z;
	if (strength > 0.0) {
		vec2 duv = (p - (side < 1.5 ? vec2(0.0) : floor(p))) * role_layout[i].w;
		float grain = textureGrad(role_detail, vec3(duv, float(i)), qdx / tile_m * role_layout[i].w, qdy / tile_m * role_layout[i].w).r;
		float mean = textureLod(role_detail, vec3(0.5, 0.5, float(i)), 12.0).r;
		t.albedo *= mix(1.0, (1.0 + grain) / (1.0 + mean), strength);
	}
#endif
	t.albedo *= role_tint[i].rgb;
	return t;
}

// Role i at map position `pos`, world normal `g`; `dpx`/`dpy` are the screen derivatives of `pos` (taken in uniform control flow).
RoleTap role_sample(int i, vec3 pos, vec3 g, vec3 dpx, vec3 dpy) {
	float pixels = float(textureSize(role_albedo, 0).x);
	float strength = role_relief[i].x;
	if (!(use_triplanar && role_relief[i].w > 0.5)) {
		RoleTap t = role_plane(i, pos.xz, dpx.xz, dpy.xz, pixels);
		vec3 n = role_decode_normal(t.normal, strength);
		t.normal = vec3(n.x + g.x, abs(n.z) * g.y, n.y + g.z);
		return t;
	}
	vec3 b = pow(abs(g), vec3(4.0));
	b /= (b.x + b.y + b.z + 0.0001);
	RoleTap ty = role_plane(i, pos.xz, dpx.xz, dpy.xz, pixels);
	RoleTap tx = role_plane(i, pos.zy, dpx.zy, dpy.zy, pixels);
	RoleTap tz = role_plane(i, pos.xy, dpx.xy, dpy.xy, pixels);
	vec3 nx = role_decode_normal(tx.normal, strength);
	vec3 ny = role_decode_normal(ty.normal, strength);
	vec3 nz = role_decode_normal(tz.normal, strength);
	nx = vec3(nx.xy + g.zy, abs(nx.z) * g.x);
	ny = vec3(ny.xy + g.xz, abs(ny.z) * g.y);
	nz = vec3(nz.xy + g.xy, abs(nz.z) * g.z);
	RoleTap t;
	t.albedo = ty.albedo * b.y + tx.albedo * b.x + tz.albedo * b.z;
	t.orm = ty.orm * b.y + tx.orm * b.x + tz.orm * b.z;
	t.normal = nx.zyx * b.x + ny.xzy * b.y + nz.xyz * b.z;
	return t;
}
