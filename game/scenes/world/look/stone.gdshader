shader_type spatial;

// F137 (RFC-030i-b): the stone look of a petrified body (later Skin of Stone), sacengine dagon bone.d:189-192:
//   brightness = (r + g + b) / 3;  diffuse = 0.3 + 0.7 · brightness · (1, 1, 0.8);  roughness/metallic 0.5.
// The formula works on the texture's stored (sRGB) values, so the texture is read raw and the grey is turned to linear
// for ALBEDO: on screen it is the same grey sacengine writes. One ShaderMaterial per source material (StoneLook).

uniform sampler2D albedo_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
// The source material's albedo_color (sRGB, like the texture).
uniform vec4 albedo_color = vec4(1.0);
// The source's alpha scissor; 0 = opaque.
uniform float alpha_scissor = 0.0;
uniform float stone_base = 0.3;
uniform float stone_gain = 0.7;
uniform vec3 stone_tint = vec3(1.0, 1.0, 0.8);
uniform float stone_roughness : hint_range(0.0, 1.0) = 0.5;
uniform float stone_metallic : hint_range(0.0, 1.0) = 0.5;

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void fragment() {
	vec4 c = texture(albedo_tex, UV) * albedo_color;
	if (alpha_scissor > 0.0 && c.a < alpha_scissor) {
		discard;
	}
	float brightness = (c.r + c.g + c.b) / 3.0;
	vec3 grey = clamp(vec3(stone_base) + stone_gain * brightness * stone_tint, 0.0, 1.0);
	ALBEDO = srgb_to_linear(grey);
	ROUGHNESS = stone_roughness;
	METALLIC = stone_metallic;
}
