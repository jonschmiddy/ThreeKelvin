shader_type canvas_item;
render_mode unshaded, blend_disabled;

// R14 BIG CRUNCH, the pour: the approved film's r14.py `sky_pour()` per pixel. Every pixel
// at distance r from the sink shows the world from further out along its ray,
// R0 = sqrt(r^2 + A^2) + B, six taps over the last 1/14 s for the smear; where R0 lands past
// the window there is no sky left, so the pixel is void. The moving gas is lit by its own
// speed. After the burst the same pass maps the sky back out behind the shock ring.
// Why: docs/why/SeqBigCrunch.md#pour

#include "res://shaders/jump/jump_common.gdshaderinc"

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform vec4 world = vec4(0.0, 0.0, 960.0, 540.0);
uniform vec4 win = vec4(0.0, 0.0, 960.0, 540.0);
uniform vec2 pc = vec2(203.0, 282.0);
// 0 the world as it is, 1 the pour, 2 the burst
uniform int phase = 0;
uniform vec2 ab[6];
uniform float p_t = 0.0;
uniform float th = 0.0;
uniform float rb = 0.0;
uniform float empty = 1.0;
uniform float charge = 0.0;
uniform float kb = -1.0;

const vec3 VOID = vec3(5.0, 3.0, 10.0) / 255.0;
const float SPAN = 1.0 / 14.0;

float shock_r(float k) {
	return 8.0 + 1150.0 * (1.0 - exp(-k / 0.40));
}

void fragment() {
	vec2 p = floor(SCREEN_UV / SCREEN_PIXEL_SIZE);
	vec2 px = SCREEN_PIXEL_SIZE;
	if (phase == 0) {
		COLOR = vec4(j_world(screen, px, p, world), 1.0);
	} else {
		vec2 d = p - pc;
		float RP = length(d) + 1e-3;
		vec2 U = d / RP;
		vec3 sky;
		if (phase == 1) {
			// the window's interior edge along this ray
			float sx = U.x > 0.0 ? (win.x + win.z - 1.0 - pc.x) / U.x : (U.x < 0.0 ? (win.x - pc.x) / U.x : 1e9);
			float sy = U.y > 0.0 ? (win.y + win.w - 1.0 - pc.y) / U.y : (U.y < 0.0 ? (win.y - pc.y) / U.y : 1e9);
			float RMAX = min(sx, sy);
			vec3 acc = vec3(0.0);
			float R0a = 0.0, R0b = 0.0;
			for (int j = 0; j < 6; j++) {
				float A = ab[j].x, B = ab[j].y;
				float R0 = sqrt(RP * RP + A * A) + B;
				vec3 src = j_world(screen, px, floor(pc + U * R0 + 0.5), world);
				float vf = clamp((R0 - RMAX + 22.0) / 22.0, 0.0, 1.0) > j_dith4(p) ? 1.0 : 0.0;
				acc += mix(src, VOID, vf);
				if (j == 0) {
					R0a = R0;
				}
				R0b = R0;
			}
			sky = acc / 6.0;
			float flow = (R0a - R0b) / SPAN;
			float fl = clamp(flow / 500.0, 0.0, 3.0);
			float base = max(max(sky.r, max(sky.g, sky.b)) - 8.0 / 255.0, 0.0);
			float heat = (1.8 * p_t + 0.8 * th * p_t) * exp(-max(RP - rb, 0.0) / 150.0) * empty;
			sky = VOID + (sky - VOID) * (1.0 + charge + 1.4 * fl + heat) + base * (0.9 * fl + 0.6 * heat) * (J_LIL * 0.6 + J_VIO * 0.4);
		} else {
			float S = shock_r(kb);
			float push = 34.0 * exp(-kb / 0.30) * exp(-max(S - RP, 0.0) / 55.0);
			float sp = 6.0 * exp(-kb / 0.5) * sin(TAU * kb / 0.5);
			float R0 = max(RP - push - sp * clamp(RP / 400.0, 0.0, 1.0), 0.0);
			sky = j_world(screen, px, floor(pc + U * R0 + 0.5), world);
			bool inside = clamp((S - RP) / 6.0, 0.0, 1.0) > j_dith4(p);
			sky = inside ? sky : VOID;
		}
		COLOR = vec4(clamp(sky, 0.0, 1.0), 1.0);
	}
}
