shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, shadows_disabled;

// Death rising out of the land: the model is shown from its feet up as `reveal` goes from 0 to 1, with a soft band at the top edge (sacengine's
// «building summon» material: the threshold goes from -1.2 to 12 m of the model's height). Lit like a creature. Anything above the band is not drawn.

uniform sampler2D skin : source_color, filter_linear_mipmap, repeat_enable;
uniform float height_m = 12.0;
uniform float band_m = 1.2;
instance uniform float reveal : hint_range(0.0, 1.0) = 1.0;

varying float local_height;

void vertex() {
	local_height = VERTEX.y;
}

void fragment() {
	float threshold = -band_m + (height_m + band_m) * reveal;
	float edge = clamp((threshold - local_height) / band_m, 0.0, 1.0);
	if (edge <= 0.0) {
		discard;
	}
	ALBEDO = texture(skin, UV).rgb;
	ALPHA = reveal >= 1.0 ? 1.0 : edge;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
