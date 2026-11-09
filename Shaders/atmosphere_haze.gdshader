// Atmospheric depth for background layers.
// Far layers fade toward the sky/haze colour, lose saturation and go slightly
// out of focus (depth of field), the way INARI and similar games layer depth.
shader_type canvas_item;

uniform vec4 haze_color : source_color = vec4(0.5, 0.6, 0.8, 1.0);
uniform float haze_amount : hint_range(0.0, 1.0) = 0.0;
uniform float desaturate : hint_range(0.0, 1.0) = 0.0;
uniform float blur_texels : hint_range(0.0, 4.0) = 0.0;  // depth-of-field softness, in art pixels

varying vec4 vertex_color;

void vertex() {
	vertex_color = COLOR;  // node modulate etc., applied after the blur
}

void fragment() {
	vec4 c;
	if (blur_texels > 0.01) {
		// 13-tap disc blur in texture space
		vec2 r = TEXTURE_PIXEL_SIZE * blur_texels;
		c = texture(TEXTURE, UV) * 2.0;
		c += texture(TEXTURE, UV + vec2( r.x, 0.0));
		c += texture(TEXTURE, UV + vec2(-r.x, 0.0));
		c += texture(TEXTURE, UV + vec2(0.0,  r.y));
		c += texture(TEXTURE, UV + vec2(0.0, -r.y));
		c += texture(TEXTURE, UV + r * vec2( 0.7,  0.7));
		c += texture(TEXTURE, UV + r * vec2(-0.7,  0.7));
		c += texture(TEXTURE, UV + r * vec2( 0.7, -0.7));
		c += texture(TEXTURE, UV + r * vec2(-0.7, -0.7));
		c += texture(TEXTURE, UV + r * vec2( 0.5,  0.0));
		c += texture(TEXTURE, UV + r * vec2(-0.5,  0.0));
		c += texture(TEXTURE, UV + r * vec2( 0.0,  0.5));
		c += texture(TEXTURE, UV + r * vec2( 0.0, -0.5));
		c /= 14.0;
		c *= vertex_color;
	} else {
		c = COLOR;
	}
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	c.rgb = mix(c.rgb, vec3(lum), desaturate);
	c.rgb = mix(c.rgb, haze_color.rgb, haze_amount);
	COLOR = c;
}
