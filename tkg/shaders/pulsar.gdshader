shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;

// THE PULSAR, painted per game pixel: the system map's renderer (the
// scratchpad's `sysmap/page/index.html`, sealed there as `PS`, from "Six
// Pulsars") on the GPU, with the map's own settings (`pulsarDraw` in
// `sysmap/template.html`): seen from the orbits' tilt, a bigger beam, three
// heights through the cloud.
//
// Everything the mockup drew here was LIGHT, added up per pixel: the cloud of
// gas turning round the star, its jets, the two beams, a starquake's ring, a
// sprinkler's spray, the star's glow. The light is then toned, dithered and
// snapped to the renderer's own thirty colours, exactly as the page did, and
// laid on the map the way its `layOn` laid it: nothing is solid, so every pixel
// ADDS (alpha 0), and faint pixels fade in rather than switch on, so the
// renderer's 480 x 320 box never shows against the sky.
//
// The cloud's texture is worked out for every pixel. build.py meant the map to
// work it out once per 2x2 block, but its cache kept the time in a
// Float32Array and compared it with the frame's own double, so it almost
// never matched: the cloud Jon approved on the map is the per-pixel one, fine
// wound streaks, and the blocky one (seen only on a time a float holds
// exactly, like 0.5 s) looked wrong beside it. The sprinkler's spray was thrown
// out particle by particle; the 300 particles are placed by `PulsarView` and
// handed over as a list.
//
// ZOOM: the map zooms by redrawing, never by stretching. Every length here is
// in the pulsar's own units, its pixels at zoom 1; a game pixel is 1 / zoom of
// one, so at zoom 2 the cloud, beams, jets, ring and star are worked out over
// twice the pixels each way. The dither and the spray's dots stay on game pixels.

// the dither in cell x cell blocks (2 on the map, whose place is drawn in 2x2 blocks)
uniform int cell = 1;
uniform float time = 0.0;
// the frame (`PS.frame`): the beam's magnetic axis m this moment, the steady
// spin axis s and the equator plane's axes e1, e2 (the cloud turns in it)
uniform vec3 m_axis = vec3(1.0, 0.0, 0.0);
uniform vec3 s_axis = vec3(0.0, -1.0, 0.0);
uniform vec3 e1 = vec3(-1.0, 0.0, 0.0);
uniform vec3 e2 = vec3(0.0, 0.0, 1.0);
uniform float flash = 0.0;
uniform float glitch_k = 0.0;
// seconds since the latest flash on the beat, and where in the five-second loop
uniform float beat_age = 0.0;
uniform float loop_at = 0.0;

// the cloud (`P.gas`): ring radius, width, height through it, turbulence, warp,
// haze, brightness, turn rate, and where in the noise its pattern is cut from
uniform float gas_r = 34.0;
uniform float gas_w = 12.0;
uniform float gas_tall = 0.9;
uniform float gas_turb = 0.9;
uniform float gas_warp = 1.2;
uniform float gas_haze = 0.3;
uniform float gas_i = 0.8;
uniform float gas_spin = 0.3;
uniform vec2 gas_off = vec2(0.0);
// the cloud's turn this moment (spin * t, mod TAU) and its crossfade phase (t / 10, mod 1)
uniform float gas_rot = 0.0;
uniform float gas_ph = 0.0;
uniform int gas_vol = 3;

// the one or two motions rolled from the system's seed
uniform bool beat_glow = false;
uniform bool jets = false;
uniform bool quake = false;
uniform float jet_ph1 = 0.0; // 1.6 t, mod TAU
uniform float jet_ph2 = 0.0; // 3.2 t, mod TAU
// the sprinkler's spray: each particle's pixel (x, y, in the box), its light, white or ice; sorted by y
uniform vec4 spray[300];
uniform int n_spray = 0;

// the map's beam (`pulsarDraw`): beamLen 200, bw 3.2, spread 0.16, beamI 1.5
uniform float beam_len = 200.0;
uniform float beam_w = 3.2;
uniform float beam_spread = 0.16;
uniform float beam_i = 1.5;

// THE WEATHER (`SkyWeather`): Crab wisps rippling out in the cloud's plane; the
// Vela jet whipping along the spin axis (the rolled jets fade out for it); a
// magnetar's flare on a beat. Ages in seconds, strengths 0 for none.
uniform float wisp_age = 0.0;
uniform float wisp_k = 0.0;
uniform float hose_age = 0.0;
uniform float hose_k = 0.0;
uniform float jets_fade = 1.0;
uniform float mag_age = 0.0;
uniform float mag_k = 0.0;
// THE SHIP, in this box's pixels: the weather's light fades out round it (the
// wisps and the firehose grow with the map and would sweep over it)
uniform vec2 g_ship = vec2(-9999.0);

// the map's zoom, and half the box this moment in game pixels (the box is
// BOX x zoom, so its beams are never cut short at any zoom)
uniform float zoom = 1.0;
uniform vec2 box_half = vec2(240.0, 160.0);

const vec3 WHITE = vec3(1.0, 1.0, 1.0);
const vec3 ICE = vec3(0.72, 0.94, 1.0);
const vec3 CYAN = vec3(0.22, 0.66, 0.84);
const vec3 BLUE = vec3(0.1, 0.24, 0.52);
const vec3 VIOLET = vec3(0.4, 0.27, 0.74);
const vec3 SPACE = vec3(0.02, 0.024, 0.04);

// the renderer's own colours, each pixel's light snapped to the nearest
const vec3 PAL[30] = vec3[30](
	vec3(5.0, 6.0, 10.0), vec3(11.0, 18.0, 32.0), vec3(18.0, 32.0, 58.0), vec3(26.0, 52.0, 86.0), vec3(36.0, 79.0, 122.0),
	vec3(52.0, 120.0, 160.0), vec3(79.0, 166.0, 196.0), vec3(127.0, 208.0, 224.0), vec3(184.0, 236.0, 244.0), vec3(234.0, 252.0, 255.0),
	vec3(255.0, 255.0, 255.0), vec3(51.0, 68.0, 90.0), vec3(201.0, 216.0, 234.0), vec3(160.0, 228.0, 238.0), vec3(96.0, 188.0, 212.0),
	vec3(10.0, 16.0, 48.0), vec3(16.0, 32.0, 96.0), vec3(26.0, 58.0, 138.0), vec3(42.0, 90.0, 184.0), vec3(74.0, 138.0, 216.0),
	vec3(138.0, 208.0, 240.0), vec3(200.0, 240.0, 255.0), vec3(26.0, 16.0, 48.0), vec3(46.0, 28.0, 82.0), vec3(74.0, 48.0, 128.0),
	vec3(122.0, 90.0, 180.0), vec3(28.0, 22.0, 64.0), vec3(44.0, 36.0, 102.0), vec3(70.0, 58.0, 148.0), vec3(108.0, 92.0, 196.0)
);

// ---------------------------------------------------------------- noise, as the page's
// (its own two-dimensional hash: Math.imul wraps as uint multiplication does)
float hash2(float x, float y) {
	uint h = (uint(int(x)) * 374761393u) ^ (uint(int(y)) * 668265263u);
	h = (h ^ (h >> 13u)) * 1274126177u;
	return float(h ^ (h >> 16u)) / 4294967296.0;
}
float noise(float x, float y) {
	float xi = floor(x), yi = floor(y), xf = x - xi, yf = y - yi;
	float u = xf * xf * (3.0 - 2.0 * xf), v = yf * yf * (3.0 - 2.0 * yf);
	float a = hash2(xi, yi), b = hash2(xi + 1.0, yi), c = hash2(xi, yi + 1.0), d = hash2(xi + 1.0, yi + 1.0);
	return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v;
}
float sm(float a, float b, float x) { float u = clamp((x - a) / (b - a), 0.0, 1.0); return u * u * (3.0 - 2.0 * u); }
float env(float a, float r, float h, float f) { return sm(0.0, r, a) * (1.0 - sm(r + h, r + h + f, a)); }
float fbm(float x, float y) {
	return noise(x, y) * 0.5 + noise(x * 2.03 + 17.0, y * 2.03 + 9.0) * 0.25 + noise(x * 4.1 + 3.0, y * 4.1 + 31.0) * 0.125 + noise(x * 8.3 + 11.0, y * 8.3 + 5.0) * 0.0625;
}

// ---------------------------------------------------------------- the equator plane
// where a point on screen (from the star) lands on the star's equator plane:
// its radius, its angle round the star, and how far toward you it leans
vec3 plane_at(float px, float py) {
	float det = e1.x * e2.y - e1.y * e2.x;
	float u = (px * e2.y - py * e2.x) / det, v = (e1.x * py - e1.y * px) / det;
	float r = sqrt(u * u + v * v);
	return vec3(r, atan(v, u), r > 0.0 ? (u * e1.z + v * e2.z) / r : 0.0);
}

// ---------------------------------------------------------------- the gas
float dens_at(float r, float h) {
	float R = gas_r, w = gas_w;
	float a = (r - R) / w, b = h / (w * gas_tall), c = h / (w * gas_tall * 1.4);
	return exp(-(a * a + b * b)) + gas_haze * exp(-r / (R * 0.75)) * exp(-(c * c));
}
float cloud_sample(float r, float a, float rot) {
	float aa = a - rot, u = r * cos(aa), v = r * sin(aa), sc = 0.075;
	float ox = gas_off.x, oy = gas_off.y;
	float wx = gas_warp * (noise(u * 0.03 + 7.0 + ox, v * 0.03 + oy) - 0.5) * 30.0;
	float wy = gas_warp * (noise(u * 0.03 + 19.0 + ox, v * 0.03 + 3.0 + oy) - 0.5) * 30.0;
	return fbm((u + wx) * sc + ox, (v + wy) * sc + oy);
}
// two copies of the pattern, each turning for a while and swapped out while the
// other shows, so the cloud turns faster near the star without winding up
float cloud_at(float r, float a) {
	float Tc = 10.0, ph = gas_ph, wr = gas_spin * pow(gas_r / max(r, 6.0), 1.2);
	float p2 = fract(ph + 0.5), wt1 = 1.0 - abs(2.0 * ph - 1.0), wt2 = abs(2.0 * ph - 1.0);
	float cl = wt1 * cloud_sample(r, a, gas_rot + (wr - gas_spin) * ph * Tc)
		+ wt2 * cloud_sample(r, a + 3.7, gas_rot + (wr - gas_spin) * p2 * Tc);
	return 1.0 - gas_turb + gas_turb * 1.9 * cl * cl;
}

void fragment() {
	vec2 pix = floor(UV * box_half * 2.0);
	float x = pix.x, y = pix.y;
	// this game pixel in the pulsar's own units (game pixels at zoom 1)
	float px = (x - box_half.x) / zoom, py = (y - box_half.y) / zoom;
	vec3 L = SPACE;
	vec3 pl = plane_at(px, py);
	float gk = sm(30.0, 90.0, length(vec2(x, y) - g_ship));

	// THE CLOUD: a soft doughnut of glowing gas, summed through its height
	float span = gas_w * gas_tall * 1.6;
	if (pl.x <= gas_r + gas_w * 3.2 + span * 2.0) {
		float dens = 0.0;
		for (int k = 0; k < gas_vol; k++) {
			float h = gas_vol == 1 ? 0.0 : -span + 2.0 * span * float(k) / float(gas_vol - 1);
			float r = gas_vol == 1 ? pl.x : plane_at(px - h * s_axis.x, py - h * s_axis.y).x;
			dens += dens_at(r, h) * (gas_vol == 1 ? 1.0 : 2.4 / float(gas_vol));
		}
		if (dens >= 0.01) {
			float sum = dens * cloud_at(pl.x, pl.y) * gas_i * (1.0 + 0.35 * pl.z) * (beat_glow ? 1.0 + 0.65 * exp(-beat_age / 0.22) : 1.0);
			// the magnetar's flare blazes through the cloud
			if (mag_k > 0.0 && mag_age >= 0.0) sum *= 1.0 + 1.6 * mag_k * exp(-mag_age / 0.2);
			if (sum >= 0.01) L += (sum > 0.5 ? ICE : (sum > 0.22 ? CYAN : (sum > 0.1 ? BLUE : VIOLET))) * sum;
		}
	}

	// WISPS: thin bright arcs rippling out from the pulsar in the cloud's own
	// plane, one after another, brighter on the side leaning toward you
	if (wisp_k > 0.0) {
		for (int i = 0; i < 4; i++) {
			float ai = wisp_age - 2.5 * float(i);
			if (ai <= 0.0) continue;
			float Ri = 0.4 * gas_r + 11.0 * ai;
			float dw = pl.x - Ri;
			// (gone once it has faded: zoomed in, a ring left to spread forever
			// nudged the dither of the whole picture)
			float fade = exp(-Ri / (1.2 * gas_r)) * env(ai, 1.0, 2.0, 4.0);
			if (abs(dw) > 8.0 || fade < 0.05) continue;
			L += gk * ICE * 1.2 * wisp_k * exp(-pow(dw / 2.2, 2.0)) * fade
				* (0.6 + 0.4 * noise(cos(pl.y) * 6.0 + float(i) * 7.0, sin(pl.y) * 6.0)) * (1.0 + 0.5 * pl.z);
		}
	}

	// THE FIREHOSE: a thin jet along the spin axis to twice its length, a kink
	// running out along it so it whips, a bright knot riding the bend
	if (hose_k > 0.0) {
		float len = length(s_axis.xy), ux = s_axis.x / len, uy = s_axis.y / len;
		float a0 = px * ux + py * uy, p0 = px * uy - py * ux;
		float he = env(hose_age, 2.0, 7.0, 3.0) * hose_k;
		for (int i = 0; i < 2; i++) {
			float sg = i == 0 ? 1.0 : -1.0, along = sg * a0;
			if (along < 3.0) continue;
			float Lj = 75.0 * len * (1.0 + sm(0.0, 3.0, hose_age));
			// (a whip slow enough, and a jet thick enough, that a block it crosses
			// stays lit for more than a few frames)
			float y = 0.12 * along * sin(0.08 * along - 1.4 * hose_age);
			float d = abs(sg * p0 - y);
			if (d > 10.0) continue;
			float jet = exp(-pow(d / 2.0, 2.0)) * sm(3.0, 7.0, along) * exp(-along / Lj) * (1.0 - 0.5 * sm(50.0, 70.0, along));
			float knot = exp(-(pow(along - 18.0 * hose_age, 2.0) + d * d) / 7.0) * 1.6;
			L += (mix(VIOLET, ICE, 0.4) * jet + ICE * knot) * he * (sg * s_axis.z > 0.0 ? 1.0 : 0.6) * gk;
		}
	}

	// JETS along the spin axis, wiggling, bright knots running outward
	if (jets && jets_fade > 0.0) {
		float len = length(s_axis.xy), ux = s_axis.x / len, uy = s_axis.y / len;
		float reach = 75.0 * len, a0 = px * ux + py * uy, p0 = px * uy - py * ux;
		for (int i = 0; i < 2; i++) {
			float sg = i == 0 ? 1.0 : -1.0, along = sg * a0;
			if (along < 3.0 || along > reach) continue;
			float wig = 0.8 * sin(along * 0.16 - jet_ph1 * sg + sg);
			float d = abs(sg * p0 - wig);
			if (d > 3.0) continue;
			float knots = 0.55 + 0.45 * sin(along * 0.32 - jet_ph2);
			L += (d < 0.5 ? ICE : CYAN) * 1.4 * exp(-(d / 0.8) * (d / 0.8)) * knots * pow(1.0 - along / reach, 0.9) * (sg * s_axis.z > 0.0 ? 1.0 : 0.6) * jets_fade;
		}
	}

	// THE BEAMS out of the magnetic poles: a white core, a cyan body, a soft blue
	// halo, streaks running outward, foreshortened as they turn toward you
	for (int i = 0; i < 2; i++) {
		float sg = i == 0 ? 1.0 : -1.0;
		float dx = sg * m_axis.x, dy = sg * m_axis.y, len = sqrt(dx * dx + dy * dy);
		if (len < 0.05) continue;
		float ux = dx / len, uy = dy / len, reach = beam_len * len;
		float along = px * ux + py * uy;
		if (along < 0.0 || along > reach) continue;
		float perp = px * uy - py * ux, w = beam_w + along * beam_spread, ap = abs(perp);
		// the halo fades to nothing before it is cut, so the cone has no hard side
		if (ap > w * 6.0) continue;
		float fall = pow(1.0 - along / reach, 0.75);
		float streak = 0.72 + 0.4 * noise(along * 0.09 - time * 2.2, perp * 0.7 + sg * 9.0);
		float k = beam_i * fall * streak;
		float wc = beam_w * 0.4 + along * beam_spread * 0.08;
		L += WHITE * k * 1.5 * exp(-(ap / wc) * (ap / wc));
		L += CYAN * k * 0.75 * exp(-(ap / w) * (ap / w));
		float wh = w * 2.6;
		L += BLUE * k * 0.3 * exp(-(ap / wh) * (ap / wh));
	}

	// A STARQUAKE: a ring of light leaving across the equator plane once a loop,
	// widening and fading into nothing before it is gone
	if (quake && loop_at < 0.9 * 2.5) {
		float a = loop_at, d = pl.x, rr = a * 70.0;
		if (abs(d - rr) < 4.0 * 2.4 * (1.0 + a) + 2.0) {
			float w = 2.4 * (1.0 + a * 1.2), f = min(1.0, a / (0.9 * 2.5)), gone = 1.0 - f * f * (3.0 - 2.0 * f);
			float k = exp(-a / 0.9) * gone * exp(-((d - rr) / w) * ((d - rr) / w));
			if (k >= 0.01) L += WHITE * 2.2 * k;
		}
	}

	// THE SPRINKLER: particles thrown out along each beam as it turns. They come
	// sorted by row, so a pixel finds the few near its own row by halving the list
	// rather than reading all three hundred (which was most of this shader's cost).
	// Each is one pixel at zoom 1 and a round dot zoom pixels across above it,
	// all of it as bright as the one pixel (a dimmer rim leaves faint ones a
	// single pixel at every zoom); its place comes in game pixels.
	if (n_spray > 0) {
		float sr = floor(0.5 * zoom), r2 = 0.25 * zoom * zoom;
		float y0 = y - sr, y1 = y + sr;
		int lo = 0, hi = n_spray;
		for (int k = 0; k < 9; k++) {
			if (lo >= hi) break;
			int mid = (lo + hi) / 2;
			if (spray[mid].y < y0) lo = mid + 1; else hi = mid;
		}
		for (int i = lo; i < n_spray; i++) {
			vec4 s = spray[i];
			if (s.y > y1) break;
			float ddx = s.x - x, ddy = s.y - y, dd = ddx * ddx + ddy * ddy;
			if (dd <= r2) L += (s.w > 0.5 ? WHITE : ICE) * s.z;
		}
	}

	// THE STAR: a white-hot point in a soft glow that flares on each flash
	{
		float I = 1.0 + flash * 3.0 + glitch_k * 5.0 + (mag_k > 0.0 && mag_age >= 0.0 ? 4.0 * mag_k * exp(-mag_age / 0.12) : 0.0);
		float R = 30.0, r0 = 1.9, base = 1.0 / (1.0 + (R / r0) * (R / r0));
		float d = sqrt(px * px + py * py);
		if (d <= R) {
			float v = I * (1.0 / (1.0 + (d / r0) * (d / r0)) - base);
			if (v >= 0.004) L += (d < 2.2 ? WHITE : (d < 5.0 ? ICE : CYAN)) * v;
		}
		// THE HALO that carries its size (Jon: "the planet looks bigger than the
		// pulsar itself"): the neutron star stays a brilliant point, its light a
		// wide glow round it, brighter as it flashes
		float h = 0.42 * (1.0 + flash * 1.5) * exp(-d / 13.0) * (1.0 - smoothstep(40.0, 64.0, d));
		if (h >= 0.01) L += (d < 9.0 ? ICE : CYAN) * h;
	}

	// light to pixels, as the page: a soft shoulder, a little ordered dither, the
	// nearest of its colours (read at five bits a channel, as its lookup table was)
	COLOR = vec4(0.0);
	if (L.r + L.g + L.b >= 0.09) {
		int bx = (int(x) / max(cell, 1)) & 3, by = (int(y) / max(cell, 1)) & 3;
		int bay = (by == 0 ? (bx == 0 ? 0 : bx == 1 ? 8 : bx == 2 ? 2 : 10)
			: by == 1 ? (bx == 0 ? 12 : bx == 1 ? 4 : bx == 2 ? 14 : 6)
			: by == 2 ? (bx == 0 ? 3 : bx == 1 ? 11 : bx == 2 ? 1 : 9)
			: (bx == 0 ? 15 : bx == 1 ? 7 : bx == 2 ? 13 : 5));
		float dth = (float(bay) / 16.0 - 0.47) * 0.08;
		vec3 c = vec3(1.0) - exp(-L * 1.35) + dth;
		vec3 q = vec3(c.r <= 0.0 ? 0.0 : (c.r >= 1.0 ? 31.0 : floor(c.r * 31.0 + 0.5)),
			c.g <= 0.0 ? 0.0 : (c.g >= 1.0 ? 31.0 : floor(c.g * 31.0 + 0.5)),
			c.b <= 0.0 ? 0.0 : (c.b >= 1.0 ? 31.0 : floor(c.b * 31.0 + 0.5))) / 31.0;
		int best_k = 0;
		float best = 1e9;
		for (int j = 0; j < 30; j++) {
			vec3 e = PAL[j] / 255.0 - q;
			float dd = 2.0 * e.r * e.r + 4.0 * e.g * e.g + 3.0 * e.b * e.b;
			if (dd < best) { best = dd; best_k = j; }
		}
		// laid on the map as `layOn` laid it: the empty colour not at all, the
		// faintest faded in, everything added to what is behind
		if (best_k != 0) {
			vec3 p8 = PAL[best_k];
			float sum = p8.r + p8.g + p8.b;
			if (sum >= 36.0) {
				float k = sum < 110.0 ? (sum - 36.0) / 74.0 : 1.0;
				COLOR = vec4(floor(p8 * k) / 255.0, 0.0);
			}
		}
	}
}
