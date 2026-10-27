shader_type spatial;
// A blink of light added over a body that was hit (HitFlash sets it as material_overlay). `hit_flash` is per body (0 = nothing).
render_mode unshaded, blend_add, depth_draw_never, cull_back, fog_disabled;

uniform vec3 tint : source_color = vec3(1.0, 0.92, 0.8);
instance uniform float hit_flash = 0.0;

void fragment() {
	ALBEDO = tint * hit_flash;
}
