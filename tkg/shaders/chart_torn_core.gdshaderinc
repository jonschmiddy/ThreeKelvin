// TORN AWAY, direction B, every style's share (`ChartTorn`): a dwarf being eaten by a
// giant neighbour. The dwarf is stripped of its outside ring by ring, redrawn at its
// real size, never shrunk (`tornShapeN`); ONE stream of its stars trails out of it
// along its orbit round the giant, a short trail at first and a loop round the giant
// by the end (`tornStreamL`); the giant itself up the screen (`tornGiant`). No ring
// is marked. Off (u_torn.x 0) unless the run sets it: nothing here runs.
//
// The including style defines TORN_FBM(p, blk, oct), its own noise (-1..1) at p with
// a block's size blk there (PAINTED's anchored `fbmL`, the others' `kitFbm2`).
//
// All of it in the core's own frame (`vb`: view px at zoom 1 about the core, round on
// the screen as a ball is drawn), and the ball's own frame (gS: vb / u_k with y over
// the ball's roundness).
uniform vec4 u_torn = vec4(0.0);    // on, the edge (gu, the rings' own, `ChartTorn.edge`), progress 0..1, squash
uniform vec4 u_tornG = vec4(0.0);   // the giant: view px x, y (zoom 1, the core's own frame), tilt, half length (gu)
uniform vec4 u_tornA = vec4(0.0);   // 0, 0, 1, rings lost
// the rings' flatness in the ball's frame (TILT / its roundness), the cut's strength,
// where the dwarf's lit body ends along the stream (gu on the screen, `lit_along`),
// the dwarf's edge against its whole (the stream's head)
uniform vec4 u_tornB = vec4(0.0);
uniform vec4 u_tornP[48];           // the stream: view px x, y, length along (gu), age 0..1
// the way the stream leaves the dwarf where it crosses the torn edge, in the ball's own
// frame on the screen (`ChartTorn.stream_dir`), how far the edge is drawn out that way
// (a share of it, `ChartTorn.lobe`), and the outermost ring standing (gu, the plane; 0
// once the picture is inside it): the edge's floor
uniform vec4 u_tornC = vec4(1.0, 0.0, 0.0, 0.0);
// the same way in the galaxy's plane at this turn (its stars' cut, where the place pass
// cuts them), the most the edge is drawn out (gu), 0
uniform vec4 u_tornS = vec4(1.0, 0.0, 0.12, 0.0);
const int TORN_N = 48;
// THE TORN EDGE'S OWN SIZES, in gu (a ring's gap is about 0.045): its rag either way,
// the light's fade inside it, the band of clumps past it, and how far past the
// outermost standing ring it stays at least (a system's mark stands on the picture)
const float TORN_RAG = 0.03;
const float TORN_FADE = 0.035;
const float TORN_BAND = 0.065;
const float TORN_MARGIN = 0.018;

bool tornOn() { return u_torn.x > 0.5; }

// (a small remnant's rag and band at its own size, so it goes to nothing in a few
// clumps, never a speck)
float tornSz() { return clamp(u_torn.y / 0.14, 0.2, 1.0); }

// THE TORN EDGE (REDRAW A, STRIPPED): what is left of the dwarf, a multiplier of its
// light at a point of the ball's own frame (gS; gq the same turned with the galaxy, blkS
// its block there). Nothing moves or is resized: the core, the body, its glow and grain
// are read where they always are, and only what lay past the edge is gone. The edge is
// torn: ragged on the galaxy's own noise (held on it, so it turns with it and never
// crawls), never inside the outermost ring still standing, drawn out toward the stream
// (the tidal side), and the last band of it broken into clumps that feed the stream's
// start; inside, the light fades out over a short band, never a hard cut. 1 everywhere
// with no ring lost; 0 everywhere once the edge is gone
float tornShapeN(vec2 gS, vec2 gq, float blkS) {
	float eT = u_torn.y;
	float r = length(gS);
	float c = r > 1e-5 ? dot(gS / r, u_tornC.xy) : 0.0;
	float pull = pow(max(c, 0.0), 3.0);
	float lobe = min(u_tornC.z * eT, u_tornS.z) * pull;
	float sz = tornSz();
	// (ragged: the galaxy's own noise, at one size whatever the edge, so it holds still
	// as the edge eats in through it)
	float n = TORN_FBM(gq * 11.0 + 4.3, blkS * 11.0, 4);
	float Ee = eT + lobe + TORN_RAG * sz * n;
	// (never inside the outermost ring standing: its systems stand on the picture)
	if (u_tornC.w > 0.0 && r > 1e-5) {
		vec2 u = gS / r;
		float yq = u.y / max(u_tornB.x, 1e-3);
		Ee = max(Ee, u_tornC.w / sqrt(u.x * u.x + yq * yq) + TORN_MARGIN);
	}
	float wF = TORN_FADE * sz;
	float keep = smoothstep(Ee + 0.2 * wF, Ee - wF, r);
	// the band being lost: clumps past the edge, more of them and longer toward the
	// stream, thinning out across it
	float band = TORN_BAND * sz * (1.0 + 1.4 * pull * (0.4 + 0.6 * u_torn.z));
	float x = (r - Ee) / max(band, 1e-4);
	if (x > -0.2 && x < 1.0) {
		vec2 dq = kitRot(-u_phi) * u_tornC.xy;
		vec2 cq = vec2(dot(gq, dq), dot(gq, vec2(-dq.y, dq.x)));
		// (drawn out along the pull on the tidal side, round elsewhere)
		float el = 1.0 + 1.6 * pull;
		float cl = 0.5 + 0.5 * TORN_FBM(vec2(cq.x * 34.0 / el, cq.y * 34.0) + 9.1, blkS * 34.0, 2);
		float th = mix(0.5, 0.85, clamp(x, 0.0, 1.0));
		keep = max(keep, smoothstep(th, th + 0.08, cl) * (1.0 - 0.6 * clamp(x, 0.0, 1.0)) * (0.6 + 0.4 * pull));
	}
	// (to nothing: the last of it goes as the edge does)
	keep *= smoothstep(0.004, 0.02, eT);
	return mix(1.0, keep, u_tornB.y);
}

// whether the chart's star at plane point p (gu) is left (1) or has gone with its ring
// (0): as PAINTED's sparkles are cut (`chart_b_stars`), on a hash held on the plane, so
// a star keeps its answer as the galaxy turns
float tornStarKeep(vec2 p) {
	if (!tornOn() || u_tornB.y <= 0.0) {
		return 1.0;
	}
	float eT = u_torn.y;
	float re = length(p);
	vec3 h = kitHash3(ivec2(floor(p / 0.008)) + ivec2(7331, 919));
	float pull = re > 1e-5 ? pow(max(dot(p / re, u_tornS.xy), 0.0), 3.0) : 0.0;
	float sz = tornSz();
	float Ee = eT + min(u_tornC.z * eT, u_tornS.z) * pull + TORN_RAG * sz * (2.0 * h.x - 1.0);
	if (u_tornC.w > 0.0) {
		Ee = max(Ee, u_tornC.w + TORN_MARGIN);
	}
	float band = TORN_BAND * sz * (1.0 + 1.4 * pull);
	float x = (re - Ee) / max(band, 1e-4);
	float keepP = (1.0 - x) * (0.4 + 0.5 * pull);
	bool gone = eT < 0.004 || x >= 1.0 || (x > 0.0 && h.y >= keepP);
	return gone && u_tornB.y > 0.5 ? 0.0 : 1.0;
}

// the stream's width (screen gu) at age f: a pull off the dwarf as wide as the
// dwarf is drawn, narrowing to a river along its orbit; all of it wider as it is fed
float tornW(float f) {
	float w = 0.006 + 0.03 * u_tornB.w * exp(-f / 0.12) + 0.011 * sqrt(f) * (1.0 - 0.5 * f);
	return w * (0.7 + 0.6 * u_torn.z);
}

// the nearest of the stream's segments, by distance over width: signed distance
// across (gu), length along (gu), age, width
void tornNear(vec2 v, out float sd, out float al, out float f, out float W) {
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
		float w = tornW(ff);
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
float tornFlowT(float speed, float ph, float bw) {
	float st = bw / speed;
	return (floor(u_time / st + ph) - ph) * st;
}

// THE STREAM'S LIGHT at v (the core's own frame, view px), bw a block there (gu), holeR
// the hole's radius (gu), gas whether the dwarf is a gassy one; and whether a star of it
// lies in this block (warm 1, cool 2)
float tornStreamL(vec2 v, float bw, float holeR, bool gas, out int star) {
	star = 0;
	float sd, al, f, W;
	tornNear(v, sd, al, f, W);
	// (its edge ragged, held where it lies: the stars flow through it)
	float x = (sd + 0.35 * W * kitSnoise2(vec2(al * 5.0, 2.0))) / W;
	if (abs(x) > 3.2) {
		return 0.0;
	}
	float prog = u_torn.z;
	// fed as the dwarf goes (brightest as the most of it pours in), densest near the
	// dwarf and thinning along its orbit; once the dwarf is gone, a faint loop of its
	// stars round the giant, about as bright all round (Jon's reference, panel three)
	float endK = smoothstep(0.88, 1.0, prog);
	float B = mix(1.0, mix(0.3, 0.75, endK), smoothstep(0.0, 1.0, f)) * (0.25 + 0.6 * prog) * mix(1.0, 0.55, endK);
	// (its light held where it lies: knots, clumps and grain are the stream's shape;
	// what flows are its stars, below)
	float wob = 1.6 * kitSnoise2(vec2(al * 1.7, 0.0));
	float strand = 0.5 + 0.5 * cos(x * 4.2 + wob);
	float clump = 0.5 + 0.5 * TORN_FBM(vec2(al * 9.0, x * 0.7), bw * 9.0, 3);
	float core = exp(-x * x);
	// knots and gaps along it (a stream of stars, never a tube), and a grain of two
	// blocks over it
	float knots = smoothstep(0.22, 0.68, 0.5 + 0.5 * TORN_FBM(vec2(al * 4.5, 0.0), bw * 4.5, 2));
	vec2 gq = vec2(al, sd) / (2.0 * bw);
	float grain = 0.6 + 0.8 * kitHash3(ivec2(floor(gq)) + ivec2(0, 17)).x;
	float lA = B * (core * (0.3 + 0.7 * strand) * (0.4 + 0.9 * clump) * grain + 0.12 * exp(-abs(x) * 1.3) * (0.6 + 0.6 * clump));
	lA *= 0.3 + 0.95 * knots;
	// (out of the dwarf's own light: it rises faint inside the lit body's outer part,
	// over its outer stars and glow where it outshines them, and is brightest just past
	// where that light ends (`ChartTorn.lit_along`, er), where the stars are pulled off;
	// never near its core, which stays the goal: clear of the hole's ring)
	float er = u_tornB.z;
	float rise = max(0.1, 0.3 * er);
	lA *= smoothstep(er - rise, er, al) * (1.0 + 0.6 * exp(-pow((al - er - 0.15 * rise) / (0.8 * rise), 2.0)));
	lA *= smoothstep(2.5 * holeR, 4.0 * holeR, length(v) / u_k);
	// (and thins out at its far end, round the orbit)
	lA *= smoothstep(1.0, 0.86, f);
	// its stars: one a cell of three blocks at most, thicker where it is bright, riding
	// the flow in lanes three blocks wide across it, each lane at its own pace
	float cs = 3.0 * bw;
	float lane = floor(sd / cs);
	vec3 hl = kitHash3(ivec2(int(lane), 977));
	float spd = 0.035 * (0.75 + 0.5 * hl.x);
	float as = al - spd * tornFlowT(spd, hl.y, bw);
	vec2 q = vec2(as, sd) / cs;
	ivec2 cq = ivec2(floor(q));
	vec3 h = kitHash3(cq + ivec2(0, 311));
	vec2 sp = (vec2(cq) + 0.15 + 0.7 * h.xy) * cs;
	// (none deep in the dwarf's body: they come off its outer part)
	if (al > er - rise && abs(as - sp.x) < 0.5 * bw && abs(sd - sp.y) < 0.5 * bw && h.z < smoothstep(0.015, 0.3, lA) * (0.4 + 0.6 * core)) {
		star = fract(h.z * 17.0) < (gas ? 0.3 : 0.75) ? 1 : 2;
	}
	return lA;
}

// the giant: in its own frame on the screen (gu along, across), from the core's own frame
vec2 tornGiantF(vec2 vb) {
	vec2 d = (vb - u_tornG.xy) / u_k;
	float c = cos(u_tornG.z), s = sin(u_tornG.z);
	return vec2(c * d.x + s * d.y, -s * d.x + c * d.y);
}

// its light: warm (the bulge and the inner disc), cool (the outer disc), and the
// spill on the sky. A giant spiral far bigger than the dwarf, seen steeply tilted:
// a broad disc with its arms and its dust lane, a gold bulge, its ends warped by
// the meal and its disc puffed up as it feeds (Jon's reference, panel three: "the
// larger disc responds"). Faint for its size (it is far off): the core goal stays
// the hottest thing on the chart.
vec3 tornGiant(vec2 vb, float bw) {
	vec2 ab = tornGiantF(vb);
	float L = u_tornG.w;
	float a = ab.x;
	float aa = abs(a);
	float prog = u_torn.z;
	// the disc warped by the meal (an integral sign), flaring toward its ends, more so
	// as it feeds
	float b = ab.y + (0.03 + 0.06 * prog) * L * sign(a) * pow(smoothstep(0.45 * L, 1.1 * L, aa), 2.0);
	// (in its own plane: tilted to a quarter of its length across, puffed up a little
	// as it is heated)
	float Q = 0.27 + 0.05 * prog;
	vec2 dp = vec2(a, b / Q);
	float r = length(dp) / L;
	float th = atan(dp.y, dp.x);
	// two arms wound out from the bulge, lumpy with star clouds
	float arm = 0.5 + 0.5 * cos(2.0 * th - 6.0 * log(max(r, 0.04)) + 1.3);
	arm = arm * arm * arm;
	float lumps = 0.65 + 0.7 * TORN_FBM(dp * 9.0 / L + 3.7, bw * 9.0 / L, 3);
	float disc = exp(-r / 0.3) * smoothstep(1.08, 0.75, r) * (0.12 + 1.7 * arm) * lumps;
	// the dust lane, on the near side of the bulge, along the disc
	float lz = (b + 0.05 * L * Q) / (0.018 * L);
	float lane = 1.0 - 0.85 * exp(-lz * lz) * smoothstep(0.75, 0.05, r);
	float bx = a / (0.055 * L), by = ab.y / (0.04 * L);
	float bul = exp(-(bx * bx + by * by));
	float px = a / 0.012, py = ab.y / 0.009;
	float pt = exp(-(px * px + py * py));
	// (its middle brighter as it feeds)
	float warm = (0.5 * bul + 0.9 * pt) * mix(1.0, lane, 0.85) * (1.0 + 0.6 * prog);
	float cool = 0.3 * disc * lane;
	// (close round it, and none past its disc's own end: past it the sky is the
	// dwarf's own, as it always was)
	float spill = exp(-r / 0.35) * smoothstep(1.25, 0.85, r);
	return vec3(warm, cool, spill);
}

// THE STREAM AND THE GIANT AS LIGHT (SIMPLIFIED's and RADIANT's, which add light where
// PAINTED picks a palette step): linear colour to add over what lies at vb, and how
// much of it is solid (the giant over the sky, the stream's core), 0..1, in .a.
// warmC / coolC the dwarf's own ramps (its stream's colour), giantW / giantC the giant's.
vec4 tornLightN(vec2 vb, float bw, float holeR, bool gas, vec3 dwarfC, vec3 starC, vec3 giantW, vec3 giantC, float gain) {
	vec3 gi = tornGiant(vb, bw);
	vec3 c = (giantW * gi.x + giantC * gi.y) * 0.32 * gain;
	int st;
	float lR = tornStreamL(vb, bw, holeR, gas, st);
	c += dwarfC * lR * 0.11 * gain;
	if (st > 0) {
		c += starC * (st == 1 ? 0.55 : 0.45) * gain;
	}
	float a = clamp(max(gi.x + gi.y, lR) * 4.0, 0.0, 1.0);
	return vec4(c, a);
}
