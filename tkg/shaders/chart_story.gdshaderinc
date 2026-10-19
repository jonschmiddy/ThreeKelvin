// A BALL'S STORY, SHARED BY EVERY STYLE (`ChartSky.ball_story`; Jon, Oct 19, of a round
// elliptical beside a multi-arm spiral: "so boring ... almost like the angle is
// different AND the level of detail in the clouds are different"). A ball's light is a
// smooth glow; a spiral has arms, dust and an angle. Three looks to compare, behind
// `-- balllook2=0|A|B|C` (0 today):
//   A  its victims round it: two or three small galaxies near it (a small spiral, a
//      dwarf) lying on the chart's tilted plane, one of them being torn into a curved
//      tidal stream of stars wrapping part way round the ball; shell arcs on its far
//      side; stray streams of stars through its halo ("its halo is full of stars taken
//      from them");
//   B  a busy core: a relativistic jet both ways out of the hole, thin and knotted,
//      leaning off the disc's normal and foreshortened by the chart's tilt; a hot ring
//      of gas round the hole lying in the plane, tilted as the spirals' discs are (the
//      angle a ball lacks); a swarm of bright globular clusters with a slow, slight
//      sparkle;
//   C  both.
// Every layer is LIGHT, added in the style's own light before its palette, so each
// style steps it in its own colours and patterns. Everything is drawn about the core
// in the core's own frame (`g`, gu, the flat chart's: y down the screen, the plane
// squashed by KIT_TILT), so it sits where the ball does in every style. Fixed sizes in
// gu (a zoom only magnifies), nothing finer than a block (`blk`, gu), and the
// clusters' sparkle slow.
//
// THE INCLUDING SHADER PROVIDES chart_kit.gdshaderinc (kitRot, kitHash3, kitHash1,
// kitSnoise2, kitFbm2, KIT_TILT) before this.

// the look (0 today, 1 A, 2 B, 3 C), a seed 0..1, the jet's turn in the plane and its
// lean off the plane's normal (rad)
uniform vec4 u_story = vec4(0.0);
// the companions: their place on the plane (gu, as the screen holds it), radius (gu),
// kind (0 none, 1 a small spiral, 2 a dwarf)
uniform vec4 u_storyC[3];
// and their turn (rad), how tight their arms wind, torn (0/1), brightness
uniform vec4 u_storyD[3];
// the ball: re (gu), roundness on the screen, how bright the ball's own light is here
// (each style's own scale), and 1 for a dwarf (a small thing is a victim, not a
// predator: no stream, shells, jet or ring of its own, and a thin swarm)
uniform vec4 u_storyK = vec4(0.3, 0.74, 1.0, 0.0);

const vec3 STORY_STAR = vec3(1.0, 0.86, 0.66);
const vec3 STORY_YOUNG = vec3(0.55, 0.72, 1.0);
const vec3 STORY_JET = vec3(0.72, 0.86, 1.0);
const vec3 STORY_GAS = vec3(1.0, 0.56, 0.26);
const float STORY_COS_E = 0.92499;     // a height off the plane, up the flat chart

float storyLook() { return u_story.x; }
bool storyA() { int l = int(u_story.x + 0.5); return l == 1 || l == 3; }
bool storyB() { return int(u_story.x + 0.5) >= 2; }

// a point of the flat chart about the core (gu) to the disc's plane (gu)
vec2 storyPlane(vec2 g, float phi) {
	return kitRot(-phi) * vec2(g.x, g.y / KIT_TILT);
}
// and back: a point on the plane, with a height above it, to the flat chart
vec2 storyView(vec3 p, float phi) {
	vec2 q = kitRot(phi) * p.xy;
	return vec2(q.x, q.y * KIT_TILT - p.z * STORY_COS_E);
}

// stars too faint to see one by one but grainy: a grain a block or two across
float storyGrain(vec2 p, float blk) {
	vec2 c = floor(p / max(blk * 1.5, 0.004));
	return 0.55 + 0.9 * kitHash1(ivec2(c) + ivec2(int(u_story.y * 911.0), 37));
}

// ------------------------------------------------------------------ A: its victims
vec3 storyCompanions(vec2 pl, float blk, out float warmL, out float coolL) {
	vec3 C = vec3(0.0);
	warmL = 0.0;
	coolL = 0.0;
	for (int i = 0; i < 3; i++) {
		vec4 c = u_storyC[i];
		int kind = int(c.w + 0.5);
		if (kind == 0) {
			continue;
		}
		vec4 e = u_storyD[i];
		vec2 d = kitRot(-e.x) * (pl - c.xy);
		// (the one being torn: drawn out along its orbit, its middle loosened)
		if (e.z > 0.5) {
			d.x *= 0.62;
		}
		float r = length(d) / c.z;
		if (r > 3.0) {
			continue;
		}
		float w = 0.0;
		vec3 col = STORY_STAR;
		if (kind == 1) {
			// a small spiral: a warm knot of a bulge, two blue arms wound round it
			float th = atan(d.y, d.x);
			float arm = 0.5 + 0.5 * cos(2.0 * (th - e.y * log(max(r, 0.05))));
			float disc = exp(-r * 2.6) * (0.35 + 0.9 * arm * arm);
			float bul = exp(-r * r / 0.05);
			w = disc + 1.4 * bul;
			col = (STORY_YOUNG * disc + STORY_STAR * 1.4 * bul) / max(w, 1e-4);
			coolL += disc * e.w;
			warmL += 1.4 * bul * e.w;
		} else {
			// a dwarf: a soft round knot of old stars
			w = exp(-r * r * 1.6) * 1.1;
			warmL += w * e.w;
		}
		C += col * w * e.w;
	}
	return C;
}

// the torn one's stream: a curved arc of stars sweeping on round the ball from where
// it is, sinking inward as it goes, thinning out along its length
vec3 storyStream(vec2 pl, float blk) {
	vec3 C = vec3(0.0);
	for (int i = 0; i < 3; i++) {
		if (u_storyD[i].z < 0.5 || int(u_storyC[i].w + 0.5) == 0) {
			continue;
		}
		vec2 c = u_storyC[i].xy;
		float rc = length(c);
		float thc = atan(c.y, c.x);
		float rp = length(pl);
		float th = atan(pl.y, pl.x);
		// the leading arm round ahead (2.4 rad), a short trailing one behind (0.7 rad)
		for (int s = 0; s < 2; s++) {
			float dir = s == 0 ? 1.0 : -1.0;
			float span = s == 0 ? 2.4 : 0.7;
			float u = mod(dir * (th - thc) + 6.2832, 6.2832);
			if (u > span) {
				continue;
			}
			float f = u / span;
			float rs = rc * (1.0 - (s == 0 ? 0.12 : -0.08) * f) + 0.025 * kitSnoise2(vec2(u * 3.0, float(i) + 4.0));
			float wd = 0.022 + 0.03 * f;
			float a = exp(-pow((rp - rs) / wd, 2.0)) * pow(1.0 - f, 0.8) * (s == 0 ? 1.0 : 0.6);
			C += STORY_STAR * a * 0.55 * storyGrain(pl, blk) * u_storyD[i].w;
		}
	}
	return C;
}

// shells of swallowed galaxies on the far side (up the screen): sharp outer edges,
// a soft inside, each arc on its own bearing; and the halo's stray streams
vec3 storyShells(vec2 g, float blk) {
	float re = u_storyK.x;
	vec2 e = vec2(g.x, g.y / u_storyK.y);
	float s = length(e);
	float an = atan(e.y, e.x);
	float sh = 0.0;
	for (int k = 0; k < 3; k++) {
		float rk = (1.35 + 0.45 * float(k)) * re;
		// (the far side: up the screen, an arc a third of the way round)
		float side = pow(max(0.0, 0.5 + 0.5 * cos(an + 1.5708 + 0.5 * (float(k) - 1.0) + 0.6 * (u_story.y - 0.5))), 4.0);
		float dk = s - rk;
		sh += (dk < 0.0 ? exp(dk / (0.20 * re)) : exp(-pow(dk / (0.03 * re), 2.0))) * side * (1.0 - 0.18 * float(k));
	}
	vec3 C = STORY_STAR * sh * 0.04;
	// two stray streams through the halo, curving ROUND the ball as the tidal stream does
	// (arcs about the core on the plane, each a stretch of an orbit, broad and faint):
	// first drawn as arcs of circles off to one side, near the ball they ran straight
	// out from it and read as spokes
	vec2 pv = vec2(g.x, g.y / KIT_TILT);
	float rp = length(pv);
	float thp = atan(pv.y, pv.x);
	for (int k = 0; k < 2; k++) {
		float rk = re * (2.3 + 0.9 * float(k)) / KIT_TILT * 0.45;
		float a0 = 6.2832 * u_story.y + 2.6 * float(k) + 1.0;
		float u = mod(thp - a0 + 6.2832, 6.2832);
		float span = 2.0;
		if (u > span) {
			continue;
		}
		float f = u / span;
		float rs = rk * (1.0 + 0.10 * f) + 0.03 * kitSnoise2(vec2(u * 2.0, float(k) + 9.0));
		float w = 0.05 + 0.04 * sin(f * 3.1416);
		float along = sin(f * 3.1416);
		float brk = smoothstep(-0.6, 0.2, kitSnoise2(pv * 2.5 + vec2(float(k) * 5.1, 1.3)));
		C += STORY_STAR * exp(-pow((rp - rs) / w, 2.0)) * along * brk * 0.010 * storyGrain(g, blk);
	}
	return C;
}

// ------------------------------------------------------------------ B: a busy core
// the jet both ways out of the hole: thin, knotted, leaning off the disc's normal and
// foreshortened by the chart's tilt; the far one fainter
vec3 storyJet(vec2 g, float phi, float blk) {
	float a = u_story.z, l = u_story.w;
	vec3 dir = vec3(cos(a) * sin(l), sin(a) * sin(l), cos(l));
	vec2 J = storyView(dir, phi);
	float Lj = 0.62 * u_storyK.x / 0.4;
	vec3 C = vec3(0.0);
	for (int s = 0; s < 2; s++) {
		vec2 Js = s == 0 ? J : -J;
		float len = length(Js) * Lj;
		vec2 Jn = Js / max(length(Js), 1e-4);
		float along = dot(g, Jn);
		if (along < 0.0 || along > len * 1.15) {
			continue;
		}
		float perp = length(g - Jn * along);
		float f = along / len;
		float wd = max(0.003 + 0.010 * f, 0.55 * blk);
		float beam = exp(-pow(perp / wd, 2.0));
		float knots = 0.45 + 0.9 * pow(0.5 + 0.5 * sin(along / max(len, 1e-3) * 26.0 + 6.2832 * u_story.y), 5.0);
		float fade = smoothstep(0.03, 0.08, along) * (1.0 - smoothstep(0.85, 1.15, f));
		// its end: a soft lobe where it runs into the halo
		float lobe = exp(-pow(length(g - Jn * len) / (0.06 * Lj + 2.0 * blk), 2.0)) * 0.25;
		C += STORY_JET * (beam * knots * fade + lobe) * (s == 0 ? 0.42 : 0.17);
	}
	return C;
}

// the hot gas round the hole, lying in the plane: a lumpy ring, seen at the chart's tilt
vec3 storyRing(vec2 g, float phi) {
	vec2 pl = storyPlane(g, phi);
	float r = length(pl);
	float rr = 0.13 * u_storyK.x / 0.4;
	float ring = exp(-pow((r - rr) / (0.26 * rr), 2.0));
	float lump = 0.55 + 0.9 * smoothstep(-0.3, 0.6, kitSnoise2(vec2(atan(pl.y, pl.x) * 2.2, r * 40.0) + 7.0 * u_story.y));
	// (its near half, low on the screen, a touch brighter: the side toward us)
	float near = 0.8 + 0.4 * smoothstep(-0.02, 0.02, g.y);
	return STORY_GAS * ring * lump * near * 0.5;
}

// the globular swarm: many bright old clusters round the ball, each at least a block,
// with a slow slight sparkle
vec3 storySwarm(vec2 g, float blk, float t) {
	float Rs = 2.2 * u_storyK.x;
	const float CELL = 0.035;
	ivec2 c0 = ivec2(floor(g / CELL));
	int salt = int(u_story.y * 997.0) + 53;
	float rC = max(0.0035, 0.6 * blk);
	float rF = max(0.009, 1.4 * blk);
	vec3 acc = vec3(0.0);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			ivec2 cc = c0 + ivec2(i, j);
			vec3 h = kitHash3(cc + ivec2(salt * 29 + 101, salt * 5 - 77));
			vec2 ctr = (vec2(cc) + 0.15 + 0.7 * h.xy) * CELL;
			float rc = length(vec2(ctr.x, ctr.y / u_storyK.y)) / Rs;
			float prob = 0.16 * exp(-rc * 1.6) * smoothstep(0.12, 0.3, rc) * (1.0 - smoothstep(1.3, 1.8, rc));
			if (h.z > prob) {
				continue;
			}
			float hb = kitHash1(cc + ivec2(salt * 11 + 3, 517));
			float d = length(g - ctr);
			float sp = 0.88 + 0.12 * sin(t * 0.7 + 6.2832 * hb);
			acc += STORY_STAR * (0.5 + 0.7 * hb * hb) * sp * (0.34 * exp(-pow(d / rC, 2.0)) + 0.03 * exp(-pow(d / rF, 2.0)));
		}
	}
	return acc;
}

// ------------------------------------------------------------------ all of it
// `g`: the point about the core (gu, the flat chart's frame); `phi`: the disc's turn;
// `t`: the sky's clock; `blk`: a block, gu. Light in the style's own units times
// u_storyK.z; `warmL` and `coolL` the same split for a style that bands warm and cool
// light apart (PAINTED).
vec3 storyLight(vec2 g, float phi, float t, float blk, out float warmL, out float coolL) {
	warmL = 0.0;
	coolL = 0.0;
	if (u_story.x < 0.5) {
		return vec3(0.0);
	}
	vec3 C = vec3(0.0);
	// (the victims and their stream on the plane as the screen holds it, not turned with
	// the disc: they lie out past the systems' rim, above and below the ball, and stay on
	// the chart however the galaxy has turned)
	vec2 pl = vec2(g.x, g.y / KIT_TILT);
	if (storyA()) {
		float wc, cc;
		C += storyCompanions(pl, blk, wc, cc);
		warmL += wc;
		coolL += cc;
		if (u_storyK.w < 0.5) {
			vec3 st = storyStream(pl, blk) + storyShells(g, blk);
			C += st;
			warmL += dot(st, vec3(0.3333));
		}
	}
	if (storyB()) {
		bool dw = u_storyK.w > 0.5;
		vec3 jt = dw ? vec3(0.0) : storyJet(g, phi, blk);
		vec3 rg = dw ? vec3(0.0) : storyRing(g, phi);
		vec3 sw = storySwarm(g, blk, t) * (dw ? 0.45 : 1.0);
		C += jt + rg + sw;
		coolL += dot(jt, vec3(0.3333));
		warmL += dot(rg + sw, vec3(0.3333));
	}
	warmL *= u_storyK.z;
	coolL *= u_storyK.z;
	return C * u_storyK.z;
}
