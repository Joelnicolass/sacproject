// GrassKit's blades, opaque (the kit's blade and any mesh without alpha_scissor). The body is in
// grass_body.gdshaderinc; grass_cut.gdshader is the same with alpha scissor.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, specular_schlick_ggx;

#include "res://addons/grass_kit/field/grass_body.gdshaderinc"
