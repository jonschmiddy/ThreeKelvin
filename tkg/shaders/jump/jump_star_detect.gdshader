shader_type canvas_item;
render_mode unshaded, blend_disabled;

// Finds the stars in the sky as it was (`JumpStars`), as the films' Python did: a pixel
// brighter than its surround by STEP (the mean of its 5x5 ring, which skips a 2x2 star's
// own block) and the peak of its 3x3, inside the window by a margin and off the hull.
// Red where a star is, green where any pixel stands out (the film's CAND, which its cluster
// test counts); alpha a half, so a full byte is only ever a mark. Drawn once and read back.
// Why: docs/why/JumpStars.md#lift

uniform sampler2D src : filter_nearest, repeat_disable;
uniform vec4 world = vec4(0.0, 0.0, 960.0, 540.0);
uniform vec4 keep_out = vec4(0.0);
uniform float margin = 4.0;
const float STEP = 12.0 / 255.0;

float lum(vec2 q) {
	vec2 px = 1.0 / vec2(textureSize(src, 0));
	vec3 c = texture(src, (q + 0.5) * px).rgb;
	return max(c.r, max(c.g, c.b));
}

void fragment() {
	vec2 p = floor(FRAGCOORD.xy) + world.xy;
	float l = lum(p);
	float ring = 0.0;
	float mx = 0.0;
	for (int y = -2; y <= 2; y++) {
		for (int x = -2; x <= 2; x++) {
			if (x == 0 && y == 0) {
				continue;
			}
			float v = lum(p + vec2(float(x), float(y)));
			if (abs(x) <= 1 && abs(y) <= 1) {
				mx = max(mx, v);
			} else {
				ring += v;
			}
		}
	}
	ring /= 16.0;
	bool inside = p.x >= world.x + margin && p.y >= world.y + margin
		&& p.x < world.x + world.z - margin && p.y < world.y + world.w - margin;
	bool on_hull = p.x >= keep_out.x && p.y >= keep_out.y
		&& p.x < keep_out.x + keep_out.z && p.y < keep_out.y + keep_out.w;
	bool cand = l - ring > STEP;
	bool star = cand && l >= mx && inside && !on_hull;
	COLOR = vec4(star ? 1.0 : 0.0, cand ? 1.0 : 0.0, 0.0, 0.5);
}
