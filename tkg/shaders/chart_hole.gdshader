shader_type canvas_item;
render_mode unshaded, blend_disabled;

// THE BLACK HOLE (`ChartSky`), the sector map's: every block a ray from the
// eye bent round the hole and landing on its disc, in it, or on the sky behind
// (`core_trace.gdshader`, traced once at one size and read here scaled to the
// hole's). The disc is laid over the bent sky: its heat falls off outward, its
// near side brighter where it comes at you, streaked, turning by the
// galaxy's one law (fast against the hole, with the galaxy at the innermost
// ring); then the photon ring, then the shadow. In the hole's own colours,
// laid over the light that is already there, so it stays orange streaks over
// a bright bulge instead of whitening it.
//
// THE PHOTON RING IS LIGHT, NOT A STROKE. It used to be a band of one cream,
// as thick at the sides as at the top ("that plain bright solid white arc
// ... isn't good looking", Jon). Now it is the disc's own hot inner edge bent
// round the hole: its brightness and colour are the disc's there, streaked
// and turning with it, brighter on the side coming at you, thickest over the
// top where the far side of the disc is lensed up, thinning down the sides,
// stepping down into the glow on its outer edge in the palette's steps, and
// laid over what is there rather than added to it, so only its hottest spots
// reach white. (The sector map's core, `core_hole.gdshader`, still draws its
// ring as one cream band, a pixel or so wide.)
//
// NO WHITE STROKE ("still has a white line on the left side", Jon): the ring
// and the disc top out at hot cream, never the palette's near-white, and the
// disc's light is eased before it is stepped, so the hot side keeps its
// streaks (amber and cream) instead of filling to one bright arc.
//
// THREE LOOKS while Jon picks (`ChartSky.hole_look`, `look` here):
//   0 this one: the disc laid over the bulge, the ring over the top.
//   1 the sector map's (`core_hole.gdshader`, his pick #11): its wide disc
//     (out to 110 / 15 hole radii, traced to match), its gas added at 70%,
//     its warm glow under it, the ring over the top; the bulge dimmed under
//     the disc so the added gas reads as streaks, not white.
//   2 the textbook look: the bulge dimmed round the hole, the disc drawn
//     near opaque so its near side crosses in front of the shadow and its far
//     side is seen lensed over the top (and thinly under), and a thin ring all
//     the way round the shadow, brighter on the side coming at you.


#include "res://shaders/chart_galaxy.gdshaderinc"

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform sampler2D trace : filter_nearest;
// the trace's picture (one band of four), its hole's radius, its radius range
uniform vec2 trace_size = vec2(349.0, 393.0);
uniform float rh_c = 40.0;
uniform float r_pack = 168.0;
uniform vec2 vp_size = vec2(330.0, 220.0);
uniform vec2 hv = vec2(165.0, 110.0);
// the hole's radius in blocks
uniform float rh_v = 5.0;
uniform float z = 1.0;
uniform float phi = 0.0;
uniform float t = 0.0;
uniform float rin_p = 10.0;
uniform float rb = 30.0;
// which look (above), and how far out the disc reaches in hole radii
uniform int look = 0;
uniform float rout_k = 4.0;
// BANDS (`ChartSky.hole_bands`, the shape Jon picked, lit like his reference):
// 0 as stepped and dithered; 1 flat bands in the hole's warm colours; 2 flat
// bands in cream, pink, magenta and purple
uniform int bands = 0;
// how far toward the flat bands, 0 (as stepped and dithered) to 1 (the warm
// bands), every step between a blend of the two (`ChartSky.hole_band_amt`)
uniform float band_amt = 0.0;

const vec3 BH[8] = vec3[](vec3(30.0, 8.0, 4.0), vec3(74.0, 20.0, 6.0), vec3(132.0, 40.0, 12.0),
	vec3(194.0, 74.0, 20.0), vec3(236.0, 122.0, 38.0), vec3(255.0, 176.0, 84.0),
	vec3(255.0, 220.0, 150.0), vec3(255.0, 246.0, 226.0));
// the brightest step the hole uses: hot cream, never the near-white
const int TOP = 6;

// The disc at radius rr (blocks) and angle aa: falling off outward, plunging
// inside its inner edge, brighter turning toward you, streaked, breathing.
float disc_val(float rr, float aa, bool second, float fr) {
	float rin = rh_v * 1.16, rout = rh_v * rout_k;
	if (rr > rout || rr < rin * 0.55) {
		return 0.0;
	}
	// the gas inside the inner edge plunging in, dimming as it goes -- but
	// below the hole (`fr`, 0 to 1 going down), where the near side is in
	// front of the shadow, only by half: there it was a dark band between the
	// shadow and the disc's bright inner edge, which read as a gap in the disc
	// ("weird gap at the bottom of the black hole", Jon)
	float plunge = rr < rin ? 0.5 * fr + (1.0 - 0.5 * fr) * pow((rr - rin * 0.55) / (rin * 0.45), 1.6) : 1.0;
	float f = 1.0 - (max(rr, rin) - rin) / (rout - rin);
	float pre = pow(f, 1.4) * (1.0 + 0.45 * cos(PI - aa + 0.4)) * plunge * (second ? 0.75 : 1.0);
	// the disc's own spin: Keplerian, fast against the hole, whatever the
	// galaxy round it is doing
	float rb0 = max(rr * 2.0 / z, rin_p);
	float a2 = aa + mod(1.1 * pow(rb0 / rin_p, -1.5) * t, TAU_G) + phi;
	float rn = rr * 15.0 / rh_v;
	vec2 cs = vec2(cos(a2), sin(a2)) * rn;
	float tab = g_noise(cs * 0.11 + 40.0) * 0.6 + g_noise(cs * 0.231 + 84.0) * 0.3 + g_noise(cs * 0.473 + 172.0) * 0.1;
	float breath = 1.0 + 0.06 * sin(t * 0.9);
	return pre * (0.55 + 0.8 * tab) * breath;
}

// The disc's light made smooth for the bands: the same fall-off, plunge and
// brighter side, but only a slow wobble in place of the streaks' grain, so a
// band's edge is a clean curve; the wobble turns with the disc, so the bands'
// shapes shift as it spins.
float disc_soft(float rr, float aa, bool second, float fr) {
	float rin = rh_v * 1.16, rout = rh_v * rout_k;
	if (rr > rout || rr < rin * 0.55) {
		return 0.0;
	}
	// the gas inside the inner edge plunging in, dimming as it goes -- but
	// below the hole (`fr`, 0 to 1 going down), where the near side is in
	// front of the shadow, only by half: there it was a dark band between the
	// shadow and the disc's bright inner edge, which read as a gap in the disc
	// ("weird gap at the bottom of the black hole", Jon)
	float plunge = rr < rin ? 0.5 * fr + (1.0 - 0.5 * fr) * pow((rr - rin * 0.55) / (rin * 0.45), 1.6) : 1.0;
	float f = 1.0 - (max(rr, rin) - rin) / (rout - rin);
	float pre = pow(f, 1.4) * (1.0 + 0.45 * cos(PI - aa + 0.4)) * plunge * (second ? 0.75 : 1.0);
	float rb0 = max(rr * 2.0 / z, rin_p);
	float a2 = aa + mod(1.1 * pow(rb0 / rin_p, -1.5) * t, TAU_G) + phi;
	vec2 cs = vec2(cos(a2), sin(a2)) * rr * 15.0 / rh_v;
	float lo = g_noise(cs * 0.045 + 40.0);
	return pre * (0.8 + 0.5 * (lo - 0.5));
}

float unpack16(vec4 c) {
	return (floor(c.r * 255.0 + 0.5) * 256.0 + floor(c.g * 255.0 + 0.5)) / 65535.0;
}

// Whether the block dd blocks from the hole shows the shadow: its ray fell
// in, or (inside the shadow's radius) landed on gas too dim to see.
bool fell_at(vec2 dd) {
	float k = rh_c / rh_v;
	vec2 tp = clamp(floor(dd * k + 0.5) + floor(trace_size * 0.5), vec2(0.0), trace_size - 1.0);
	vec4 b0 = texelFetch(trace, ivec2(tp), 0);
	int fl = int(floor(b0.b * 255.0 + 0.5));
	if ((fl & 3) == 1) {
		return true;
	}
	if ((fl & 3) != 2 || length(dd) >= rh_v) {
		return false;
	}
	float aa = unpack16(texelFetch(trace, ivec2(tp) + ivec2(0, int(trace_size.y)), 0)) * TAU_G - PI;
	return disc_val(unpack16(b0) * r_pack / k, aa, (fl & 4) != 0, g_sm(0.1 * rh_v, 0.6 * rh_v, dd.y)) < 0.02;
}

// The smooth light at a point dd blocks from the hole, read from the trace
// (0 off the disc).
float soft_at(vec2 dd) {
	float k = rh_c / rh_v;
	vec2 tp = clamp(floor(dd * k + 0.5) + floor(trace_size * 0.5), vec2(0.0), trace_size - 1.0);
	vec4 b0 = texelFetch(trace, ivec2(tp), 0);
	int fl = int(floor(b0.b * 255.0 + 0.5));
	if ((fl & 3) != 2) {
		return 0.0;
	}
	float aa = unpack16(texelFetch(trace, ivec2(tp) + ivec2(0, int(trace_size.y)), 0)) * TAU_G - PI;
	float v = disc_soft(unpack16(b0) * r_pack / k, aa, (fl & 4) != 0, g_sm(0.1 * rh_v, 0.6 * rh_v, dd.y));
	// (the far image round the hole only near the shadow, as `fragment` has it)
	if ((fl & 4) != 0) {
		v *= 1.0 - g_sm(rh_v * 1.05, rh_v * 1.2, length(dd));
	}
	return v;
}

void fragment() {
	vec2 vp = floor(UV * vp_size);
	vec4 under = texture(screen_tex, SCREEN_UV);
	vec2 d = vp - hv;
	float dist = length(d);
	// what is behind, dimmed where the look wants the disc to read against it
	// (1 under the sector map's disc, 2 round the textbook hole)
	// (less when the hole is a few blocks across, where a dimmed ring round it
	// would read as a dark doughnut)
	vec3 base = under.rgb;
	float big = g_sm(2.0, 10.0, rh_v * rout_k / 4.0);
	if (look == 1) {
		float cov = length(vec2(d.x, d.y / 0.5)) / (rh_v * rout_k);
		base *= 1.0 - 0.72 * big * (1.0 - g_sm(0.5, 1.4, cov));
	} else if (look == 2) {
		float cov = length(vec2(d.x, d.y / 0.45)) / (rh_v * rout_k);
		base *= 1.0 - 0.42 * big * (1.0 - g_sm(0.4, 1.6, cov));
	}
	COLOR = vec4(base, under.a);
	float k = rh_c / rh_v;
	vec2 half_t = floor(trace_size * 0.5);
	vec2 tp = floor(d * k + 0.5) + half_t;
	bool inside = tp.x >= 0.0 && tp.y >= 0.0 && tp.x <= trace_size.x - 1.0 && tp.y <= trace_size.y - 1.0;
	tp = clamp(tp, vec2(0.0), trace_size - 1.0);
	vec4 b0 = texelFetch(trace, ivec2(tp), 0);
	vec4 b1 = texelFetch(trace, ivec2(tp) + ivec2(0, int(trace_size.y)), 0);
	int fl = int(floor(b0.b * 255.0 + 0.5));
	int kd = fl & 3;
	bool behind_ord = (fl & 4) != 0;
	bool front = (fl & 8) != 0;
	float rr = unpack16(b0) * r_pack / k;
	float aa = unpack16(b1) * TAU_G - PI;
	float rin = rh_v * 1.16;
	float val = kd == 2 ? disc_val(rr, aa, behind_ord, g_sm(0.1 * rh_v, 0.6 * rh_v, d.y)) : 0.0;
	// the disc seen again after going round the hole only as the thin arcs
	// hugging the shadow: further out, past the near side's edge, that image
	// was a lone bright crescent under the disc, a "smile" with a dark band
	// over it, that read as a smudge and a gap
	if (kd == 2 && behind_ord && dist > rh_v * 1.05) {
		val *= 1.0 - g_sm(rh_v * 1.05, rh_v * 1.2, dist);
	}
	// in the textbook look, the near band's gas in front of the shadow has the
	// shadow behind it: its faint outer part is dark on black, not dark specks
	// on the bulge
	if (look == 2 && kd == 2 && front && dist < rh_v) {
		base = vec3(0.0);
		COLOR = vec4(base, 0.5);
	}
	// the ring: up is 1 over the top of the hole, 0 at its sides
	float up = clamp(-d.y / max(dist, 1e-3), -1.0, 1.0);
	bool ring;
	float rwi0 = max(0.5, rh_v * 0.03);
	if (look == 2) {
		// thin, and all the way round: hidden only where the disc crosses in front
		float rw2 = max(0.6, rh_v * 0.05), rwi2 = max(0.5, rh_v * 0.03);
		ring = dist > rh_v - rwi2 && dist <= rh_v + rw2 && !front && val < 0.5;
	} else {
		float rw = max(0.5, rh_v * (look == 1 ? 0.06 : 0.05)) * (0.3 + 1.2 * max(0.0, up));
		float rwi = max(0.5, rh_v * (look == 1 ? 0.04 : 0.03));
		ring = dist > rh_v - rwi && dist <= rh_v + rw && !front && up > -0.2 && val < 0.5;
	}
	float th = (g_bayer(ivec2(d)) / 16.0 - 0.5) * 0.9;
	int code = -1;
	bool over = false;
	if (!inside) {
		code = -1;
	} else if (ring) {
		// the disc's hot inner edge, seen round the hole: the far side over the
		// top, so the angle is the screen's own
		float ar = atan(d.y, d.x);
		float vr = disc_val(rin * 1.04, ar, false, 0.0);
		if (look == 2) {
			vr *= 0.8;
		} else {
			vr *= (0.75 + 0.55 * max(0.0, up)) * (1.0 - 0.55 * g_sm(rh_v, rh_v + rh_v * 0.06 * 1.5 + 0.5, dist));
		}
		// eased hard, so even on the side coming at you its streaks step
		// between amber and cream instead of all reaching the top step and
		// reading as one pale line
		float vt = vr / (1.0 + 0.6 * vr);
		code = clamp(int(floor(vt * 7.0 + th)), look == 2 ? 3 : 2, TOP);
		over = true;
	} else if (kd == 1 && val < 0.06) {
		code = 10;
	} else if (val > 0.02) {
		// eased before it is stepped, so the hot side keeps its streaks; the
		// sector map's look steps it as the sector map does, capped at cream
		float vt = look == 1 ? val * 8.0 / 7.0 : val * 1.15 / (1.0 + 0.45 * val);
		int kq = int(floor(vt * 7.0 + th));
		if (kq >= 1 || (kq == 0 && val > 0.07)) {
			code = min(TOP, kq);
		}
	}
	if (code == 10) {
		COLOR = vec4(0.0, 0.0, 0.0, 0.5);
	} else {
		if (look == 1) {
			// the sector map's warm glow under its disc: an ellipse 152 x 82 at
			// a hole of 15, dithered away
			float gd = length(vec2(d.x / (rh_v * 152.0 / 15.0), d.y / (rh_v * 82.0 / 15.0)));
			if (gd < 1.0) {
				float gv = (1.0 - gd) * (1.0 - gd) * (1.0 + 0.08 * sin(t * 1.3));
				if (gv * 4.5 * 16.0 >= g_bayer(ivec2(d) + ivec2(99)) * 0.9) {
					vec3 gc = (gv > 0.45 ? BH[5] : BH[3]) / 255.0;
					base = mix(base, gc, 0.12 + gv * 0.26);
					COLOR = vec4(base, under.a);
				}
			}
		}
		if (code >= 0) {
			vec3 bc = BH[code] / 255.0;
			if (over) {
				COLOR = vec4(mix(base, bc, look == 2 ? 0.9 : 0.85), 0.5);
			} else if (look == 1) {
				// the gas added at 70%, as the sector map adds it
				// (never past hot cream, so a bright bulge under it is not whitened)
				COLOR = vec4(min(base + floor(BH[code] * 0.7) / 255.0, BH[TOP] / 255.0), 0.5);
			} else if (look == 2) {
				// near opaque where it is bright, the disc in front of what lies
				// behind it; its faint outer gas thinning to nothing, never a
				// dark rim
				float op = 0.88 * g_sm(0.0, 0.55, val);
				COLOR = vec4(mix(base, max(base, bc), op), 0.5);
			} else {
				// laid over the light behind rather than added to it: added to a
				// bright bulge every streak went to white, and the hole sat in a
				// white field
				COLOR = vec4(mix(base, max(base, bc), 0.8), 0.5);
			}
		}
	}
	float amt = bands > 0 ? 1.0 : band_amt;
	if (look == 0 && amt > 0.0) {
		// FLAT BANDS, or a step toward them. At 1: the light cut into five
		// solid steps, brightest against the hole, a cream ring hugging the
		// shadow, a dark outline between the shadow and the light, two soft
		// bands of glow outside; no dither, each step written whole so the
		// palette keeps it one colour. Between, everything moves together:
		// the streaks' grain gives way to a slow wobble, the steps go from
		// eight to five, the dither thins out, the outermost band melts into
		// the bulge less and less, and the ring, outline and glow come in.
		// The smooth light is averaged over nine points round the block (a
		// couple of the trace's pixels apart) before it is cut, so a band's
		// edge is a clean curve where the trace flips between the direct and
		// the bent picture.
		vec3 R[6];
		if (bands == 2) {
			R = vec3[6](vec3(255.0, 236.0, 214.0), vec3(246.0, 160.0, 178.0), vec3(208.0, 78.0, 150.0),
				vec3(136.0, 46.0, 130.0), vec3(74.0, 26.0, 90.0), vec3(26.0, 10.0, 34.0));
		} else {
			R = vec3[6](BH[6], BH[5], BH[4], BH[3], BH[2], BH[1]);
		}
		// how smooth the light is (a touch of grain left at 0.75), how many
		// steps, how much dither, how wide the outer fade (in steps)
		float sm = amt <= 0.75 ? amt / 0.75 * 0.85 : 0.85 + 0.6 * (amt - 0.75);
		float nst = amt < 0.375 ? 8.0 : (amt < 0.625 ? 6.0 : 5.0);
		float dth = 0.9 * pow(max(0.0, 1.0 - amt / 0.6), 1.5);
		float fw = amt >= 1.0 ? 0.0 : 2.4 * (1.0 - amt);
		float gk = g_sm(0.4, 1.0, amt);
		vec3 col = vec3(-1.0);
		float a_out = 0.5;
		// short of halfway there is no ring: the shadow runs out to its own
		// edge and meets the disc's light there; any block of it that sticks
		// out (three or fewer of its eight neighbours are shadow too) takes
		// the disc's light instead, so no lone block pokes up where a small
		// hole's rows are uneven
		bool rim = false;
		if (amt < 0.5 && fell_at(d)) {
			int nn = 0;
			for (int j = 0; j < 9; j++) {
				vec2 o9 = vec2(float(j % 3) - 1.0, float(j / 3) - 1.0);
				if (j != 4 && fell_at(d + o9)) {
					nn++;
				}
			}
			rim = nn <= 3;
		} else if (amt < 0.5 && dist < rh_v * 1.3 && max(under.r, max(under.g, under.b)) < 0.06) {
			// and a block just off the shadow showing only the dark the lens
			// bends in there (a tip on a small hole): the faintest step too
			rim = true;
		}
		if (!inside) {
			col = vec3(-1.0);
		} else if (kd == 1 && val < 0.06 && !(ring && amt >= 0.5) && !rim) {
			// (a block the trace rounds into the shadow just past its edge,
			// with no ring over it, takes the light round it instead: no nub)
			// the dark outline, thin at first
			float ow = max(1.0, rh_v * 0.07) * g_sm(0.35, 0.75, amt);
			col = (ow > 0.3 && dist > rh_v - rwi0 - ow) ? R[5] : vec3(0.0);
		} else if (ring && amt >= 0.5) {
			float vr = disc_soft(rin * 1.04, atan(d.y, d.x), false, 0.0) * (0.75 + 0.55 * max(0.0, up));
			col = R[vr > 0.7 ? 0 : 1];
		} else {
			// (short of halfway there is no ring, "without the white line
			// thing", Jon, of 0.25: the shadow's edge meets the disc's own
			// banded light, so nothing round it is brighter than its band)
			float Ls = 0.0;
			if (sm > 0.0 || rim) {
				float o = max(0.6, 2.0 * rh_v / rh_c);
				Ls = soft_at(d) * 2.0;
				for (int j = 0; j < 8; j++) {
					float an = float(j) * 0.785 + 0.39;
					Ls += soft_at(d + vec2(cos(an), sin(an)) * o * (j % 2 == 0 ? 1.0 : 0.6));
				}
				Ls /= 10.0;
			}
			float L = rim ? Ls : mix(val * 0.85, Ls, sm);
			// where the light sits on the bands' scale: 0 at the faintest
			// band's edge, 1 at each next, 4 at the cream
			float u = L < 0.17 ? (L - 0.07) / 0.1 : (L < 0.33 ? 1.0 + (L - 0.17) / 0.16
				: (L < 0.55 ? 2.0 + (L - 0.33) / 0.22 : (L < 0.85 ? 3.0 + (L - 0.55) / 0.3 : 4.0 + (L - 0.85) / 0.45)));
			// (the rim takes at least the faintest step: the sky the lens bends
			// in there is dark, and read as a nub on the shadow)
			if (rim) {
				u = max(u, 0.0);
			}
			if (u >= 0.0 || (fw > 0.0 && u > -fw * 0.5)) {
				float q = floor(max(u, 0.0) * nst / 5.0 + th * dth / 0.9);
				float x = clamp(q * 5.0 / nst, 0.0, 4.0);
				int i0 = int(floor(x));
				vec3 bc = mix(R[4 - i0], R[max(0, 3 - i0)], x - float(i0));
				// the outermost steps melting into the bulge
				float w = (fw > 0.0 && !rim) ? g_sm(-fw * 0.5, fw * 0.5, u) : 1.0;
				// and, short of the full bands, laid over the light as C lays it
				vec3 lay = mix(mix(base * 255.0, max(base * 255.0, bc), 0.8), bc, g_sm(0.5, 1.0, amt));
				// a star over the disc (a point: alpha under 0.6) shows through,
				// pulled toward the band's colour the brighter the band, so
				// the stars run in to the shadow and the bands still read
				if (under.a < 0.6 && dist > rh_v * 1.15) {
					lay = mix(under.rgb * 255.0, bc, 0.3 + 0.4 * clamp(x / 4.0, 0.0, 1.0));
				}
				col = mix(base * 255.0, lay, w);
				if (w < 0.98) {
					a_out = under.a;
				}
			} else if (dist < rh_v * 1.05 && amt >= 0.5) {
				// the dim gas plunging in, seen against the shadow, is the outline
				col = R[5];
			}
		}
		if (col.x >= 0.0) {
			COLOR = vec4(col / 255.0, a_out);
		} else {
			// the glow: two soft bands just past the disc's edge, fading into
			// the sky, coming in from halfway
			float ge = length(vec2(d.x / (rh_v * rout_k), d.y / (rh_v * rout_k * 0.42)));
			if (ge < 1.08) {
				COLOR = vec4(mix(under.rgb, R[4] / 255.0, 0.6 * gk), 0.5);
			} else if (ge < 1.2) {
				COLOR = vec4(mix(under.rgb, R[4] / 255.0, 0.3 * gk), 0.5);
			} else {
				COLOR = under;
			}
		}
	}
}
