// TORN AWAY, direction B: the stream (`ChartTorn`). A dwarf being eaten by a giant
// neighbour, seen far off and steeply tilted up the chart: ONE stream of the dwarf's
// stars runs out of it toward the giant and spirals into the giant's middle, wider
// and brighter as more of the dwarf goes into it. The dwarf itself loses its outside
// with each ring lost, redrawn at its real size, never shrunk (`tornShape`). No ring
// is marked. Off (u_torn.x 0) unless the run sets it: nothing
// here runs.
uniform vec4 u_torn = vec4(0.0);    // on, the drawn edge (gu, the ball's own frame, `ChartTorn.drawn_edge`), progress 0..1, squash
uniform vec4 u_tornG = vec4(0.0);   // the giant: view px x, y (zoom 1, about the core), tilt, half length (gu)
uniform vec4 u_tornA = vec4(0.0);   // the line to the giant (plane, unrotated), 1, rings lost
// 0, the cut's strength, where the dwarf's lit body ends along the stream (gu on the
// screen, `lit_along`), the dwarf's drawn reach against its whole (the stream's head)
uniform vec4 u_tornB = vec4(0.0);
uniform vec4 u_tornP[48];           // the stream: view px x, y, length along (gu), age 0..1
const int TORN_N = 48;
// where the stream rises out of the dwarf, as shares of its lit body's reach along it
// (u_tornB.z): first light, and full
const float TORN_IN0 = 0.5;
const float TORN_IN1 = 1.0;

bool tornOn() { return u_torn.x > 0.5; }

// the way the stream leaves the dwarf where it crosses the torn edge, in the ball's own
// frame on the screen (`ChartTorn.stream_dir`), and how far the edge is drawn out that
// way (a share of the edge, `ChartTorn.lobe`)
uniform vec4 u_tornC = vec4(1.0, 0.0, 0.0, 0.0);

// THE TORN EDGE (REDRAW A, STRIPPED): what is left of the dwarf, a multiplier of its
// light at a point of the ball's own frame (gS, round on the screen as its light is
// drawn; gq the same turned with the galaxy, blkS its block there). Nothing moves or
// is resized: the core, the body, its glow and grain are read where they always are,
// and only what lay past the edge is gone. The edge is torn: ragged on the galaxy's
// own noise (held on it, so it turns with it and never crawls), drawn out toward the
// stream (the tidal side), and the last band of it broken into clumps that feed the
// stream's start; inside, the light fades out over a short band, never a hard cut.
// 1 everywhere with no ring lost
float tornShape(vec2 gS, vec2 gq, float blkS) {
	float eT = u_torn.y;
	float r = length(gS);
	float c = r > 1e-5 ? dot(gS / r, u_tornC.xy) : 0.0;
	float pull = pow(max(c, 0.0), 3.0);
	float lobe = u_tornC.z * pull;
	// (ragged: the galaxy's own noise, at one size whatever the edge, so it holds still
	// as the edge eats in through it)
	float n = fbmL(gq * 11.0 + 4.3, blkS * 11.0, 4);
	float Ee = eT * (1.0 + lobe) + (0.015 + 0.25 * eT) * n;
	float wF = 0.02 + 0.2 * eT;
	float keep = smoothstep(Ee + 0.2 * wF, Ee - wF, r);
	// the band being lost: clumps past the edge, more of them and longer toward the
	// stream, thinning out across it
	float band = eT * (0.3 + 1.4 * lobe);
	float x = (r - Ee) / max(band, 1e-4);
	if (x > -0.2 && x < 1.0) {
		vec2 dq = kitRot(-u_phi) * u_tornC.xy;
		vec2 cq = vec2(dot(gq, dq), dot(gq, vec2(-dq.y, dq.x)));
		// (drawn out along the pull on the tidal side, round elsewhere)
		float el = 1.0 + 1.6 * pull;
		float cl = 0.5 + 0.5 * fbmL(vec2(cq.x * 34.0 / el, cq.y * 34.0) + 9.1, blkS * 34.0, 2);
		float th = mix(0.5, 0.85, clamp(x, 0.0, 1.0));
		keep = max(keep, smoothstep(th, th + 0.08, cl) * (1.0 - 0.6 * clamp(x, 0.0, 1.0)) * (0.6 + 0.4 * pull));
	}
	return mix(1.0, keep, u_tornB.y);
}

// the stream's width (screen gu) at age f: a pull off the dwarf as wide as the
// dwarf is drawn, narrowing to a river, then a thread as it winds into the giant;
// all of it wider as it is fed
float tornW(float f) {
	float w = 0.005 + 0.024 * u_tornB.w * exp(-f / 0.1) + 0.016 * sqrt(f) * (1.0 - f);
	return w * (0.7 + 0.6 * u_torn.z);
}

// the nearest of the stream's segments, by distance over width: signed distance
// across (gu), length along (gu), age, width
void tornNear(vec2 v, float ws, out float sd, out float al, out float f, out float W) {
	float best = 1e9;
	sd = 1e3;
	al = 0.0;
	f = 1.0;
	W = 1.0;
	for (int i = 0; i < TORN_N - 1; i++) {
		vec4 A = u_tornP[i];
		vec4 B = u_tornP[i + 1];
		vec2 ab = B.xy - A.xy;
		float L2 = max(dot(ab, ab), 1e-6);
		float t = clamp(dot(v - A.xy, ab) / L2, 0.0, 1.0);
		vec2 d = v - (A.xy + ab * t);
		float dist = length(d) / u_k;
		float ff = mix(A.w, B.w, t);
		float w = tornW(ff) * ws;
		float sc = dist / w;
		if (sc < best) {
			best = sc;
			float side = sign(ab.x * d.y - ab.y * d.x);
			sd = dist * side;
			al = mix(A.z, B.z, t);
			f = ff;
			W = w;
		}
	}
}

// the flow's held clock for one lane of the stream's stars: they step one block
// along it a pose, each lane at its own pace and on its own beat, so a frame moves
// a lane or two, never the whole stream at once (that read as a pulse)
float tornFlowT(float speed, float ph) {
	float bw = blockView() / u_k;
	float st = bw / speed;
	return (floor(u_time / st + ph) - ph) * st;
}

// the stream's light, and whether a star of it lies in this block (warm 1, cool 2)
float tornStream(Px P, vec2 v, out int star) {
	star = 0;
	float sd, al, f, W;
	// (its width held near what it is on the screen: the camera's perspective would
	// make its near end a flood across the bottom of the chart)
	float ws = 1.0 / pow(max(solidMag(v), 0.3), 0.75);
	tornNear(v, ws, sd, al, f, W);
	// (its edge ragged, held where it lies: the stars flow through it)
	float x = (sd + 0.35 * W * kitSnoise2(vec2(al * 5.0, 2.0))) / W;
	if (abs(x) > 3.2) {
		return 0.0;
	}
	float prog = u_torn.z;
	float B = mix(1.0, 0.7, f) * (0.3 + 0.9 * prog);
	float bw = blockView() / u_k;
	// (its light held where it lies: knots, clumps and grain are the stream's shape;
	// what flows are its stars, below)
	float a1 = al;
	// braided strands along it, wandering across, and clumps riding the flow
	float wob = 1.6 * kitSnoise2(vec2(al * 1.7, 0.0));
	float strand = 0.5 + 0.5 * cos(x * 4.2 + wob);
	float clump = 0.5 + 0.5 * fbmL(vec2(a1 * 9.0, x * 0.7), bw * 9.0, 3);
	float core = exp(-x * x);
	// knots and gaps riding the flow (a stream of stars, never a tube), and a grain
	// of two blocks over it
	float knots = smoothstep(0.22, 0.68, 0.5 + 0.5 * fbmL(vec2(a1 * 4.5, 0.0), bw * 4.5, 2));
	vec2 gq = vec2(a1, sd) / (2.0 * bw);
	float grain = 0.6 + 0.8 * kitHash3(ivec2(floor(gq)) + ivec2(0, 17)).x;
	float lA = B * (core * (0.3 + 0.7 * strand) * (0.4 + 0.9 * clump) * grain + 0.12 * exp(-abs(x) * 1.3) * (0.6 + 0.6 * clump));
	lA *= 0.3 + 0.95 * knots;
	// (out of the dwarf's own light: it rises faint inside the lit body's outer part,
	// over its outer stars and glow where it outshines them (`tornOver`), and is
	// brightest just past where that light ends (`ChartTorn.lit_along`, er), where the
	// stars are pulled off; never near its core, which stays the goal: clear of the
	// hole's ring, u_g2.w, however small the dwarf is drawn)
	float er = u_tornB.z;
	lA *= smoothstep(TORN_IN0 * er, TORN_IN1 * er, al) * (1.0 + 0.6 * exp(-sq((al - 1.15 * er) / (0.3 * er))));
	lA *= smoothstep(2.5 * u_g2.w, 4.0 * u_g2.w, length(v) / u_k);
	// (and fades into the giant's middle: it is eaten there)
	lA *= smoothstep(1.0, 0.86, f);
	// its stars: one a cell of three blocks at most, thicker where it is bright, riding
	// the flow in lanes three blocks wide across it, each lane at its own pace
	float cs = 3.0 * bw;
	float lane = floor(sd / cs);
	vec3 hl = kitHash3(ivec2(int(lane), 977));
	float spd = 0.035 * (0.75 + 0.5 * hl.x);
	float as = al - spd * tornFlowT(spd, hl.y);
	vec2 q = vec2(as, sd) / cs;
	ivec2 cq = ivec2(floor(q));
	vec3 h = kitHash3(cq + ivec2(0, 311));
	vec2 sp = (vec2(cq) + 0.15 + 0.7 * h.xy) * cs;
	// (none deep in the dwarf's body: they come off its outer part)
	if (al > 0.8 * er && abs(as - sp.x) < 0.5 * bw && abs(sd - sp.y) < 0.5 * bw && h.z < smoothstep(0.015, 0.3, lA) * (0.4 + 0.6 * core)) {
		star = fract(h.z * 17.0) < (ballGas() ? 0.3 : 0.75) ? 1 : 2;
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
	// (its middle brighter as it feeds)
	float warm = (0.5 * bul + 0.9 * pt) * mix(1.0, lane, 0.85) * (1.0 + 0.6 * u_torn.z);
	float cool = 0.3 * disc * lane;
	// (close round it, and none past its disc's own end: past it the sky is the
	// dwarf's own, as it always was)
	float spill = exp(-r / 0.35) * smoothstep(1.25, 0.85, r);
	return vec3(warm, cool, spill);
}

// the screen's own view px of a block (zoom 1, about the core's centre pixel)
vec2 tornScreen(Px P) {
	return (u_vp_origin + (vec2(P.blk) + 0.5) * 2.0 - u_cpix) / u_zoom;
}

// the light the sky takes from the giant (its stepped navy and violet tiers)
float tornGlow(Px P) {
	return 0.012 * tornGiant(tornScreen(P), blockView() / u_k).z;
}

// all of it over what the chart has here: the giant behind (over the sky only), the
// stream over the sky, and over the dwarf where it outshines it
Cand tornOver(Px P, vec2 v, Cand sc) {
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
				// disc the halo's violet)
				if (gi.x >= gi.y) {
					res = cand(M_BULGE, clamp(1.0 + log2(Eg) / 6.0, 0.0, 0.999), 0, 0.0);
				} else {
					res = cand(M_HALO, clamp(0.5 + 0.12 * log2(Eg / 0.012), 0.3, 0.92), 0, 0.0);
				}
			}
		}
	}
	// the stream
	int st;
	float lR = tornStream(P, v, st);
	if (lR > 0.008) {
		// (the dwarf's own stars, on its own ramp: a blue compact dwarf's young blue-white,
		// a dwarf spheroidal's old gold, `ballGas`)
		float lv = clamp(1.05 + log2(lR) / 6.0, 0.0, 0.999);
		Cand rc = cand(ballGas() ? M_ARM : M_BULGE, lv, 0, 0.0);
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
