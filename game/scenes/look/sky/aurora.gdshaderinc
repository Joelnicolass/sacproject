// Aurora borealis for sky shaders.
//
// This is inspired by a shader found on Shadertoy, so credit where credit is due:
// https://www.shadertoy.com/view/XtGGRt
// Converted and adapted to Godot sky shaders, with the customisation variables extracted
// (colour gradient, speed, height, scale), performance optimisations and some simplification.
//
// The functions take their parameters instead of declaring uniforms, so every sky shader that
// includes this file keeps its own (human named, grouped) uniforms.

// The lower the value is for this variable, the better for performance.
// If set too low, the jitter effect on the aurora becomes visible, set it to as low as it can be
// without it changing the visual effect.
const float AURORA_RESOLUTION_LOOP_COUNT = 30.0;

mat2 aurora_mm2(float a) {
	float c = cos(a), s = sin(a);
	return mat2(vec2(c, s), vec2(-s, c));
}

float aurora_tri(float x) {
	return clamp(abs(fract(x) - 0.5), 0.01, 0.49);
}

vec2 aurora_tri2(vec2 p) {
	return vec2(aurora_tri(p.x) + aurora_tri(p.y), aurora_tri(p.y + aurora_tri(p.x)));
}

float aurora_trinoise2d(vec2 p, float t) {
	float z = 1.8;
	float z2 = 2.5;
	float rz = 0.0;

	p *= aurora_mm2(p.x * 0.06);
	vec2 bp = p;
	mat2 rot = aurora_mm2(t);

	for (int i = 0; i < 4; i++) {
		vec2 dg = aurora_tri2(bp * 1.85) * 0.75;
		dg = dg * rot;
		p -= dg / z2;

		bp *= 1.3;
		z2 *= 0.45;
		z *= 0.42;

		p *= 1.21 + (rz - 1.0) * 0.02;
		rz += aurora_tri(p.x + aurora_tri(p.y)) * z;

		p *= mat2(vec2(-0.95534, -0.29552), vec2(0.29552, -0.95534));
	}

	return clamp(1.0 / pow(rz * 29.0, 1.3), 0.0, 0.55);
}

// rgb = colour, a = coverage of the aurora seen along `direction`.
vec4 aurora_color(vec3 direction, sampler2D color_gradient, float time_s, float brightness, float speed, float height, float scale) {
	vec4 color = vec4(0.0);
	vec4 average_color = vec4(0.0);

	// Instead of using the height as the loop count, jitter is used to decrease the loop count
	// and keep a similar visual effect.
	float jitter = fract(sin(dot(direction.xz, vec2(13.0, 78.0))));
	float jitter_step_scale = height / AURORA_RESOLUTION_LOOP_COUNT;

	for (int i = 0; i < int(AURORA_RESOLUTION_LOOP_COUNT); i++) {
		float depth_step = (float(i) + jitter) * jitter_step_scale;
		float depth = ((scale + pow(depth_step, 1.4) * 0.002)) / (direction.y * 2.0 + 0.4);
		vec3 pos = depth * direction;
		float noise = aurora_trinoise2d(pos.zx, time_s * speed);

		vec4 col = vec4(0.0);
		col.a = noise;

		float weight = exp2(-depth_step * 0.065 - 2.5) * smoothstep(0.0, 5.0, depth_step);

		col.rgb = textureLod(color_gradient, vec2(depth_step / height, 0.0), 0.0).rgb * noise;
		average_color = mix(average_color, col, 0.5);

		color += average_color * weight * jitter_step_scale;
	}

	color *= clamp(direction.y * 15.0 + 0.4, 0.0, 1.0);
	color *= brightness;

	return color;
}

// `sky_color` with the aurora over it.
vec3 aurora_over(vec3 sky_color, vec3 direction, sampler2D color_gradient, float time_s, float brightness, float speed, float height, float scale) {
	// No need to run the calculations on the bottom half of the sky.
	// -0.1 instead of 0.0 avoids a hard cutoff of the aurora in the far distance.
	if (direction.y > -0.1) {
		vec4 aurora = aurora_color(direction, color_gradient, time_s, brightness, speed, height, scale);
		sky_color = mix(sky_color, aurora.rgb, aurora.a);
	}
	return sky_color;
}
