// Recolours HUD art into the game's red / white / black palette.
// Whites, blacks and greys stay as they are; every coloured pixel (the blue
// backdrop, the yellow boost meter, the gold ring) becomes a shade of red picked
// by its brightness, so shading and highlights are kept.
shader_type canvas_item;

uniform vec4 dark_red : source_color = vec4(0.32, 0.02, 0.05, 1.0);
uniform vec4 red : source_color = vec4(0.85, 0.12, 0.16, 1.0);
uniform vec4 light_red : source_color = vec4(0.98, 0.22, 0.25, 1.0);
uniform float grey_tolerance = 0.12;   // pixels less saturated than this are left alone
uniform bool white_outlines_to_black = true;   // HUD frame outlines become black (white text is a separate node, so it stays white)

void fragment() {
	vec4 c = COLOR;
	float hi = max(c.r, max(c.g, c.b));
	float lo = min(c.r, min(c.g, c.b));
	if (hi - lo > grey_tolerance) {
		float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
		vec3 r = l < 0.45 ? mix(dark_red.rgb, red.rgb, smoothstep(0.1, 0.45, l))
						  : mix(red.rgb, light_red.rgb, smoothstep(0.55, 0.85, l));
		// keep the pixel-art banding: snap to 4 levels
		c.rgb = floor(r * 6.0 + 0.5) / 6.0;
	} else if (white_outlines_to_black && lo > 0.85) {
		c.rgb = vec3(0.0);
	}
	COLOR = c;
}
