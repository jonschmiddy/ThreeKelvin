// TORN AWAY, direction B: the stream (`ChartTorn`). A dwarf being eaten by a giant
// neighbour, seen far off and steeply tilted up the chart: ONE stream of the dwarf's
// stars runs out of it toward the giant and spirals into the giant's middle, wider
// and brighter as more of the dwarf goes into it. The dwarf itself is drawn smaller
// with each ring lost (`tornBody`, the scene's ball frames) and cut at its edge
// (`tornCut`). No ring is marked. Off (u_torn.x 0) unless the run sets it: nothing
// here runs.
uniform vec4 u_torn = vec4(0.0);    // on, the drawn edge (gu, the rings'), progress 0..1, squash
uniform vec4 u_tornG = vec4(0.0);   // the giant: view px x, y (zoom 1, about the core), tilt, half length (gu)
uniform vec4 u_tornA = vec4(0.0);   // the line to the giant (plane, unrotated), the dwarf's drawn scale, rings lost
uniform vec4 u_tornP[48];           // the stream: view px x, y, length along (gu), age 0..1
const int TORN_N = 48;

bool tornOn() { return u_torn.x > 0.5; }

// THE DWARF DRAWN SMALLER: a point of the ball's own frame (vb, about the core) to
// where the dwarf's picture is read, so the whole of it -- body, glow, halo, grain --
// shrinks about the core by u_tornA.z, drawn out a little toward the giant as the
// run goes on (none with no ring lost: the dwarf as it always is)
vec2 tornBody(vec2 vb) {
	vec2 axr = kitRot(u_phi) * u_tornA.xy;
	vec2 axS = normalize(vec2(axr.x, axr.y * KIT_TILT));
	float st = 0.3 * u_torn.z;
	float pa = dot(vb, axS);
	vec2 q = axS * pa / (1.0 + st) + (vb - pa * axS);
	return q / u_tornA.z;
}

// the dwarf's light cut at its drawn edge (what has gone is gone), ragged, drawn
// out toward the giant as its picture is; none with no ring lost
float tornCut(vec2 g, float bw) {
	vec2 gal = vec2(g.x, g.y * u_torn.w);
	vec2 ax = u_tornA.xy;
	float al = dot(gal, ax);
	float pe = dot(gal, vec2(-ax.y, ax.x));
	float re = length(vec2(al / (1.0 + 0.3 * u_torn.z), pe));
	re += 0.03 * fbmL(gal * 9.0 + 4.3, bw * 9.0, 2);
	float e = u_torn.y;
	return mix(1.0, smoothstep(e + 0.03, e - 0.04, re), clamp(u_tornA.w, 0.0, 1.0));
}

// the stream's width (screen gu) at age f: a pull off the dwarf as wide as the
// dwarf is drawn, narrowing to a river, then a thread as it winds into the giant;
// all of it wider as it is fed
float tornW(float f) {
	float w = 0.005 + 0.024 * u_tornA.z * exp(-f / 0.1) + 0.016 * sqrt(f) * (1.0 - f);
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

// the flow's held clock: the stream's stars step one block along it a pose
float tornFlowT(float speed) {
	float bw = blockView() / u_k;
	float st = bw / speed;
	return floor(u_time / st) * st;
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
	// the stars stream from the dwarf into the giant
	const float SPEED = 0.035;
	float ft = tornFlowT(SPEED);
	float a1 = al - SPEED * ft;
	float bw = blockView() / u_k;
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
	// (out of the dwarf's own body, wherever its edge now is: the stream comes up
	// through its outskirts, brightest just past them, and the body outshines it inside)
	float s = u_tornA.z;
	lA *= smoothstep(0.08 * s, 0.22 * s, al) * (1.0 + 0.6 * exp(-sq((al - 0.28 * s) / (0.08 * s))));
	// (and fades into the giant's middle: it is eaten there)
	lA *= smoothstep(1.0, 0.86, f);
	// its stars: one a cell of three blocks at most, riding the flow, thicker where it is bright
	float cs = 3.0 * bw;
	vec2 q = vec2(a1, sd) / cs;
	ivec2 cq = ivec2(floor(q));
	vec3 h = kitHash3(cq + ivec2(0, 311));
	vec2 sp = (vec2(cq) + 0.15 + 0.7 * h.xy) * cs;
	if (abs(a1 - sp.x) < 0.5 * bw && abs(sd - sp.y) < 0.5 * bw && h.z < smoothstep(0.015, 0.3, lA) * (0.4 + 0.6 * core)) {
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
	// (close round it: past it the sky is the dwarf's own, as it always was)
	float spill = exp(-length(vec2(a * 0.5, ab.y)) / (0.4 * L));
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
