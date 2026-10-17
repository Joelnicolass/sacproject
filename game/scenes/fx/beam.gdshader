shader_type spatial;
// fog_disabled for the same reason as sprite_particle_add: Godot's fog adds its light to an additive
// surface. The ribbon fades by the map's depth fog instead (globals of ThemeApplier).
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

#include "res://scenes/fx/beam.gdshaderinc"
