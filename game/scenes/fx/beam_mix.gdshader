shader_type spatial;
// Mix ribbon of a BeamFx (BeamType.blend MIX): a straight-alpha atlas over the scene, so a glow keeps its hue over
// the snow (where adding light only reaches white). F124: the Gnome's gun flame (gmfl_a).
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

#define BEAM_MIX
#include "res://scenes/fx/beam.gdshaderinc"
