shader_type canvas_item;
render_mode unshaded, blend_disabled;

// The sky's stars, found once for R14 (`SeqBigCrunch`): on the LOCAL sky's own 480x270
// picture, a texel brighter than the ring two texels round it by 12 levels, the peak of its
// 3x3, and not part of a bright blob (a sun, a world, a station). Out: the star's light over
// its ground in rgb, 1 in alpha where it is a star. Read back once and scanned.
// Why: docs/why/SeqBigCrunch.md#stars

uniform sampler2D sky : filter_nearest, repeat_disable;

vec3 px(ivec2 q) {
	return texelFetch(sky, q, 0).rgb;
}

float lum(vec3 c) {
	return max(c.r, max(c.g, c.b));
}

void fragment() {
	ivec2 q = ivec2(floor(UV * vec2(textureSize(sky, 0))));
	vec3 c = px(q);
	float L = lum(c);
	// the ground: the mean of the ring two texels out
	vec3 ring = vec3(0.0);
	float n = 0.0;
	for (int dy = -2; dy <= 2; dy++) {
		for (int dx = -2; dx <= 2; dx++) {
			if (abs(dx) == 2 || abs(dy) == 2) {
				ring += px(q + ivec2(dx, dy));
				n += 1.0;
			}
		}
	}
	ring /= n;
	float bg = lum(ring);
	bool cand = L - bg > 12.0 / 255.0;
	bool peak = true;
	int blob = 0;
	if (cand) {
		for (int dy = -1; dy <= 1; dy++) {
			for (int dx = -1; dx <= 1; dx++) {
				if ((dx != 0 || dy != 0) && lum(px(q + ivec2(dx, dy))) > L) {
					peak = false;
				}
			}
		}
		for (int dy = -3; dy <= 3; dy++) {
			for (int dx = -3; dx <= 3; dx++) {
				if (lum(px(q + ivec2(dx, dy))) - bg > 12.0 / 255.0) {
					blob++;
				}
			}
		}
	}
	bool star = cand && peak && blob <= 5;
	COLOR = star ? vec4(max(c - ring, vec3(0.0)), 1.0) : vec4(0.0);
}
