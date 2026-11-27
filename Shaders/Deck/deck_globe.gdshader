shader_type spatial;
render_mode unshaded;
// A round lamp: warm white, brightest in the middle

uniform vec4 color : source_color = vec4(1.0, 0.95, 0.82, 1.0);

varying vec3 wn;

void vertex() { wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz); }

void fragment() {
	vec3 to_cam = normalize(CAMERA_POSITION_WORLD - (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
	ALBEDO = color.rgb * (0.75 + 0.25 * abs(dot(wn, to_cam)));
}
