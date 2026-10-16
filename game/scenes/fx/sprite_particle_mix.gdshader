shader_type spatial;
// Unshaded mix sprite (ParticleType.lit = false). The shaded one is sprite_particle_mix_lit.gdshader.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

#include "res://scenes/fx/sprite_particle.gdshaderinc"
