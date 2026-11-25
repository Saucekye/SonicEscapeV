shader_type spatial;
render_mode unshaded, cull_disabled;
// Pool water, lit from below

uniform vec4 deep : source_color = vec4(0.03, 0.25, 0.42, 1.0);
uniform vec4 light : source_color = vec4(0.55, 0.95, 1.0, 1.0);

varying vec3 wp;

void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	float t = TIME * 0.5;
	vec2 p = wp.xz;
	vec2 warp = vec2(n(p * 0.7 + t), n(p * 0.7 - t)) * 0.6;
	vec2 g = abs(fract((p + warp) / 1.0) - 0.5);
	float lane = smoothstep(0.47, 0.5, g.x) * 0.25;    // the tiles on the bottom, wobbling
	float a = n(p * 1.6 + vec2(t, t * 0.7));
	float b = n(p * 2.3 - vec2(t * 0.8, -t * 0.5));
	float vein = smoothstep(0.06, 0.0, abs(a - b));
	vec3 col = deep.rgb + light.rgb * (vein * 0.75 + lane + 0.12 * a);
	vec3 to_cam = normalize(CAMERA_POSITION_WORLD - wp);
	col += vec3(0.5, 0.7, 0.9) * pow(1.0 - clamp(to_cam.y, 0.0, 1.0), 5.0) * 0.6;
	ALBEDO = col;
}
