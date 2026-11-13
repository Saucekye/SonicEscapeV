shader_type spatial;

void vertex() {
	vec2 translate = UV.x + vec2(10.0, 0.0);
	VERTEX += vec3(10.0, 0.0, 0.0);
}

void fragment() {
	
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
