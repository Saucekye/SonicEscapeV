shader_type spatial;
render_mode unshaded;
// The water below the deck

uniform vec4 deep : source_color = vec4(0.02, 0.07, 0.16, 1.0);
uniform vec4 glow : source_color = vec4(0.55, 0.85, 1.0, 1.0);
uniform vec4 haze : source_color = vec4(0.12, 0.25, 0.45, 1.0);

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	float t = TIME * 0.35;
	vec2 p = wp.xz * 0.08;
	float a = n(p * 3.0 + vec2(t, t * 0.6));
	float b = n(p * 5.0 - vec2(t * 0.7, -t));
	float c = abs(a - b);
	float lines = smoothstep(0.08, 0.0, c);   // bright veins where the two ripples cross
	vec3 col = deep.rgb + glow.rgb * (lines * 0.9 + pow(a * b, 2.0) * 0.4);
	float d = distance(CAMERA_POSITION_WORLD, wp);
	ALBEDO = mix(col, haze.rgb, smoothstep(40.0, 300.0, d) * 0.8);
}
