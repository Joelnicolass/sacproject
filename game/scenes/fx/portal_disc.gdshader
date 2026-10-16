shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

// Flat ring + center that always faces the camera (sacengine SacVortex rim and center meshes).
// Quad of 2x2 m in model space: the ring is the crown between inner_ratio and 1, the center is the
// whole quad. The size of the disc is half_size * openness (meters), set by portal_disc.gd.

uniform sampler2D rim_tex : source_color, filter_linear, repeat_disable;
uniform sampler2D center_tex : source_color, filter_linear, repeat_disable;
uniform bool use_textures = false;
uniform vec3 fallback_color : source_color = vec3(0.3, 0.7, 1.0);
uniform float rim_energy = 10.0;
uniform float center_energy = 1.0;
uniform float frame_s = 0.0333;
uniform float inner_ratio = 0.65;
uniform float zigzag_repeats = 16.0;
uniform vec2 half_size = vec2(1.0);
uniform float openness = 1.0;
uniform float phase = 0.0;

varying vec2 quad;

void vertex() {
	quad = VERTEX.xy;
	VERTEX.xy *= half_size * openness;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	float frame = mod(floor((TIME + phase) / frame_s), 16.0);
	vec2 cell = vec2(mod(frame, 4.0), floor(frame / 4.0)) * 0.25;
	float inset = 0.5 / 64.0;
	float r = length(quad);
	float t = (1.0 - r) / (1.0 - inner_ratio);
	vec3 rim = vec3(0.0);
	vec3 center = vec3(0.0);
	if (use_textures) {
		center = textureLod(center_tex, cell + (UV * (1.0 - 2.0 * inset) + inset) * 0.25, 0.0).rgb * center_energy;
		// The cell is not black right at its border: fade the square away (not in the original).
		center *= clamp((1.0 - r) / 0.2, 0.0, 1.0);
		if (r <= 1.0 && t >= 0.0 && t <= 1.0) {
			// Edges (outer and inner) at the top of the cell, middle of the crown at the bottom.
			float v = 1.0 - abs(2.0 * t - 1.0);
			float x = (atan(quad.y, quad.x) / 6.2831853 + 0.5) * zigzag_repeats;
			float a = fract(x);
			if (mod(floor(x), 2.0) > 0.5) {
				a = 1.0 - a;
			}
			vec2 uv = vec2(mix(inset, 1.0 - inset, a), mix(inset, 1.0 - inset, v));
			rim = textureLod(rim_tex, cell + uv * 0.25, 0.0).rgb * rim_energy;
		}
	} else {
		float band = 0.0;
		if (r <= 1.0 && t >= 0.0 && t <= 1.0) {
			band = pow(1.0 - abs(2.0 * t - 1.0), 2.0);
		}
		rim = fallback_color * band * rim_energy * 0.4;
		center = fallback_color * exp(-r * r * 3.0) * center_energy;
	}
	ALBEDO = rim + center;
	ALPHA = 1.0;
}
