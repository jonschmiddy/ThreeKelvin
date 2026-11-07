// TORN AWAY, direction B: the stream (`ChartTorn`). A dwarf being eaten by a giant
// neighbour: its stars unwound into a ribbon that loops across the whole chart and
// off to the giant, seen far off and edge-on; the next ring to go frays red at the
// tidal radius, its stars pulled off at the two tips into the two tails; past it,
// the old shear. Off (u_torn.x 0) for every kind but the dwarfs: nothing here runs.
uniform vec4 u_torn = vec4(0.0);    // on, tidal radius (gu, the rings'), progress 0..1, squash
uniform vec4 u_tornG = vec4(0.0);   // the giant: view px x, y (zoom 1, about the core), tilt, half length (gu)
uniform vec4 u_tornA = vec4(0.0);   // the line to the giant (plane, unrotated), the ring after's radius, rings lost
uniform vec4 u_tornP[64];           // the ribbon: view px x, y, signed length along (gu), age 0..1
const int TORN_NL = 24;
const int TORN_N = 64;

bool tornOn() { return u_torn.x > 0.5; }

// the ribbon's width (screen gu) at age f: a thread at the dwarf, broad far out
float tornW(float f, bool lead) {
	float w = (0.006 + 0.03 * pow(f, 0.8)) * (0.8 + 0.5 * u_torn.z);
	return lead ? w * (1.0 - 0.55 * f) : w;
}

// the nearest of one arm's segments, by distance over width: signed distance
// across (gu), length along (gu, unsigned), age
void tornNear(vec2 v, int arm, float ws, out float sd, out float al, out float f, out float W) {
	int i0 = arm == 0 ? 0 : TORN_NL;
	int i1 = arm == 0 ? TORN_NL - 1 : TORN_N - 1;
	float best = 1e9;
	sd = 1e3;
	al = 0.0;
	f = 1.0;
	W = 1.0;
	for (int i = i0; i < i1; i++) {
		vec4 A = u_tornP[i];
		vec4 B = u_tornP[i + 1];
		vec2 ab = B.xy - A.xy;
		float L2 = max(dot(ab, ab), 1e-6);
		float t = clamp(dot(v - A.xy, ab) / L2, 0.0, 1.0);
		vec2 d = v - (A.xy + ab * t);
		float dist = length(d) / u_k;
		float ff = mix(A.w, B.w, t);
		float w = tornW(ff, arm == 0) * ws;
		float sc = dist / w;
		if (sc < best) {
			best = sc;
			float side = sign(ab.x * d.y - ab.y * d.x);
			sd = dist * side;
			al = abs(mix(A.z, B.z, t));
			f = ff;
			W = w;
		}
	}
}

// the flow's held clock: the ribbon's stars step one block along it a pose
float tornFlowT(float speed) {
	float bw = blockView() / u_k;
	float st = bw / speed;
	return floor(u_time / st) * st;
}

// one arm's light, and whether a star of it lies in this block (warm 1, cool 2)
float tornArm(Px P, vec2 v, int arm, out int star) {
	star = 0;
	float sd, al, f, W;
	// (its width held near what it is on the screen: the camera's perspective would
	// make the near loop a flood across the bottom of the chart)
	float ws = 1.0 / pow(max(solidMag(v), 0.3), 0.75);
	tornNear(v, arm, ws, sd, al, f, W);
	// (its edge ragged, held where it lies: the stars flow through it)
	float x = (sd + 0.35 * W * kitSnoise2(vec2(al * 5.0, float(arm) * 5.1 + 2.0))) / W;
	if (abs(x) > 3.2) {
		return 0.0;
	}
	bool lead = arm == 0;
	float prog = u_torn.z;
	float B = (lead ? mix(1.0, 0.75, f) : mix(1.0, 0.16, pow(f, 0.6))) * (0.5 + 0.8 * prog);
	// the stars stream away from the dwarf down both tails
	const float SPEED = 0.035;
	float ft = tornFlowT(SPEED);
	float a1 = al - SPEED * ft;
	float bw = blockView() / u_k;
	// braided strands along it, wandering across, and clumps riding the flow
	float wob = 1.6 * kitSnoise2(vec2(al * 1.7, float(arm) * 7.3));
	float strand = 0.5 + 0.5 * cos(x * 4.2 + wob);
	float clump = 0.5 + 0.5 * fbmL(vec2(a1 * 9.0, x * 0.7 + float(arm) * 3.1), bw * 9.0, 3);
	float core = exp(-x * x);
	// knots and gaps riding the flow (a stream of stars, never a tube), and a grain
	// of two blocks over it
	float knots = smoothstep(0.22, 0.68, 0.5 + 0.5 * fbmL(vec2(a1 * 4.5, float(arm) * 9.7), bw * 4.5, 2));
	vec2 gq = vec2(a1, sd) / (2.0 * bw);
	float grain = 0.6 + 0.8 * kitHash3(ivec2(floor(gq)) + ivec2(arm * 131, 17)).x;
	float lA = B * (core * (0.3 + 0.7 * strand) * (0.4 + 0.9 * clump) * grain + 0.12 * exp(-abs(x) * 1.3) * (0.6 + 0.6 * clump));
	lA *= 0.3 + 0.95 * knots;
	// (where it leaves the dwarf's tip, a hot thread, rising out of the fraying ring:
	// no blunt end)
	lA *= smoothstep(0.0, 0.045, f) * (1.0 + 1.3 * exp(-sq((f - 0.06) / 0.05)));
	// its stars: one a cell of three blocks at most, riding the flow, thicker where it is bright
	float cs = 3.0 * bw;
	vec2 q = vec2(a1, sd) / cs;
	ivec2 cq = ivec2(floor(q));
	vec3 h = kitHash3(cq + ivec2(arm * 7919, 311));
	vec2 sp = (vec2(cq) + 0.15 + 0.7 * h.xy) * cs;
	if (abs(a1 - sp.x) < 0.5 * bw && abs(sd - sp.y) < 0.5 * bw && h.z < smoothstep(0.015, 0.3, lA) * (0.4 + 0.6 * core)) {
		star = fract(h.z * 17.0) < 0.3 ? 1 : 2;
	}
	return lA;
}

// the giant: in its own frame on the screen (gu along, across)
vec2 tornGiantF(vec2 vS) {
	// (drawn on the screen about where the camera shows its place, at the camera's
	// scale there, never stretched by the perspective: far off, it is smaller)
	vec2 d = (vS - solidV(u_tornG.xy)) / u_k;
	float c = cos(u_tornG.z), s = sin(u_tornG.z);
	return vec2(c * d.x + s * d.y, -s * d.x + c * d.y);
}

// its light: warm (the bulge and the inner disc), cool (the outer disc), and the
// spill on the sky. A giant spiral far bigger than the dwarf, seen steeply tilted:
// a broad disc with its arms and its dust lane, a gold bulge, its ends warped by
// the meal. Faint for its size (it is far off): the core goal stays the hottest
// thing on the chart.
vec3 tornGiant(vec2 vS, float bw) {
	vec2 ab = tornGiantF(vS);
	float L = u_tornG.w;
	float a = ab.x;
	float aa = abs(a);
	// the disc warped by the meal (an integral sign), flaring toward its ends
	float b = ab.y + 0.06 * L * sign(a) * pow(smoothstep(0.45 * L, 1.1 * L, aa), 2.0);
	// (in its own plane: tilted to a quarter of its length across)
	const float Q = 0.27;
	vec2 dp = vec2(a, b / Q);
	float r = length(dp) / L;
	float th = atan(dp.y, dp.x);
	// two arms wound out from the bulge, lumpy with star clouds
	float arm = 0.5 + 0.5 * cos(2.0 * th - 6.0 * log(max(r, 0.04)) + 1.3);
	arm = pow(arm, 3.0);
	float lumps = 0.65 + 0.7 * fbmL(dp * 9.0 / L + 3.7, bw * 9.0 / L, 3);
	float disc = exp(-r / 0.3) * smoothstep(1.08, 0.75, r) * (0.12 + 1.7 * arm) * lumps;
	// the dust lane, on the near side of the bulge, along the disc
	float lane = 1.0 - 0.85 * exp(-sq((b + 0.05 * L * Q) / (0.018 * L))) * smoothstep(0.75, 0.05, r);
	float bul = exp(-(sq(a / (0.055 * L)) + sq(ab.y / (0.04 * L))));
	float pt = exp(-(sq(a / 0.012) + sq(ab.y / 0.009)));
	float warm = (0.5 * bul + 0.9 * pt) * mix(1.0, lane, 0.85);
	float cool = 0.3 * disc * lane;
	float spill = exp(-length(vec2(a * 0.5, ab.y)) / (0.7 * L));
	return vec3(warm, cool, spill);
}

// where the dwarf's rings lie, from the plane: (radius as the rings measure it,
// stretched toward the tips; the angle from the line to the giant)
vec2 tornRing(vec2 g) {
	vec2 gal = vec2(g.x, g.y * u_torn.w);
	vec2 ax = u_tornA.xy;
	float al = dot(gal, ax);
	float pe = dot(gal, vec2(-ax.y, ax.x));
	// (the tidal surface is a lemon pointed at the giant: the ring frays first at its
	// tips; mild, so the band stays on the doomed systems' ring. `ChartTorn.lemon`,
	// the marks' dashed ring the same)
	float re = length(vec2(al / (1.06 + 0.1 * u_torn.z), pe));
	return vec2(re, atan(pe, al));
}

// the dwarf's own light cut at the tidal radius (what has gone is gone)
float tornCut(vec2 g) {
	float re = tornRing(g).x;
	return smoothstep(u_torn.y + 0.05, u_torn.y - 0.06, re);
}

// the light the sky takes from all this (its stepped navy and violet tiers):
// the dwarf's remaining body of old stars out to the tidal radius, and the giant's spill
// the screen's own view px of a block (zoom 1, about the core's centre pixel)
vec2 tornScreen(Px P) {
	return (u_vp_origin + (vec2(P.blk) + 0.5) * 2.0 - u_cpix) / u_zoom;
}

float tornGlow(Px P, vec2 g) {
	vec2 rr = tornRing(g);
	float inside = smoothstep(u_torn.y + 0.012, u_torn.y - 0.02, rr.x);
	float body = 0.0034 * inside * (0.75 + 0.5 * fbmL(g * 6.0 + 2.1, blockView() / u_k * 6.0, 2));
	return body + 0.012 * tornGiant(tornScreen(P), blockView() / u_k).z;
}

// the doomed ring: red, fraying, its stars flowing toward the tips and off them
float tornDoom(vec2 g, float bw, out float pull) {
	vec2 rr = tornRing(g);
	float rt = u_torn.y;
	float dr = rr.x - rt;
	// (the angle from the nearer tip: 0 at a tip, pi/2 broadside)
	float ca = abs(cos(rr.y));
	float fromTip = acos(ca);
	// the stars along it slide toward the nearer tip, in held poses
	const float SPEED = 0.05;
	float ft = tornFlowT(SPEED * max(rt, 0.15));
	float flow = fromTip * rt + SPEED * max(rt, 0.15) * ft * 1.0;
	float fray = 0.5 + 0.5 * fbmL(vec2(flow * 26.0, dr * 30.0), bw * 26.0, 3);
	float w = 0.018 + 0.03 * pow(ca, 3.0);
	float band = exp(-sq(dr / w)) * (0.35 + 0.9 * fray);
	// tongues pulled out past it, longest at the tips
	float tong = smoothstep(-0.01, 0.02, dr) * exp(-max(dr, 0.0) / (0.03 + 0.16 * pow(ca, 4.0)))
		* smoothstep(0.5, 0.85, 0.5 + 0.5 * fbmL(vec2(flow * 16.0, dr * 3.0 + 1.7), bw * 16.0, 2));
	pull = tong;
	return 0.16 * band + 0.07 * tong;
}

// the old shear past the tidal radius: what went before, swept into arcs that
// wind out into the tails
float tornShear(vec2 g, float bw) {
	vec2 rr = tornRing(g);
	float dr = rr.x - u_torn.y;
	if (dr < 0.0) {
		return 0.0;
	}
	float sp = rr.y * 1.0 - 9.0 * log(max(rr.x, 0.05));
	float arcs = smoothstep(0.55, 0.95, 0.5 + 0.5 * sin(sp * 2.0 + 2.5 * fbmL(g * 4.0, bw * 4.0, 2)));
	return 0.0075 * arcs * exp(-dr / 0.16) * (0.4 + 0.8 * u_torn.z) * (0.5 + 0.5 * pow(abs(cos(rr.y)), 2.0));
}

// all of it over what the chart has here: the giant behind (over the sky only),
// the shear and the ribbon over the sky, the doomed ring and the ribbon over the
// dwarf where they outshine it
Cand tornOver(Px P, vec2 v, vec2 g, Cand sc) {
	float bw = blockView() / u_k;
	bool skyHere = sc.m == M_SKY || sc.sid == SID_FAR;
	Cand res = sc;
	if (skyHere) {
		vec3 gi = tornGiant(tornScreen(P), bw);
		float Eg = gi.x + gi.y;
		if (Eg > 0.012) {
			float a = smoothstep(0.012, 0.03, Eg);
			if (pat(P, a)) {
				// (its bulge and inner disc the bulge's ramp, gold and cream; its outer
				// disc the halo's violet: never the ribbon's blue, never the doomed
				// ring's red)
				if (gi.x >= gi.y) {
					res = cand(M_BULGE, clamp(1.0 + log2(Eg) / 6.0, 0.0, 0.999), 0, 0.0);
				} else {
					res = cand(M_HALO, clamp(0.5 + 0.12 * log2(Eg / 0.012), 0.3, 0.92), 0, 0.0);
				}
			}
		}
		float Es = tornShear(g, bw);
		if (Es > 0.004 && res.m == M_SKY) {
			res = cand(M_HALO, clamp(0.35 + Es * 40.0, 0.0, 0.999), 0, 0.0);
		}
	}
	// the doomed ring
	float pull;
	float Ed = tornDoom(g, bw, pull);
	if (Ed > 0.02) {
		float lv = clamp(0.95 + log2(Ed) / 4.5, 0.0, 0.999);
		Cand dc = cand(M_HA, lv, 0, 0.0);
		if (pat(P, smoothstep(0.02, 0.05, Ed)) && (skyHere || dc.y > sc.y - 0.05)) {
			res = dc;
		}
	}
	// the ribbon: the two tails
	int st0, st1;
	float lR = tornArm(P, v, 0, st0) + tornArm(P, v, 1, st1);
	int st = max(st0, st1);
	if (lR > 0.008) {
		// (the ribbon's stars on the arms' blue-white: the marks' orange reads on it)
		float lv = clamp(1.05 + log2(lR) / 6.0, 0.0, 0.999);
		Cand rc = cand(M_ARM, lv, 0, 0.0);
		// the faint fringe goes to the halo's violet
		if (lv < 1.0 / 6.0) {
			rc = cand(M_HALO, 0.45 + 2.0 * lv, 0, 0.0);
		}
		float a = smoothstep(0.008, 0.03, lR);
		if (pat(P, a) && (res.m == M_SKY || res.sid == SID_FAR || rc.y > res.y)) {
			res = rc;
		}
	}
	if (st > 0) {
		Cand sc2 = cand(st == 1 ? M_STARW : M_STAR, st == 1 ? 0.6 : 0.5, 0, 0.0);
		if (sc2.y > res.y) {
			res = sc2;
		}
	}
	return res;
}
