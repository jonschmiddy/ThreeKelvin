shader_type canvas_item;
render_mode blend_mix;

// THE LIVING PART OF THE SKY (`StarchartScreen.MapChart`, the SkyAnim layer):
// stars catching the light, a density wave turning through the disc, the
// stars orbiting the black hole, its accretion disc, and the pulsars. The
// gamma-ray bursts stay in GDScript (`SkyAnim.Bursts`): three channels, rare,
// and only drawn while one is lit.
//
// Every particle's fixed facts were already laid out once by `_build_stars`;
// what moves is the clock. That loop used to run in GDScript every frame at
// 6 to 12ms. Here it is the same arithmetic per quad, driven by uniforms.
//
// THE CLOCK ARRIVES ALREADY FOLDED. A float on the GPU cannot hold an hour of
// seconds times an orbital speed to a fraction of a pixel, so the CPU hands
// over each global rate's phase already reduced to one turn (`tw`, `twv`,
// `u55`, `u31`, `u42`), and the orbits and the disc, whose rates differ per
// particle, carry their angle as it stood at the last REBASE plus `tau`, the
// seconds since. `MapChart._anim_rebase` rewrites those angles now and then.
//
// The data texture holds two texels per particle, in draw order:
//   twinkle  (x, y, phase, -)           (-)
//   wave     (x, y, phase, -)           (colour)
//   orbit    (radius, angle, rate, size + 4 * may-be-darkened)  (colour)
//   disc     (radius, angle, rate, radial light)  (b, breath, churn 1, churn 2)
//   pulsar   (x, y, period, phase at rebase)     (-)
// and each pulsar has three quads: itself, and a pixel either side at the peak.

#include "res://shaders/chart_sky.gdshaderinc"

uniform sampler2D data : filter_nearest;
uniform int tex_w = 2048;
uniform int n_tw = 0;
uniform int n_wv = 0;
uniform int n_orb = 0;
uniform int n_disc = 0;
uniform int n_puls = 0;

uniform vec2 centre = vec2(0.0);
uniform vec2 size = vec2(0.0);
uniform float zoom = 1.0;
uniform float tw = 0.0;
uniform float twv = 0.0;
uniform float u55 = 0.0;
uniform float u31 = 0.0;
uniform float u42 = 0.0;
uniform float tau = 0.0;
uniform float hole_sq = 0.0;
uniform float hole_px = 0.0;
uniform float gk = 1.0;
// the dark lobes that reach the orbiting region: x, y, radius
uniform vec4 dark[32];
uniform int n_dark = 0;
// twinkle 3, disc 8, pulsar 3
uniform vec4 pal[14];

float extinct(vec2 p) {
	float e = 0.0;
	for (int i = 0; i < n_dark; i++) {
		float d = len(p - dark[i].xy) / max(1.0, dark[i].z);
		if (d < 1.0) {
			float f = 1.0 - d;
			e = max(e, f * f * (3.0 - 2.0 * f));
		}
	}
	return e;
}

bool on_chart(vec2 q) {
	return !(q.x < 0.0 || q.y < 0.0 || q.x > size.x || q.y > size.y);
}

void vertex() {
	int quad = VERTEX_ID / 6;
	int e = quad;
	int slot = 0;
	int s_wv = n_tw;
	int s_orb = s_wv + n_wv;
	int s_disc = s_orb + n_orb;
	int s_puls = s_disc + n_disc;
	if (quad >= s_puls) {
		slot = (quad - s_puls) % 3;
		e = s_puls + (quad - s_puls) / 3;
	}
	ivec2 at = ivec2((2 * e) % tex_w, (2 * e) / tex_w);
	vec4 d0 = texelFetch(data, at, 0);
	vec4 d1 = texelFetch(data, at + ivec2(1, 0), 0);
	vec4 col = vec4(1.0);
	float side = 1.0;
	vec2 pos = vec2(0.0);
	bool ok = false;

	if (quad < s_wv) {
		// Stars catching the light: a slice of the field, and only the few at
		// the top of their cycle, ramping through three brightnesses so a star
		// brightens and fades rather than blinking. Slow and narrow at the
		// top -- fast and wide was a Christmas tree, not a sky.
		float pulse = sin(tw + d0.z);
		vec2 q = centre + mul2(d0.xy, zoom);
		ok = pulse >= 0.955 && on_chart(q);
		col = pal[0];
		if (pulse > 0.995) {
			col = pal[2];
		} else if (pulse > 0.98) {
			col = pal[1];
		}
		pos = q;
	} else if (quad < s_orb) {
		// A density wave: nothing moves, a brightness sweeps round the disc
		// lighting the stars already there. Anything that visibly travelled
		// would read as the background sliding past a frozen galaxy.
		vec2 q = centre + mul2(d0.xy, zoom);
		ok = on_chart(q) && sin(d0.z + twv) >= 0.93;
		col = d1;
		pos = q;
	} else if (quad < s_disc) {
		// The inner stars, in orbit: the one place fast motion is honest.
		float oa = d0.y - tau * d0.z;
		float oc = cos(oa);
		float osn = sin(oa);
		vec2 off = mul2(vec2(oc, osn) * d0.x, zoom);
		vec2 q = centre + off;
		ok = mul(off.x, off.x) + mul(off.y, off.y) >= hole_sq && on_chart(q);
		float sz = floor(d0.w + 0.5);
		bool may_dark = sz >= 3.5;
		if (may_dark) {
			sz -= 4.0;
		}
		// Gas from a cloud goes back as a block, at the static wash's size.
		side = sz > 1.5 ? gk : (sz > 0.5 ? 2.0 : 1.0);
		col = d1;
		// Dimmed rather than dropped when a dark cloud is in front of it: a
		// particle winking out at the cloud's edge would be a worse artifact.
		if (may_dark) {
			float oex = extinct(vec2(oc, osn) * d0.x);
			if (oex > 0.02) {
				col = darkened(col, oex * 0.88);
			}
		}
		pos = q;
	} else if (quad < s_puls) {
		// The accretion disc, after M87*: a narrow band packed hard enough to
		// be solid, brightness the radial profile times the Doppler beam times
		// a slow churn, on a ramp from black through red and orange to white.
		float ang2 = d0.y - tau * d0.z;
		float co = cos(ang2);
		float beam = clamp(0.20 + 0.80 * co, 0.0, 1.0);
		float hi = d0.w * beam * 1.14;
		float churn = 0.88 + 0.14 * sin(ang2 * 4.0 - u55 + d1.z) + 0.12 * sin(ang2 * 7.0 + u31 + d1.w);
		float heat = d0.w * beam * churn;
		float dr = d0.x * (1.0 + 0.06 * sin(u42 + d1.y));
		vec2 q = centre + mul2(vec2(co, sin(ang2)) * dr, zoom);
		ok = !(hi < 0.055 || d1.x > 0.55 + hi * 0.45)
			&& !(heat < 0.055 || d1.x > 0.55 + heat * 0.45) && on_chart(q);
		col = pal[3];
		if (heat > 0.80) {
			col = pal[10];
		} else if (heat > 0.66) {
			col = pal[9];
		} else if (heat > 0.52) {
			col = pal[8];
		} else if (heat > 0.39) {
			col = pal[7];
		} else if (heat > 0.27) {
			col = pal[6];
		} else if (heat > 0.16) {
			col = pal[5];
		} else if (heat > 0.09) {
			col = pal[4];
		}
		pos = q;
	} else if (e < s_puls + n_puls) {
		// Pulsars: the only thing on the chart that keeps time, each at its own
		// rate. Never filtered by the chart's toggles -- the icon is a claim
		// about somewhere you can go, the flash is simply happening.
		float ph = mod(d0.w + tau, d0.z) / d0.z;
		float env = 1.0 - ph / 0.16;
		vec2 pz = mul2(d0.xy, zoom);
		vec2 q = centre + pz;
		ok = ph <= 0.16 && len(pz) >= hole_px
			&& !(q.x < 1.0 || q.y < 0.0 || q.x > size.x - 1.0 || q.y > size.y);
		col = env > 0.45 ? pal[11] : pal[12];
		if (slot > 0) {
			// A pixel either side at the peak: a pulsar is a lighthouse.
			ok = ok && env > 0.55;
			col = pal[13];
		}
		pos = snap(q) + vec2(slot == 1 ? px_scale : (slot == 2 ? -px_scale : 0.0), 0.0);
		VERTEX = ok ? quad_corner(VERTEX_ID, pos, vec2(1.0)) : HIDE;
		COLOR = col;
	}
	if (quad < s_puls) {
		VERTEX = ok ? quad_corner(VERTEX_ID, snap(pos), vec2(side)) : HIDE;
		COLOR = col;
	} else if (e >= s_puls + n_puls) {
		VERTEX = HIDE;
		COLOR = col;
	}
}
