shader_type canvas_item;
render_mode unshaded, blend_add;

// The films' streaks and sparks (`JumpSparkQuads`): one quad per instance, stretched from this
// instant's head to its tail by a closed form of t in the vertex stage, whole pixels, added
// over the picture. The mode picks the form; an instance's own numbers ride in its colour
// and custom data.
// Why: docs/why/JumpSparkQuads.md#shader

#include "res://shaders/jump/jump_common.gdshaderinc"

uniform int mode = 0;
uniform float width = 1.0;
uniform float t = 0.0;
uniform vec2 pc = vec2(0.0);
// R14 stars: 0 still, 1 the pour, 2 the burst; the pour's (A, B) now and 0.14 s ago
uniform int phase = 0;
uniform vec2 ab0 = vec2(0.0);
uniform vec2 ab1 = vec2(0.0);
uniform float p_t = 0.0;
uniform float rb = 0.0;
uniform float vis = 0.0;
uniform float kb = -1.0;

varying vec4 v_head;
varying vec4 v_tail;
varying float v_u;
varying float v_len;

const vec3 E_GREY = vec3(0.80, 0.80, 0.92);
const vec3 R14_LIL = vec3(0.88, 0.76, 1.00);
const vec3 R10_MAG = vec3(1.00, 0.36, 0.84);

// Where content that lives at R0 shows in the pour (< 0: swallowed).
float r_of(float R0, vec2 ab) {
	float q = R0 - ab.y;
	return q > ab.x ? sqrt(max(q * q - ab.x * ab.x, 0.0)) : -1.0;
}

float shock_r(float k) {
	return 8.0 + 1150.0 * (1.0 - exp(-k / 0.40));
}

// A star thrown back out by the shock: it rides just behind the front, then springs about its home.
float burst_pos(float R0, float k, float lag) {
	float ride = shock_r(k) - lag;
	float q = clamp(1.0 - (R0 + lag - 8.0) / 1150.0, 1e-4, 1.0);
	float kp = -0.40 * log(q);
	float dk = max(k - kp, 0.0);
	float amp = min(0.07 * R0, 18.0);
	float spring = R0 + (k > kp ? amp * exp(-dk / 0.16) * sin(TAU * dk / 0.42) : 0.0);
	return max(min(ride, spring), 0.0);
}

void vertex() {
	vec2 H = vec2(0.0), T = vec2(0.0);
	vec3 hc = vec3(0.0), tc = vec3(0.0);
	float w = width;
	float head_w = width;
	bool on = false;
	if (mode == 0) {
		float R0 = INSTANCE_CUSTOM.x;
		vec2 U = vec2(cos(INSTANCE_CUSTOM.y), sin(INSTANCE_CUSTOM.y));
		float eb = INSTANCE_CUSTOM.z;
		float lag = INSTANCE_CUSTOM.w;
		int kind = int(COLOR.a + 0.5);
		vec3 base = COLOR.rgb;
		float r1 = -1.0, r0 = -1.0;
		if (phase == 1) {
			r1 = r_of(R0, ab0);
			r0 = r_of(R0, ab1);
			if (r0 < 0.0) {
				r0 = r1;
			}
			if (r1 >= 0.0) {
				float speed = (r0 - r1) / 0.14;
				float hot = clamp(speed / 900.0, 0.0, 1.5) + 1.2 * exp(-max(r1 - rb, 0.0) / 90.0) * p_t;
				if (kind == 0) {
					// the poured sky shows the star itself: only its heat and its tail are added
					hc = base * 1.5 * hot + hot * (60.0 / 255.0) * R14_LIL;
					tc = (base * (1.0 + 1.5 * hot) + hot * (60.0 / 255.0) * R14_LIL) * 0.85;
				} else {
					vec3 col = base * (eb * vis * (110.0 + 120.0 * hot) / 255.0);
					hc = col;
					tc = col * 0.9;
				}
				on = true;
			}
		} else if (phase == 2 && kind != 0) {
			float vb = 1.0 - j_ease((kb - 0.25) / 0.9);
			if (vb > 0.005) {
				r1 = burst_pos(R0, kb, lag);
				r0 = kb > 0.0 ? burst_pos(R0, max(kb - 0.04, 0.0), lag) : 0.0;
				float esp = abs(r1 - r0) / 0.04;
				float ehot = clamp(esp / 700.0, 0.0, 1.5);
				vec3 col = base * (eb * vb * (30.0 + 45.0 * ehot) / 255.0);
				hc = col;
				tc = col * 0.9;
				on = true;
			}
		}
		if (on) {
			H = pc + U * r1;
			T = pc + U * r0;
			if (kind == 3) {
				H.y += 1.0;
				T.y += 1.0;
				hc *= 0.7;
				tc *= 0.7;
			}
		}
	} else if (mode == 1) {
		float a = INSTANCE_CUSTOM.x, V = INSTANCE_CUSTOM.y, life = INSTANCE_CUSTOM.z, B = INSTANCE_CUSTOM.w;
		if (kb >= 0.0 && kb < life) {
			float r1 = V * (1.0 - exp(-2.6 * kb)) / 2.6;
			float r0 = V * (1.0 - exp(-2.6 * max(kb - 0.035, 0.0))) / 2.6;
			float fade = pow(1.0 - kb / life, 1.5) * B;
			H = pc + vec2(cos(a) * r1, sin(a) * r1 * 0.85);
			T = pc + vec2(cos(a) * r0, sin(a) * r0 * 0.85);
			hc = COLOR.rgb * fade * 1.6;
			tc = hc * 0.8;
			on = true;
		}
	} else {
		float kk = t - INSTANCE_CUSTOM.x;
		float life = INSTANCE_CUSTOM.w;
		if (kk >= 0.0 && kk < life) {
			float dragf = (1.0 - exp(-kk / 0.5)) * 0.5;
			H = vec2(INSTANCE_CUSTOM.y + COLOR.r * dragf, INSTANCE_CUSTOM.z + COLOR.g * dragf + 5.0 * kk * kk);
			T = H;
			float blink = mod(floor(kk * 10.0) + COLOR.a, 4.0) != 0.0 ? 1.0 : 0.0;
			float v = COLOR.b * pow(1.0 - kk / life, 0.7) * 2.0 * blink;
			hc = vec3(v);
			on = v > 0.0;
			// a 3x3 block about the spark's pixel (the plus lives in its cross)
			H = floor(H + 0.5) - 1.0;
			T = H;
			w = 3.0;
			head_w = 3.0;
		}
	}
	if (!on) {
		VERTEX = vec2(-10.0);
		v_len = 0.0;
	} else {
		H = floor(H + 0.5);
		T = floor(T + 0.5);
		vec2 D = T - H;
		float len = length(D);
		vec2 dir = len > 0.01 ? D / len : vec2(1.0, 0.0);
		vec2 n = vec2(-dir.y, dir.x);
		vec2 c0 = H + 0.5 * head_w;
		vec2 c1 = T + 0.5 * head_w;
		vec2 a = c0 - dir * 0.5 * head_w;
		vec2 b = c1 + dir * 0.5 * head_w;
		VERTEX = a + (b - a) * VERTEX.x + n * (VERTEX.y - 0.5) * w;
		v_len = len;
	}
	v_head = vec4(hc, 1.0);
	v_tail = vec4(tc, 1.0);
	v_u = UV.x;
}

void fragment() {
	vec2 p = floor(FRAGCOORD.xy);
	vec3 c;
	if (mode == 2) {
		vec2 cell = floor(UV * 3.0);
		float v = v_head.r;
		if (cell == vec2(1.0)) {
			c = vec3(j_line_q(v, 9.0)) * J_WHT;
		} else if ((cell.x == 1.0 || cell.y == 1.0) && v > 1.0) {
			c = j_line_q(0.3 * v, 9.0) * R10_MAG;
		} else {
			c = vec3(0.0);
		}
	} else {
		float span = v_len + width;
		bool head = v_u * span < width;
		if (head) {
			c = v_head.rgb;
		} else {
			c = v_tail.rgb * pow(max(1.0 - v_u, 0.0), 1.3);
		}
		if (mode == 1) {
			float lm = max(c.r, max(c.g, c.b));
			c = lm > 0.0 ? j_glow_q(lm, 7.0, p) * (c / lm) : vec3(0.0);
		}
	}
	COLOR = vec4(c, 1.0);
}
