// THE SOLID LOOK, SHARED BY EVERY STYLE THAT DRAWS IT (`ChartSky.solid`, per style in
// `ChartSky.SOLID_STYLES`): the chart seen through a real camera, the gas with a
// body, the edge dissolving into black space, the middle's relief, the nebulae's
// bodies, the near lane across the core, and the envelopes that end the bulge, the
// halo and the disc's dust. Approved in SIMPLIFIED, Oct 12 (Jon: "THIS IS PERFECT").
// This file holds only what is the same in every style: the uniforms `ChartSky`
// pushes, the projection, the height fields and how they are lit. How a style's own
// place pass wires them in (where it reads its disc, where it lights its dust, its
// clouds) stays in that style's place pass; SIMPLIFIED's (`chart_c_place`) is the
// reference: its `galaxy()` and `place()` show every call.
//
// THE INCLUDING SHADER PROVIDES, before including this:
//   * chart_kit.gdshaderinc (kitRot, kitHash3, kitFbm2, kitBayer4,
//     kitViewToPlane, KIT_TILT, KIT_TILT_COS);
//   * uniforms u_k (view px a gu at zoom 1), u_phi (the disc's turn), u_zoom,
//     u_laneStr (how dusty the lanes are, 0 to 1+), and the galaxy's bakes
//     u_struct and u_noise with bakeUV(vec2 plane) -> uv (SIMPLIFIED's bakes:
//     struct R ridge, G lane; noise B billows; `ChartSky`'s bake). A style with
//     bakes of its own maps them to these, or binds SIMPLIFIED's.
// Every function here reads the disc's own plane coordinates (gu) at fixed scales and
// mip levels, so a zoom only magnifies what it draws.

// THE SOLID GALAXY (`ChartSky.solid`, its section below): on, and the camera --
// its distance (gu), the sine and cosine of its elevation, 0
uniform bool u_solid = false;
uniform vec4 u_solidW = vec4(1.9, 0.38, 0.92499, 0.0);
// where the camera looks, on the disc's plane (gu, turned to the view)
uniform vec2 u_solidT = vec2(0.0);
// THE GAS WITH A BODY (`ChartSky.fluff`, its section below): how tall it stands, 0 off
uniform float u_fluff = 0.0;
// and how big its puffs are (1 the medium)
uniform float u_fluffS = 1.0;
// THE DISC'S EDGE DISSOLVES (`ChartSky.edge`, the edge section below): where the
// fade starts (gu), where it ends (gu), how uneven it is (gu either way), on (1) or off
uniform vec4 u_edge = vec4(0.0);
// THE MIDDLE HAS RELIEF (`ChartSky.terrain`, the terrain section below): how much, 0 off
uniform float u_terr = 0.0;
// THE NEBULAE HAVE BODIES (`ChartSky.nebulae`, `nebBody` with the clouds): how much, 0 off
uniform float u_neb = 0.0;

// THE SOLID GALAXY'S PROJECTION (its section, further down, says what it is for):
// the flat view (gu, y already tilted) to the camera's (gu): the point it looks at
// (u_solidT) stays where the flat view has it, and round it the disc's plane is seen
// in perspective from the camera's elevation
vec2 solidFwdN(vec2 o) {
	vec2 d = vec2(o.x, o.y / KIT_TILT) - u_solidT;
	float D = u_solidW.x;
	float s = D / (D - d.y * u_solidW.z);
	return vec2(u_solidT.x, u_solidT.y * KIT_TILT) + vec2(d.x * s, d.y * u_solidW.y * s);
}
// and back: the camera's view of the disc's plane to the flat view
vec2 solidInvN(vec2 p) {
	float D = u_solidW.x;
	vec2 r = p - vec2(u_solidT.x, u_solidT.y * KIT_TILT);
	float dy = r.y * D / (D * u_solidW.y + r.y * u_solidW.z);
	float dx = r.x * (D - dy * u_solidW.z) / D;
	return vec2(u_solidT.x + dx, (u_solidT.y + dy) * KIT_TILT);
}
// the same in view px at zoom 1 (u_k a gu), and nothing at all with it off
vec2 solidV(vec2 o) {
	return u_solid ? solidFwdN(o / u_k) * u_k : o;
}
// how much the camera magnifies the core (1 with it off): the hole and the bulge
// are drawn about it at that one scale, never stretched by the perspective round them
float solidCoreK() {
	return u_solid ? u_solidW.x / (u_solidW.x + u_solidT.y * u_solidW.z) : 1.0;
}
vec2 solidO(vec2 v) {
	return u_solid ? solidInvN(v / u_k) * u_k : v;
}

// ------------------------------------------------------------------ envelopes
// What the solid look ends where the flat chart let it run on, each the same
// arithmetic it was inline in SIMPLIFIED's place pass:
// THE BULGE'S SWELL ENDS (Jon: "The haze on top of the galaxy is kinda crazy"): its
// long tails, under the disc's light in the flat view, stood up past the far side
// of the disc as a dome of haze. What the bulge's light at s (the bulge's own
// radius measure; bs its size) is multiplied by through the camera.
float solidBulgeEnd(float s, float bs) {
	return 1.0 - smoothstep(0.12 * bs, 0.30 * bs, s);
}
// THE HALO ENDS WITH THE DISC (Jon: "The solid (indigo?) haze around the whole galaxy
// sits weird with me"): past the edge's fade the halo was a flat wash of the
// palette's darkest blue. What the halo's light at plane radius r is multiplied by.
float solidHaloEnd(float r) {
	float t = smoothstep(u_edge.x, u_edge.y + 0.04, r);
	return (1.0 - t) * (1.0 - t);
}
// THE DISC'S OWN DUST FADES WITH IT: what the dust under the disc (or any of the
// disc's own layers) at plane radius r is multiplied by past the edge's fade.
float solidDiscFade(float r) {
	float t = smoothstep(u_edge.x, u_edge.y, r);
	return (1.0 - t) * (1.0 - t);
}

// ------------------------------------------------------------------ fluff
// THE GAS WITH A BODY (`ChartSky.fluff`, SIMPLIFIED; Jon:
// "the details still feel flat. I want the galaxy to almost be fluffy"). The disc's
// gas was a painted texture lying on the plane, so even tilted it read as a printed
// plate. Now it is heaped into round puffs where it is dense (`fluffPuff`: the arms
// ridges of billows, the thin parts low haze, the dust lanes the valleys between),
// lit from the core -- the galaxy's own light -- and a little from above: each puff a
// lit side toward the core and a shaded side away, the creases between puffs in shade,
// a faint bright rim where a puff's edge catches the core's light (`fluffShade`); and
// it stands up toward the camera (`fluffSeen`), so a puff slides against the haze
// behind it as the view turns. All in the disc's own units at fixed sizes, so a zoom
// only magnifies the same puffs and shading; the palette steps the shading into its
// own few tones. (A first version stood the density itself up as a height field and
// marched the view ray down through it: each step drew a streak where the field was
// steep, and its broad slopes read as relief, not as cloud.) u_fluff: how strongly lit
// and how tall, 0 off; u_fluffS: how big the puffs. (Declared with the uniforms at the
// top.)
// how much gas stands at plane point p, 0 to 1: the arms and the clumps on them, the
// dust lanes cut out of it (fixed scales: a zoom only magnifies it)
float fluffDens(vec2 p) {
	float r = length(p);
	if (r > 1.1 || r < 0.05) {
		return 0.0;
	}
	vec4 S = textureLod(u_struct, bakeUV(p), 3.0);
	float n = textureLod(u_noise, bakeUV(p), 2.5).r;
	float dens = 0.8 * S.r + 0.55 * smoothstep(0.3, 0.8, n) - 1.1 * S.g * max(u_laneStr, 0.5);
	float env = smoothstep(0.05, 0.14, r) * (1.0 - smoothstep(0.75, 1.1, r));
	return clamp(dens, 0.0, 1.0) * env;
}
// ------------------------------------------------------------------ the edge
// THE DISC'S EDGE DISSOLVES (Jon, of the fluffy galaxy: "the edge of the galaxy is
// kinda weird... it looks like the edge of a plate", then "it could be even softer
// and more diffuse at the edge"). A real galaxy has no edge. Its outer part thins
// gradually: the disc's light and dust fall off over a long stretch, from
// `u_edge.x` gu out to nothing at `u_edge.y`, as a soft haze dissolving into the
// dark (`edgeMask`). The fall-off is a little uneven, broad and low in contrast, so
// the outline is never a perfect ellipse but has no crisp bays or wisps. The outer
// stars are left standing past it. The disc's thickness tapers like a lens
// (`edgeLens`): thick round the core, thinning out along the arms, so the puffs get
// smaller, lower and fainter and are gone well before the rim, leaving only faint
// gas and loose stars in the last stretch. (Two earlier versions: a slab's lit face
// below the rim read as a plate's rim; then a ragged cut-out outline read as torn
// paper rather than haze.) All in the disc's own units at fixed scales, so a zoom
// only magnifies it. The fade is dithered on the palette's anchored Bayer, as the
// billows' edges are, so the palette's dark steps break into a dither instead of
// hard bands. u_edge: where the fade starts, where it ends, how uneven, on.
// the fade's dither cell: the block a point of the flat view falls in, so the dither
// travels with the disc as a drag slides it, rather than staying on the screen while
// the fade slides under it
ivec2 edgeDq(vec2 v) {
	return ivec2(floor(v * u_zoom * 0.5));
}
// how thick the disc stands at plane radius r, 1 at the core to 0 a little past the
// middle of the fade
float edgeLens(float r) {
	if (u_edge.w <= 0.0) {
		return 1.0;
	}
	float t = clamp(1.0 - r / mix(u_edge.x, u_edge.y, 0.45), 0.0, 1.0);
	return t * (2.0 - t);
}
// how much of the disc's own light and dust is left at plane point p: 1 inside the
// fade, 0 past it
float edgeMask(vec2 p) {
	float r = length(p);
	if (u_edge.w <= 0.0 || r < u_edge.x - u_edge.z * 2.0) {
		return 1.0;
	}
	// the fade's radius here pulled in and pushed out a little, broadly
	float un = kitFbm2(p * 1.7 + vec2(4.1, 7.3), 2);
	float rr = r + u_edge.z * un;
	float t = smoothstep(u_edge.x, u_edge.y, rr);
	// (falling off fastest early, then a long faint tail)
	return (1.0 - t) * (1.0 - t);
}

// THE PUFFS: the gas heaped into round billows, as PAINTED heaps its own, but lit
// as light: in cells of the plane, a puff where there is gas enough (more and bigger
// where it is denser), each a squashed dome; at a point, the topmost dome over it.
// (its height gu, then its slope as the dome's normal x, y, z)
vec4 fluffPuff(vec2 p, float cs, int seed) {
	ivec2 c0 = ivec2(floor(p / cs));
	vec4 best = vec4(0.0, 0.0, 0.0, 1.0);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			ivec2 c = c0 + ivec2(i, j);
			vec3 h = kitHash3(c + ivec2(seed * 7919, 4441));
			vec2 ctr = (vec2(c) + 0.2 + 0.6 * h.xy) * cs;
			float dn = fluffDens(ctr);
			// (and the disc thins toward its rim: there they are fewer, smaller and lower)
			float ln = edgeLens(length(ctr));
			// (fewer in the thin gas between the arms: the puffs follow the arms)
			if (h.z > pow(dn, 1.5) * 1.6 * mix(0.1, 1.0, sqrt(ln))) {
				continue;
			}
			float R = cs * (0.45 + 0.5 * dn) * (0.8 + 0.4 * fract(h.z * 17.3)) * mix(0.35, 1.0, sqrt(ln));
			vec2 d = p - ctr;
			float dd = dot(d, d);
			if (dd >= R * R) {
				continue;
			}
			float ht = sqrt(R * R - dd) * 0.55 * (0.5 + dn) * mix(0.2, 1.0, ln);
			if (ht > best.x) {
				best = vec4(ht, normalize(vec3(d * 0.55 * (0.5 + dn), ht)));
			}
		}
	}
	return best;
}
// the topmost puff at p, of the two sizes (the small ones on top of the large)
vec4 fluffTop(vec2 p) {
	vec4 a = fluffPuff(p, 0.032 * u_fluffS, 1);
	vec4 b = fluffPuff(p, 0.016 * u_fluffS, 2);
	b.x *= 0.6;
	return b.x > a.x ? b : a;
}
// where the camera is, for a point of the plane: the way to it along the plane per
// unit of height (camera-turned plane, then into the plane's own frame). The flat view
// is a camera far off at the sector map's tilt; the solid galaxy's is near.
vec2 fluffToward(vec2 p) {
	vec2 q = kitRot(u_phi) * p;
	vec2 d;
	if (u_solid) {
		float D = u_solidW.x;
		vec2 cxy = u_solidT + vec2(0.0, D * u_solidW.z);
		d = (cxy - q) / (D * u_solidW.y);
	} else {
		d = vec2(0.0, KIT_TILT_COS / KIT_TILT);
	}
	return kitRot(-u_phi) * d;
}
// the point of the gas the eye meets looking down at plane point p: moved toward the
// camera by the height of the puff it meets there (twice over), so a tall puff stands
// in front of what is behind it and slides against the low haze as the view turns
vec2 fluffSeen(vec2 p) {
	if (u_fluff <= 0.0) {
		return p;
	}
	vec2 d = fluffToward(p) * u_fluff;
	vec2 q = p + d * fluffTop(p).x;
	return p + d * fluffTop(q).x;
}
// how the gas at plane point p is lit: (what its own light is multiplied by, the rim,
// the puff's own lit body)
vec3 fluffShade(vec2 p) {
	vec4 t = fluffTop(p);
	// (and fading as the disc thins toward its rim: `edgeLens`)
	float cover = smoothstep(0.08, 0.35, fluffDens(p)) * smoothstep(0.0, 0.45, edgeLens(length(p)));
	float r = max(length(p), 1e-4);
	vec2 toC = -p / r;
	vec3 L = normalize(vec3(toC, 0.55));
	if (t.x <= 0.0) {
		// the creases between puffs, where there is gas: in their shadow
		return vec3(mix(1.0, 0.5, cover * min(u_fluff, 1.0)), 0.0, 0.0);
	}
	vec3 N = t.yzw;
	float lit = max(dot(N, L), 0.0);
	float shade = 0.4 + 1.05 * lit + 0.15 * N.z;
	// a puff's edge toward the core catching its light
	float edge = 1.0 - N.z;
	float rim = smoothstep(0.55, 0.9, edge) * max(dot(normalize(N.xy + 1e-6), toC), 0.0);
	// the puff's body: gas lit where it faces the core, so a puff is a dome of light
	float body = cover * (0.12 + 0.9 * lit) * smoothstep(0.0, 0.25, N.z);
	return vec3(mix(1.0, shade, cover * min(u_fluff, 1.0)), rim * cover, body);
}

// ------------------------------------------------------------------ terrain
// THE MIDDLE HAS RELIEF (`ChartSky.terrain`; Jon: "what about the clouds in the
// middle of the galaxy? I want almost like hills and valleys of dust ... a body to
// the galaxy both in the horizontal sense and vertically"). The arms' gas has its
// puffs (`fluffPuff`); the inner disc round the bulge was still a flat painted plate.
// Here its gas is a height field (`terrH`): broad hills of dust with smaller billows
// on them, following the gas's own structure, so the arm ridges are ridges and the
// dark lanes the valleys. It is lit like terrain, from the core and low: faces
// toward the core lit warm, backs in shade, valley floors occluded, and each ridge
// casting its shadow outward into the valley behind it (`terrShade`: a few steps
// from each point toward the core over the field). It stands up toward the camera
// (`terrSeen`), so hills slide against valleys as the view turns, and near the core
// the ridges on the near side stand in silhouette against the gold bulge, dark dust
// with a lit rim, hiding its lower edge (`terrSilh`). All in the disc's own units at
// fixed scales and read at fixed mip levels, so a zoom only magnifies it, and the
// light comes from the core, so the shadows turn with the disc and never crawl.
// u_terr: how much relief (0 off). Never over the hole's own disc or through its
// lens (`place` fades it out across the lens's patch).
const float TERR_H = 0.010;           // the tallest hill at u_terr 1, gu
const float TERR_R0 = 0.035;          // the relief starts this far out from the core
const float TERR_R1 = 0.50;           // and is gone by here (the arms have their puffs)
const float TERR_PX = 0.4;            // how far the view's slide goes, of the whole way
// the height of the dust at plane point p, gu, its mip levels lifted by `lo` (a
// blur, for the valley floors' occlusion)
float terrH(vec2 p, float lo) {
	float r = length(p);
	if (r > TERR_R1 || r < TERR_R0 * 0.5) {
		return 0.0;
	}
	vec4 S = textureLod(u_struct, bakeUV(p), 3.5 + lo);
	// broad hills (the billow field read coarse at a place of its own), and smaller
	// ridges on them (the same field finer, folded into crests)
	float b1 = textureLod(u_noise, bakeUV(p * 0.7 + vec2(0.31, 0.12)), 1.5 + lo).b;
	float b2 = textureLod(u_noise, bakeUV(p * 1.6 + vec2(-0.21, 0.37)), 1.75 + lo).b;
	float hills = smoothstep(0.30, 0.70, b1);
	float c2 = 2.0 * smoothstep(0.25, 0.75, b2) - 1.0;
	float crest = 1.0 - c2 * c2;
	float h = 0.65 * hills + 0.35 * crest * (0.4 + 0.6 * hills) + 0.30 * S.r
		- 1.0 * S.g * max(u_laneStr, 0.6);
	float env = smoothstep(TERR_R0, TERR_R0 * 2.2, r) * (1.0 - smoothstep(TERR_R1 * 0.55, TERR_R1, r));
	return clamp(h, 0.0, 1.2) * env * TERR_H * u_terr;
}
// the point of the dust the eye meets looking down at plane point p: moved toward the
// camera by the height it meets there (twice over), as `fluffSeen`
vec2 terrSeen(vec2 p) {
	if (u_terr <= 0.0 || length(p) > TERR_R1) {
		return p;
	}
	// (read from the field blurred, and moved a share of the way: moved the whole way
	// by the sharp field, neighbouring blocks folded onto scattered points and the
	// dust broke into a grain)
	vec2 d = fluffToward(p) * TERR_PX;
	vec2 q = p + d * terrH(p, 1.5);
	return p + d * terrH(q, 1.5);
}
// how the dust at plane point p is lit: (what its light is multiplied by, the warm
// light on faces toward the core, how much it is a hill: 0 to 1)
vec3 terrShade(vec2 p) {
	float r = length(p);
	if (u_terr <= 0.0 || r > TERR_R1 || r < TERR_R0 * 0.5) {
		return vec3(1.0, 0.0, 0.0);
	}
	float Hm = TERR_H * u_terr;
	float h0 = terrH(p, 0.0);
	const float TE = 0.006;
	float hx = terrH(p + vec2(TE, 0.0), 0.0) - h0;
	float hy = terrH(p + vec2(0.0, TE), 0.0) - h0;
	// (the slopes drawn out, so the hills read as hills at any relief)
	vec3 N = normalize(vec3(-hx, -hy, TE * 0.5));
	vec2 toC = -p / r;
	// the core's light, low over the disc
	const float TAN_L = 0.30;
	vec3 L = normalize(vec3(toC, TAN_L));
	float lit = max(dot(N, L), 0.0);
	// the ridges between it and the core: a few steps toward the core over the field
	// (over the field a little blurred: the finest crests cast only a grain)
	float sh = 0.0;
	float hs0 = terrH(p, 0.75);
	for (int i = 1; i <= 6; i++) {
		float t = float(i) * 0.010;
		if (t > r - TERR_R0 * 0.5) {
			break;
		}
		float hs = terrH(p + toC * t, 0.75);
		sh = max(sh, (hs - hs0 - t * TAN_L * 0.35) / (Hm * 0.35));
	}
	sh = clamp(sh, 0.0, 1.0);
	// the valley floors, lower than the land round them
	float hb = terrH(p, 2.0);
	float ao = clamp(1.0 - 1.6 * max(hb - h0, 0.0) / max(Hm * 0.5, 1e-6), 0.4, 1.0);
	float relief = smoothstep(0.0, Hm * 0.25, max(h0, hb));
	float shade = (0.5 + 0.8 * lit) * (1.0 - 0.55 * sh) * ao;
	float warm = lit * (1.0 - sh) * smoothstep(0.0, 0.5, h0 / Hm);
	return vec3(mix(1.0, shade, relief), warm * relief, relief);
}
// how much a near ridge at plane point p stands in front of the bulge behind it: 0 to
// 1 (near side only, round the bulge)
float terrSilh(vec2 p) {
	if (u_terr <= 0.0) {
		return 0.0;
	}
	float r = length(p);
	vec2 q = kitRot(u_phi) * p;
	float near = smoothstep(0.0, 0.03, q.y) * (1.0 - smoothstep(0.10, 0.22, r));
	return near * smoothstep(0.30, 0.85, terrH(p, 0.0) / (TERR_H * u_terr));
}

// THE NEBULAE HAVE BODIES (`ChartSky.nebulae`, solid view only; Jon: "the nebula
// can also have some texture too. Like the supernova remnants would have height at
// the edges and be more flat towards the emptier center"). Each kind in the same
// height-field language as the middle's dust, lit from the galaxy's core:
//   * the shells (remnants, the ring nebulae): a wall piled up at the rim like a
//     crater's or a blown bubble's, its face toward the core lit and its back in
//     shade, the floor inside low and emptier and in the wall's shadow on the
//     core's side (`nebShell`);
//   * emission nebulae and the pink knots: puffs standing off the disc, lit tops
//     toward the core, shaded undersides (`nebPuff`);
//   * dark nebulae: dense mounds, their rim toward the core lit brighter, each
//     casting its own shadow outward.
// Their colours and shapes are their own; the light only shades them. Fixed in
// each cloud's own units, so a zoom only magnifies it. u_neb: how much, 0 off.
// a shell's light at a point (its direction from the centre, its distance from the
// wall in radii, the direction toward the core): (on the wall, on the floor inside)
vec2 nebShell(vec2 dir, float xr, vec2 toC) {
	if (u_neb <= 0.0) {
		return vec2(1.0);
	}
	// the wall: a ridge round the rim, its slope outward outside, inward inside
	float h = exp(-xr * xr / 0.02);
	vec3 N = normalize(vec3(dir * (xr / 0.02) * h * 0.35, 1.0));
	float lit = max(dot(N, normalize(vec3(toC, 0.5))), 0.0);
	float wall = 0.3 + 1.3 * lit;
	// the floor: emptier toward the middle, and shaded under the wall on the core's side
	float sh = clamp(dot(dir, toC), 0.0, 1.0) * smoothstep(-0.7, -0.15, xr) * (1.0 - smoothstep(-0.12, -0.02, xr));
	float flo = (1.0 - 0.7 * sh) * mix(0.45, 1.0, smoothstep(-0.8, -0.2, xr));
	return mix(vec2(1.0), vec2(wall, flo), u_neb);
}
// a puff's light at cloud point u (cloud radius R, seed, toward the core): what the
// cloud's light is multiplied by
float nebPuff(vec2 u, float R, float seed, vec2 toC) {
	if (u_neb <= 0.0) {
		return 1.0;
	}
	vec2 q = u / R * 2.6 + seed * 1.7;
	const float e = 0.08;
	float h = kitFbm2(q, 3);
	float hx = kitFbm2(q + vec2(e, 0.0), 3) - h;
	float hy = kitFbm2(q + vec2(0.0, e), 3) - h;
	vec3 N = normalize(vec3(-hx, -hy, e * 0.45));
	float lit = max(dot(N, normalize(vec3(toC, 0.55))), 0.0);
	return mix(1.0, 0.4 + 1.15 * lit, u_neb);
}

// ------------------------------------------------------------------ the solid galaxy
// THE SOLID GALAXY (`ChartSky.solid`, SIMPLIFIED): the chart seen through a real
// camera instead of laid flat like a tilted poster. The galaxy is painted as before
// in its flat ("orthographic") view, o, and each block of the screen looks it up
// through the camera: a camera `u_solidW.x` gu away at the sector map's tilt,
// looking down at `u_solidT` (the core) on the disc's plane, so the near half of the
// disc is nearer and bigger and the far half smaller and squashed. The camera never
// moves: a drag slides the picture and a zoom only magnifies it. One projection for
// the sky and for everything the chart draws over it (`ChartSky.solid_fwd` /
// `solid_inv` and `StarchartScreen`'s `_proj` / `_to_plane`). u_solidW: camera distance (gu), sin and cos of its elevation, 0 (the
// uniforms are at the top: the bulge reads them).
// (its projection, solidFwdN, solidInvN, solidV and solidO, is with the view's
// functions at the top: the supernova and the stars read it)
// THE NEAR SIDE'S DUST LANE ACROSS THE CORE: the disc passes in front of the bottom
// of the bulge, so a dark lane of its dust cuts across the core below the hole --
// a band of the disc's plane about 0.15 to 0.19 gu out on its near half, broken by the
// gas, read where the lane itself is (never through the hole's lens, so it never
// bends round the hole or crosses its disc). What it lets through.
vec3 solidLane(vec2 o) {
	vec2 p = kitViewToPlane(o, u_phi, u_k);
	float r = length(p);
	vec2 q = kitRot(u_phi) * p;
	if (r < 0.11 || r > 0.26 || q.y <= 0.0) {
		return vec3(1.0);
	}
	float band = exp(-pow((r - 0.17) / 0.03, 2.0)) * smoothstep(0.0, 0.06, q.y);
	float n = 0.5 + 0.5 * kitFbm2(p * 38.0 + vec2(3.7, 1.1), 3);
	// (at the least as dusty as a lane-rich spiral's: a galaxy without lanes of its
	// own still has the near disc in front of its bulge)
	float tau = 3.2 * band * (0.4 + 1.0 * n) * max(u_laneStr, 0.8);
	return exp(-tau * vec3(0.62, 0.80, 1.0));
}
