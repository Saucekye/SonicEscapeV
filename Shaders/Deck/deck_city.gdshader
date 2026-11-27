shader_type spatial;
render_mode unshaded;
// Towers far off

uniform vec4 wall : source_color = vec4(0.05, 0.08, 0.15, 1.0);
uniform vec4 lit_a : source_color = vec4(0.85, 0.92, 1.0, 1.0);
uniform vec4 lit_b : source_color = vec4(1.0, 0.85, 0.6, 1.0);
uniform vec4 haze : source_color = vec4(0.12, 0.25, 0.45, 1.0);
uniform float lit_share = 0.35;
uniform float haze_from = 60.0;
uniform float haze_to = 320.0;

varying vec3 wp;
varying vec3 wn;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	vec3 col = wall.rgb;
	if (abs(wn.y) < 0.5) {
		float along = abs(wn.z) > 0.5 ? wp.x : wp.z;
		vec2 w = vec2(along / 1.6, wp.y / 2.4);
		vec2 f = fract(w);
		float win = step(0.25, f.x) * step(f.x, 0.8) * step(0.3, f.y) * step(f.y, 0.8);
		float r = h(floor(w) + floor(wp.xz / 37.0) * 13.0);
		vec3 light = mix(lit_a.rgb, lit_b.rgb, step(0.7, h(floor(w) * 1.7)));
		col = mix(col, light * (0.6 + 0.4 * r), win * step(1.0 - lit_share, r));
		col = mix(col, col * 0.6 + vec3(0.04, 0.07, 0.14), win * (1.0 - step(1.0 - lit_share, r)));
	}
	float d = distance(CAMERA_POSITION_WORLD, wp);
	ALBEDO = mix(col, haze.rgb, smoothstep(haze_from, haze_to, d) * 0.85);
}
