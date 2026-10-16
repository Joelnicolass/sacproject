shader_type spatial;
// fog_disabled stays: Godot 4.7 adds the fog's inscatter to the fragment (rgb * T + fog), and with
// blend_add that brightens a far sprite. Instead the sprite fades by the same depth fog (FX_FOG_FADE,
// globals written by ThemeApplier), RFC-029 029a.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

#define FX_FOG_FADE
#include "res://scenes/fx/sprite_particle.gdshaderinc"
