shader_type spatial;
// A flung body in Salvage
render_mode unshaded, cull_disabled, shadows_disabled;

uniform sampler2D sheet : source_color, filter_nearest;
uniform vec4 region = vec4(0.0, 0.0, 1.0, 1.0);   // the frame in the sheet
uniform bool flip = false;
uniform vec2 size = vec2(1.0, 1.0);               // metres
uniform float spin = 0.0;                         // radians, round the line to the camera
uniform vec4 tint : source_color = vec4(1.0);

void vertex() {
	vec2 corner = VERTEX.xy * size;
	float c = cos(spin);
	float s = sin(spin);
	vec2 turned = vec2(c * corner.x - s * corner.y, s * corner.x + c * corner.y);
	vec4 centre = MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0);
	POSITION = PROJECTION_MATRIX * (centre + vec4(turned, 0.0, 0.0));
}

void fragment() {
	vec2 uv = vec2(flip ? 1.0 - UV.x : UV.x, UV.y);
	vec4 px = texture(sheet, region.xy + uv * region.zw);
	if (px.a < 0.5) {
		discard;
	}
	ALBEDO = px.rgb * tint.rgb;
}
