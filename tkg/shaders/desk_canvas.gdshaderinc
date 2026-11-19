// The page's 1920 x 1080 canvas, read back from the room's 384 x 216 viewport: the art at 5x, and
// the CRT's scanlines on the glass rows (DESK 1: a 0.34 dark row and a 0.12 one per art row, as the
// page fills them, in 8-bit; each room its own, `scan_mul`: the fifth row's and the first's). `desk_tube` and `desk_mean` both read the canvas through this.
// Why: docs/why/DeskScene.md#the-plan

uniform sampler2D room_tex : filter_nearest, repeat_disable;
uniform bool scan_on = false;
// (z 1: the fifth row is floored, v * x truncated, as Chrome blends DESK 2's 0.3 fill)
uniform vec3 scan_mul = vec3(0.6588235, 0.8784314, 0.0);

const ivec4 GLASS_C = ivec4(585, 110, 750, 700);

vec3 canvas_px(ivec2 c) {
	vec3 v = floor(texelFetch(room_tex, c / 5, 0).rgb * 255.0 + 0.5);
	if (scan_on && c.x >= GLASS_C.x && c.x < GLASS_C.x + GLASS_C.z && c.y >= GLASS_C.y && c.y < GLASS_C.y + GLASS_C.w) {
		int r = (c.y - GLASS_C.y) % 5;
		if (r == 4) v = scan_mul.z > 0.5 ? floor(v * scan_mul.x + 0.0001) : floor(v * scan_mul.x + 0.5);
		else if (r == 0 && scan_mul.y < 1.0) v = floor(v * scan_mul.y + 0.5);
	}
	return v;
}
