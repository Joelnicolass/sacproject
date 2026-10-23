shader_type sky;

// This shader is inspired by one I found on shadertoy so credit where credit is due:
// https://www.shadertoy.com/view/XtGGRt
// What I've done here is convert it over and adapted it to godot shaders, sky shaders specificly +
// extracted out some customisation variables like setting a color gradient etc +
// made some performance optimisations + overall tried to simplify it a bit.


// equirectangular = flat texture representing a full 360° spherical sky
uniform sampler2D equirectangular_sky_texture : source_color, filter_linear;

uniform sampler2D color_gradient : source_color; // gradient texture 1D
uniform float brightness = 1.7;
uniform float speed = 0.12;
uniform float height = 42.0;
uniform float scale = 0.8;

#include "res://scenes/look/sky/aurora.gdshaderinc"

vec3 get_base_sky_color_from_sky_texture(vec3 direction) {
    float u = atan(direction.x, direction.z) / (2.0 * PI) + 0.5;
    float v = asin(direction.y) / PI + 0.5; // -asin if it needs to be flipped

	vec3 sky_color = texture(equirectangular_sky_texture, vec2(u, v)).rgb;

	return sky_color;
}

void sky(){
	vec3 direction = normalize(EYEDIR);
	
	vec3 base_sky = get_base_sky_color_from_sky_texture(direction);
	vec3 base_sky_with_aurora = aurora_over(base_sky, direction, color_gradient, TIME, brightness, speed, height, scale);

    COLOR = base_sky_with_aurora;
}
