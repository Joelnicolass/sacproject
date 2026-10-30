// `PER_INSTANCE uniform float x;` is an instance uniform on Forward+ and Mobile, and a plain material
// uniform on Compatibility (WebGL 2): there every instance uniform takes a slot of a buffer of
// 1024 shared by the whole scene, and past it the instance draws with the wrong values. On
// Compatibility each instance gets its own material instead (InstanceParams, instance_params.gd).
#ifndef PER_INSTANCE_INCLUDED
#define PER_INSTANCE_INCLUDED
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
#define PER_INSTANCE
#else
#define PER_INSTANCE instance
#endif
#endif
