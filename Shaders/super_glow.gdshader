shader_type canvas_item;
// A super form's own colour

uniform vec4 glow : source_color = vec4(1.0, 0.5, 0.8, 1.0);
uniform float amount = 0.6;   // 0 = its own colours, 1 = all glow colour
uniform float pulse = 0.0;     // 0..1, set every frame

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float lum = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	vec3 tinted = glow.rgb * (0.6 + 0.9 * lum);
	c.rgb = mix(c.rgb, tinted, amount) + glow.rgb * pulse * 0.15;
	COLOR = c;
}
