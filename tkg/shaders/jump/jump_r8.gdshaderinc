// R8 MAELSTROM's storm and its ship, shared by the ship pass, the warp pass and the points
// (maelstrom.py `frame`). Positions are the film's px about the eye: (screen - Tg) / S, and
// the disc's plane divides y by KY. Every pass that includes this declares these uniforms.
// Why: docs/why/SeqMaelstrom.md#storm

const float KY = 0.62;
const float RC = 120.0;

uniform vec2 Tg = vec2(655.0, 250.0);
uniform float S = 1.0;
// the twist at the core and the inflow
uniform float PH = 0.0;
uniform float P = 0.0;
// the ship's pose: the twist's weight on it, its centre's turn factor, its centre less the eye
// (film px), cos and sin of minus its extra turn, its scale, its sprite centre (canvas px)
uniform float wk = 0.0;
uniform float fc = 1.0;
uniform vec2 crel = vec2(-447.0, 32.0);
uniform vec2 cbsb = vec2(1.0, 0.0);
uniform float s_ship = 1.0;
uniform vec2 sc = vec2(167.5, 57.0);

float r8_f(float r) {
	return 1.0 / (1.0 + (r / RC) * (r / RC));
}

// The ship's canvas position (float) for a point d in the disc's plane: the same twist as the
// world, weighted while it still holds against the current (rigid at its centre's rate, plus 30%
// of the local shear), then its own turn and scale.
vec2 r8_ship_h(vec2 d) {
	float a3 = -PH * wk * (fc + 0.30 * (r8_f(length(d)) - fc));
	vec2 rd = jw_rot(d, a3);
	vec2 u = (vec2(rd.x, rd.y * KY) - crel) * S;
	return vec2(u.x * cbsb.x - u.y * cbsb.y, u.x * cbsb.y + u.y * cbsb.x) / s_ship + sc;
}
