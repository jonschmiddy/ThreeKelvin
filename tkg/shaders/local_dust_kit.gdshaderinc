// LOCAL'S DUST, A MOTE'S PIXELS (`local_dust.gdshader`): what one pixel of a
// mote adds, from its whole offset `d` from the mote's middle. Returns (light,
// how much of it is the core's colour). Light in 0..~0.4, added. Every level
// is a step (smooth fills too, finely): a level that crept by a hair between two
// frames must not tip a pixel one way and back.

// the brightest a mote's core adds (a channel, before its colour)
const float DUST_PEAK = 0.36;

float dust_bayer4(ivec2 b) {
	const float B[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	ivec2 q = b & ivec2(3);
	return (B[q.y * 4 + q.x] + 0.5) / 16.0;
}

float dust_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// a light level in steps: dithered between them (an ordered pattern anchored to
// the mote), or, PAINTED, flat steps a pixel artist would pick
float dust_steps(float v, float th, int style) {
	if (v <= 0.0) {
		return 0.0;
	}
	if (style == 1) {
		return floor(v * 3.0 + 0.35) / 3.0;
	}
	if (style == 3) {
		return floor(v * 3.0 + th) / 3.0;
	}
	return floor(v * 4.0 + th) / 4.0;
}

vec2 dust_pixel(int kind, vec2 d, float R, float seed, vec2 to_star, float inten, float aux, float vis, float th, int style) {
	float dist = length(d);
	float side = dist > 0.01 ? dot(d / dist, to_star) : 0.0;
	if (kind == 2) {
		// A SPECK: one pixel, and a faint cross round it when it is bright
		float v = 0.0;
		if (dist < 0.5) {
			v = inten;
		} else if (dist < 1.01 && inten > 0.6) {
			v = (inten - 0.6) * 1.1;
		}
		float q = dust_steps(v * vis, th, style);
		return vec2(q * DUST_PEAK, dist < 0.5 ? inten : 0.0);
	}
	if (kind == 0) {
		// A MOTE: its core and its fall of light, lit on the star's side
		float rc = max(0.5, R * 0.3);
		float prof = dist <= rc ? 1.0 : pow(clamp(1.0 - (dist - rc) / max(R - rc, 0.75), 0.0, 1.0), 1.5) * 0.8;
		if (dist > rc) {
			prof *= 1.0 + 0.4 * side;
		}
		float v = prof * inten;
		// ITS GLINT (`aux`, 0..1): the core flares, a short cross grows out of it
		float gl = aux;
		if (gl > 0.0) {
			if (dist <= rc) {
				v *= 1.0 + 0.7 * gl;
			}
			float along = abs(d.x) + abs(d.y);
			if ((abs(d.x) < 0.5 || abs(d.y) < 0.5) && along >= 1.0) {
				float len = R + 1.0 + 5.0 * gl;
				if (along < len) {
					v = max(v, gl * inten * 0.95 * (1.0 - along / len));
				}
			}
		}
		float q = dust_steps(v * vis, th, style);
		float soft = 0.0;
		if (style == 2) {
			// RADIANT: the light it gathers spills round it, smooth (light
			// through the gas, not paint)
			soft = floor(0.09 * inten * vis * exp(-dist * dist / max(R * R * 4.0, 1.0)) * 48.0 + 0.5) / 48.0;
		}
		if (style == 1 && dist < 0.5) {
			// PAINTED: the middle pixel a held highlight, a flat step up
			q = max(q, min(1.0, inten * vis * 1.25));
		}
		return vec2(q * DUST_PEAK + soft * DUST_PEAK, smoothstep(0.55, 1.0, v));
	}
	if (kind == 1) {
		// A BOKEH: a near mote far out of focus -- a faint smooth disc, its rim lit
		// on the star's side, its edge dithered out
		float v = 0.0;
		// (a disc of light more than a ring: the fill near the rim's own level, the
		// rim lifted mostly on the star's side -- a bright ring all round read as a
		// bubble)
		float rim_w = 1.25;
		float lit = max(side, 0.0);
		if (dist <= R - rim_w) {
			float fill = 0.14 + 0.08 * lit * (dist / max(R, 1.0));
			v = floor(fill * inten * vis * (style == 1 ? 12.0 : 32.0) + 0.5) / (style == 1 ? 12.0 : 32.0);
			return vec2(v * DUST_PEAK, 0.0);
		}
		float rim = 0.12 + 0.4 * lit * lit;
		if (dist <= R) {
			v = rim;
		} else if (dist <= R + 1.6) {
			v = rim * (1.0 - (dist - R) / 1.6) * 0.8;
		}
		float q = dust_steps(v * inten * vis, th, style);
		return vec2(q * DUST_PEAK, 0.25 * lit);
	}
	if (kind == 3) {
		// A FILAMENT: grains along a slow curve, a faint body between them
		float L = max(R, 1.0);
		float H = max(aux, 1.0);
		float u = d.x / L;
		if (abs(u) > 1.0) {
			return vec2(0.0);
		}
		float taper = 1.0 - u * u;
		float yc = H * 0.62 * sin(u * 2.3 + seed * 6.283) * (0.65 + 0.35 * cos(u * 3.7 + seed * 3.1));
		float w = 0.55 + 1.7 * taper;
		float dy = d.y - yc;
		float lump = 0.55 + 0.45 * sin(d.x * 0.19 + seed * 11.0) * sin(d.x * 0.071 + seed * 5.0);
		float body = exp(-(dy * dy) / (w * w)) * taper * lump;
		// lit along the edge that faces the star
		float lit = 1.0 + 0.45 * clamp(-dy * to_star.y / w, -1.0, 1.0);
		float v = body * 0.3 * lit;
		float hs = dust_hash(d + vec2(seed * 173.0, seed * 59.0));
		if (hs < 0.26 * body) {
			v = max(v, (0.5 + 0.4 * dust_hash(d * 1.7 + seed * 31.0)) * lit);
		}
		float q = dust_steps(v * inten * vis, th, style);
		return vec2(q * DUST_PEAK, 0.0);
	}
	// A CLUMP: a knot of grains round a faint glow
	float r = dist / max(R, 1.0);
	if (r > 1.25) {
		return vec2(0.0);
	}
	float dens = exp(-r * r * 2.6);
	float lit = 1.0 + 0.4 * side;
	float glowv = floor(0.07 * dens * inten * vis * (style == 1 ? 12.0 : 48.0) + 0.5) / (style == 1 ? 12.0 : 48.0);
	float hs = dust_hash(d + vec2(seed * 211.0, seed * 47.0));
	float v = 0.0;
	if (hs < 0.32 * dens) {
		v = (0.45 + 0.45 * dust_hash(d * 2.3 + seed * 17.0)) * lit;
	}
	float q = dust_steps(v * inten * vis, th, style);
	return vec2((q + glowv) * DUST_PEAK, 0.0);
}
