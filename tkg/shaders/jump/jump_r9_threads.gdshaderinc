// R9 UNRAVEL's threads, one quad a sample, placed by VERTEX_ID (`SeqUnravel`): every ink row
// of the hull is a thread pulled out of its row's unravel front, sampled every 0.55 px of arc
// as the film did (r9.py `ribbon_samples`), and summed into a light buffer as its `deposit`
// did: a sample adds its light to the one whole pixel it rounds to. One shader, five uses:
//   mode 0  the threads' line light (back or front band, or both for the afterglow)
//   mode 1  the aurora rays hanging up from every third sample (`ribbon_light`'s curtains)
//   mode 2  the hull's paint near the root, opaque, dithered out as it burns (`mats`)
//   mode 3  the corona's burst of rays after the snap (`streaks`)
// `cell` is the buffer's pixel in screen px (4 for the quarter-size light the sky is lit by).
// Why: docs/why/SeqUnravel.md#threads

uniform int mode = 0;
// 0 the back band (odd groups), 1 the front band (even), 2 both
uniform int band = 2;
uniform float t = 0.0;
uniform vec2 hoff = vec2(0.0);
uniform float gain = 1.0;
// the curtains' and matter's own lum, for the quarter-size buffer: 0 light, 1 its brightest channel
uniform int as_lum = 0;
uniform float cell = 1.0;
uniform vec2 origin = vec2(0.0);
uniform sampler2D hull : filter_nearest, repeat_disable;
uniform vec2 hull_size = vec2(1.0);
// where the ink starts in the hull's canvas, and on screen
uniform vec2 ink_c = vec2(0.0);
uniform vec2 ink_s = vec2(90.0, 232.0);
uniform int rows = 0;
uniform int maxj = 1;
uniform int stride = 1;
// per ink row: its first and last ink column, its delay, its band's spread
uniform vec4 row_d[160];
// per band of four rows: amplitude, wavelength, rate, phase; twist length, width, rise, hue
uniform vec4 g_a[40];
uniform vec4 g_b[40];
uniform int ng = 24;
// the plates' edge columns and when each goes
uniform float pe[9];
uniform float tk[9];
uniform vec2 vp = vec2(772.0, 260.0);
uniform float taut = 0.0;
uniform float reel = 0.0;
// the corona's rays (mode 3): angle, length, brightness
uniform vec3 cr[54];
uniform float k_s = -1.0;

const float T_UNR = 2.3;
const float T_ZIP = 6.08;
const float T_SNAP = 6.15;
const float STR = 1.75;
const float STEP = 0.55;
const vec3 MINT = vec3(0.42, 1.00, 0.70);
const vec3 VIO = vec3(0.62, 0.36, 1.00);
const vec3 LIL = vec3(0.86, 0.80, 1.00);
const vec3 WHT = vec3(1.00, 0.97, 1.00);
const vec3 MAG = vec3(1.00, 0.36, 0.80);
const float B2[4] = float[4](0.0, 0.5, 0.75, 0.25);
const vec2 CORNER[6] = vec2[](vec2(0.0, 0.0), vec2(1.0, 0.0), vec2(1.0, 1.0),
	vec2(0.0, 0.0), vec2(1.0, 1.0), vec2(0.0, 1.0));

varying flat vec4 v_col;
varying float v_jj;
varying flat vec2 v_c;

float ease(float u) {
	u = clamp(u, 0.0, 1.0);
	return u * u * (3.0 - 2.0 * u);
}

float ease5(float u) {
	u = clamp(u, 0.0, 1.0);
	return u * u * u * (u * (6.0 * u - 15.0) + 10.0);
}

// the unravel front of row r, in ink columns: what lies left of it has left the hull
float front(int r) {
	float tt = t - row_d[r].z;
	float F = -1.0;
	for (int k = 0; k < 8; k++) {
		if (tt >= tk[k]) {
			float d = tk[k + 1] - tk[k];
			F = pe[k] + (pe[k + 1] - pe[k]) * ease5((tt - tk[k]) / (0.78 * d));
		}
	}
	return F;
}

void vertex() {
	vec2 corner = CORNER[VERTEX_ID % 6];
	int slot = VERTEX_ID / 6;
	vec2 at = vec2(-1e5);
	vec2 size = vec2(cell);
	vec4 col = vec4(0.0);
	float jj_top = 0.0;
	if (mode == 3) {
		// the corona's burst: a streak from a quarter of the ray out to its end
		int ray = slot / maxj;
		int k = slot % maxj;
		if (ray < 54 && k_s >= 0.0) {
			float rb = exp(-k_s / 0.45);
			float ln = cr[ray].y * (1.0 - exp(-k_s / 0.16));
			vec2 dir = vec2(cos(cr[ray].x), sin(cr[ray].x));
			vec2 p0 = vp + dir * ln * vec2(0.25, 0.2);
			vec2 p1 = vp + dir * ln * vec2(1.0, 0.8);
			float lnp = max(abs(p1.x - p0.x), abs(p1.y - p0.y));
			int cnt = clamp(int(ceil(lnp)) + 1, 1, 1400);
			if (k < cnt && rb > 0.02) {
				float u = float(k) / float(max(cnt - 1, 1));
				vec2 p = p0 + (p1 - p0) * u;
				float ih = cr[ray].z * rb * 1.8;
				float it = cr[ray].z * rb * 0.3;
				float w = (ih * pow(1.0 - u, 1.6) + it * (1.0 - u)) / sqrt(max(float(cnt) / 6.0, 1.0));
				vec3 c = mix(WHT, MINT * 0.5 + VIO * 0.5, u);
				at = floor(p + 0.5);
				col = vec4(c * w * gain, 1.0);
			}
		}
	} else {
		int r = slot / maxj;
		int j = (slot % maxj) * stride;
		if (r < rows && row_d[r].y >= 0.0) {
			float F = front(r);
			float rl_ = row_d[r].x;
			float rr_ = row_d[r].y;
			int g = (r / 4) % ng;
			bool front_band = ((r / 4) % 2) == 0;
			bool want = band == 2 || (band == 1) == front_band;
			float Fr = min(F, rr_ + 1.0);
			float Lr = (Fr - rl_) * STR;
			float s = float(j) * STEP;
			if (want && F > rl_ && s < Lr && t >= T_UNR - 0.05 && t < T_SNAP) {
				float c = Fr - s / STR;
				float ci = clamp(floor(c), 0.0, hull_size.x - 1.0 - ink_c.x);
				vec4 paint = textureLod(hull, (ink_c + vec2(ci, float(r)) + 0.5) / hull_size, 0.0);
				bool alive = paint.a > 0.0;
				float o = float(r % 4) - 1.5;
				float Rx = ink_s.x + hoff.x + Fr;
				float Ry = ink_s.y + hoff.y + float(r);
				vec4 ga = g_a[g];
				vec4 gb = g_b[g];
				float spr = row_d[r].w;
				float grow = ease((t - T_UNR) / 0.8);
				float amp = ga.x * pow(clamp(s / 150.0, 0.0, 1.0), 1.2) * (0.4 + 0.6 * grow);
				float wave = amp * sin(6.2831853 * (s / ga.y - ga.z * t) + ga.w);
				float lift = spr * 72.0 * (1.0 - exp(-s / 55.0)) - gb.z * s;
				float wid = 1.0 + gb.y * clamp(s / 130.0, 0.0, 1.0);
				float tw = cos((6.2831853 * s / gb.x - 2.2 * t) * clamp(s / 40.0, 0.0, 1.0));
				float xw = Rx + s;
				float yw = Ry + lift + wave + o * (wid * tw - 1.0);
				float k = taut;
				if (k > 0.0) {
					float Rx2 = Rx + (vp.x - Rx) * reel;
					float Ry2 = Ry + (vp.y - Ry) * reel;
					vec2 dd = vp - vec2(Rx2, Ry2);
					float dl = length(dd) + 1e-3;
					float xl = Rx2 + dd.x / dl * s;
					float yl = Ry2 + dd.y / dl * s;
					if (t > T_ZIP) {
						float z = (t - T_ZIP) / (T_SNAP - T_ZIP);
						yl += 14.0 * sin(3.14159265 * clamp((s / max(dl, 1.0) - (1.0 - z)) * 3.0, 0.0, 1.0))
							* sign(spr + 0.01);
					}
					xw = xw * (1.0 - k) + xl * k;
					yw = yw * (1.0 - k) + yl * k;
					if (s > dl && k > 0.5) {
						alive = false;
					}
				}
				float m = exp(-s / 30.0) * (1.0 - k);
				float tipf = clamp((Lr - s) / 18.0, 0.0, 1.0);
				float face = 0.65 + 0.35 * abs(tw);
				float I = (1.0 - m) * tipf * face * (0.42 + (o > 0.0 ? 0.22 : 0.0)) * (1.0 - 0.72 * k);
				vec2 px = floor(vec2(xw, yw) + 0.5);
				if (alive) {
					if (mode == 0) {
						// white-hot root, mint body, violet then magenta tips, drawn to lilac-mint taut
						vec3 mint = MINT + gb.w * vec3(0.6, 0.0, 0.4);
						float u1 = clamp(s / 90.0, 0.0, 1.0);
						float u2 = clamp((s - 90.0) / 170.0, 0.0, 1.0);
						float u3 = clamp((s - 260.0) / 160.0, 0.0, 1.0);
						vec3 cc = mix(mix(mix(WHT, mint, u1), VIO, u2), MAG, u3);
						cc = cc * (1.0 - k * 0.6) + (LIL * 0.5 + MINT * 0.5) * k * 0.6;
						float w = I * 0.9;
						at = px;
						col = as_lum == 1 ? vec4(vec3(w * max(cc.r, max(cc.g, cc.b))) * gain, 1.0) : vec4(cc * w * gain, 1.0);
					} else if (mode == 1) {
						if (I > 0.05 && k < 0.98) {
							float stri = pow(clamp(0.5 + 0.5 * sin(s * 0.45 + ga.w * 3.0) * sin(s * 0.11 - 2.6 * t + ga.w),
								0.0, 1.0), 1.5);
							float hgt = (6.0 + 22.0 * stri) * clamp(s / 60.0, 0.0, 1.0) * (1.0 - k);
							float n = ceil(hgt);
							if (n > 0.0 && cell > 1.0) {
								// (the quarter-size light: the ray's whole light in the cell round its middle)
								at = vec2(px.x, px.y - floor(n * 0.3));
								float sum = 0.0;
								for (int q = 0; q < 29; q++) {
									if (float(q) < n) {
										sum += exp(-2.2 * float(q) / max(hgt, 1.0));
									}
								}
								col = vec4(0.055 * (0.3 + stri) * sum * gain, 1.0, 0.0, 1.0);
							} else if (n > 0.0) {
								at = vec2(px.x, px.y - n + 1.0);
								size = vec2(1.0, n);
								jj_top = n;
								col = vec4(0.055 * (0.3 + stri) * gain, hgt, 0.0, 1.0);
							}
						}
					} else if (mode == 2) {
						float thr = B2[int(mod(px.y, 2.0)) * 2 + int(mod(px.x, 2.0))] * 0.5 + 0.22;
						if (m > thr) {
							float e = 1.0 - m;
							vec3 pcol = paint.rgb * (1.0 + 0.7 * e) + e * (MINT * 0.30 + WHT * 0.10);
							at = px;
							col = vec4(clamp(pcol, 0.0, 1.0), front_band ? 1.0 : 0.5);
						}
					}
				}
			}
		}
	}
	v_col = col;
	v_c = vec2(float(as_lum), 0.0);
	if (cell > 1.0 && at.x > -1e4) {
		// the quarter-size buffer: the whole cell the pixel falls in
		at = origin + floor((at - origin) / cell) * cell;
		size = vec2(cell);
	}
	v_jj = jj_top * (1.0 - corner.y);
	VERTEX = at + corner * size;
}

