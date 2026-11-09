// TORN AWAY, the hook (Jon, Nov 8), every style's share (`ChartTorn`): a dwarf being
// eaten by a giant neighbour. The dwarf is stripped of its outside ring by ring, redrawn
// at its real size, never shrunk (`tornShapeN`); ONE stream of its stars, gas and
// clouds leaves its left side as a wide band, swings down and round and climbs into the
// giant's underside, narrowing as it goes, its matter drifting along it (`tornStreamL`);
// the giant whole in the opening's upper left, further off than the chart (`tornGiant`).
// No ring is marked. Off (u_torn.x 0) unless the run sets it: nothing here runs.
//
// The including style defines TORN_FBM(p, blk, oct), its own noise (-1..1) at p with
// a block's size blk there (PAINTED's anchored `fbmL`, the others' `kitFbm2`).
//
// All of it in the core's own frame (`vb`: view px at zoom 1 about the core, round on
// the screen as a ball is drawn), and the ball's own frame (gS: vb / u_k with y over
// the ball's roundness).
uniform vec4 u_torn = vec4(0.0);    // on, the edge (gu, the rings' own, `ChartTorn.edge`), progress 0..1, squash
uniform vec4 u_tornG = vec4(0.0);   // the giant: view px x, y (zoom 1, the core's own frame), tilt, half length (gu)
uniform vec4 u_tornA = vec4(0.0);   // the stream's root half width (gu, `ChartTorn.root_w`), its length drawn (gu), how far round (`reach`), rings lost
// the least half width before the tip (gu), the giant's breadth against its length, the
// hook's share of the decay (`ChartTorn.share`), the giant's slide in blocks along x
// (its y in u_tornS.w)
uniform vec4 u_tornH = vec4(0.0);
// the rings' flatness in the ball's frame (TILT / its roundness), the cut's strength,
// where the dwarf's lit body ends (gu, the ball's own frame, `ChartTorn.lit_r`), the
// dwarf's edge against its whole
uniform vec4 u_tornB = vec4(0.0);
uniform vec4 u_tornP[48];           // the stream's hook: view px x, y, length along (gu), age 0..1 (to `reach`)
// the way the stream leaves the dwarf where it crosses the torn edge, in the ball's own
// frame on the screen (`ChartTorn.stream_dir`), how far the edge is drawn out that way
// (a share of it, `ChartTorn.lobe`), and the outermost ring standing (gu, the plane; 0
// once the picture is inside it): the edge's floor
uniform vec4 u_tornC = vec4(1.0, 0.0, 0.0, 0.0);
// the same way in the galaxy's plane at this turn (its stars' cut, where the place pass
// cuts them), the most the edge is drawn out (gu), the giant's slide in blocks along y
uniform vec4 u_tornS = vec4(1.0, 0.0, 0.12, 0.0);
const int TORN_N = 48;
// the dwarf's clouds torn with it (`ChartTorn.cloud_tear`)
#include "res://shaders/chart_torn_cloud.gdshaderinc"
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

// THE STREAM'S HALF WIDTH (screen gu) at its age f (the mockup's band, Jon, Nov 8): as
// wide as the dwarf where it leaves it (`u_tornA.x`), narrowing toward the giant; while
// it has not come all the way round (`u_tornA.z`), its leading tip narrows to a point
// over the last third of its way
float tornW(float f) {
	float R = max(u_tornA.x, 1e-3);
	float w = max(u_tornH.x, R * (1.0 - 0.85 * f));
	float reach = u_tornA.z;
	float tip = reach >= 0.999 ? 1.0 : clamp((reach - f) / 0.3, 0.04, 1.0);
	return w * tip;
}

// the stream's nearest point (the arc's, by distance): signed distance across (gu),
// length along (gu; below 0 behind the dwarf's core, the first segment run on back),
// age, and its half width there (`tornW`)
void tornNear(vec2 v, out float sd, out float al, out float f, out float W) {
	float best = 1e18;
	sd = 1e3;
	al = 0.0;
	f = 1.0;
	for (int i = 0; i < TORN_N - 1; i++) {
		vec4 A = u_tornP[i];
		vec4 B = u_tornP[i + 1];
		vec2 ab = B.xy - A.xy;
		float L2 = max(dot(ab, ab), 1e-6);
		float t = clamp(dot(v - A.xy, ab) / L2, 0.0, 1.0);
		vec2 d = v - (A.xy + ab * t);
		float d2 = dot(d, d);
		if (d2 < best) {
			best = d2;
			float side = sign(ab.x * d.y - ab.y * d.x);
			sd = sqrt(d2) / u_k * side;
			al = A.z + (B.z - A.z) * t;
			f = clamp(mix(A.w, B.w, t), 0.0, 1.0);
		}
	}
	// (its width wandering a little along it, Jon's "too squared off": never straight sides)
	// (and more so near the dwarf, Jon's H2: swelling and pinching there, never a pipe)
	float nr = 1.0 - smoothstep(0.1, 0.55, f);
	W = tornW(f) * max(1.0 + (0.16 + 0.3 * nr) * kitSnoise2(vec2(al * 1.6, 5.3)), 0.45);
}

// the flow's held clock for one lane of the stream's matter: it steps one block
// along it a pose, each lane at its own pace and on its own beat, so a frame moves
// a lane or two, never the whole stream at once (that read as a pulse)
float tornFlowT(float speed, float ph, float bw) {
	float st = bw / speed;
	return (floor(u_time / st + ph) - ph) * st;
}

// one lane of drifting matter at (al, sd) (gu): cells `cs` long along the stream, the
// lane at its own pace (`spd` gu a second, stepped a block at a time); what lies in this
// block: the cell's hash (z picks), and whether its sprite, `len` x `wid` blocks, covers it
vec3 tornDrift(float al, float sd, float bw, float cs, float spd, float tag, float len, float wid, out bool hit) {
	float lane = floor(sd / cs);
	vec3 hl = kitHash3(ivec2(int(lane), int(977.0 + tag)));
	float sp = spd * (0.75 + 0.5 * hl.x);
	float as = al - sp * tornFlowT(sp, hl.y, bw);
	ivec2 cq = ivec2(floor(vec2(as, sd) / cs));
	vec3 h = kitHash3(cq + ivec2(int(tag), 311));
	vec2 c = (vec2(cq) + 0.15 + 0.7 * h.xy) * cs;
	// (its blocks on the stream's own grid, so a sprite keeps its shape as it moves)
	vec2 d = floor((vec2(as, sd) - c) / bw);
	hit = d.x >= -floor(len * 0.5) && d.x < ceil(len * 0.5) && d.y >= -floor(wid * 0.5) && d.y < ceil(wid * 0.5);
	return h;
}

// THE STREAM'S LIGHT at v (the core's own frame, view px), bw a block there (gu), holeR
// the hole's radius (gu), gas whether the dwarf is a gassy one; and what of its drifting
// matter lies in this block: a star (warm 1, cool 2), a pink cloud's speck (3), a puff of
// its gas (4)
float tornStreamL(vec2 v, float bw, float holeR, bool gas, out int star) {
	star = 0;
	float sd, al, f, W;
	tornNear(v, sd, al, f, W);
	// (its root rounded: behind it the distance is to the root's point, so it ends in a
	// round cap, never cut square across; inside the dwarf's light it is faint, below)
	float R0 = max(u_tornA.x, 1e-3);
	float ahead = 1.0;
	// (its edge torn, held where it lies: a slow lumpy rag at its own width and a finer
	// one, each side its own; the matter drifts through it)
	float sdS = sd >= 0.0 ? 1.0 : -1.0;
	// (Jon's 3A: its first stretch off the dwarf one wide smooth glow, the mockup's band;
	// its strands, clumps, knots and torn edge come in further along)
	float tx = smoothstep(0.12, 0.5, f);
	// (its edges still wander slowly there, each side its own: only the fine rag waits)
	// (near the dwarf its middle sways across it and each side wanders on its own, slow
	// and deep, so its two sides never run parallel: Jon's H2)
	float nr2 = 1.0 - tx;
	sd += nr2 * 0.35 * W * kitSnoise2(vec2(al * 1.3, 9.1));
	sdS = sd >= 0.0 ? 1.0 : -1.0;
	float rag = nr2 * 0.32 * kitSnoise2(vec2(al * 2.2, 13.0 + 4.0 * sdS)) + mix(0.4, 1.0, tx) * (0.3 - 0.15 * smoothstep(0.08, 0.3, W)) * kitSnoise2(vec2(al * 5.0, 2.0 + 3.0 * sdS)) + tx * 0.12 * TORN_FBM(vec2(al * 22.0, 7.0 + 5.0 * sdS), bw * 22.0, 2);
	float x = (sd + rag * W * sdS) / W;
	if (abs(x) > 3.2) {
		return 0.0;
	}
	float sh = u_tornH.z;
	// brightest as the most of the dwarf pours in, densest near the dwarf and thinning
	// toward the giant, about as bright all along by the end
	float endK = smoothstep(0.85, 1.0, sh);
	float B = mix(1.0, mix(0.45, 0.8, endK), smoothstep(0.0, 1.0, f)) * (0.5 + 0.25 * sh);
	// (the broad root in many strands that run together as it narrows: a tidal tail's
	// streamers, never a flat cone)
	float ns = clamp(W / 0.05, 1.0, 4.0);
	float wob = 1.6 * kitSnoise2(vec2(al * 1.7, 0.0));
	float strand = 0.5 + 0.5 * cos(x * 4.2 * ns + wob);
	float clump = 0.5 + 0.5 * TORN_FBM(vec2(al * 9.0, x * 0.7 * ns), bw * 9.0, 3);
	// (light across it: full along its middle, its broad root's sides fainter)
	float core = exp(-x * x * mix(1.0, 1.6, smoothstep(0.05, 0.3, W)));
	// knots and gaps along it (a stream of stars, never a tube), and a grain of two
	// blocks over it
	float knots = smoothstep(0.22, 0.68, 0.5 + 0.5 * TORN_FBM(vec2(al * 4.5, 0.0), bw * 4.5, 2));
	vec2 gq = vec2(al, sd) / (2.0 * bw);
	float grain = 0.6 + 0.8 * kitHash3(ivec2(floor(gq)) + ivec2(0, 17)).x;
	float lA = B * (core * mix(0.45, (0.3 + 0.7 * strand) * (0.4 + 0.9 * clump) * grain, tx) + 0.12 * exp(-abs(x) * 1.3) * mix(0.9, 0.6 + 0.6 * clump, tx));
	lA *= mix(0.8, 0.3 + 0.95 * knots, tx);
	// (its light gathers as it narrows: what left the dwarf across its whole width runs
	// into the giant down a thread)
	lA *= 1.0 + 0.5 * (1.0 - clamp(W / R0, 0.0, 1.0));
	// (out of the dwarf's own light: it rises from faint inside the lit body's outer part
	// to full a little past where that light ends (`ChartTorn.lit_r`, er, in the ball's own
	// frame), with no peak at the edge, where the standing rim's marks are; never near the core)
	float er = u_tornB.z;
	float bsq = KIT_TILT / max(u_tornB.x, 1e-3);
	float rB = length(vec2(v.x, v.y / bsq)) / u_k;
	float rise = max(0.1, 0.45 * er);
	// (Jon's H3: it rises from well inside the dwarf's light, so it reads as joined to it)
	lA *= smoothstep(er - 1.8 * rise, er, rB) * ahead;
	lA *= smoothstep(2.5 * holeR, 4.0 * holeR, length(v) / u_k);
	// (and thins out at its far end, into the giant's disc)
	lA *= u_tornA.z >= 0.999 ? smoothstep(1.0, 0.85, f) : 1.0;
	// ITS DRIFTING MATTER (Jon's sketch: "stars, gas, nebulae slowly streaming"): stars
	// one block, puffs of gas two by two, pink cloud specks two by one, each in lanes
	// across it at its own calm pace, toward the giant, a block at a time
	// (none in the round cap behind its root: lanes measured from the root's point bend
	// into rings round it, and drew pale crescents there)
	vec2 d0 = normalize(u_tornP[1].xy - u_tornP[0].xy + 1e-6);
	float fore = step(0.0, dot(v - u_tornP[0].xy, d0));
	float inside = smoothstep(1.15, 0.6, abs(x)) * step(er - rise, rB) * ahead * fore;
	if (inside > 0.0) {
		bool hit;
		vec3 h = tornDrift(al, sd, bw, 3.0 * bw, 0.022, 0.0, 1.0, 1.0, hit);
		if (hit && h.z < smoothstep(0.01, 0.25, lA) * (0.4 + 0.6 * core) * inside) {
			star = fract(h.z * 17.0) < (gas ? 0.3 : 0.75) ? 1 : 2;
		}
		h = tornDrift(al, sd, bw, 7.0 * bw, 0.016, 41.0, 2.0, 2.0, hit);
		if (star == 0 && hit && h.z < 0.55 * inside * smoothstep(0.01, 0.12, lA)) {
			star = 4;
		}
		h = tornDrift(al, sd, bw, 11.0 * bw, 0.013, 83.0, 2.0, 1.0, hit);
		if (hit && h.z < 0.45 * inside * smoothstep(0.005, 0.08, lA)) {
			star = 3;
		}
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
// larger disc responds"). It reads as the bigger, brighter galaxy doing the eating
// (Nov 8's review: the big dwarf outshone it): its disc lit out to its ends, its bulge
// broad; the core goal still the hottest point on the chart.
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
	float Q = u_tornH.y * (1.0 + 0.15 * prog);
	vec2 dp = vec2(a, b / Q);
	float r = length(dp) / L;
	float th = atan(dp.y, dp.x);
	// two arms wound out from the bulge, lumpy with star clouds
	float arm = 0.5 + 0.5 * cos(2.0 * th - 6.0 * log(max(r, 0.04)) + 1.3);
	arm = arm * arm * arm;
	float lumps = 0.65 + 0.7 * TORN_FBM(dp * 9.0 / L + 3.7, bw * 9.0 / L, 3);
	float disc = (exp(-r / 0.3) + 0.35 * exp(-r / 0.7)) * smoothstep(1.08, 0.75, r) * (0.2 + 1.7 * arm) * lumps;
	// the dust lane, on the near side of the bulge, along the disc
	float lz = (b + 0.05 * L * Q) / (0.018 * L);
	float lane = 1.0 - 0.85 * exp(-lz * lz) * smoothstep(0.75, 0.05, r);
	float bx = a / (0.075 * L), by = ab.y / (0.055 * L);
	float bul = exp(-(bx * bx + by * by));
	float px = a / 0.012, py = ab.y / 0.009;
	float pt = exp(-(px * px + py * py));
	// (its middle brighter as it feeds)
	float warm = (0.7 * bul + 0.9 * pt) * mix(1.0, lane, 0.85) * (1.0 + 0.6 * prog);
	float cool = 0.55 * disc * lane;
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
	vec3 c = (giantW * gi.x + giantC * gi.y) * 0.4 * gain;
	int st;
	float lR = tornStreamL(vb, bw, holeR, gas, st);
	c += dwarfC * lR * 0.2 * gain;
	if (st == 1 || st == 2) {
		c += starC * (st == 1 ? 0.55 : 0.45) * gain;
	} else if (st == 3) {
		// (a speck of one of its pink clouds, torn off with it)
		c += vec3(0.9, 0.3, 0.55) * 0.3 * gain;
	} else if (st == 4) {
		// (a puff of its gas, its own colour, softer than a star)
		c += dwarfC * 0.12 * gain;
	}
	float a = clamp(max(gi.x + gi.y, lR) * 4.0, 0.0, 1.0);
	return vec4(c, a);
}
