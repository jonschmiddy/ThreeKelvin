// R1 HYPERSPACE's colours and its star law (r1.py), shared by the streak instances
// (`jump_lines.gdshader`) and the world pass (`jump_r1.gdshader`), which must agree on
// where every star is.
// Why: docs/why/SeqHyperspace.md#stars

const vec3 R1_VIO = vec3(0.62, 0.36, 1.00);
const vec3 R1_LIL = vec3(0.86, 0.74, 1.00);
const vec3 R1_WHT = vec3(1.00, 0.96, 1.00);
const vec3 R1_MAG = vec3(1.00, 0.40, 0.86);

// Where the star at `home` has leaned toward the pinhole at stretch S: head and tail.
// Near stars lag (`u` is the star's rolled lag); after the hit the lag fades with S so
// every star settles on its home and none is thrown past it.
void r1_star(vec2 home, vec2 vp, float S, bool after, bool extra, float u, out vec2 head, out vec2 tail) {
	vec2 D = home - vp;
	float R = length(vec2(D.x, D.y * 1.6));
	float LAG = 0.6 * clamp(R / 700.0, 0.0, 1.0) + u;
	float Sp = S;
	if (S > 0.0) {
		if (extra) {
			Sp = after ? S * (1.0 - LAG * 0.3 / 0.72) : clamp(S - LAG * 0.3, -0.2, 0.985);
		} else {
			float lg = LAG * 0.35 * max(0.0, 1.0 - abs(S) * 0.9);
			Sp = after ? S * (1.0 - lg / 0.72) : clamp(S - lg, -0.2, 0.985);
		}
	}
	head = vp + D * (1.0 - Sp);
	tail = home;
	if (S < 0.0) {
		tail = vp + D * (1.0 - S * 1.3);
		head = home;
	}
}

// How much of the star's own dot stays on its home pixel: all of it while it is a dot, none
// once it is a streak; after the hit a short streak fades in over the dot (1.2 to 14 px).
float r1_keep(float slen, bool after) {
	if (!after) {
		return slen > 1.2 ? 0.0 : 1.0;
	}
	float g = clamp((slen - 1.2) / 12.8, 0.0, 1.0);
	return 1.0 - g * g * (3.0 - 2.0 * g);
}
