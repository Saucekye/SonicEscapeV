// Makes characters sit in their stage's lighting.
//  - tint: the stage's light colour over the whole sprite (subtle)
//  - rim: a 1-pixel highlight on the edges that face the stage's light source
//  - wet: in rain, a cool sheen on the top edges
//  - under: a glow on the bottom edges from a light below (the boss arenas'
//    glowing waterline), 1 pixel bright and a softer second pixel
//  - rim2: a second rim highlight from another direction (a coloured side light)
// Works with flip_h (mirrors the light side automatically) and keeps modulate
// (so hurt flicker etc. still work).
shader_type canvas_item;

uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 rim_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float rim_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec2 light_dir = vec2(1.0, -1.0);   // where the light comes FROM, screen space (+x right, -y up)
uniform float wet : hint_range(0.0, 1.0) = 0.0;
uniform vec4 under_color : source_color = vec4(0.47, 1.0, 0.92, 1.0);
uniform float under_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 rim2_color : source_color = vec4(1.0);
uniform float rim2_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec2 rim2_dir = vec2(1.0, 0.5);    // where the second light comes FROM
uniform float flip = 1.0;                    // -1 when the sprite is mirrored (set from the game)

varying vec4 modulate_color;

void vertex() {
	modulate_color = COLOR;   // modulate only (fragment COLOR already includes the texture)
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (c.a > 0.0) {
		c.rgb *= tint.rgb;
		// Step exactly one art pixel toward the light (a fraction would land on the same pixel)
		vec2 d = normalize(light_dir);
		vec2 dir = vec2(abs(d.x) > 0.38 ? sign(d.x) * flip : 0.0, abs(d.y) > 0.38 ? sign(d.y) : 0.0);
		vec2 step_uv = dir * TEXTURE_PIXEL_SIZE;
		float toward = texture(TEXTURE, UV + step_uv).a;
		float rim = (1.0 - step(0.5, toward)) * rim_strength;
		c.rgb = mix(c.rgb, rim_color.rgb, rim * 0.75);
		// Second rim light
		if (rim2_strength > 0.0) {
			vec2 d2 = normalize(rim2_dir);
			vec2 dir2 = vec2(abs(d2.x) > 0.38 ? sign(d2.x) * flip : 0.0, abs(d2.y) > 0.38 ? sign(d2.y) : 0.0);
			float toward2 = texture(TEXTURE, UV + dir2 * TEXTURE_PIXEL_SIZE).a;
			c.rgb = mix(c.rgb, rim2_color.rgb, (1.0 - step(0.5, toward2)) * rim2_strength * 0.75);
		}
		// Glow from below on bottom edges
		if (under_strength > 0.0) {
			float b1 = texture(TEXTURE, UV + vec2(0.0, TEXTURE_PIXEL_SIZE.y)).a;
			float b2 = texture(TEXTURE, UV + vec2(0.0, 2.0 * TEXTURE_PIXEL_SIZE.y)).a;
			float u = (1.0 - step(0.5, b1)) * 0.85 + step(0.5, b1) * (1.0 - step(0.5, b2)) * 0.35;
			c.rgb = mix(c.rgb, under_color.rgb, u * under_strength);
		}
		// Rain sheen on top edges
		if (wet > 0.0) {
			float above = texture(TEXTURE, UV + vec2(0.0, -TEXTURE_PIXEL_SIZE.y)).a;
			c.rgb = mix(c.rgb, vec3(0.8, 0.9, 1.0), (1.0 - step(0.5, above)) * wet * 0.5);
		}
	}
	COLOR = c * modulate_color;
}
