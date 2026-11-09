// Soft light halo around the Salvage lamps (salvage.gd): a camera-facing quad that
// adds a warm glow into the dark, like the lamps in "It Steals".
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

uniform vec4 glow_color : source_color = vec4(1.0, 0.75, 0.45, 1.0);
uniform float strength = 0.55;
uniform float flicker = 1.0;

void vertex() {
	// Always face the camera
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float a = pow(max(1.0 - d, 0.0), 2.4) * strength * flicker;
	ALBEDO = glow_color.rgb * a;
}
