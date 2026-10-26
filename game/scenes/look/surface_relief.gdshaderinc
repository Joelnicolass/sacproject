// The relief of a surface's own normal map, for a shader that draws a copy of a StandardMaterial3D (StoneLook, BuildReveal).
// SurfaceRelief.forward(source, copy) fills the three uniforms; with use_relief off nothing is written and the surface keeps its
// vertex normal, as before. Call relief_apply(UV) inside fragment(), after any discard. Same convention as StandardMaterial3D:
// OpenGL normal (Y up), the scale goes to NORMAL_MAP_DEPTH.

uniform bool use_relief = false;
uniform sampler2D relief_normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float relief_normal_scale = 1.0;

// A macro, not a function: NORMAL_MAP is a fragment() output and a function cannot write it.
#define relief_apply(uv) if (use_relief) { NORMAL_MAP = texture(relief_normal_tex, uv).rgb; NORMAL_MAP_DEPTH = relief_normal_scale; }
