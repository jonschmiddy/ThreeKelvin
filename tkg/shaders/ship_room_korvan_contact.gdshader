shader_type canvas_item;
render_mode unshaded, blend_mul;

// The film's contact shadow (core.contact) as one multiply: an ellipse round the feet, solid inside, its rim
// ordered-dithered on the frame's grid. cs = (centre x, x radius, feet row, length + darkness), one slot.

instance uniform vec4 cs = vec4(0.0, 2.0, 0.0, 3.5);

varying vec2 fp;

void vertex() {
	fp = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float bay(ivec2 q) {
	float B[16] = float[](0., 8., 2., 10., 12., 4., 14., 6., 3., 11., 1., 9., 15., 7., 13., 5.);
	return B[(q.y & 3) * 4 + (q.x & 3)] / 16.0;
}

void fragment() {
	ivec2 q = ivec2(floor(fp));
	float len = floor(cs.w);
	float cdark = cs.w - len;
	float dy = float(q.y) - cs.z;
	float r = sqrt(pow((float(q.x) - cs.x) / cs.y, 2.0) + pow((dy + 1.0) / (len + 1.0), 2.0));
	float k = clamp(1.0 - r, 0.0, 1.0);
	bool on = dy >= -1.0 && dy <= len && (k > 0.35 || (k > 0.0 && bay(q) < k / 0.35));
	float f = on ? 1.0 - cdark * clamp(0.45 + k, 0.0, 1.0) : 1.0;
	COLOR = vec4(f, f, f, 1.0);
}
