shader_type spatial;
render_mode unshaded, cull_back;
// The TV's round glass

uniform sampler2D clip : source_color, filter_linear, repeat_disable;
uniform int cols = 1;
uniform int rows = 1;
uniform int frame = 0;
uniform float crop_x = 1.0;     // how much of each frame's width fills the round screen
uniform float bend = 0.18;
uniform float scanlines = 0.18;
uniform float brightness = 1.1;

void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float r = length(c);
	if (r > 1.0) {
		discard;   // a round screen
	}
	c *= 1.0 + bend * r * r * 0.5;
	vec2 uv = clamp(c * 0.5 + 0.5, vec2(0.001), vec2(0.999));
	vec2 cell_uv = vec2(0.5 + (uv.x - 0.5) * crop_x, uv.y);
	vec2 cell = vec2(float(frame % cols), float(frame / cols));
	vec3 col = texture(clip, (cell + cell_uv) / vec2(float(cols), float(rows))).rgb;
	col *= 1.0 - scanlines * (0.5 + 0.5 * sin(uv.y * 300.0 * 3.14159));
	col *= 1.0 - 0.03 * sin(TIME * 60.0);
	col *= smoothstep(1.02, 0.7, r);
	ALBEDO = col * brightness;
}
