shader_type spatial;
// Two sided: the map has faces seen from behind (cliffs, hole edges, the void walls).
render_mode cull_disabled;

// Splat, zone rules and macro drift shared with the grass (grass.gdshader).
#include "res://scenes/look/ground/ground_common.gdshaderinc"
// The ground can move after the map loaded (RFC-057): the vertices are moved here, the mesh is never rebuilt.
#include "res://scenes/look/ground/terrain_deform.gdshaderinc"

// Ground of a biome: up to four PBR layers blended by the original map's zones (splat), slope,
// altitude and height maps. Maps by map coordinates (the mesh stores them in local vertex space,
// so the editor preview shift does not move the texture). Rock-like layers can go triplanar.
// Anti-repetition: macro variation of color and roughness, and optional two-tap offsets after
// Inigo Quilez, "Texture Repetition" (iquilezles.org/articles/texturerepetition).
//
// The MIT License
// Copyright (c) 2017 Inigo Quilez
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
// associated documentation files (the "Software"), to deal in the Software without restriction,
// including without limitation the rights to use, copy, modify, merge, publish, distribute,
// sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions: The above copyright notice and this
// permission notice shall be included in all copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT
// NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
// DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
// (Only the idea of the two offset taps is used; the code here is rewritten for this shader.)
// Written by `GroundMaterial`, which fills the uniforms from a `GroundSet`; nothing here is a look.

uniform sampler2D albedo_0 : source_color, filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
uniform sampler2D albedo_1 : source_color, filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
uniform sampler2D albedo_2 : source_color, filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
uniform sampler2D albedo_3 : source_color, filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
uniform sampler2D normal_0 : filter_linear_mipmap_anisotropic, repeat_enable, hint_default_black;
uniform sampler2D normal_1 : filter_linear_mipmap_anisotropic, repeat_enable, hint_default_black;
uniform sampler2D normal_2 : filter_linear_mipmap_anisotropic, repeat_enable, hint_default_black;
uniform sampler2D normal_3 : filter_linear_mipmap_anisotropic, repeat_enable, hint_default_black;
uniform sampler2D orm_0 : filter_linear_mipmap, repeat_enable, hint_default_white;
uniform sampler2D orm_1 : filter_linear_mipmap, repeat_enable, hint_default_white;
uniform sampler2D orm_2 : filter_linear_mipmap, repeat_enable, hint_default_white;
uniform sampler2D orm_3 : filter_linear_mipmap, repeat_enable, hint_default_white;

/** Gradient (RG, 0.5 = flat) of a seamless height noise: the rolling relief. */
uniform sampler2D bump_tex : filter_linear_mipmap, repeat_enable, hint_default_black;

uniform bool use_triplanar = true;
uniform bool use_stochastic = false;
// Per layer (index = slot); the rest of the layer rules are in ground_common.gdshaderinc.
uniform float uv_scale_m[4];
uniform float normal_strength[4];

uniform float bump_height_m = 0.6;
uniform float bump_scale_m = 36.0;

varying vec3 map_pos;
varying float view_dist;

struct Lay {
	vec3 alb;
	vec3 wn;
	vec3 orm;
};

struct Tap {
	vec3 alb;
	vec3 nrm;
	vec3 orm;
};

void vertex() {
	map_pos = VERTEX;
	deform_hole = 0.0;
	if (terrain_deform_on > 0.5) {
		vec2 shift = deform_at(VERTEX.xz);
		NORMAL = deform_normal(NORMAL, VERTEX.xz);
		VERTEX.y += shift.x;
		deform_hole = shift.y;
	}
	view_dist = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
}

Tap tap_plain(sampler2D a, sampler2D n, sampler2D o, vec2 uv, vec2 dx, vec2 dy) {
	Tap t;
	t.alb = textureGrad(a, uv, dx, dy).rgb;
	t.nrm = textureGrad(n, uv, dx, dy).rgb;
	t.orm = textureGrad(o, uv, dx, dy).rgb;
	return t;
}

// Two taps with offsets picked from low-frequency noise, blended where the albedo differs.
Tap tap_stochastic(sampler2D a, sampler2D n, sampler2D o, vec2 uv, vec2 dx, vec2 dy, float k) {
	float l = k * 8.0;
	float f = fract(l);
	float ia = floor(l);
	vec2 oa = sin(vec2(3.0, 7.0) * ia);
	vec2 ob = sin(vec2(3.0, 7.0) * (ia + 1.0));
	vec3 a0 = textureGrad(a, uv + oa, dx, dy).rgb;
	vec3 a1 = textureGrad(a, uv + ob, dx, dy).rgb;
	float w = smoothstep(0.2, 0.8, f - 0.1 * dot(a0 - a1, vec3(1.0)));
	Tap t;
	t.alb = mix(a0, a1, w);
	t.nrm = mix(textureGrad(n, uv + oa, dx, dy).rgb, textureGrad(n, uv + ob, dx, dy).rgb, w);
	t.orm = mix(textureGrad(o, uv + oa, dx, dy).rgb, textureGrad(o, uv + ob, dx, dy).rgb, w);
	return t;
}

vec3 decode_normal(vec3 enc, float strength) {
	vec3 nt = enc * 2.0 - 1.0;
	nt.xy *= strength;
	nt.z = sqrt(max(1.0 - dot(nt.xy, nt.xy), 0.0));
	return nt;
}

// Evaluates layer i: albedo, world-space normal (unnormalized), ORM. `g` is the geometric
// world normal; the normal map is combined with it by projection (whiteout), so no tangents.
// `dpx`/`dpy`: screen derivatives of the map position, taken in uniform control flow, so a layer
// can be skipped (rule weight 0) without breaking mip selection.
Lay eval_layer(int i, sampler2D a, sampler2D n, sampler2D o, vec3 g, vec3 dpx, vec3 dpy) {
	Lay r;
	vec3 alb; vec3 wn; vec3 orm;
	float scale = 1.0 / uv_scale_m[i];
	float str = normal_strength[i];
	vec2 uv = map_pos.xz * scale;
	bool tri = use_triplanar && layer_flags[i].x > 0.5;
	if (tri) {
		vec3 b = pow(abs(g), vec3(4.0));
		b /= (b.x + b.y + b.z + 0.0001);
		Tap ty = tap_plain(a, n, o, uv, dpx.xz * scale, dpy.xz * scale);
		Tap tx = tap_plain(a, n, o, map_pos.zy * scale, dpx.zy * scale, dpy.zy * scale);
		Tap tz = tap_plain(a, n, o, map_pos.xy * scale, dpx.xy * scale, dpy.xy * scale);
		alb = ty.alb * b.y + tx.alb * b.x + tz.alb * b.z;
		orm = ty.orm * b.y + tx.orm * b.x + tz.orm * b.z;
		vec3 nx = decode_normal(tx.nrm, str);
		vec3 ny = decode_normal(ty.nrm, str);
		vec3 nz = decode_normal(tz.nrm, str);
		nx = vec3(nx.xy + g.zy, abs(nx.z) * g.x);
		ny = vec3(ny.xy + g.xz, abs(ny.z) * g.y);
		nz = vec3(nz.xy + g.xy, abs(nz.z) * g.z);
		wn = nx.zyx * b.x + ny.xzy * b.y + nz.xyz * b.z;
	} else {
		Tap t;
		vec2 dx = dpx.xz * scale;
		vec2 dy = dpy.xz * scale;
		if (use_stochastic && layer_flags[i].y > 0.5) {
			t = tap_stochastic(a, n, o, uv, dx, dy, textureLod(noise_tex, uv * 0.07, 0.0).b);
		} else {
			t = tap_plain(a, n, o, uv, dx, dy);
		}
		alb = t.alb;
		orm = t.orm;
		vec3 nt = decode_normal(t.nrm, str);
		vec3 w = vec3(nt.xy + g.xz, abs(nt.z) * g.y);
		wn = w.xzy;
	}
	orm.g = clamp(orm.g + layer_flags[i].z, 0.04, 1.0);
	r.alb = alb;
	r.wn = wn;
	r.orm = orm;
	return r;
}

void fragment() {
	if (deform_hole > 0.0001) {
		discard;
	}
	vec3 g = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec2 xz = map_pos.xz;
	// Rule weights first: they need no texture, and decide which layers are sampled at all.
	vec4 rules = ground_rules(xz, degrees(acos(clamp(g.y, -1.0, 1.0))), map_pos.y);
	float rule[4] = float[4](rules.x, rules.y, rules.z, rules.w);
	if (COLOR.a < 0.5) {
		for (int i = 0; i < 4; i++) {
			rule[i] = (i < layer_count && i == 1) ? 1.0 : 0.0; // the map's void walls: the rock layer
		}
	}
	vec3 dpx = dFdx(map_pos);
	vec3 dpy = dFdy(map_pos);
	Lay L[4];
	for (int i = 0; i < 4; i++) {
		L[i].alb = vec3(0.0);
		L[i].wn = vec3(0.0);
		L[i].orm = vec3(1.0, 1.0, 0.0);
	}
	// If no rule claims the pixel, layer 0 is the fallback.
	bool fallback = (rule[0] + rule[1] + rule[2] + rule[3]) < 0.002;
	if (rule[0] > 0.002 || fallback) {
		L[0] = eval_layer(0, albedo_0, normal_0, orm_0, g, dpx, dpy);
	}
	if (rule[1] > 0.002) {
		L[1] = eval_layer(1, albedo_1, normal_1, orm_1, g, dpx, dpy);
	}
	if (rule[2] > 0.002) {
		L[2] = eval_layer(2, albedo_2, normal_2, orm_2, g, dpx, dpy);
	}
	if (rule[3] > 0.002) {
		L[3] = eval_layer(3, albedo_3, normal_3, orm_3, g, dpx, dpy);
	}

	// Height blend so the stones poke through the soil.
	float w[4];
	float score[4];
	float top = 0.0;
	for (int i = 0; i < 4; i++) {
		w[i] = rule[i];
		score[i] = 0.0;
		if (w[i] > 0.002) {
			score[i] = w[i] + L[i].orm.b * height_contrast[i] * 0.5;
			top = max(top, score[i]);
		}
	}
	float total = 0.0;
	for (int i = 0; i < 4; i++) {
		float f = max(score[i] - (top - blend_depth), 0.0) * step(0.002, w[i]);
		w[i] = f;
		total += f;
	}
	if (total < 0.0001) {
		w[0] = 1.0;
		total = 1.0;
		if (!fallback) {
			L[0].alb = vec3(0.3);
		}
	}

	vec4 w_norm = vec4(w[0], w[1], w[2], w[3]) / total;
	vec3 out_alb = vec3(0.0);
	vec3 out_n = vec3(0.0);
	vec3 out_orm = vec3(0.0);
	for (int i = 0; i < 4; i++) {
		float f = w[i] / total;
		out_alb += L[i].alb * tint[i].rgb * f;
		out_n += L[i].wn * f;
		out_orm += L[i].orm * f;
	}

	out_alb = grass_paint_textured(out_alb, w_norm, xz, TIME, degrees(acos(clamp(g.y, -1.0, 1.0))));
	if (use_macro) {
		float drift = ground_drift(xz);
		out_alb *= ground_macro_mul(drift);
		out_orm.g = clamp(out_orm.g + drift * macro_roughness, 0.05, 1.0);
	}
	if (lightmap_tint > 0.0) {
		out_alb *= ground_lightmap_mul(xz);
	}

	vec3 world_n = normalize(out_n);
	if (bump_height_m > 0.0) {
		float s0 = bump_scale_m;
		float s1 = bump_scale_m * 0.25;
		vec2 g0 = (texture(bump_tex, xz / s0).rg - 0.5) * (bump_height_m * 256.0 / s0 / 8.0);
		vec2 g1 = (texture(bump_tex, xz / s1).rg - 0.5) * (bump_height_m * 256.0 / s1 / 8.0);
		float fade = 1.0 - smoothstep(120.0, 320.0, view_dist);
		vec2 grad = (g0 + 0.5 * g1) * fade;
		world_n = normalize(world_n - vec3(grad.x, 0.0, grad.y));
	}
	NORMAL = normalize((VIEW_MATRIX * vec4(world_n, 0.0)).xyz);
	// The normal is rebuilt here, so a back face has to flip it by hand to light like the front.
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	ALBEDO = out_alb;
	ROUGHNESS = out_orm.g;
	SPECULAR = 0.2;
	AO = out_orm.r;
	AO_LIGHT_AFFECT = 0.6;
}
