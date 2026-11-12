shader_type canvas_item;
render_mode unshaded, blend_disabled;

// R4 SLIT-SCAN CORRIDOR, the world pass: the approved film's r4.py `corridor()` and
// `frame()` per pixel. The curves (phase, mouth, fold, gain, the ship's place) are
// worked out once a frame by `SeqSlitScan.step`; this pass is spatial.
// Why: docs/why/SeqSlitScan.md#world-pass

#include "res://shaders/jump/jump_common.gdshaderinc"

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform sampler2D hull : filter_nearest, repeat_disable;
uniform sampler2D aux : filter_nearest, repeat_disable;
uniform sampler2D aux2 : filter_nearest, repeat_disable;
uniform vec4 world = vec4(0.0, 0.0, 960.0, 540.0);
uniform vec4 ship = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec2 vp = vec2(772.0, 281.0);
uniform vec2 core = vec2(0.0);
uniform float mid_y = 282.0;
uniform float ship_x0 = 90.0;
uniform float t = 0.0;
uniform float hull_on = 0.0;
// the corridor
uniform float cor_on = 0.0;
uniform float o = 0.0;
uniform float dn = 900.0;
uniform float sq = 1.0;
uniform float sl = 1.0;
uniform float blur = 0.0;
uniform float gain = 0.0;
uniform float wh = 0.0;
uniform float dimk = 0.0;
uniform float before_shut = 1.0;
// the slit, the point, the slot, the fold
uniform vec2 slit = vec2(0.0);
uniform float br = 0.0;
uniform float slot_k = 0.0;
uniform vec3 fold = vec3(0.0);
// the ship: place, depth scale, flare
uniform vec2 ship_d = vec2(0.0);
uniform float f = 1.0;
uniform float jolt = 0.0;
uniform float k_hit = -1.0;
uniform float k_shut = -1.0;
// hull light
uniform float tw = -1.0;
uniform float pulse_s = 0.0;
uniform float plane_g = 0.0;
uniform vec3 topc = vec3(0.0);
uniform vec3 botc = vec3(0.0);
uniform float rib_x[4];
uniform vec3 rib_c[4];
uniform float rib_f[4];
uniform int rib_n = 0;
// foreground dashes, shards
uniform float fga = 0.0;
uniform float ph = 0.0;
uniform float ln_k = 0.03;
uniform float speck_on = 0.0;

const float BPX = 270.0;
const float K = 10.0;
const float RIB = 3.4;
const vec3 MAG = vec3(1.00, 0.22, 0.72);
const vec3 EMR = vec3(0.16, 1.00, 0.50);
const vec3 LIME = vec3(0.74, 1.00, 0.26);
const vec3 ROSE4 = vec3(1.00, 0.46, 0.60);
const vec3 PAL[6] = vec3[6](MAG, J_VIO, ROSE4, EMR, LIME, J_LIL);
const int WALL_PAL[20] = int[20](0, 1, 2, 0, 1, 3, 4, 3, 5, 3, 1, 5, 0, 3, 1, 1, 5, 0, 3, 1);
const int RIB_PAL[5] = int[5](5, 0, 3, 1, 4);
const int PULSE_PAL[6] = int[6](0, 3, 1, 4, 2, 5);
const vec3 ECHO_COL[6] = vec3[6](MAG, EMR, J_VIO, LIME, ROSE4, EMR);
const vec2 SUBS[4] = vec2[4](vec2(-0.25, -0.25), vec2(0.25, -0.25), vec2(-0.25, 0.25), vec2(0.25, 0.25));

// the 26 near dashes (r4.py FG_*, rng 909) and the 90 shards (SP_*, rng 404), as the film rolled them
const float FG_A[26] = float[26](3.19630, 3.08006, 3.11213, 3.17647, 3.04624, 3.26993, 3.08005, 3.09681, 3.19780, 3.03265, 3.27804, 3.26884, 2.99819, 3.03671, 3.01356, 3.12868, 3.18436, 3.28335, 3.26081, 3.11129, 3.14457, 3.07074, 3.16177, 3.08135, 3.25130, 3.24651);
const float FG_U0[26] = float[26](0.7649, 0.1148, 0.3265, 0.8335, 0.5313, 0.8692, 0.0325, 0.3201, 0.6040, 0.8399, 0.0195, 0.3383, 0.1034, 0.8851, 0.0573, 0.5925, 0.2436, 0.4045, 0.0243, 0.1324, 0.5449, 0.5590, 0.1003, 0.5185, 0.5737, 0.4588);
const float FG_V[26] = float[26](1.2436, 0.9359, 0.7291, 1.0106, 0.7929, 1.0221, 0.9912, 0.8194, 1.2747, 0.7185, 0.8091, 0.9090, 1.1851, 1.2437, 1.1491, 0.8306, 0.7324, 1.2773, 1.1992, 0.9991, 1.1815, 0.8204, 1.0074, 1.1188, 1.1010, 1.1044);
const float FG_B[26] = float[26](1.462, 1.498, 1.403, 1.408, 1.848, 1.642, 2.292, 1.243, 1.788, 2.004, 1.542, 2.228, 1.946, 1.622, 1.385, 2.151, 1.539, 1.448, 2.206, 2.003, 1.690, 1.526, 1.822, 2.328, 1.637, 1.815);
const int FG_C[26] = int[26](3, 1, 4, 4, 1, 1, 5, 3, 3, 3, 4, 0, 4, 4, 5, 0, 4, 3, 3, 3, 0, 4, 3, 3, 1, 0);
const float SP_X0[90] = float[90](63.41, -98.57, 73.10, 142.87, 47.91, -4.05, 47.51, 218.31, -233.70, 264.40, -80.35, -42.80, -79.84, -115.23, -38.13, 71.63, 61.46, 59.58, -26.80, 132.74, -170.03, 68.12, 41.56, 121.33, 182.87, -353.90, -21.76, -38.32, -140.61, -311.59, 145.01, 168.42, 95.12, 24.43, -66.13, 16.42, 4.74, -497.56, 123.06, 178.64, -41.54, -6.21, 390.19, -166.06, -126.39, -10.37, 0.52, 61.97, 33.90, 180.48, -21.03, -100.43, 212.22, 72.48, -123.16, 136.44, 85.76, 63.44, -137.14, -95.90, -1.70, 8.09, -13.01, 4.54, 4.42, 10.42, -1.67, -4.66, -6.99, -2.04, 5.29, -7.60, 4.26, 0.90, 6.99, 1.80, 1.62, -3.13, -3.37, -0.14, -4.97, 6.83, -2.03, -1.11, -0.44, 10.25, 6.67, 11.68, 0.18, 0.33);
const float SP_Y0[90] = float[90](1.06, 0.04, 1.85, 0.39, -0.91, -0.84, -2.04, -1.13, 0.21, -0.95, -1.26, -0.77, 0.16, -0.57, -0.20, 0.97, -0.42, -1.23, 1.41, 0.89, 2.05, -0.22, 0.17, 0.30, 0.53, 0.63, 0.01, 2.94, 1.23, -0.35, -1.39, 0.17, 0.02, -1.48, 2.01, 1.78, 0.64, 0.05, 2.45, -1.82, -1.85, -1.38, -1.46, -1.15, -1.43, -0.85, -0.83, -2.09, 0.22, 0.74, -0.09, 0.38, 0.58, 1.11, -0.39, -0.41, -1.54, -0.93, 2.76, 0.78, -0.36, 1.19, -0.94, -0.34, 3.05, -1.07, -0.08, -0.06, -0.12, -1.18, 1.48, -1.07, 0.29, 0.38, -0.93, -0.05, -2.66, -0.07, -2.16, -0.57, -0.74, 1.68, -0.23, 0.82, 1.02, 0.07, -0.51, -0.03, -1.18, 1.61);
const float SP_VX[90] = float[90](-49.80, -38.56, -16.41, -67.43, -56.93, 81.84, -31.10, 54.76, 25.14, -73.74, 69.45, -55.27, -36.83, 131.78, -44.64, 23.08, -18.72, -24.37, 51.75, -12.99, 29.16, -25.25, 69.80, 88.05, -12.15, 122.97, 102.58, 39.40, -5.84, 53.89, 22.72, -19.23, 30.39, -15.08, 72.17, -12.45, 103.01, -22.17, -63.03, -10.91, 4.80, 57.75, 132.24, 86.93, -19.56, 90.77, 47.65, 98.67, -22.38, -28.48, -33.98, -26.22, -29.14, -23.91, -59.73, -5.31, 24.85, -33.47, 30.56, 34.51, 62.20, -69.36, 12.58, 148.50, -94.42, -99.99, -22.66, -33.18, -19.33, -14.28, -101.41, 114.82, 38.16, -40.74, 24.92, -107.85, -64.78, -38.33, 94.00, 30.06, 150.48, -90.66, 35.79, -11.53, 22.18, 52.77, 127.70, -19.83, 96.07, -30.51);
const float SP_VY[90] = float[90](-68.47, -39.45, -34.70, -5.62, -26.18, 17.87, -22.86, 28.96, -21.04, 42.46, -8.68, 55.21, 15.12, 8.99, 65.59, -69.09, -66.82, -2.45, -55.82, 8.41, 22.68, -16.45, -23.79, 29.31, 8.71, 28.61, -11.18, 50.24, -10.44, -4.77, 5.73, -8.03, -65.46, 13.24, -52.96, -28.19, -56.01, -18.77, 28.34, -18.60, 18.59, 37.46, 38.66, -16.08, 6.31, -56.91, -43.93, -55.88, -26.80, 19.85, 52.88, -34.97, 30.14, -16.70, -3.18, -46.52, 36.93, -58.01, 38.90, -1.43, 69.13, 41.91, 35.57, -5.28, 24.22, 6.16, -10.88, -74.11, -26.57, 71.02, 42.09, -20.25, 44.16, 23.05, -15.01, -40.33, 38.30, 6.77, 45.33, 55.29, -2.42, -0.35, 12.86, 16.10, 29.84, 8.39, -10.54, 21.08, -20.73, 27.88);
const float SP_LIFE[90] = float[90](1.980, 1.732, 2.386, 1.408, 1.703, 1.089, 2.589, 1.897, 2.044, 1.548, 2.187, 2.463, 2.200, 1.249, 2.207, 1.256, 1.180, 1.216, 1.176, 2.520, 1.717, 1.089, 2.125, 2.371, 2.234, 1.703, 1.246, 2.516, 2.258, 1.033, 2.539, 1.004, 0.984, 2.200, 2.031, 1.950, 2.275, 0.994, 2.187, 2.064, 2.424, 0.932, 1.324, 0.857, 0.838, 0.864, 0.986, 2.579, 1.565, 2.092, 1.904, 2.472, 2.373, 2.077, 1.303, 1.915, 1.283, 1.880, 1.122, 1.976, 1.291, 2.387, 2.312, 1.332, 1.436, 1.857, 0.846, 2.061, 1.124, 1.813, 1.093, 2.000, 1.624, 2.433, 2.117, 1.599, 0.857, 1.557, 0.833, 2.570, 1.055, 1.723, 2.240, 2.253, 1.059, 1.155, 1.064, 2.576, 1.781, 1.031);
const float SP_B[90] = float[90](1.510, 1.483, 0.996, 1.296, 1.484, 0.990, 1.545, 0.763, 1.072, 1.327, 1.224, 1.351, 0.693, 0.653, 0.833, 1.386, 0.694, 1.586, 1.317, 0.704, 0.809, 0.981, 0.822, 0.652, 1.193, 1.155, 1.389, 0.809, 1.420, 1.589, 0.838, 0.927, 1.020, 1.201, 1.457, 1.489, 1.590, 1.310, 0.812, 1.480, 1.096, 0.843, 1.265, 0.965, 0.770, 0.621, 0.912, 0.601, 1.325, 0.862, 1.158, 0.992, 1.518, 0.821, 1.507, 0.635, 0.623, 1.424, 0.974, 0.922, 1.492, 1.553, 1.585, 1.402, 1.474, 1.352, 1.533, 0.712, 1.117, 1.085, 1.456, 1.152, 0.642, 0.954, 1.462, 0.823, 0.868, 1.371, 1.473, 0.677, 1.430, 1.222, 1.156, 0.658, 1.437, 1.420, 1.556, 0.935, 0.903, 0.897);
const int SP_C[90] = int[90](4, 4, 0, 3, 1, 0, 2, 4, 0, 0, 3, 5, 5, 2, 1, 4, 4, 5, 5, 5, 4, 2, 5, 4, 1, 2, 5, 2, 5, 2, 1, 4, 4, 0, 1, 2, 1, 1, 2, 5, 4, 1, 1, 1, 2, 3, 5, 0, 2, 4, 5, 1, 4, 0, 1, 2, 2, 0, 4, 3, 0, 3, 1, 1, 2, 2, 0, 0, 3, 5, 2, 5, 0, 3, 0, 1, 0, 3, 2, 0, 5, 3, 1, 2, 2, 2, 2, 0, 1, 2);
const int SP_LEN[90] = int[90](1, 1, 1, 3, 2, 1, 1, 2, 1, 1, 2, 2, 2, 1, 3, 3, 1, 3, 2, 3, 1, 3, 1, 1, 2, 3, 2, 3, 1, 1, 2, 2, 1, 3, 3, 2, 3, 2, 3, 2, 2, 3, 1, 1, 1, 1, 1, 1, 3, 3, 1, 3, 3, 3, 3, 3, 1, 3, 2, 2, 2, 1, 3, 3, 1, 2, 3, 1, 1, 2, 2, 2, 1, 2, 1, 2, 3, 2, 3, 3, 3, 2, 1, 1, 3, 1, 1, 3, 3, 3);

// A square wave (period P, on for d*P) box-filtered over [x-a, x+a]: antialias and motion blur in one.
float fsq(float x, float P, float d, float a) {
	float z1 = x + a, z0 = x - a;
	float c1 = floor(z1 / P) * d * P + min(mod(z1, P), d * P);
	float c0 = floor(z0 / P) * d * P + min(mod(z0, P), d * P);
	return (c1 - c0) / (2.0 * a);
}

// The hull's coverage and colour at screen pixel p, drawn at depth scale f about the point.
vec4 hull_at(vec2 p, float fs, vec2 d, int n) {
	if (fs >= 0.999) {
		vec2 h = p - d - ship.xy;
		vec4 px = j_hull_px(hull, h, ship.zw);
		return vec4(px.rgb, px.a > 0.0 ? 1.0 : 0.0);
	}
	vec3 acc = vec3(0.0);
	float cov = 0.0;
	for (int i = 0; i < n; i++) {
		for (int j = 0; j < n; j++) {
			vec2 sp = vp + (p + vec2((float(i) + 0.5) / float(n), (float(j) + 0.5) / float(n)) - 0.5 - vp) / fs;
			vec4 px = j_hull_px(hull, floor(sp - d - ship.xy), ship.zw);
			if (px.a > 0.0) {
				acc += px.rgb;
				cov += 1.0;
			}
		}
	}
	return vec4(cov > 0.0 ? acc / cov : vec3(0.0), cov / float(n * n));
}

float cover_at(vec2 p, float fs) {
	return hull_at(p, fs, vec2(8.0, 0.0), 2).a;
}

void fragment() {
	vec2 p = floor(SCREEN_UV / SCREEN_PIXEL_SIZE);

	// --- the corridor's light and cover
	vec3 L = vec3(0.0);
	float cover = 0.0;
	if (cor_on > 0.5) {
		float sq_ = max(sq, 1e-3), sl_ = max(sl, 1e-3);
		for (int si = 0; si < 4; si++) {
			float dx = (p.x + SUBS[si].x - vp.x) / sl_;
			float dy = (p.y + SUBS[si].y - vp.y) / sq_;
			float adx = abs(dx) + 1e-3, ady = abs(dy) + 1e-3;
			bool tb = ady * K >= adx;
			float d = tb ? BPX / ady : BPX * K / adx;
			float lat = tb ? dx / ady : K * dy / adx;
			int wall = tb ? (dy < 0.0 ? 0 : 1) : (dx < 0.0 ? 2 : 3);
			float fp_l = d / BPX / min(sq_, sl_);
			float fp_w = d * d / BPX;
			float w = d + o;
			float a = 0.5 * (fp_w + blur) + 1e-4;
			float val = 0.0;
			vec3 col = vec3(0.0);
			for (int li2 = 0; li2 < 2; li2++) {
				float Lw = li2 == 0 ? 0.16 : 0.045;
				float kb = li2 == 0 ? 1.0 : 0.45;
				float salt = li2 == 0 ? 1.0 : 7.0;
				float li = floor(lat / Lw);
				float pos = lat / Lw - li;
				float id = li + 1000.0 * float(wall);
				float h1 = j_hsh(id, salt), h2 = j_hsh(id, salt + 1.0), h3 = j_hsh(id, salt + 2.0);
				float h4 = j_hsh(id, salt + 3.0), h5 = j_hsh(id, salt + 4.0), h6 = j_hsh(id, salt + 5.0);
				float c = 0.10 + 0.42 * h1;
				float b = pow(0.15 + 0.85 * h2, 2.0) * kb;
				float P = 0.35 + 2.2 * h3;
				float dd = 0.12 + 0.55 * h4;
				float fpl = fp_l / Lw;
				float cv = clamp((c / 2.0 - abs(pos - 0.5)) / max(fpl, 1e-3) + 0.5, 0.0, 1.0);
				float dash = fsq(w + h5 * P, P, dd, a);
				float v = cv * dash * b;
				float mfar = clamp((fpl - 0.5) / 1.5, 0.0, 1.0);
				v = v * (1.0 - mfar) + (0.31 * 0.43 * 0.40 * kb) * mfar;
				float bandn = floor(w / RIB);
				int pi = WALL_PAL[wall * 5 + int(mod(floor(h6 * 5.0) + bandn, 5.0))];
				val += v;
				col += v * PAL[pi];
			}
			float rib = fsq(w + 0.02, RIB, 0.022 / RIB, a) * clamp((d - 0.5) / 1.5, 0.0, 1.0);
			rib = min(rib, 1.0);
			int ri = int(mod(floor((w + 0.02 + RIB / 2.0) / RIB), 5.0));
			rib *= (0.25 + 0.75 * exp(-pow(lat / (tb ? 5.0 : 0.7), 2.0))) * (0.3 + 1.6 * min(val, 1.0));
			vec3 rcol = PAL[RIB_PAL[ri]] * 0.75 + J_WHT * 0.25;
			col += rib * 2.4 * rcol;
			val += rib * 2.4;
			float vis = clamp((d - dn) / (fp_w * 1.2 + 0.01), 0.0, 1.0);
			float rim = clamp(1.0 - abs(d - dn) / (0.012 * dn + fp_w), 0.0, 1.0) * (dn < 600.0 ? 1.0 : 0.0);
			float fog = 0.3 + 0.7 * exp(-d / 40.0);
			float m = vis * fog * (tb ? 1.0 : 0.75);
			L += col * (m * gain) + rim * (0.25 + 2.2 * min(val, 1.0)) * gain * J_LIL;
			cover += vis;
		}
		L /= 4.0;
		cover /= 4.0;
		if (wh > 0.0) {
			float lm = max(L.r, max(L.g, L.b));
			L = L * (1.0 - wh) + lm * J_WHT * wh;
		}
		L *= pow(1.0 / max(sq_, 0.08), 0.25) * pow(1.0 / max(sl_, 0.15), 0.2);
	}

	// --- the sky: dimmed inside the corridor; the shut's ring bends it
	vec2 q = p;
	if (k_shut >= 0.0 && k_shut < 1.6) {
		vec2 dv = p - vp;
		float r = length(vec2(dv.x, dv.y * 1.5));
		float front = 8.0 + 520.0 * pow(k_shut, 0.75);
		float amp = 0.14 * exp(-k_shut / 0.5);
		float mm = -amp * exp(-pow((r - front) / 18.0, 2.0)) * sign(r - front + 1e-3);
		q = floor(vp + dv * (1.0 + mm) + 0.5);
	}
	vec3 sky = j_world(screen, SCREEN_PIXEL_SIZE, q, world);
	if (dimk > 0.005) {
		sky *= before_shut > 0.5 ? 1.0 - dimk * clamp(cover * 1.2, 0.0, 1.0) : 1.0 - dimk;
	}

	vec3 Lback = L;
	vec3 Lglow = vec3(0.0);
	vec3 Lhull = vec3(0.0);

	// the slit, the point, the slot, the fold
	if (slit.x > 0.0) {
		float bar = exp(-pow((p.y - vp.y) / 0.55, 2.0)) * pow(clamp(1.0 - abs(p.x - vp.x) / slit.y, 0.0, 1.0), 1.5);
		Lback += bar * slit.x * J_LIL;
	}
	if (br > 0.0) {
		Lglow += j_splat(p, vp, 1.2, J_WHT, 2.2 * br, 1.0);
		Lglow += j_splat(p, vp, 7.0, J_LIL, 0.45 * br, 1.0);
		Lglow += j_splat(p, vp, 30.0, J_VIO, 0.12 * br, 2.4);
	}
	if (slot_k > 0.0) {
		float slot = exp(-abs(p.y - vp.y) / 7.0) * exp(-abs(p.x - vp.x) / 300.0);
		Lglow += slot * slot_k * (J_LIL * 0.6 + J_VIO * 0.4);
	}
	if (fold.x > 0.0) {
		float cl = fold.x;
		float lx = pow(clamp(1.0 - abs(p.x - vp.x) / fold.y, 0.0, 1.0), 0.6);
		float cr = exp(-pow((p.y - vp.y) / 0.6, 2.0)) * lx;
		Lback += cr * (0.6 + 2.6 * cl) * (J_WHT * 0.7 + J_LIL * 0.3);
		float fr = lx * cl * (0.8 + 0.6 * (1.0 - fold.z));
		Lback += exp(-pow((p.y - vp.y + 2.0) / 0.8, 2.0)) * fr * MAG;
		Lback += exp(-pow((p.y - vp.y - 2.0) / 0.8, 2.0)) * fr * EMR;
		Lglow += exp(-abs(p.y - vp.y) / 6.0) * lx * 0.35 * cl * J_VIO;
	}

	// --- the hull: drive pulses, the planes' light from above and below, ribs passing
	vec4 hs = vec4(0.0);
	bool have_hull = hull_on > 0.5 && f >= 0.012;
	if (have_hull) {
		hs = hull_at(p, f, ship_d, 3);
		if (hs.a > 0.0 && f >= 0.999) {
			vec2 h = p - ship_d - ship.xy;
			vec4 ax = texture(aux, (h + 0.5) / ship.zw);
			vec4 ax2 = texture(aux2, (h + 0.5) / ship.zw);
			float seam = ax.r;
			vec3 hv = vec3(0.0);
			if (tw >= 0.0) {
				float dcore = length(vec2(p.x - ship_d.x - core.x, (p.y - ship_d.y - core.y) * 1.7));
				float a2 = 2.6 / 4.0, b2 = 1.2;
				float last = floor(b2 * tw + a2 * tw * tw);
				for (int j = 0; j < 4; j++) {
					float pk = last - float(j);
					if (pk < 0.0) {
						break;
					}
					float tp = (-b2 + sqrt(b2 * b2 + 4.0 * a2 * pk)) / (2.0 * a2);
					float dtp = tw - tp;
					float front = dtp * (150.0 + 150.0 * pulse_s);
					float amp = (0.2 + 0.5 * pulse_s) * exp(-dtp / 0.24);
					float wave = exp(-pow((dcore - front) / (5.0 + 5.0 * pulse_s), 2.0)) * amp;
					vec3 pcol = PAL[PULSE_PAL[int(mod(pk, 6.0))]];
					hv += wave * (0.2 + 1.5 * seam) * pcol;
					hv += amp * 1.4 * exp(-dcore / 7.0) * exp(-dtp / 0.08) * J_WHT;
				}
			}
			if (plane_g > 0.0) {
				hv += ax2.r * 1.25 * plane_g * topc;
				hv += ax2.g * 1.25 * plane_g * botc;
				float edge = max(ax2.b, seam);
				for (int r = 0; r < rib_n; r++) {
					float bandr = exp(-pow((p.x - rib_x[r]) / 4.0, 2.0)) * (0.35 + 0.65 * edge);
					hv += bandr * 1.3 * rib_f[r] * plane_g * rib_c[r];
				}
			}
			Lhull = hv;
		}
	}

	// --- the swallow: the streak down the path, the aimed hull's light, the pip; the shut
	if (k_hit > 1.0 / 60.0 && k_hit < 1.0) {
		float kk = k_hit - 1.0 / 60.0;
		float fs2 = exp(-kk / 0.35);
		float gone_x = ship_x0 + (vp.x - ship_x0) * j_ease(kk / 0.6);
		if (p.x > gone_x && p.x <= vp.x) {
			float line = exp(-pow((p.y - mid_y) / (0.55 + 2.0 * exp(-kk / 0.05)), 2.0));
			Lback += line * 1.6 * fs2 * clamp((p.x - gone_x) / 80.0, 0.0, 1.0) * J_LIL;
		}
		float ai = exp(-kk / 0.10);
		if (ai > 0.03) {
			vec4 px = j_hull_px(hull, p - vec2(8.0, 0.0) - ship.xy, ship.zw);
			if (px.a > 0.0) {
				float hl = (px.r + px.g + px.b) / 3.0;
				Lback += pow(hl, 1.5) * 1.6 * ai * (MAG * 0.5 + J_VIO * 0.5);
			}
		}
		float ka = k_hit - 0.40;
		if (ka >= 0.0) {
			Lglow += j_splat(p, vp, 2.0, J_WHT, 5.0 * exp(-ka / 0.08), 1.0);
			Lglow += j_splat(p, vp, 14.0 + 30.0 * ka, J_LIL, 0.7 * exp(-ka / 0.18), 1.0);
		}
	}
	if (k_shut >= -0.05) {
		float ks = max(k_shut, 0.0);
		float pk = exp(-ks / 0.16);
		Lglow += j_splat(p, vp, 2.0, J_WHT, 7.0 * pk, 1.0);
		Lglow += j_splat(p, vp, 16.0 + 50.0 * ks, J_VIO, 0.5 * exp(-ks / 0.3), 1.0);
		float sc = exp(-ks / 0.7);
		if (sc > 0.02) {
			float half = 520.0 * exp(-ks / 1.2) + 20.0;
			float bar = exp(-pow((p.y - vp.y) / 0.55, 2.0)) * pow(clamp(1.0 - abs(p.x - vp.x) / half, 0.0, 1.0), 2.0);
			Lback += bar * 2.0 * sc * (J_LIL * 0.6 + MAG * 0.2 + EMR * 0.2);
			float vbar = exp(-pow((p.x - vp.x) / 0.55, 2.0)) * exp(-abs(p.y - vp.y) / (70.0 * exp(-ks / 0.25) + 5.0));
			Lback += vbar * 1.2 * exp(-ks / 0.2) * J_LIL;
		}
		float rr = length(vec2(p.x - vp.x, (p.y - vp.y) * 1.5));
		float front = 8.0 + 520.0 * pow(ks, 0.75);
		float ring = exp(-pow((rr - front) / (5.0 + 12.0 * ks), 2.0)) * exp(-ks / 0.35);
		Lglow += ring * 0.22 * (J_VIO * 0.5 + EMR * 0.25 + MAG * 0.25);
	}

	// --- the dive's echoes: the hull's outline left behind, one colour each
	if (have_hull && f < 0.999) {
		float k = k_hit - 1.0 / 60.0;
		for (int gi = 0; gi < 6; gi++) {
			float kk = max(k - float(gi + 1) * 0.011, 0.0);
			float fg = 1.0 / (1.0 + pow(kk / 0.055, 2.1));
			if (fg > 0.97) {
				continue;
			}
			fg = max(fg, 0.012);
			// only where the shrunken hull can be
			vec2 lo = vp + (ship.xy - vp) * fg - 2.0;
			vec2 hi = vp + (ship.xy + ship.zw + vec2(8.0, 0.0) - vp) * fg + 2.0;
			if (p.x < lo.x || p.y < lo.y || p.x > hi.x || p.y > hi.y) {
				continue;
			}
			float ga = cover_at(p, fg);
			float mn = ga;
			for (int dy = -1; dy <= 1; dy++) {
				for (int dx = -1; dx <= 1; dx++) {
					mn = min(mn, cover_at(p + vec2(float(dx), float(dy)), fg));
				}
			}
			float edge = clamp(ga - mn, 0.0, 1.0);
			Lback += (edge * (1.5 - 0.18 * float(gi)) + ga * 0.10) * ECHO_COL[gi];
		}
	}

	// --- composite: back light behind the hull, then the hull, then the near light
	bool hid = hs.a > 0.5;
	vec3 o3 = j_add_line(sky, hid ? vec3(0.0) : Lback, 10.0);
	o3 = j_add_glow(o3, hid ? Lglow * 0.25 : Lglow, 7.0, p);
	if (hs.a > 0.0) {
		vec3 base = hs.rgb;
		if (f < 0.999) {
			float hot = clamp(1.0 - f, 0.0, 1.0) * 0.5 + 0.03;
			base = mix(base, J_WHT, hot);
		} else if (jolt > 0.5) {
			base = base * 0.85 + J_WHT * 0.15;
		}
		float lm = max(Lhull.r, max(Lhull.g, Lhull.b));
		vec3 lit = base;
		if (lm > 0.0) {
			float qv = j_glow_q(lm, 7.0, p);
			vec3 colr = Lhull / lm;
			lit = base * (1.0 + 0.85 * qv * (0.4 + 0.6 * colr)) + qv * colr * 0.35;
			lit = mix(lit, J_WHT, clamp((lm - 3.0) / 2.0, 0.0, 1.0));
		}
		o3 = mix(o3, lit, hs.a);
	}

	// --- in front of everything: the near dashes and the shut's shards
	vec3 Lfront = vec3(0.0);
	if (fga > 0.01) {
		for (int i = 0; i < 26; i++) {
			float u = fract(FG_U0[i] + ph * FG_V[i]);
			float r1 = 900.0 * pow(u, 1.6);
			float ln = ln_k * 900.0 * pow(u, 1.2) + 4.0;
			float r0 = max(r1 - ln, 0.0);
			float ca = cos(FG_A[i]), sa = sin(FG_A[i]);
			float rr = (p.x - vp.x) / ca;
			if (rr < r0 || rr > r1) {
				continue;
			}
			float yr = floor(vp.y + sa * rr + 0.5);
			float wgt = (0.15 + 0.85 * (rr - r0) / max(r1 - r0, 1e-3)) * FG_B[i] * fga * clamp(u / 0.15, 0.0, 1.0);
			if (p.y == yr) {
				Lfront += wgt * PAL[FG_C[i]];
			} else if (p.y == yr + 1.0) {
				Lfront += 0.6 * wgt * PAL[FG_C[i]];
			}
		}
	}
	if (speck_on > 0.5 && k_shut >= 0.0) {
		float ks = k_shut;
		float dragf = (1.0 - exp(-ks / 0.5)) * 0.55;
		float held = floor(ks * 10.0);
		for (int i = 0; i < 90; i++) {
			float life = 1.0 - ks / SP_LIFE[i];
			if (life <= 0.0 || int(mod(held + float(i), 5.0)) == 0) {
				continue;
			}
			float sy = floor(vp.y + SP_Y0[i] + SP_VY[i] * dragf + 3.0 * ks * ks);
			if (p.y != sy) {
				continue;
			}
			float sx = floor(vp.x + SP_X0[i] + SP_VX[i] * dragf);
			float jx = sx - p.x;
			if (jx < 0.0 || jx >= float(SP_LEN[i])) {
				continue;
			}
			float v = SP_B[i] * pow(life, 0.8) * 2.0;
			Lfront += PAL[SP_C[i]] * v * (1.0 - 0.25 * jx) + (jx == 0.0 ? J_WHT * v * 0.3 : vec3(0.0));
		}
	}
	o3 = j_add_line(o3, Lfront, 10.0);
	COLOR = vec4(clamp(o3, 0.0, 1.0), 1.0);
}
