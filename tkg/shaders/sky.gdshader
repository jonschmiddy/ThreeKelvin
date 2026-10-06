shader_type canvas_item;
render_mode unshaded, blend_disabled;

// THE SKY EACH FRAME: the baked sky (`sky_bake.gdshader`) with its gas added
// back under slow waves of brightness, so its bands of colour creep and shift
// under the palette (Jon: "why does the gas no longer move slightly?"); and
// round a pulsar, the shell's gas lit where the beam points, like a
// lighthouse's beam in fog, both ends of it at once.
//
// THE SKY IS FAR AWAY. When the map pans it slides by `sky_off`, a tenth of
// the pan, behind orbits that move the whole way (Jon: "a parallax
// background"); the bake has `margin` pixels to spare on every side.
//
// THE STAR'S OWN LIGHT IS NOT FAR AWAY: the glow round it and the gentle
// shafts through the dust ride the star as the map pans and grow as it zooms.
// It is added here, in the same tone map the bake used, through the dust the
// bake kept in its alpha.

uniform sampler2D base : filter_nearest, repeat_disable;
uniform sampler2D gas : filter_nearest, repeat_disable;
uniform float time = 0.0;
uniform bool pulsar = false;
// where the star is on screen this frame, and how far the map is zoomed
uniform vec2 star_at = vec2(480.0, 270.0);
uniform float zoom = 1.0;
uniform vec3 star_col = vec3(1.0, 0.86, 0.62);
uniform float rays_k = 1.0;
// the star's own glow on the sky (SIMPLIFIED inside a cloud: 0, the cloud is lit by it instead)
uniform float light_k = 1.0;
// SIMPLIFIED's clear sky (C): the star's glow gathered close and falling off fast, a
// long faint reach, its shafts faint -- clean black beyond, never a smog
uniform bool simplified = false;
// SIMPLIFIED round a pulsar: the shell's glimmer -- bright bands travelling along its
// filaments, brighter on each beat (`beat` 0..0.5) -- and its strength (0 with
// reduced motion)
uniform float beat = 0.0;
uniform float glim_k = 1.0;
// PAINTED: the star's light on a clear sky as two flat rings, subtle (bible 4.4:
// light drawn as bands, not haze); the paint pass sets them on the halo ramp
uniform bool painted = false;
// RADIANT (direction A): a clear sky stays clean, but the system's thin dust
// lens lies along its plane (the zodiacal light), faint and warm, brightest by
// the sun, seen at the plane's tilt; round a pulsar the beams light a faint
// fog the whole way out, like a lighthouse's in mist, the shell's gas most
uniform bool radiant = false;
// RADIANT's warm haze round the sun on a clear sky (0 in a cloud: the gas is its haze)
uniform float r_haze = 0.085;
uniform float tilt = 0.38;
uniform vec2 sky_off = vec2(0.0);
uniform float margin = 0.0;
// the beam's angle on screen, and whether it points across the screen at all
uniform float beam_angle = 0.0;
uniform bool beam_on = false;
// ROUND A PULSAR THE GAS IS ITS REMNANT, NOT FAR SKY (Jon: "zooming and panning
// causes issues with the gas cloud around the pulsar"): it is read about the
// pulsar where it stands now, zoomed with the map (`shell_k` times as large as
// baked, the bake made with the pulsar at `bake_star`), while the far sky behind
// it slides by the parallax and does not zoom
uniform float shell_k = 1.0;
uniform vec2 bake_star = vec2(480.0, 270.0);
// THE WEATHER OUTSIDE A NEBULA (`SkyWeather`), one event at a time (`e_ev`):
//   1 a blue sun's ERUPTION SHELL lifting off it (in the system: with the map);
//   2 a dark GLOBULE drifting across the galaxy's band (far sky);
//   3 FOG: a knot of gas drifting into a pulsar's shell, lit by its beam;
//   4 a MAGNETAR's rings racing out through the shell's gas;
//   5 a FLARE'S ECHO, a warm ring sweeping out through the core's far gas.
// `e_at` is in the sky's own pixels (far sky) or the shell's (3); `e_r` a
// radius, `e_rmax` the eruption's last; strength `e_k` (0: none).
uniform int e_ev = 0;
uniform vec2 e_at = vec2(-9999.0);
uniform float e_age = 0.0;
uniform float e_k = 0.0;
uniform float e_r = 0.0;
uniform float e_rmax = 1.0;
uniform float e_seed = 0.0;
// THE SHIP, on screen: an event's light fades out round it
uniform vec4 g_ship = vec4(-9999.0, -9999.0, 30.0, 90.0);

const vec3 VOID = vec3(7.0, 10.0, 18.0) / 255.0;

float hash2(vec2 p) {
	ivec2 q = ivec2(floor(p));
	uint h = (uint(q.x) * 374761393u) ^ (uint(q.y) * 668265263u);
	h = (h ^ (h >> 13u)) * 1274126177u;
	return float(h ^ (h >> 16u)) / 4294967296.0;
}
float noise2(vec2 p) {
	vec2 i = floor(p), f = p - i;
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash2(i), b = hash2(i + vec2(1.0, 0.0)), c = hash2(i + vec2(0.0, 1.0)), d = hash2(i + vec2(1.0, 1.0));
	return a + (b - a) * u.x + (c - a) * u.y + (a - b - c + d) * u.x * u.y;
}
float fbm2(vec2 p, int o) {
	float a = 0.5, s = 0.0, n = 0.0;
	for (int i = 0; i < o; i++) { s += a * noise2(p); n += a; p *= 2.03; a *= 0.5; }
	return s / n;
}
float smooth_k(float a, float b, float x) { float u = clamp((x - a) / (b - a), 0.0, 1.0); return u * u * (3.0 - 2.0 * u); }

float lit_by_beam(float d) {
	if (d >= 0.42) return 0.0;
	return min(1.0, exp(-pow(d / 0.2, 2.0)) + 0.3 * exp(-d / 0.35)) * (d > 0.36 ? (0.42 - d) / 0.06 : 1.0);
}

void fragment() {
	vec2 px = floor(UV * vec2(960.0, 540.0));
	ivec2 tp = ivec2(px - floor(sky_off) + margin);
	vec4 bs = texelFetch(base, tp, 0);
	vec3 c = bs.rgb;
	float dk = bs.a;
	vec4 g = texelFetch(gas, tp, 0);
	vec2 q = vec2(0.0);
	if (pulsar) {
		// the shell, about the pulsar and zoomed: read between the baked pixels
		q = bake_star + (px + 0.5 - star_at) / max(shell_k, 1e-3) + margin - 0.5;
		vec2 qi = floor(q), qf = q - qi;
		ivec2 gs = textureSize(gas, 0);
		ivec2 q0 = clamp(ivec2(qi), ivec2(0), gs - 1), q1 = clamp(ivec2(qi) + 1, ivec2(0), gs - 1);
		vec4 a0 = mix(texelFetch(gas, q0, 0), texelFetch(gas, ivec2(q1.x, q0.y), 0), qf.x);
		vec4 a1 = mix(texelFetch(gas, ivec2(q0.x, q1.y), 0), texelFetch(gas, q1, 0), qf.x);
		g = mix(a0, a1, qf.y);
		if (q.x < 0.0 || q.y < 0.0 || q.x > float(gs.x - 1) || q.y > float(gs.y - 1)) g = vec4(0.0);
	}
	// FOG: a knot of thicker gas in the shell, for the beam to light on the beat
	if (e_k > 0.0 && e_ev == 3 && pulsar) {
		vec2 fq = q - e_at;
		float r2 = dot(fq, fq);
		if (r2 < 8100.0) {
			float gx = exp(-r2 / 900.0) * fbm2(q * 0.06 + e_seed, 3) * e_k;
			g.a += gx * 0.07;
			g.rgb += vec3(0.24, 0.42, 0.8) * gx * 0.12;
		}
	}
	vec2 b = px - mod(px, 2.0);
	float gk = smooth_k(g_ship.z, g_ship.w, length(b - g_ship.xy));
	float m = 1.0 + 0.24 * sin(b.x * 0.011 + time * 0.22) * sin(b.y * 0.017 - time * 0.16)
		+ 0.12 * sin(b.x * 0.029 - time * 0.31) * cos(b.y * 0.025 + time * 0.27);
	if (pulsar && simplified) {
		// THE REMNANT ROUND THE PULSAR (C): its filaments hydrogen red on the
		// outside of the front, oxygen teal in curtains just inside it, the dark of
		// the system within; shock glimmers running along the shell, on the beat
		float shell = g.r, skin_t = g.g, inner = g.b;
		vec2 cd = normalize((b + 1.0 - star_at) / vec2(1.0, 0.66) + vec2(1e-4, 0.0));
		float glim = 0.0;
		for (int k = 0; k < 3; k++) {
			float a0 = float(k) * 2.094 + time * 0.05;
			float da = acos(clamp(dot(cd, vec2(cos(a0), sin(a0))), -1.0, 1.0));
			glim += 0.6 * exp(-pow(da / 0.15, 2.0));
		}
		glim *= glim_k * (0.6 + beat);
		vec3 HA = vec3(1.0, 0.2, 0.3), O3 = vec3(0.2, 0.95, 0.85);
		vec3 sc = mix(mix(vec3(0.75, 0.10, 0.12), HA * vec3(1.0, 0.85, 0.9), clamp(shell * 1.6, 0.0, 1.0)), O3 * 0.95, smooth_k(0.14, 0.40, inner));
		vec3 H = sc * shell * (0.36 + glim * 0.7) * (1.0 + 0.5 * smooth_k(0.2, 0.7, inner));
		H += O3 * 0.30 * pow(skin_t, 0.8) * smooth_k(0.03, 0.20, inner) * (1.0 - smooth_k(0.36, 0.80, inner));
		H += vec3(0.010, 0.011, 0.023) * inner * 0.25;
		c = min(vec3(1.0), c + pow(vec3(1.0) - exp(-H * 1.2), vec3(1.0 / 2.2)));
	} else {
		c = min(vec3(1.0), c + g.rgb * m);
	}
	// A GLOBULE: a small ragged dark cloud hiding the band and the far stars,
	// its edge faintly lit (the nearer stars are drawn over it)
	if (e_k > 0.0 && e_ev == 2) {
		vec2 qg = (b - floor(sky_off)) - e_at;
		float lg = length(qg);
		if (lg < e_r * 1.6) {
			float mg = smooth_k(1.0, 0.7, lg / e_r + 0.35 * (fbm2(qg / e_r * 1.5 + e_seed, 3) - 0.5)) * e_k;
			c = mix(c, VOID, mg * 0.92) + vec3(0.62, 0.62, 0.78) * 0.05 * mg * (1.0 - mg) * 4.0 * e_k;
		}
	}
	// A FLARE'S ECHO: a broad warm ring sweeping out from the hole through the
	// far gas, lighting its thick parts as it passes
	if (e_k > 0.0 && e_ev == 5) {
		float de = length((b - floor(sky_off)) - e_at);
		float ring = exp(-pow((de - e_r) / 16.0, 2.0));
		vec3 add = (g.rgb * m * ring * 2.6 + vec3(1.0, 0.64, 0.36) * ring * 0.09 * (1.0 - dk)) * e_k * gk;
		// (added as gathered light: on the thickest gas it clipped to a flat white patch)
		// and held to the gas's own top step: the core's palette jumps from it
		// straight to a pale grey, so thick gas lit past it turned into a flat
		// grey slab dotted with amber, like a stamp
		vec3 lit = vec3(1.0) - (vec3(1.0) - c) * exp(-add * 1.4);
		c = min(lit, max(c, vec3(0.40, 0.36, 0.41)));
	}
	// the star's light, in 2x2 blocks as the bake worked it out, at the zoom
	vec2 sv = (b + 0.5 - star_at) / zoom;
	float dd = length(vec2(sv.x, sv.y * 1.25));
	float I2 = (0.36 * exp(-dd / 42.0) + 0.06 * exp(-dd / 160.0)) * (pulsar ? 0.35 : 1.0);
	if (simplified && !pulsar) I2 = 0.30 * exp(-dd / 28.0) + 0.022 * exp(-dd / 110.0);
	// (PAINTED: a clear sky's rings are set by the band memory, `sector_b_state`)
	if (painted && !pulsar) I2 = 0.05 * step(dd, 34.0) + 0.028 * step(dd, 58.0);
	if (!pulsar) {
		float a = atan(sv.y, sv.x), n = fbm2(vec2(a * 7.0 + 30.0, 3.1), 3);
		float rays = pow(max(0.0, n - 0.45) * 2.6, 3.0);
		I2 += rays_k * rays * (simplified ? 0.018 : 0.05) * exp(-dd / 260.0) * smooth_k(10.0, 60.0, dd);
	}
	float hz = 0.0;
	if (radiant && !pulsar) {
		// A's warm haze round the sun on a clear sky: its light scattered by the
		// system's own dust, broad and soft, about the same size on screen at every
		// zoom (held to the frame, as A's)
		float dpx = length(vec2(b + 0.5 - star_at) * vec2(1.0, 1.25)) / pow(max(shell_k, 0.05), 0.42);
		// (stronger as the map closes in on the sun: faint over the whole system,
		// a broad glow round the star itself)
		hz = r_haze * sqrt(clamp(shell_k, 1.0, 8.0)) * (exp(-dpx / 85.0) + 0.35 * exp(-dpx / 210.0)) * (0.85 + 0.3 * fbm2(b * 0.02 + 5.0, 2));
		// THE ZODIACAL LENS: dust in the plane, its density falling off from the
		// sun, a thin sheet seen at the tilt; forward light a little stronger
		// on the sun's far side
		// (a lens, not a disc: thin across the plane, thickening a little and
		// fading away along it)
		float ax = abs(sv.x);
		I2 += 0.07 * exp(-ax / 300.0) * exp(-abs(sv.y) / ((7.0 + 0.07 * ax) * max(tilt, 0.05) / 0.38)) * smooth_k(10.0, 34.0, dd);
	}
	vec3 P = I2 * light_k * (1.0 - dk * 0.5) * (1.0 - dk * 0.85) * star_col;
	// (the haze in the dust's own warm brown, whatever the star's tint: in its
	// white it came out grey)
	P += hz * light_k * (1.0 - dk * 0.85) * vec3(1.0, 0.6, 0.34);
	// AN ERUPTION SHELL: a thin clumped shell lifting off a blue sun, a sphere
	// seen from outside (so round, never the plane's ellipse), fading as it goes
	if (e_k > 0.0 && e_ev == 1) {
		float re = length(b + 0.5 - star_at);
		if (abs(re - e_r) < 6.0 * (2.0 + 0.08 * e_r)) {
			vec2 nd = normalize(b - star_at);
			float sh = exp(-pow((re - e_r) / (2.0 + 0.08 * e_r), 2.0)) * (0.5 + fbm2(nd * 6.0 + e_seed + re * 0.02, 3))
				* smooth_k(0.38, 0.62, fbm2(nd * 3.2 + e_seed * 1.7 + 11.0, 3))
				/ (1.0 + pow(e_r / (60.0 * zoom), 2.0));
			P += mix(vec3(0.75, 0.85, 1.0), vec3(1.0, 0.45, 0.55), smooth_k(0.3, 1.0, e_r / e_rmax)) * sh * 1.3 * e_k * gk
				* (1.0 - 0.6 * smooth_k(0.04, 0.2, I2)) / (1.0 + 0.4 * max(zoom - 1.0, 0.0));
		}
	}
	c = min(vec3(1.0), VOID + 1.0 - (1.0 - max(c - VOID, vec3(0.0))) * exp(-1.5 * P));
	if (pulsar && beam_on && radiant) {
		// (RADIANT: the beam through the fog, all the way out, the shell brightest)
		float a = atan(px.y - star_at.y, px.x - star_at.x);
		float d1 = abs(mod(a - beam_angle + PI, 2.0 * PI) - PI);
		float d2 = abs(mod(a - beam_angle, 2.0 * PI) - PI);
		float w = max(lit_by_beam(d1), lit_by_beam(d2));
		float rs0 = length(px - star_at);
		float fog = max(g.a, 0.010 * exp(-rs0 / (420.0 * max(shell_k, 0.5))));
		float add2 = 1.0 - exp(-1.5 * fog * 4.0 * 3.0);
		c = min(vec3(1.0), c + w * add2 * vec3(0.80, 0.90, 1.0));
	} else if (pulsar && beam_on && g.a > 0.0075) {
		float a = atan(px.y - star_at.y, px.x - star_at.x);
		float d1 = abs(mod(a - beam_angle + PI, 2.0 * PI) - PI);
		float d2 = abs(mod(a - beam_angle, 2.0 * PI) - PI);
		float w = max(lit_by_beam(d1), lit_by_beam(d2));
		float add2 = 1.0 - exp(-1.5 * g.a * 4.0 * 2.2);
		c = min(vec3(1.0), c + w * add2 * vec3(1.0, 0.88, 0.72));
	}
	// A MAGNETAR'S RINGS racing out through the shell's gas, lighting it as they pass
	if (e_k > 0.0 && e_ev == 4 && pulsar && g.a > 0.0075) {
		float rs = length(px - star_at), rr = 0.0;
		for (int i = 0; i < 3; i++) {
			float v = i == 0 ? 30.0 : (i == 1 ? 42.0 : 55.0);
			rr += exp(-pow((rs - v * e_age * shell_k) / (4.0 * max(shell_k, 1.0)), 2.0));
		}
		c = min(vec3(1.0), c + rr * (1.0 - exp(-1.5 * g.a * 4.0 * 2.2)) * vec3(0.75, 0.85, 1.0) * e_k);
	}
	COLOR = vec4(c, 1.0);
}
