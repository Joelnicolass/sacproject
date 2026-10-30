// GrassKit's colours between the renderer's space and linear. GrassKit computes the colours it
// shares (the grass from afar, under the grass) in linear; Forward+ and Mobile shade in linear, but
// Compatibility takes `source_color` colours and ALBEDO as they are (sRGB), so there they are
// converted. Included by the blade shader and grass_ground.gdshaderinc.

#ifndef GRASSKIT_COLOR
#define GRASSKIT_COLOR

// A colour as the renderer has it (a `source_color` uniform or texture, ALBEDO) to linear.
vec3 grasskit_to_linear(vec3 c) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
#else
	return c;
#endif
}

// A linear colour to the renderer's (what ALBEDO takes).
vec3 grasskit_from_linear(vec3 c) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	c = max(c, vec3(0.0));
	return mix(1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, c * 12.92, lessThan(c, vec3(0.0031308)));
#else
	return c;
#endif
}

#endif
