// The last step of the Salvage screen look
shader_type canvas_item;

uniform float vignette = 1.05;
uniform float grain = 0.07;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 col = texture(TEXTURE, UV).rgb;
	float g = hash(floor(FRAGCOORD.xy / 2.0) + fract(TIME * 13.7) * 91.0) - 0.5;
	col += g * grain;
	vec2 c = UV - 0.5;
	col *= clamp(1.0 - dot(c, c) * vignette * 2.2, 0.0, 1.0);
	COLOR = vec4(max(col, 0.0), 1.0);
}
