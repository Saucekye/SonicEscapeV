shader_type canvas_item;
uniform float scalar_x : hint_range(-5, 5) = 1.25;

void vertex() {
	// Called for every vertex the material is visible on.
	UV.x += TIME * scalar_x;
}