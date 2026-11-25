shader_type spatial;
render_mode unshaded;
// Chrome rails and posts

uniform vec4 dark : source_color = vec4(0.12, 0.17, 0.22, 1.0);
uniform vec4 bright : source_color = vec4(0.85, 0.95, 1.0, 1.0);

varying vec3 wn;
varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 to_cam = normalize(CAMERA_POSITION_WORLD - wp);
	vec3 r = reflect(-to_cam, wn);
	float sky = smoothstep(-0.1, 0.6, r.y);
	float streak = pow(max(0.0, 1.0 - abs(r.y - 0.35) * 5.0), 6.0);
	ALBEDO = mix(dark.rgb, vec3(0.2, 0.32, 0.5), sky) + bright.rgb * streak;
}
