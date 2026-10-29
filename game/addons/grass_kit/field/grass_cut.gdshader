// GrassKit's blades with alpha scissor (petals, cards of stalks): grass.gdshader cutting the
// pixels whose albedo alpha is under the kind's alpha_scissor.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, specular_schlick_ggx;

#define ALPHA_CUT
#include "res://addons/grass_kit/field/grass_body.gdshaderinc"
