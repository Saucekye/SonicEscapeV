// Glossy floor reflection. Draws a mirrored copy of a sprite below
// the floor surface, fading out with depth, with a slight horizontal shimmer.
shader_type canvas_item;

uniform float floor_y = 0.0;          // world y of the floor surface
uniform float fade_length = 60.0;     // world units below the floor until it's gone
uniform float strength : hint_range(0.0, 1.0) = 0.35;
uniform vec4 tint : source_color = vec4(0.7, 0.8, 1.0, 1.0);
uniform float shimmer = 0.0;          // horizontal wobble, in texels

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 uv = UV;
	if (shimmer > 0.0) {
		uv.x += sin(world_pos.y * 0.35 + TIME * 6.0) * TEXTURE_PIXEL_SIZE.x * shimmer;
	}
	vec4 c = texture(TEXTURE, uv);
	float depth = world_pos.y - floor_y;
	float fade = clamp(1.0 - depth / fade_length, 0.0, 1.0);
	fade *= step(0.0, depth);  // never show above the floor
	c.rgb = mix(c.rgb, c.rgb * tint.rgb, 0.6);
	c.a *= fade * fade * strength;
	COLOR = c;
}
