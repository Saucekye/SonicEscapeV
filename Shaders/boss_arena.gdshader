// Boss arena dressing, in the spirit of Animal Well's glowing caves (all
// original, drawn here in code). Covers the arena's terrain layer and the air
// around it, using a small map of which tiles are solid (one pixel per tile):
//  - ground: dark carved interior with rows of wave patterns and a few brick
//    blocks, lit near the surface and fading to black deeper in
//  - surfaces: a glowing cyan line on floors, blue on walls and ceilings,
//    with a soft blue halo spilling into the room
// Drawn on the tileset's own pixel grid. Set up by boss_arena.gd, for the boss
// arenas and the rest stops.
shader_type canvas_item;

uniform sampler2D occ : filter_nearest;   // 1 pixel per tile, white = solid
uniform vec2 occ_origin;                  // tile coordinate of occ's first pixel
uniform vec2 rect_origin;                 // this rect's top-left, in tileset pixels
uniform float tile = 16.0;
uniform bool animate = true;
uniform bool fireflies = true;
uniform vec4 firefly_color : source_color = vec4(1.0, 0.8, 0.2, 1.0);

uniform vec4 floor_line : source_color = vec4(0.47, 1.0, 0.92, 1.0);
uniform vec4 floor_line2 : source_color = vec4(0.12, 0.62, 0.78, 1.0);
uniform vec4 wall_line : source_color = vec4(0.24, 0.55, 1.0, 1.0);
uniform vec4 wall_line2 : source_color = vec4(0.09, 0.25, 0.66, 1.0);
uniform vec4 fill_base : source_color = vec4(0.016, 0.02, 0.07, 1.0);
uniform vec4 wave_color : source_color = vec4(0.15, 0.22, 0.58, 1.0);
uniform vec4 brick_color : source_color = vec4(0.25, 0.15, 0.48, 1.0);
uniform vec4 halo_color : source_color = vec4(0.16, 0.45, 1.0, 1.0);
uniform float halo_strength = 0.55;

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX + rect_origin;
}

float hash(float n) {
	return fract(sin(n * 127.1 + 311.7) * 43758.5453);
}

float hash2(vec2 v) {
	return fract(sin(dot(v, vec2(12.9898, 78.233))) * 43758.5453);
}

bool solid_cell(vec2 cell) {
	ivec2 i = ivec2(cell - occ_origin);
	ivec2 s = textureSize(occ, 0);
	if (i.x < 0 || i.y < 0 || i.x >= s.x || i.y >= s.y) {
		return false;
	}
	return texelFetch(occ, i, 0).r > 0.5;
}

bool solid_px(vec2 p) {
	return solid_cell(floor(p / tile));
}

// Distance from a pixel centre to the nearest tile of the other kind (solid/air)
float dist_other(vec2 p, bool s) {
	vec2 pc = p + 0.5;
	vec2 cell = floor(p / tile);
	float best = 99.0;
	for (int dy = -2; dy <= 2; dy++) {
		for (int dx = -2; dx <= 2; dx++) {
			vec2 n = cell + vec2(float(dx), float(dy));
			if (solid_cell(n) != s) {
				vec2 lo = n * tile;
				vec2 hi = lo + tile;
				vec2 d = max(vec2(0.0), max(lo - pc, pc - hi));
				best = min(best, length(d));
			}
		}
	}
	return best;
}

void fragment() {
	vec2 p = floor(local_pos);
	float t = animate ? TIME : 0.0;
	bool s = solid_px(p);
	vec4 col = vec4(0.0);

	if (s) {
		float d = dist_other(p, true);
		bool top = !solid_px(p - vec2(0.0, 1.0)) || !solid_px(p - vec2(0.0, 2.0));
		if (d < 1.0) {
			col = top ? floor_line : wall_line;
		} else if (d < 2.0) {
			col = top ? floor_line2 : wall_line2;
		} else if (d < 3.0 && mod(p.x + p.y, 2.0) < 1.0) {
			col = vec4((top ? floor_line2.rgb : wall_line2.rgb) * 0.55, 1.0);   // dithered falloff
		} else {
			// Lit near the surface, black deeper in
			float fade = clamp(1.0 - (d - 2.0) / 26.0, 0.0, 1.0);
			vec3 c = fill_base.rgb + vec3(0.02, 0.05, 0.12) * fade * fade;
			vec2 block = floor(p / 32.0);
			bool brick = hash2(block) > 0.72;
			bool on = false;
			if (brick) {
				// Staggered bricks
				float row = floor(p.y / 8.0);
				float bx = mod(p.x + mod(row, 2.0) * 8.0, 16.0);
				on = mod(p.y, 8.0) < 1.0 || bx < 1.0;
			} else {
				// Rows of little waves
				float w = floor(abs(mod(p.x, 8.0) - 4.0) * 0.5);
				on = mod(p.y - w, 6.0) < 1.0;
			}
			if (on) {
				float k = fade;
				// Dither the pattern away as it gets deeper
				bool dither = mod(p.x + p.y, 2.0) < 1.0;
				if (k > 0.45 || (k > 0.15 && dither)) {
					c = mix(c, brick ? brick_color.rgb : wave_color.rgb, clamp(0.35 + k * 0.65, 0.0, 1.0));
				}
			}
			col = vec4(c, 1.0);
		}
	} else {
		float d = dist_other(p, false);
		// Soft halo off every surface
		if (d < 26.0) {
			float g = (exp(-d / 3.0) * 0.7 + exp(-d / 9.0) * 0.3) * halo_strength;
			col = vec4(halo_color.rgb, g);
		}
		// Fireflies: at most one per 40-pixel cell, wandering and blinking
		if (fireflies) {
			vec2 fc = floor(p / 40.0);
			for (int fy = -1; fy <= 1; fy++) {
				for (int fx = -1; fx <= 1; fx++) {
					vec2 c = fc + vec2(float(fx), float(fy));
					float hf = hash2(c + 5.3);
					if (hf < 0.45) {
						continue;
					}
					float ph = hf * 40.0;
					vec2 pos = c * 40.0 + 20.0 + vec2(sin(t * 0.37 + ph) * 15.0 + sin(t * 0.91 + ph * 1.7) * 6.0,
							cos(t * 0.29 + ph * 1.3) * 13.0 + sin(t * 0.73 + ph) * 5.0);
					pos = floor(pos);
					float blink = clamp(sin(t * (0.8 + hf) + ph) * 1.4 + 0.5, 0.0, 1.0);
					vec2 o = abs(p - pos);
					float a = 0.0;
					if (o.x + o.y < 1.5) {
						a = 1.0;                                  // core
					} else if ((o.x < 0.5 || o.y < 0.5) && o.x + o.y < 3.5) {
						a = 0.7;                                  // "+" arms
					} else if (length(o) < 6.0) {
						a = 0.22 * (1.0 - length(o) / 6.0) + 0.06;   // glow
					}
					a *= blink;
					if (a > 0.0) {
						vec3 fcol = a > 0.9 ? vec3(1.0, 0.95, 0.6) : firefly_color.rgb;
						col.rgb = mix(col.rgb, fcol, a);
						col.a = max(col.a, a);
					}
				}
			}
		}
	}
	COLOR = col;
}
