// The page's 1920 x 1080 canvas, read back from the room's 384 x 216 viewport: the art at 5x, and
// the CRT's scanlines on the glass rows (DESK 1: a 0.34 dark row and a 0.12 one per art row, as the
// page fills them, in 8-bit; each room its own, `scan_mul`: the fifth row's and the first's). `desk_tube` and `desk_mean` both read the canvas through this.
// Why: docs/why/DeskScene.md#the-plan

uniform sampler2D room_tex : filter_nearest, repeat_disable;
uniform bool scan_on = false;
// (z 1: the fifth row is floored, v * x truncated, as Chrome blends DESK 2's 0.3 fill)
uniform float canvas_fade = 0.0;
// the NOOK's scope: its own lighter scanline (rows 97 to 109 of art, x 16 to 32)
uniform bool scan2_on = false;
const ivec4 SCOPE_C = ivec4(80, 485, 85, 65);
uniform vec3 scan_mul = vec3(0.6588235, 0.8784314, 0.0);

const ivec4 GLASS_C = ivec4(585, 110, 750, 700);

vec3 canvas_px(ivec2 c) {
	vec3 v = floor(texelFetch(room_tex, c / 5, 0).rgb * 255.0 + 0.5);
	if (scan_on && c.x >= GLASS_C.x && c.x < GLASS_C.x + GLASS_C.z && c.y >= GLASS_C.y && c.y < GLASS_C.y + GLASS_C.w) {
		int r = (c.y - GLASS_C.y) % 5;
		if (r == 4) v = scan_mul.z > 0.5 ? floor(v * scan_mul.x + 0.0001) : floor(v * scan_mul.x + 0.5);
		else if (r == 0 && scan_mul.y < 1.0) v = floor(v * scan_mul.y + 0.5);
	}
	if (scan2_on && c.x >= SCOPE_C.x && c.x < SCOPE_C.x + SCOPE_C.z && c.y >= SCOPE_C.y && c.y < SCOPE_C.y + SCOPE_C.w && (c.y - SCOPE_C.y) % 5 == 4)
		v = floor(v * (199.0 / 255.0) + 0.5);
	// a room fading in: the page's black over the whole canvas (BUNK), as Chrome blends it
	if (canvas_fade > 0.0) v = floor(v * (255.0 - floor(canvas_fade * 255.0 + 0.5)) / 255.0 + 0.5);
	return v;
}
