// Skins the flat silhouette terrain with Sonic Rush Adventure art.
// The tileset's solid fill colour is replaced by a fill texture laid out in
// world space (same pixel size as the characters), and the edge line is recoloured.
// Any other colours in the tileset (hazards etc.) are left untouched.
shader_type canvas_item;

uniform sampler2D fill_tex : filter_nearest, repeat_enable;
uniform vec4 fill_key : source_color = vec4(0.0, 0.0, 0.0, 1.0);   // tileset fill colour to replace
uniform vec4 edge_key : source_color = vec4(0.0, 0.6, 1.0, 1.0);   // tileset edge colour to replace
uniform vec4 edge_color : source_color = vec4(0.2, 0.2, 0.2, 1.0); // new edge colour
// Loops keep the default tileset colours on every stage, so match those too
uniform vec4 alt_fill_key : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 alt_edge_key : source_color = vec4(0.0, 0.608, 1.0, 1.0);
uniform float texel_world = 1.125;   // world units per art pixel (matches the characters)
uniform float fill_size = 64.0;      // size of one fill block in art pixels
uniform float fill_count = 1.0;      // how many block variants sit side by side in fill_tex
uniform float main_share = 0.6;      // how often the first (main) block is used; the rest share the remainder
uniform float fill_darken = 0.85;    // keep the ground a touch darker than the play layer
uniform bool fill_all = false;       // terrain depth copy: every solid pixel becomes fill (no edges)

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 c = COLOR;
	if (c.a > 0.5) {
		if (fill_all || distance(c.rgb, fill_key.rgb) < 0.05 || distance(c.rgb, alt_fill_key.rgb) < 0.05) {
			// Snap to whole art pixels so the fill stays crisp
			vec2 texel = floor(world_pos / texel_world);
			// Pick a block variant per cell, so the ground doesn't repeat like wallpaper
			vec2 cell = floor(texel / fill_size);
			float h = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
			float variant = 0.0;
			if (fill_count > 1.5 && h > main_share) {
				variant = 1.0 + floor((h - main_share) / (1.0 - main_share) * (fill_count - 1.0));
				variant = min(variant, fill_count - 1.0);
			}
			vec2 in_cell = mod(texel, fill_size) + 0.5;
			vec2 uv = vec2((variant * fill_size + in_cell.x) / (fill_size * fill_count), in_cell.y / fill_size);
			vec3 f = texture(fill_tex, uv).rgb;
			COLOR = vec4(f * fill_darken, c.a);
		} else if (distance(c.rgb, edge_key.rgb) < 0.08 || distance(c.rgb, alt_edge_key.rgb) < 0.08) {
			COLOR = vec4(edge_color.rgb, c.a);
		}
	}
}
