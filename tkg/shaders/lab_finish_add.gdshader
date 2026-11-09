shader_type canvas_item;
render_mode unshaded, blend_add;

// THE LAB SCREEN'S GLOW, over everything on the glass (science S9, the
// mockup's `finish`): a lit rim of phosphor at the glass's edge in the lab's
// tint, two dithered steps, and one diagonal band of glare. Added, so it
// brightens the board and its words a touch the way the mockup's did.
// `lab_finish_mul` darkens (the scanlines and the bezel's shadow).

uniform vec2 gsize = vec2(908.0, 488.0);
// Where the glare's corner is, in glass px: the glass's own top-left, or where
// the window's corner sees the glass when the camera has it past the window
// (`LabZoom`), so the glare lies where it always did on the board.
uniform vec2 glare_at = vec2(0.0);
uniform vec3 tint = vec3(190.0, 240.0, 235.0);
uniform float amount = 1.0;

float bayer(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int m[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return float(m[y * 4 + x]) / 16.0;
}

void fragment() {
	vec2 l = min(floor(UV * gsize), gsize - 1.0);
	float e = min(min(l.x, l.y), min(gsize.x - 1.0 - l.x, gsize.y - 1.0 - l.y));
	float rim = e >= 3.0 ? clamp(1.0 - (e - 3.0) / 7.0, 0.0, 1.0) : 0.0;
	float rs = floor(rim * 2.0 + bayer(l)) / 2.0;
	vec3 add = tint * (0.07 * rs);
	vec2 lg = l - glare_at;
	float d = lg.x * 0.5 + lg.y;
	if (d < 132.0 && d > 104.0 && lg.x >= 0.0 && lg.y >= 0.0 && bayer(l) < 0.5) {
		add += vec3(7.0);
	}
	COLOR = vec4(add / 255.0 * amount, 1.0);
}
