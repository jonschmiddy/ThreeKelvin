shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;

// The holo-table's turning hull (booth11.draw_holo) drawn on the GPU: each edge is the film's pixel line (its
// rounded ends, one pixel a step along the longer axis, half to even), laid over what is under it at its alpha in
// order, then the scanlines rolling through. Ends in the room's 38 x 26 canvas. Why: docs/why/ShipRoomKorvan.md#cost

uniform vec4 seg[64];
uniform vec4 segc[64];
uniform int nseg = 0;
uniform int scan_off = 0;
uniform float scan_k = 1.0;
uniform vec2 origin = vec2(418.0, 158.0);

varying vec2 fp;

void vertex() {
	fp = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

int hits(vec2 p, vec4 s) {
	vec2 a = s.xy;
	vec2 d = s.zw - s.xy;
	float n = max(1.0, max(abs(d.x), abs(d.y)));
	if (d.x == 0.0 && d.y == 0.0) {
		return p == a ? 2 : 0;
	}
	if (abs(d.x) >= abs(d.y)) {
		float i = (p.x - a.x) * sign(d.x);
		if (i < 0.0 || i > n) {
			return 0;
		}
		return roundEven(a.y + d.y * i / n) == p.y ? 1 : 0;
	}
	float i = (p.y - a.y) * sign(d.y);
	if (i < 0.0 || i > n) {
		return 0;
	}
	return roundEven(a.x + d.x * i / n) == p.x ? 1 : 0;
}

void fragment() {
	vec2 p = floor(fp) - origin;
	vec3 C = vec3(0.0);
	float A = 0.0;
	for (int i = 0; i < nseg; i++) {
		int h = hits(p, seg[i]);
		for (int k = 0; k < h; k++) {
			float a = segc[i].a;
			C = segc[i].rgb * a + C * (1.0 - a);
			A = a + A * (1.0 - a);
		}
	}
	if (int(p.y) + scan_off - 3 * ((int(p.y) + scan_off) / 3) == 0 && p.x >= 8.0 && p.x <= 30.0) {
		C *= scan_k;
		A = (1.0 - scan_k) + A * scan_k;
	}
	COLOR = vec4(C, A);
}
