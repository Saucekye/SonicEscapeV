shader_type canvas_item;

// Size of the ColorRect in pixels (set this to match your game resolution)
uniform vec2 view_size = vec2(640.0, 480.0);

uniform vec4 bg_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 line_color : source_color = vec4(0.6, 0.12, 0.6, 1.0);

// Grid A (front layer)
uniform float grid_size_a = 40.0;
uniform float line_width_a = 2.0;
uniform vec2 scroll_a = vec2(45.0, 45.0);
uniform float alpha_a = 0.9;

// Grid B (back layer, scrolls the other way, dimmer)
uniform float grid_size_b = 40.0;
uniform float line_width_b = 2.0;
uniform vec2 scroll_b = vec2(-25.0, 25.0);
uniform float alpha_b = 0.45;

// Anti-aliasing softness of the line edges in pixels (0 = hard edges)
uniform float softness = 1.0;

// Pulse and fade
uniform float pulse_speed = 1.5;
uniform float pulse_amount = 0.25;   // 0 = no pulsing
uniform float edge_fade = 0.35;      // darkens top and bottom, 0 = off

// 1.0 = smooth. Raise to 2.0+ for a chunky retro look (will look steppier).
uniform float pixel_size = 1.0;

float grid(vec2 p, float size, float width) {
	vec2 g = mod(p, size);
	vec2 d = min(g, size - g); // distance to nearest line center
	vec2 l = 1.0 - smoothstep(width * 0.5, width * 0.5 + softness, d);
	return max(l.x, l.y);
}

void fragment() {
	vec2 p = floor(UV * view_size / pixel_size) * pixel_size;

	// The grid repeats every grid_size, so wrapping the offset keeps it
	// seamless and avoids precision loss when TIME gets large.
	vec2 off_a = mod(scroll_a * TIME, grid_size_a);
	vec2 off_b = mod(scroll_b * TIME, grid_size_b);

	float a = grid(p + off_a, grid_size_a, line_width_a) * alpha_a;
	float b = grid(p + off_b, grid_size_b, line_width_b) * alpha_b;
	float lines = clamp(a + b, 0.0, 1.0);

	float pulse = 1.0 - pulse_amount + pulse_amount * (0.5 + 0.5 * sin(TIME * pulse_speed));

	float edge = smoothstep(0.0, edge_fade, UV.y) * smoothstep(1.0, 1.0 - edge_fade, UV.y);
	edge = mix(1.0, edge, step(0.001, edge_fade));

	vec3 col = mix(bg_color.rgb, line_color.rgb, lines * pulse * edge);
	COLOR = vec4(col, 1.0);
}
