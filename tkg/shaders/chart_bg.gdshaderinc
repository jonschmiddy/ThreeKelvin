// THE SKY BEHIND THE GALAXY, every chart style's (`ChartSky`, `ChartLegacy`):
// the background with depth the showcase's protos had and Jon missed in the
// game ("no distant stars or galaxies parallax in the background"). It is at
// infinity, so it never zooms with the galaxy; it slides on a pan, each layer by
// its own depth (`u_skyPan`, the chart's `sky_pan`: screen px of panning, never
// of zooming), nearer layers more:
//   * far nebulae (0.02 of the pan): broad faint clouds of colour, mostly unseen
//     but for a tint in the dark (not in PAINTED, whose prototype had none);
//   * far galaxies (0.05): small spirals seen at all angles, a warm core and two
//     blue arms, and small warm ellipticals, a few blocks across;
//   * three depths of stars (0.04, 0.10 and 0.20), dim and many to fewer and
//     brighter, the nearest now and then a little cross.
// Each style shades these its own way (linear light, painted materials, the
// legacy chart's 0-255 points); this file only says where they are.
// Needs `chart_kit.gdshaderinc`.

uniform vec2 u_skyPan = vec2(0.0);
uniform float u_skySeed = 0.0;
// a harness's `bgoff`: the far sky's light switched off, to measure what it does
// to the galaxy in front (`ChartSky._feed_sky`)
uniform float u_bgOn = 1.0;

const float BG_F_NEB = 0.02;
const float BG_F_GAL = 0.05;

// A layer's feature at q stands on screen at q + u_skyPan * f: it slides WITH
// the galaxy as you pan, a fraction of its travel, nearer layers more. (Added
// here instead, every style's far sky slid against the galaxy -- Jon: RADIANT's
// "parallax is opposite", where the sky shows most.)
vec2 bgAt(vec2 sp, float f) {
	return sp - u_skyPan * f + vec2(u_skySeed * 37.0, u_skySeed * 11.0);
}

// a star of layer 0 (deep), 1 (mid) or 2 (near) at screen offset sp (block
// centre, px from the frame centre): (found, brightness 0..1, temperature 0..1,
// a spare random)
vec4 bgStar(vec2 sp, int layer) {
	float f = layer == 0 ? 0.04 : (layer == 1 ? 0.10 : 0.20);
	float cell = layer == 0 ? 11.0 : (layer == 1 ? 24.0 : 52.0);
	float prob = layer == 0 ? 0.16 : (layer == 1 ? 0.22 : 0.3);
	return kitStar(bgAt(sp, f), 2.0, cell, prob, 41 + layer * 23);
}

// the nearest far galaxy: (core 0..1, disc and arms 0..1, blue share 0..1,
// brightness 0..1); zero where there is none
vec4 bgGalaxy(vec2 sp) {
	vec2 q = bgAt(sp, BG_F_GAL);
	const float CELL = 150.0;
	ivec2 c0 = ivec2(floor(q / CELL));
	vec4 best = vec4(0.0);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			ivec2 c = c0 + ivec2(i, j);
			vec3 h = kitHash3(c + ivec2(613, 2087));
			if (h.z > 0.5) {
				continue;
			}
			vec3 g = kitHash3(c + ivec2(77, 919));
			vec2 ctr = (vec2(c) + 0.15 + 0.7 * h.xy) * CELL;
			float size = 5.0 + 13.0 * g.x * g.x;               // px, the disc's scale
			vec2 d = q - ctr;
			if (dot(d, d) > 16.0 * size * size) {
				continue;
			}
			float an = g.y * KIT_TAU;
			float tilt = 0.25 + 0.75 * fract(g.z * 7.3);          // seen edge-on to face-on
			vec2 e = mat2(vec2(cos(an), -sin(an)), vec2(sin(an), cos(an))) * d;
			e.y /= tilt;
			float r = length(e) / size;
			bool spiral = fract(g.z * 13.1) < 0.6;
			float core = exp(-r * r * (spiral ? 9.0 : 2.2));
			float disc = 0.0;
			if (spiral) {
				float th = atan(e.y, e.x);
				float arms = 0.5 + 0.5 * cos(2.0 * (th - 2.4 * log(max(r, 0.05))) + g.x * 9.0);
				disc = exp(-r * 1.6) * (0.35 + 0.9 * arms * arms) * (1.0 - smoothstep(1.4, 2.4, r));
			}
			float bright = 0.45 + 0.55 * fract(h.z * 29.0);
			vec4 o = vec4(core, disc, spiral ? 0.75 : 0.0, bright);
			if (o.x + o.y > best.x + best.y) {
				best = o;
			}
		}
	}
	return best;
}

// the far nebulae: (amount 0..1, hue 0 magenta .. 1 teal-blue)
vec2 bgNebula(vec2 sp) {
	vec2 q = bgAt(sp, BG_F_NEB) / 420.0;
	float n = 0.5 + 0.5 * kitFbm2(q + vec2(3.1, 7.7), 4);
	float m = smoothstep(0.62, 0.92, n);
	float hue = 0.5 + 0.5 * kitSnoise2(q * 0.7 + vec2(11.0, 2.0));
	return vec2(m, hue);
}

// THE SKY BEHIND IS BEHIND: how much of it shows through `front`, the light of
// the galaxy in front of it (linear, before the composite's exposure `expo`).
// The galaxy's gas glows without stopping much light, so its transmittance
// alone let the far nebulae add their light to the disc's faint outskirts and
// halo; toned, lifted and cut to the palette, that moved the front gas's colour
// steps as the far layer slid under it (Jon, panning RADIANT: the far
// galaxies' "cloud layers" interacting with the front galaxy's). So the far sky
// shows only where the galaxy is fainter than the far sky itself, as PAINTED
// draws it, and where the galaxy is brighter the picture is the galaxy's alone.
float bgSeen(vec3 front, float expo) {
	return 1.0 - smoothstep(0.0006, 0.0025, dot(front, vec3(0.2126, 0.7152, 0.0722)) * expo);
}

// all of it as linear light (the simplified and radiant charts' sky), for a
// block at screen offset sp
vec3 bgLight(vec2 sp, float starsSeen) {
	vec3 c = vec3(0.0);
	if (u_bgOn < 0.5) {
		return c;
	}
	vec2 nb = bgNebula(sp);
	c += mix(vec3(0.004, 0.0012, 0.004), vec3(0.0008, 0.0026, 0.0045), nb.y) * nb.x;
	vec4 g = bgGalaxy(sp);
	if (g.x + g.y > 0.003) {
		vec3 warm = vec3(1.0, 0.78, 0.52), blue = vec3(0.55, 0.68, 1.0);
		c += (warm * g.x * 0.16 + mix(warm, blue, g.z) * g.y * 0.08) * g.w;
	}
	for (int l = 0; l < 3; l++) {
		vec4 s = bgStar(sp, l);
		if (s.x > 0.5 && starsSeen > 0.5) {
			float k = l == 0 ? 0.012 + 0.03 * pow(s.y, 4.0) : (l == 1 ? 0.02 + 0.12 * pow(s.y, 4.0) : 0.03 + 0.4 * pow(s.y, 5.0));
			c += kitStarTint(s.z) * k;
		}
	}
	return c;
}
