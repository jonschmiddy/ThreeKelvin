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
	float lR = tornStreamL(vb, bw, u_g2.w, ballGas(), st);
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
