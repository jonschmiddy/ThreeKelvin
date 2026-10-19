// A GALAXY'S DEPTH (SIMPLIFIED, PAINTED, RADIANT; `ChartSky.gal_depth`, `-- galdepth=0|1|2`, 2 the game's).
// Jon, Oct 19: "let's also explore giving the galaxies some depth. They seem like a
// flat image right now. This is especially evident on the edges"; then, of a first
// try with a side wall and a lit top at the rim, "depth:puffs" -- keep the approved
// soft dissolving edge and build the volume with clouds above and below the disc.
//
// What was tried before and kept (Oct 11-13): layers floated AROUND the galaxy read
// flat whatever their height ("still too high up ... like it's a single plane"); what
// worked was the galaxy itself as a solid object (the camera, the gas as a lit height
// field standing toward it, the edge dissolving into black). So these clouds are the
// disc's own gas, standing off it:
//   1  billows of its gas and dust raised ABOVE and BELOW the plane across the outer
//      disc and out over the dissolving edge, of varied sizes, denser toward the
//      bulge and where the arms' gas is, a few reaching well off the plane; each lit
//      from the core on the side toward it and shaded on the side away, the ones
//      under the plane dimmer (in the disc's shadow, seen through its thin outskirts);
//      the ones over it stand in front of the disc and hold back a little of it. And
//      a soft halo of stars round it.
//   2  1, with the camera's foot under the view's centre, so as the chart slides the
//      clouds over the plane, the plane and the clouds under it slide against each
//      other (parallax between the three).
// LIGHT ONLY WHERE A CLOUD IS: the disc's own light, lanes and arms are untouched
// between them. And NOT IN THE PALETTE'S PROBES (`u_tone_out`): the palette is cut
// from the galaxy as it was, so the clouds take its existing steps and the disc's
// contrast cannot move (a first try, drawn in the probes too, re-cut the palette
// and every arm came out a step duller).
//
// THE INCLUDING SHADER PROVIDES chart_solid (fluffToward, edgeMask, u_solidW, u_phi,
// u_solid) and u_struct / bakeUV (the disc's own bake); and, if it draws the palette's
// probes through this pass, `#define DEPTH_PROBE <its probe flag>` before including.
#ifndef DEPTH_PROBE
#define DEPTH_PROBE false
#endif

// the mode (0 off, 1 the clouds, 2 and parallax), the view's centre (view px at zoom
// 1, from the galaxy's centre), a block (view px at zoom 1)
uniform vec4 u_depth = vec4(0.0);
// how far a layer slides against the plane as the view's centre moves, a unit of its
// height (in its own scale): the camera's foot following the view
const float DEPTH_PAR = 0.035;

const float DEPTH_H = 0.05;          // a cloud layer's height off the plane at the bulge, gu
const float DEPTH_HALO = 0.006;      // the soft halo of stars' light

// how far off the plane the clouds stand at plane radius r: higher toward the bulge
float depthH(float r) {
	return DEPTH_H * (0.55 + 0.45 * exp(-r / 0.5));
}

// the plane's shift per unit of height toward the camera: the solid look's own
vec2 depthToward(vec2 p) {
	return fluffToward(p);
}

// THE PARALLAX (depth 2): a layer at height h slides against the plane as the view's
// centre moves, as it would under a camera whose foot followed the view -- but the
// WHOLE LAYER as one, ON THE SCREEN, IN WHOLE BLOCKS (view px). Worked out per block
// from a moving camera (the first try), every cloud was re-read a fraction of a block
// over each frame of a drag and the clouds crawled: shimmer 0.63 against today's 0.26
// on The Long Harvest's slow drag; held in whole steps of the PLANE (the second), the
// perspective still made each step a fraction of a block on the screen: 0.60.
vec2 depthSlide(float h) {
	if (u_depth.x < 1.5 || !u_solid) {
		return vec2(0.0);
	}
	vec2 s = -h * DEPTH_PAR * u_depth.yz;
	float bk = max(u_depth.w, 1e-4);
	return floor(s / bk + 0.5) * bk;
}

// the clouds of one layer at plane point q (0..1): billows of a size of their own,
// over the outer disc and its dissolving edge, denser toward the bulge and on the arms
float depthCloud(vec2 q, float f, float seed, float thr) {
	float r = length(q);
	float env = smoothstep(0.22, 0.5, r) * (1.0 - smoothstep(1.0, 1.35, r)) * (0.45 + 0.75 * exp(-r / 0.6));
	if (env <= 0.0) {
		return 0.0;
	}
	vec4 S = textureLod(u_struct, bakeUV(q), 3.0);
	float n = kitFbm2(q * f + vec2(seed * 7.3, seed * 3.1), 4);
	return smoothstep(thr, thr + 0.25, n + 0.35 * S.r) * env;
}

// a layer's clouds seen at the block whose plane point is p: (light, how much they
// hold back of what lies behind). `h` the layer's height (in depthH), f its billows'
// size, `lit` how much of the core's light reaches it, `base` the disc's light here
vec4 depthLayer(vec2 p, vec2 vs, vec2 dT, float h, float f, float seed, float thr, float lit, float base) {
	// (with the parallax, the layer read at the screen point it has slid to, whole)
	vec2 ps = u_depth.x > 1.5 && u_solid ? kitViewToPlane(solidO(vs + depthSlide(h)), u_phi, u_k) : p;
	vec2 q = ps + h * depthH(length(ps)) * dT;
	float d = depthCloud(q, f, seed, thr);
	if (d <= 0.0) {
		return vec4(0.0);
	}
	// lit from the core: the side toward it bright, the side away in shade
	vec2 toC = -q / max(length(q), 1e-4);
	float dn = depthCloud(q + toC * (0.6 / f), f, seed, thr);
	float face = clamp(0.5 + 2.2 * (d - dn), 0.0, 1.0);
	float r = length(q);
	vec3 col = mix(vec3(1.0, 0.78, 0.55), vec3(0.50, 0.62, 1.0), smoothstep(0.15, 0.6, r));
	vec3 L = col * base * (0.25 + 1.6 * face) * lit;
	return vec4(L * d, d);
}

// the clouds over and under the disc, and its halo, at the block whose plane point is
// p: what lies behind (the disc, C so far) goes through `T`, and `Em` gains their light
// (`vs`: the block's point on the screen, view px at zoom 1 from the galaxy's centre)
void depthClouds(vec2 p, vec2 vs, float em, vec3 discL, inout vec3 Em, inout vec3 T) {
	if (u_depth.x < 0.5 || DEPTH_PROBE) {
		return;
	}
	vec2 dT = depthToward(p);
	float r = length(p);
	// (each cloud as bright as the disc's own light thereabouts, never brighter than its
	// arms: so the palette's existing steps carry it)
	float base = max(kitLum(discL), 0.006) * 1.5 + 0.006 * exp(-r / 0.7);
	// under the plane: seen through the disc's thin outskirts, in its shadow
	vec4 lo = depthLayer(p, vs, dT, -1.1, 7.0, 0.3, 0.36, 0.55, base);
	Em += lo.rgb * (1.0 - 0.75 * em);
	// over it: two sizes, the small ones higher, a few well off the plane
	vec4 hi = depthLayer(p, vs, dT, 1.0, 6.0, 0.7, 0.32, 1.0, base);
	vec4 hi2 = depthLayer(p, vs, dT, 2.3, 13.0, 1.9, 0.45, 1.05, base);
	float a = clamp(0.55 * hi.a + 0.6 * hi2.a, 0.0, 0.8);
	T *= 1.0 - 0.3 * a;
	Em = Em * (1.0 - 0.3 * a) + hi.rgb + hi2.rgb;
	// a soft halo of stars round the disc, out past its edge
	float hz = smoothstep(1.35, 0.7, r) * (1.0 - em);
	Em += vec3(0.72, 0.78, 1.0) * DEPTH_HALO * hz * (0.6 + 0.6 * smoothstep(0.2, 0.7, kitFbm2(p * 9.0 + 2.3, 2)));
}
