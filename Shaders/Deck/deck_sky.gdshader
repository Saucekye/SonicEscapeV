shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, shadows_disabled;
// The night outside

uniform vec4 top : source_color = vec4(0.01, 0.03, 0.09, 1.0);
uniform vec4 horizon : source_color = vec4(0.12, 0.25, 0.45, 1.0);
uniform vec4 cloud : source_color = vec4(0.3, 0.45, 0.65, 1.0);

varying vec3 dir;

void vertex() {
	dir = normalize(VERTEX);
}

float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	float up = clamp(dir.y, -0.2, 1.0);
	vec3 col = mix(horizon.rgb, top.rgb, pow(clamp(up * 2.2, 0.0, 1.0), 0.6));
	vec2 p = dir.xz / max(dir.y + 0.15, 0.05);
	float c = n(p * 1.2 + vec2(TIME * 0.01, 0.0)) * 0.6 + n(p * 3.1) * 0.4;
	col = mix(col, cloud.rgb, smoothstep(0.55, 0.85, c) * 0.45 * smoothstep(0.0, 0.25, up));
	vec2 sp = floor(vec2(atan(dir.x, dir.z) * 220.0, up * 260.0));
	float star = step(0.9985, h(sp)) * smoothstep(0.15, 0.5, up);
	col += vec3(0.8, 0.9, 1.0) * star * (0.6 + 0.4 * sin(TIME * 2.0 + h(sp) * 40.0));
	ALBEDO = col;
}
