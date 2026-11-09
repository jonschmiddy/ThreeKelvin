// TORN AWAY in PAINTED (`ChartTorn`): the shared drawing (`chart_torn_core`: the torn
// edge, the stream, the giant) in this style's hand -- its anchored noise, its palette's
// steps, its ordered patterns.
#define TORN_FBM(p, b, o) fbmL(p, b, o)
#include "res://shaders/chart_torn_core.gdshaderinc"

// THE TORN EDGE in this style: `tornShapeN` on its own anchored noise
float tornShape(vec2 gS, vec2 gq, float blkS) {
	return tornShapeN(gS, gq, blkS);
}

// the light the sky takes from the giant (its stepped navy and violet tiers), at vb
// (the core's own frame)
float tornGlow(vec2 vb) {
	return 0.012 * tornGiant(vb, blockView() / u_k).z;
}

// all of it over what the chart has here (vb: the core's own frame): the giant behind
// (over the sky only), the stream over the sky, and over the dwarf where it outshines it
Cand tornOver(Px P, vec2 vb, Cand sc) {
	float bw = blockView() / u_k;
	bool skyHere = sc.m == M_SKY || sc.sid == SID_FAR;
	Cand res = sc;
	if (skyHere) {
		vec3 gi = tornGiant(vb, bw);
		float Eg = gi.x + gi.y;
		if (Eg > 0.012) {
			float a = smoothstep(0.012, 0.03, Eg);
			// (its patterns ride with it as it slides, `ChartTorn.slide`: rigid, never a crawl)
			Px PG = P;
			PG.dq -= ivec2(int(u_tornH.w), int(u_tornS.w));
			if (pat(PG, a)) {
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
	float lR = tornStreamL(vb, bw, u_g2.w, ballGas(), st);
	if (lR > 0.008) {
		// (the dwarf's own stars, on its own ramp: a blue compact dwarf's young blue-white,
		// a dwarf spheroidal's old gold, `ballGas`)
		// (a step under its light, and thinning out in the style's patterns well before it
		// is gone: a stream of stars, never a solid flame of the ramp's brightest steps)
		// (held below the arm ramp's top steps: the band runs past the rim's marks, and its
		// brightest steps lifted their sky past MARK_LUMA, TornTest)
		float lv = clamp(0.9 + log2(lR) / 6.0, 0.0, 0.5);
		Cand rc = cand(M_ARM, lv, 0, 0.0);
		if (goldD()) {
			// (the dim-gold dwarf's: its own gold ramp, as its body, Jon's 2B)
			rc = cand(M_GOLD, lv, 0, 0.0);
		} else if (!ballGas()) {
			// (an old dwarf's: the halo's violet haze, its middle a few of the warm ramp's
			// orange steps, its stars gold, below -- the warm ramp's bright steps were a
			// flame the marks' orange words were lost on)
			rc = cand(M_HALO, clamp(0.35 + 0.6 * lv, 0.3, 0.95), 0, 0.0);
			if (lv > 0.62 && pat(P, smoothstep(0.62, 0.9, lv) * 0.75)) {
				rc = cand(M_BULGE, 3.5 / 7.0, 0, 0.0);
			}
		} else if (lv < 1.0 / 6.0) {
			// the faint fringe goes to the halo's violet
			rc = cand(M_HALO, 0.45 + 2.0 * lv, 0, 0.0);
		}
		float a = smoothstep(0.012, 0.16, lR);
		if (pat(P, a) && (res.m == M_SKY || res.sid == SID_FAR || rc.y > res.y)) {
			res = rc;
		}
	}
	if (st == 1 || st == 2) {
		Cand sc2 = cand(st == 1 ? M_STARW : M_STAR, st == 1 ? 0.6 : 0.5, 0, 0.0);
		if (sc2.y > res.y) {
			res = sc2;
		}
	} else if (st == 3) {
		// (a speck of one of its pink clouds, torn off with it: the clouds' own pink)
		res = cand(M_HA, 0.62, 0, 0.0);
	} else if (st == 4) {
		// (a puff of its gas: a step up its own ramp over what lies there)
		Cand pc = ballGas() ? cand(M_ARM, 0.55, 0, 0.0) : (goldD() ? cand(M_GOLD, 0.55, 0, 0.0) : cand(M_HALO, 0.75, 0, 0.0));
		if (pc.y > res.y || res.m == M_SKY || res.sid == SID_FAR) {
			res = pc;
		}
	}
	return res;
}
