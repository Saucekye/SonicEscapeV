// Sonic Rush Adventure ground, painted onto the tiles' own shapes
shader_type canvas_item;

uniform sampler2D mask_tex : filter_nearest;   // the layer's solid pixels
uniform vec2 mask_origin;                       // where the mask starts, in the layer's pixels
uniform vec2 layer_origin;
uniform vec2 layer_scale = vec2(1.0);
uniform sampler2D fill_tex : filter_nearest, repeat_enable;
uniform float fill_size = 64.0;      // one fill block, in art pixels
uniform float fill_count = 1.0;      // block variants side by side in fill_tex
uniform float main_share = 0.6;      // how often the first one is used
uniform sampler2D strip_tex : filter_nearest, repeat_enable;
uniform vec2 strip_size = vec2(64.0, 32.0);
uniform bool surfaces = true;
uniform float texel_world = 1.125;   // world units per art pixel
uniform float art_per_px = 2.133;    // art pixels in one layer pixel
uniform float shade_depth = 40.0;
uniform float shade_strength = 0.45;
uniform vec4 env_shadow : source_color = vec4(0.1, 0.1, 0.12, 1.0);
uniform vec4 env_light : source_color = vec4(0.9, 0.9, 0.9, 1.0);
uniform float env_blend = 0.6;
uniform float deep_depth = 140.0;     // art pixels down to the darkest
uniform float deep_dark = 0.5;        // how dark the deep ground gets
uniform float fill_contrast = 0.7;    // the fill blocks, toned down so the surface stands out
uniform float rim_light = 0.55;       // the sky's light along the very top

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

bool solid(ivec2 p) {
	ivec2 size = textureSize(mask_tex, 0);
	if (p.y < 0 || p.y >= size.y) {
		return false;
	}
	// Past the left or right end it carries on into the next chunk
	p.x = clamp(p.x, 0, size.x - 1);
	return texelFetch(mask_tex, p, 0).a > 0.5;
}

void fragment() {
	vec4 c = COLOR;
	if (c.a > 0.5) {
		vec2 local = (world_pos - layer_origin) / layer_scale - mask_origin;
		ivec2 p = ivec2(floor(local));
		// How far down from the open air above (in layer pixels)
		float depth = 999.0;
		if (surfaces) {
			// One pixel at a time near the top, then in bigger steps further down
			int near = int(ceil((strip_size.y + shade_depth) / art_per_px)) + 1;
			int far = int(ceil(deep_depth / art_per_px));
			int i = 1;
			for (int k = 0; k < 96; k++) {
				if (i > far) {
					break;
				}
				if (!solid(p - ivec2(0, i))) {
					depth = float(i - 1) + fract(local.y);
					break;
				}
				i += i < near ? 1 : 3;
			}
		}
		float depth_art = depth * art_per_px;
		vec2 texel = floor(world_pos / texel_world);
		vec3 col;
		if (depth_art < strip_size.y) {
			vec2 uv = vec2((mod(texel.x, strip_size.x) + 0.5) / strip_size.x, (floor(depth_art) + 0.5) / strip_size.y);
			col = texture(strip_tex, uv).rgb;
		} else {
			// Fill blocks, one variant per block
			vec2 cell = floor(texel / fill_size);
			float h = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
			float variant = 0.0;
			if (fill_count > 1.5 && h > main_share) {
				variant = min(1.0 + floor((h - main_share) / (1.0 - main_share) * (fill_count - 1.0)), fill_count - 1.0);
			}
			vec2 in_cell = mod(texel, fill_size) + 0.5;
			col = texture(fill_tex, vec2((variant * fill_size + in_cell.x) / (fill_size * fill_count), in_cell.y / fill_size)).rgb;
			// Toned down, so it reads as the ground behind the surface
			float fl = dot(col, vec3(0.299, 0.587, 0.114));
			col = mix(vec3(fl), col, 0.8);
			col = mix(vec3(0.35), col, fill_contrast);
			// Darker just under the surface, and darker still the deeper it goes
			float below = depth_art - strip_size.y;
			float s = clamp(1.0 - below / shade_depth, 0.0, 1.0);
			col *= 1.0 - shade_strength * s * s;
			col *= mix(0.9, deep_dark, smoothstep(0.0, deep_depth, below));
		}
		// A dark rim where the ground meets open air at the sides and underneath
		if (!solid(p + ivec2(1, 0)) || !solid(p - ivec2(1, 0)) || !solid(p + ivec2(0, 1))) {
			col *= 0.45;
		}
		// Lit like the background: its darkest colour in the shadows, its brightest in the light
		float lum = dot(col, vec3(0.299, 0.587, 0.114));
		vec3 graded = mix(env_shadow.rgb, env_light.rgb, smoothstep(0.0, 1.0, lum));
		col = mix(col, graded, env_blend);
		// The sky's light catching the top edge
		if (depth_art < 2.0) {
			col = mix(col, env_light.rgb, rim_light);
		}
		COLOR = vec4(col, c.a);
	}
}
