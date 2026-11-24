shader_type canvas_item;
render_mode unshaded;

// A puff of steam or smoke (hero.draw_puffs): a disc fading out from its middle, stepped on the frame's
// grid, laid over what is there. Each rect is one puff 2r+1 wide; COLOR.r = radius / 16, COLOR.g = alpha.

varying vec2 fp;
varying vec4 pc;

void vertex() {
	fp = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	pc = COLOR;
}

float bay(ivec2 q) {
	float B[16] = float[](0., 8., 2., 10., 12., 4., 14., 6., 3., 11., 1., 9., 15., 7., 13., 5.);
	return B[(q.y & 3) * 4 + (q.x & 3)] / 16.0;
}

void fragment() {
	ivec2 q = ivec2(floor(fp));
	float rad = pc.r * 16.0;
	float rr = ceil(rad);
	float n = 2.0 * rr + 1.0;
	vec2 o = floor(UV * n) - rr;
	float k = clamp(1.0 - length(o) / max(rad, 0.5), 0.0, 1.0) * pc.g * 1.4;
	float v = clamp(k, 0.0, 2.5) * 6.0;
	float lo = floor(v);
	float fr = v - lo;
	k = (lo + ((fr > 0.75 && bay(q) < (fr - 0.75) * 4.0) ? 1.0 : 0.0)) / 6.0 / 1.4;
	COLOR = vec4(150.0 / 255.0, 160.0 / 255.0, 172.0 / 255.0, k);
}
