shader_type spatial;
render_mode unshaded;
// A fluorescent tube

uniform vec4 color : source_color = vec4(0.72, 1.0, 0.82, 1.0);

void fragment() {
	ALBEDO = color.rgb * (0.85 + 0.15 * sin(TIME * 120.0));
}
