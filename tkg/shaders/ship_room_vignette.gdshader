shader_type canvas_item;
render_mode unshaded, blend_mul;

// The ship-select rooms' vignette (PORT.md, draw order 8): k = clip(1.25 - 0.55 d, 0.55, 1),
// d the distance from the frame's centre in units of 0.62 of the frame, multiplied over all.

varying vec2 fp;

void vertex() {
	fp = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 p = floor(fp);
	vec2 q = (p - vec2(480.0, 270.0)) / (vec2(960.0, 540.0) * 0.62);
	float k = clamp(1.25 - length(q) * 0.55, 0.55, 1.0);
	COLOR = vec4(vec3(k), 1.0);
}
