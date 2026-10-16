shader_type spatial;
// Shaded mix sprite (blood, dirt, dust): takes the sun, the ambient and the fog like the ground,
// so far away it stops looking pasted on (RFC-029 029a, ParticleType.lit).
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, diffuse_lambert_wrap, specular_disabled;

#define FX_LIT
#include "res://scenes/fx/sprite_particle.gdshaderinc"
