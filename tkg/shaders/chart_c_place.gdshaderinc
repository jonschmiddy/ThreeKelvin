// THE SIMPLIFIED STAR CHART, the place pass: one fragment per 2x2 block, linear HDR
// out (`ChartSky`). Direction C, "Alive", from the Oct 5 showcase
// (`showcase/C/chart/place.glsl`), Jon's pick for the SIMPLIFIED style (once named LEGACY): today's
// layered look refined and set in slow motion.
// Back to front: sky -> stellar halo -> dust sheet under the disc (h -0.03) ->
// bulge, far share -> the disc (h 0: old stars, star clouds on the arm ridges,
// star-forming fronts, knots, the data's stars, lanes and spurs, all streaming
// along the arms) -> named clouds -> bulge, near share -> billows (a soft height
// field marched along the view ray, lit from the core) -> wisps (h 0.085) ->
// events. The hole (`legacy_hole.gdshaderinc`) is drawn over a lensed copy of
// everything behind it.
// Every galaxy kind: a spiral disc (`u_form` 0), a ball (1: the ellipticals,
// the dwarfs, the merger) and an armless disc (2: the lenticulars); a tidal
// stream for the kinds that have one.
// LOW (GRAPHICS LOW): no billow march (one lifted sheet), no wisps or
// under-sheet, one flow phase, no fine detail octaves.
// Units are the showcase's: view px at zoom 1 with u_k = 622.25 px a galaxy
// unit; `ChartSky` hands over an effective zoom so a chart of any size draws
// the same picture at the same scale on screen.

#include "res://shaders/chart_kit.gdshaderinc"
#include "res://shaders/chart_resolve.gdshaderinc"
#include "res://shaders/legacy_hole.gdshaderinc"
#include "res://shaders/chart_bg.gdshaderinc"

uniform sampler2D u_noise : filter_linear_mipmap, repeat_disable;
uniform sampler2D u_struct : filter_linear_mipmap, repeat_disable;
uniform sampler2D u_stars : filter_nearest, repeat_disable;
uniform bool u_stars_on = true;
uniform vec2 u_vp_size = vec2(330.0, 220.0);   // this viewport, in blocks
uniform vec2 u_vp_origin = vec2(-2.0);         // chart px of block (0, 0)'s corner
uniform vec2 u_cpix = vec2(327.0, 214.0);      // the galaxy's centre, chart px
uniform vec2 u_res = vec2(655.0, 429.0);       // the chart; its middle is the frame centre
uniform vec2 u_block0 = vec2(0.0);             // the dither's anchor: this viewport's first block, counted from it
uniform float u_zoom = 0.42;
// (tuning, `ChartSky.diag`: 1 no glare control, 2 no stars, 4 no added detail)
uniform int u_diag = 0;
float zDet() { return (u_diag & 4) != 0 ? min(u_zoom, 1.0) : u_zoom; }
float glareOn() { return (u_diag & 1) != 0 ? 0.0 : 1.0; }
uniform float u_k = 622.25;
uniform float u_time = 0.0;
uniform float u_phi = 0.0;
uniform float u_ext = 1.2;
uniform vec2 u_lod = vec2(0.0);                // mip level of the noise / structure bakes
uniform int u_form = 0;                        // 0 spiral disc, 1 ball, 2 armless disc
uniform vec4 u_ball = vec4(0.30, 0.74, 0.085, 0.0);   // re (gu), roundness on screen, centre light, look (0 old, 1 blue compact, 2 faint dwarf, 3 merger)
uniform float u_bulgeR = 0.128;
uniform float u_holeR = 0.0186;
uniform float u_gasAmt = 1.0;
uniform float u_laneStr = 1.0;
uniform float u_armGain = 1.0;
uniform float u_young = 1.0;                   // how much of the disc is young and blue (gas-poor discs are old and warm)
uniform float u_tail = 0.0;                    // a tidal stream
uniform vec4 u_armModel = vec4(2.0, 8.0, 0.0, 0.0);   // arms, twist, spin, bar
uniform vec3 u_bCore = vec3(1.0, 0.6, 0.26);
uniform float u_drift = 1.0;                   // 1, or 0.5 under reduced motion
uniform float u_wxOn = 1.0;                    // events allowed (0 under reduced motion)
uniform float u_exp = 1.2;                     // the composite's exposure
uniform float u_burn = 2.5;
uniform bool u_tone_out = false;               // a palette probe: write the toned sRGB
uniform int u_ncl = 0;
uniform vec4 u_cl[12];      // view centre x, y (zoom-1 view px), R (gu), reach (gu)
uniform vec4 u_clk[12];     // kind (0 emission 1 reflection 2 remnant 3 planetary 4 dark), hollow, shape, seed
uniform vec4 u_lobe[36];    // round-frame offset x, y (gu), lobe radius (gu), 0; three per cloud, biggest first
uniform vec4 u_clp[12];     // plane centre x, y (gu), R (gu), 1 if it displaces the billows
uniform vec4 u_cdir[12];    // round-frame unit vector toward the galaxy centre
uniform vec4 u_lt[12];      // lightning per cloud: envelope, round-frame x, y (gu), radius (gu)
uniform int u_nkn = 0;
uniform vec4 u_kn[64];      // knots: plane x, y (gu), size (gu), amplitude
uniform vec4 u_sn = vec4(0.0);     // supernova: view x, y, flare gain (0 = none), age
uniform vec4 u_echo = vec4(0.0);   // light echo: plane x, y, ring radius (gu), strength
// what the last minutes' supernovae left (`ChartSky.remnants`: plane x, y, age s,
// seed); none in the palette's probes
uniform int u_nrem = 0;
uniform vec4 u_rem[16];
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

const vec3 HA = vec3(1.0, 0.2, 0.3);
const vec3 OIII = vec3(0.2, 0.95, 0.85);
const vec3 REFL = vec3(0.32, 0.52, 1.0);
const vec3 LITDUST = vec3(1.0, 0.62, 0.42);
const vec3 LIGHTNING = vec3(0.69, 0.63, 1.0);
const vec3 FLARE = vec3(1.0, 0.79, 0.43);
const vec3 VOIDC = vec3(0.0021, 0.0030, 0.0060);
const float SAT = 1.5;
const vec4 NMID = vec4(0.5, 0.33, 0.5, 0.5);

vec3 warmsoft(vec3 c) {
	float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
	return vec3(l) + (c - vec3(l)) * (1.25 / SAT);
}

// ------------------------------------------------------------------ the view
// the view px at the frame's centre (the showcase's snapped pan)
vec2 gpan() { return (u_res * 0.5 - u_cpix) / u_zoom; }
vec2 scr(vec2 v) { return u_cpix + v * u_zoom; }
ivec2 blockOf(vec2 s) { return ivec2(floor((s - u_vp_origin) * 0.5)); }

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

float octFor(float F) {
#if LOW
	return clamp(log2(zDet() * u_k / (4.0 * F)), 1.0, 3.0);
#else
	return clamp(log2(zDet() * u_k / (4.0 * F)), 1.0, 6.0);
#endif
}
float wrapA(float a) { return mod(a + KIT_PI, KIT_TAU) - KIT_PI; }

// The plane point seen through view point v on a sheet at height h (gu). Weak
// perspective: the sheet scales by 1 + 0.35 h 0.925 zoom about the frame centre
// (and pans that much faster), so upper sheets slide past you as you zoom in.
vec2 sheetP(vec2 v, float h) {
	vec2 gp = gpan();
	float s = 1.0 + 0.35 * h * KIT_TILT_COS * u_zoom;
	vec2 vh = (v - gp) / s + gp;
	vh.y += h * KIT_TILT_COS * u_k;
	return kitViewToPlane(vh, u_phi, u_k);
}

// ------------------------------------------------------------------ bakes
vec2 bakeUV(vec2 p) { return (p + u_ext) / (2.0 * u_ext); }
vec4 structAtL(vec2 p, float la) {
	if (max(abs(p.x), abs(p.y)) > u_ext * 0.97) {
		return vec4(0.0);
	}
	return textureLod(u_struct, bakeUV(p), u_lod.y + la);
}
vec4 structAt(vec2 p) {
	// past the bake there is no structure (a clamped read would smear its edge)
	if (max(abs(p.x), abs(p.y)) > u_ext * 0.97) {
		return vec4(0.0);
	}
	return textureLod(u_struct, bakeUV(p), u_lod.y);
}
vec4 noiseRaw(vec2 p) { return textureLod(u_noise, bakeUV(p), u_lod.x); }
vec4 noiseRawLA(vec2 p, float la) { return textureLod(u_noise, bakeUV(p), u_lod.x + la); }
vec4 noiseRawL(vec2 p, float lod) { return textureLod(u_noise, bakeUV(p), lod); }

// Currents: the gas turns at a flat rotation curve's rate less the arms' pattern
// speed (corotation at 0.55 gu), so it streams THROUGH the arms while they stay.
float flowOm(float r) {
	const float v0 = 0.0021;
	return -(v0 / max(r, 0.06) - v0 / 0.55);
}
vec4 flowNoise(vec2 p, float la, out vec2 pa, out vec2 pb, out float w) {
	float om = flowOm(length(p));
	float tt = u_time * u_drift + 20.0 * kitVnoise2(p * 2.5 + 3.3);   // phase resets scattered in space
	vec3 fp = kitFlowPhase(tt, 20.0);
	pa = kitRot(om * fp.x * 20.0) * p;
	pb = kitRot(2.1 + om * fp.y * 20.0) * p;
#if LOW
	w = 0.0;
	return noiseRawLA(pa, la);
#else
	w = fp.z;
	vec4 a = noiseRawLA(pa, la), b = noiseRawLA(pb, la);
	float nrm = inversesqrt((1.0 - w) * (1.0 - w) + w * w);
	return clamp(NMID + ((a - NMID) * (1.0 - w) + (b - NMID) * w) * nrm, 0.0, 1.0);
#endif
}
// fine detail past the bake's resolution, fading in with zoom, streamed the same
// way: from four of the noise bake's texels down (where its own detail runs
// out, about zoom 1.7) to five blocks, octaves that only add (`crDetail`), so the
// arms' gas keeps resolving into finer clumps and filaments as you zoom instead
// of a magnified bake the palette cut into flat plates. `pxGu`: a block, gu.
float fineDetail(vec2 pa, vec2 pb, float w, float pxGu) {
#if LOW
	return 0.0;
#else
	const float LAM0 = 4.0 * 2.0 * 1.2 / 1024.0;
	if (LAM0 / pxGu < 5.0 || (u_diag & 4) != 0) {
		return 0.0;
	}
	float a = crDetail(pa, pxGu, LAM0, 3.7), b = crDetail(pb, pxGu, LAM0, 9.1);
	float nrm = inversesqrt((1.0 - w) * (1.0 - w) + w * w);
	return (a * (1.0 - w) + b * w) * nrm;
#endif
}
// THE PALETTE'S PROBES SEE THE CHART AS IT WAS: they are rendered with the stars
// off (`ChartSky._queue_probes`), and so is all of the resolving detail, and the
// palette cut from them is the one Jon approved. The detail only lands on its
// colours. 1 in a frame, 0 in a probe.
float resolveOn() { return u_stars_on ? 1.0 : 0.0; }
// ZOOMING ONLY MAGNIFIES (Jon, Oct 11: "why do the clouds change at all when you
// zoom in?"). A patch of the galaxy keeps its shape, colour and brightness at
// every zoom; zooming in may only ADD detail inside it (finer gas, its stars).
// What used to change with the zoom -- the nest of dust round the hole growing in
// from zoom 1.2, the nuclear lanes and the inner billows going from zoom 3 (later
// 4), the halo round the core thinning from 2.4, the wisps thinning from 3 --
// now stays as it is at the opening zoom, everywhere. The one exception is the core's
// own glare (the bulge's light, an elliptical's heart), still turned down deep in
// so the gold does not wash out round the hole. The palette's probes keep the old
// behaviour (`resolveOn`), so the cut is the approved palette. 1 in a probe.
float zoomChanges() { return 1.0 - resolveOn(); }
// the fine detail as the probes always had it (fbm octaves of 1/220 gu from zoom 2.8)
float fineDetailProbe(vec2 pa, vec2 pb, float w) {
#if LOW
	return 0.0;
#else
	float o = clamp(log2(u_zoom * u_k / (8.0 * 220.0)), 0.0, 2.5);
	if (o <= 0.0) {
		return 0.0;
	}
	float a = fbm2F(pa * 220.0 + 3.7, o), b = fbm2F(pb * 220.0 + 9.1, o);
	float nrm = inversesqrt((1.0 - w) * (1.0 - w) + w * w);
	return (a * (1.0 - w) + b * w) * nrm * clamp(o, 0.0, 1.0);
#endif
}
// a block, in gu, read `la` mip levels coarser through the lens
float blockGu(float la) { return 2.0 / (u_zoom * u_k) * exp2(la); }
// half a block in view px at zoom 1
float hbOf(float la) { return 1.0 / u_zoom; }
// THE DISC RESOLVES INTO ITS STARS as you zoom (`crStars`): as many as its own
// smooth light there `L`, as bright, blue-white in the young arms and warm round the
// bulge; the caller adds them where they sit, so dust in front dims them. Not
// through the lens: a star read through it hops blocks as the zoom moves.
// THEIR LIGHT WAS ALREADY THERE (Oct 11): a star takes its light from the smooth
// field round it, so a patch's light is the same with them as without. What
// comes back is the star less the light the stars bring to a block on average
// (`crStarsMean`): over the patch it adds nothing, it only gathers the light
// into points. (They used to add theirs on top, and a patch brightened as you
// zoomed and they came in.)
vec3 crStarsMean(float L, float hb, float warm) {
	float prob = clamp(L * 40.0, 0.0, 0.55);
	float t = min(prob / 0.1, 1.0);
	float eg = 0.1 * (t * t * t - 0.5 * t * t * t * t) + max(prob - 0.1, 0.0);
	float e = 0.0;
	for (int l = 0; l < 6; l++) {
		float c = 0.016 / exp2(float(l));
		float w = smoothstep(8.0, 16.0, c * u_zoom * u_k);
		if (w <= 0.0) {
			break;
		}
		// the chance a cell's star lands in this block, and its light on average
		float pb = eg * (4.0 * hb * hb) / (c * c * u_k * u_k * KIT_TILT);
		e += min(pb, 1.0) * (L * (1.5 * w + 3.5 * w * w * w) + 0.0067 * w * w);
	}
	vec3 tint = mix(kitStarTint(0.775), kitStarTint(0.375), warm);
	return tint * e;
}
vec3 resolvedStars(vec2 p, vec2 v, float hb, float la, float L, float r, int seed) {
	// (not in the palette's probes, which leave the stars out: the cut stays the gas's)
	float sq = 1.0 - smoothstep(0.2, 0.8, la);
	if (sq <= 0.0 || !u_stars_on || (u_diag & 34) != 0) {
		return vec3(0.0);
	}
	float warm = max(1.0 - smoothstep(0.10, 0.35, r), 1.0 - u_young);
	vec3 mean = (u_diag & 256) != 0 ? vec3(0.0) : crStarsMean(L, hb, warm) * sq;
	vec4 s = crStars(p, v, hb, u_phi, u_k, u_zoom, 0.016, clamp(L * 40.0, 0.0, 0.55), 211 + seed);
	if (s.x < 0.5) {
		return -mean;
	}
	vec3 tint = mix(kitStarTint(0.55 + 0.45 * s.z), kitStarTint(0.15 + 0.45 * s.z), warm);
	// (all of it scaled by the grid's fade, which is in s.y: a star comes up from nothing)
	return tint * s.y * (L * (3.0 + 14.0 * s.y * s.y) + 0.02 * s.y) * sq - mean;
}

// ------------------------------------------------------------------ the sky behind
// the sky behind, at infinity: far nebulae, far galaxies, three depths of stars
// sliding by depth as you pan (`chart_bg.gdshaderinc`). Laid in last, under
// what the galaxy's dust lets by and only where the galaxy is fainter than it
// (`bgSeen`): laid in first, it added its light to the disc's faint outskirts
// and slid their colour steps about as you panned
vec3 farSky(vec2 v, float la, float nebSeen) {
	vec2 sp = (v - gpan()) * u_zoom;                  // screen px from the frame centre
	// (where the lens squeezes the sky into a few blocks its point stars only
	// flicker as the zoom moves: they thin away there)
	return bgLightChart(sp, la < 0.8 ? 1.0 : 0.0, nebSeen, 2.0);
}

// ------------------------------------------------------------------ galaxy parts
// a slow mottle anchored in the plane: it bends the palette's dark steps into
// cloud edges, never rings
float mottle(vec2 p) { return 0.5 + 0.5 * kitFbm2(p * 2.4 + vec2(7.1, 3.3), 3); }

// The stellar halo and the outer disc's thinning light: the dim haze the
// edges fade into, a little rounder than the disc, mottled
vec3 halo(vec2 v) {
	vec2 g = v / u_k;
	float s = length(vec2(g.x, g.y / 0.42));
	float I = 0.026 * exp(-s / 0.36) + 0.0105 * exp(-s / 0.70);
	I *= 1.0 - smoothstep(0.9, 1.65, s);
	vec2 p = kitViewToPlane(v, u_phi, u_k);
	float m = mottle(p * 0.8);
	// (more evenly with the solid galaxy's dissolving edge: past the faded disc it is
	// most of what shows, and its full mottle read as blotches, not haze)
	I *= mix(1.0, 0.35 + 1.3 * m * m, smoothstep(0.35, 0.9, s) * (u_edge.w > 0.0 ? 0.3 : 1.0));
	// (it used to thin round the core from zoom 2.4; ZOOM ONLY MAGNIFIES, see `zoomChanges`)
	I *= 1.0 - 0.88 * smoothstep(2.4, 6.0, u_zoom) * (1.0 - smoothstep(0.08, 0.3, s)) * zoomChanges();
	return mix(vec3(1.0, 0.70, 0.42), vec3(0.30, 0.40, 1.0), smoothstep(0.08, 0.7, s)) * I;
}
// The grade: a hue-keeping chroma lift on muted mid tones (slate to indigo,
// khaki to amber), warm olives turned toward amber; greys, the deep dark and
// already vivid colours left as they are
vec3 grade(vec3 lin) {
	vec3 L = kitOklch(max(lin, 0.0));
	if (L.y < 1e-4) {
		return lin;
	}
	float hd = degrees(L.z);
	if (hd < 0.0) {
		hd += 360.0;
	}
	float pu = smoothstep(280.0, 292.0, hd) * (1.0 - smoothstep(338.0, 352.0, hd)) * (1.0 - smoothstep(0.05, 0.10, L.y));
	L.z -= radians((hd - 266.0) * 0.75) * pu;
	hd -= (hd - 266.0) * 0.75 * pu;
	float lift = 0.85 * smoothstep(0.004, 0.018, L.y) * (1.0 - smoothstep(0.06, 0.14, L.y)) * smoothstep(0.10, 0.26, L.x)
		* (1.0 - smoothstep(0.72, 0.92, L.x));
	L.y *= 1.0 + lift;
	float ol = smoothstep(66.0, 80.0, hd) * (1.0 - smoothstep(112.0, 128.0, hd));
	L.z -= radians((hd - 60.0) * 0.6) * ol;
	return max(kitOklchToLinear(L), 0.0);
}
// The bulge as gathered light: a bright core and a broad glow, projected round
// at 0.86. `front` = the share of its light in front of the disc along this ray:
// the near lanes cross its lower half in silhouette. Colour runs with log
// intensity, so the core is a warm gradient at every zoom, never a plate.
vec3 bulgeLight(vec2 v, out float front, out float I) {
	vec2 g = v / u_k;
	// (rounder still, through the camera: an egg pushed through a plate, rising
	// above the disc and dropping below it)
	// (and through the camera's pitch: held round however the disc opens or flattens)
	float s = length(vec2(g.x, g.y * (u_solid ? KIT_TILT / u_solidW.y : 1.0) / (u_solid ? 1.08 : 0.86)));
	float qy = v.y / (KIT_TILT * u_k);
	front = 0.5 + 0.5 * tanh(-1.05 * qy / (s + 0.008));
	// (bigger through the camera: more of a body to see turn)
	float bs = u_bulgeR / 0.128 * (u_solid ? 1.3 : 1.0);
	I = 0.95 * exp(-s / (0.022 * bs)) + 0.42 * exp(-s / (0.045 * bs)) + 0.018 * exp(-s / (0.10 * bs));
	float L = clamp((log(I) + 3.6) / 3.6, 0.0, 1.0);
	vec3 col = mix(vec3(0.95, 0.50, 0.24), vec3(1.0, 0.60, 0.26), smoothstep(0.0, 0.45, L));
	col = mix(col, vec3(1.0, 0.72, 0.38), smoothstep(0.45, 0.8, L));
	col = mix(col, vec3(1.0, 0.84, 0.60), smoothstep(0.82, 1.0, L));
	col = warmsoft(col);
	return col * 1.7 * (1.0 - exp(-I / 1.7));
}
// A ball (the ellipticals, the dwarfs, the merger's remnant): a lit ball of old
// stars, not a disc. Its light is a Sersic ball seen through (cored de
// Vaucouleurs) inside a soft power-law envelope that thins into the void over
// half a galaxy, so it never ends at an edge. Its colour runs with radius as
// well as light: a pale gold heart, amber, then the reddened, dimmer old stars
// of the outskirts, mottled in broad patches so the palette's steps fall on
// cloud edges and never on rings. u_ball says how big (re), how round on
// screen, how bright, and which: 0 an old ball (a faint dust ring), 1 a blue
// compact dwarf (young blue knots), 2 a thin dwarf (no dust), 3 a merger's
// remnant (shells and a dust lane across it). Round 0.74, flattened 0.55.
vec3 ellBall(vec2 v, out float gasOut) {
	vec2 g = v / u_k;
	float re = u_ball.x;
	int look = int(u_ball.w + 0.5);
	float s = length(vec2(g.x, g.y / u_ball.y));
	float sr = s / re;
	float core = 0.03 * re / 0.30;
	float sc = sqrt(s * s + core * core);
	// the ball, and the envelope it fades into
	float I = u_ball.z * exp(-7.67 * (pow(sc / re, 0.25) - 1.0));
	I += u_ball.z * 0.045 / (1.0 + pow(sr / 1.6, 2.2));
	I *= 1.0 - smoothstep(1.0, 2.3, s);
	vec2 pp = kitViewToPlane(v, u_phi, u_k);
	float rp = length(pp);
	// broad mottle: unresolved star clouds and patchy light in the outskirts
	float m = mottle(pp * 0.9);
	float m2 = 0.5 + 0.5 * kitFbm2(pp * 5.5 + vec2(3.7, 1.2), 3);
	// (the showcase's mottle on the round elliptical, look 0: patchier outskirts)
	I *= look == 0 ? mix(1.0, 0.40 + 1.2 * m, smoothstep(0.4 / 0.30 * 0.95, 2.4, sr)) : mix(1.0, 0.55 + 0.9 * m, smoothstep(0.6, 2.4, sr));
	I *= 0.92 + 0.16 * m2 * smoothstep(0.15, 0.6, sr);
	if (look == 3) {
		// a merger's shells: faint arcs at set radii, brighter on one side
		float an = atan(pp.y, pp.x);
		float sh = 0.0;
		for (int k = 0; k < 3; k++) {
			float rk = (1.2 + 0.55 * float(k)) * re;
			// an arc on one side only, wide and faint: a whole ring read as a rim
			float side = pow(0.5 + 0.5 * cos(an - 1.3 - 2.1 * float(k)), 4.0);
			sh += exp(-pow((rp - rk) / (0.12 * re), 2.0)) * side;
		}
		I += 0.0035 * sh * (0.6 + 0.8 * m);
	}
	// colour: by radius, nudged by the mottle so the hues wander in patches
	float tcol = smoothstep(0.0, 2.6, sr + 0.35 * (m - 0.5));
	vec3 col = mix(vec3(1.0, 0.82, 0.56), vec3(1.0, 0.64, 0.34), smoothstep(0.0, 0.35, tcol));
	col = mix(col, vec3(0.92, 0.46, 0.26), smoothstep(0.30, 0.70, tcol));
	// (a red with little blue in it: a bluer red over the navy behind read mauve)
	col = mix(col, vec3(0.74, 0.36, 0.18), smoothstep(0.65, 1.0, tcol));
	if (look == 1) {
		// a blue compact dwarf: young and blue round a warm heart
		col = mix(col, vec3(0.42, 0.62, 1.0), 0.55 * smoothstep(0.10, 0.45, tcol));
	} else if (look == 2) {
		// a dwarf spheroidal: old and thin, a little greyer (more than this and its
		// tans fell between the warm steps and a saturated one drew a ring)
		col = mix(col, vec3(0.86, 0.66, 0.46), 0.25);
	}
	if (look == 0) {
		// the round elliptical as the showcase drew it (Jon's approved reference):
		// coloured by its own brightness, rich amber through orange to a violet-blue
		// outskirts, never a pale cream plate
		float Lb = clamp((log(max(I, 1e-6)) + 5.2) / 6.0, 0.0, 1.0);
		col = mix(vec3(0.34, 0.38, 0.78), vec3(0.95, 0.52, 0.30), smoothstep(0.08, 0.5, Lb));
		col = mix(col, vec3(1.0, 0.70, 0.40), smoothstep(0.45, 0.75, Lb));
		col = mix(col, vec3(1.0, 0.76, 0.46), smoothstep(0.75, 1.0, Lb));
	}
	col = warmsoft(col);
	// gathered light: the brightest channel through a soft shoulder
	float Ic = 1.15 * (1.0 - exp(-I / 1.15));
	vec3 c = col * Ic;
	vec4 Nn = noiseRaw(pp);
	float nearS = smoothstep(-0.015, 0.02, g.y);
	if (look == 0 || look == 3) {
		// dust: a thin warped ring in the plane round the core (its near half
		// crosses the light in silhouette), and across a merger a warped lane
		float wob = 0.012 * kitSnoise2(vec2(atan(pp.y, pp.x) * 1.6, 3.1));
		float ringD = exp(-pow((rp - 0.42 * re - wob) / (0.10 * re), 2.0)) + 0.6 * exp(-pow((rp - 0.68 * re + wob) / (0.08 * re), 2.0));
		float fil = smoothstep(0.30, 0.80, Nn.g);
		float tauE = (look == 0 ? 4.2 : 1.8) * ringD * (0.30 + 0.95 * fil) * mix(0.22, 1.0, nearS);
		if (look == 3) {
			float lane = exp(-pow((g.y + 0.10 * g.x + 0.012 * kitSnoise2(vec2(g.x * 9.0, 1.7))) / (0.05 * re), 2.0))
				* (1.0 - smoothstep(0.6 * re, 1.4 * re, abs(g.x)));
			tauE += 2.6 * lane * (0.45 + 0.8 * fil);
		}
		c *= exp(-tauE * vec3(0.62, 0.86, 1.0));
		if (look == 0) {
			c *= 0.90 + 0.18 * smoothstep(0.30, 0.80, Nn.r) * smoothstep(0.1 * re / 0.30, 0.4 * re / 0.30, s);
		}
	}
	if (look == 1) {
		// its star-forming knots: pink and blue clumps through the middle
		float kn = smoothstep(0.62, 0.86, Nn.a) * (1.0 - smoothstep(1.5 * re, 3.0 * re, rp));
		c += kn * (vec3(1.0, 0.30, 0.55) * 0.05 + vec3(0.5, 0.7, 1.0) * 0.03) * (0.6 + 0.8 * m);
	}
	gasOut = min(u_gasAmt, 1.6) * exp(-rp / max(re, 0.05)) * 0.8;
	return c;
}

// A tidal stream flung off one side (the game's own: angle -0.9 to 0.8 as it
// runs from 0.55 to 2.05 gu out, thinning along its length)
vec3 tailLight(vec2 p) {
	if (u_tail < 0.5) {
		return vec3(0.0);
	}
	float r = length(p);
	if (r < 0.45 || r > 2.2) {
		return vec3(0.0);
	}
	float t = clamp((r - 0.55) / 1.5, 0.0, 1.0);
	float th = atan(p.y, p.x);
	float c = -0.9 + t * 1.7;
	float w = 0.5 * (0.10 + t * 0.30);
	float d = wrapA(th - c) / w;
	float body = exp(-d * d * 1.6) * smoothstep(0.45, 0.6, r) * (1.0 - smoothstep(1.9, 2.2, r)) * (1.0 - 0.7 * t);
	float m = mottle(p * 1.6 + 2.0);
	return vec3(0.30, 0.42, 1.0) * body * (0.010 + 0.016 * m * m);
}

// The disc at plane point p (h = 0): its light Em and the transmittance T of its
// dust, the gas there (for clouds to light) and the arm ridge A; `dust` and
// `nest` are the nuclear dust's density and the dust nest round the hole.
float nestZ() { return smoothstep(1.2, 3.6, u_zoom) * zoomChanges(); }
// THE NUCLEUS'S LANES AND ITS INNER BILLOWS AS YOU NEAR THE HOLE: they used to go
// altogether between zoom 3 and 5, and the gas round the hole went to one flat
// brown plate as you zoomed in (Jon: "dust disappearing"). Now they stay
// (`zoomChanges`); the palette's probes keep the old fade.
float nucFade() { return mix(1.0 - smoothstep(3.0, 5.0, u_zoom), 1.0, resolveOn()); }
float nucLanes(vec2 p, float r, float n) {
	float arms = u_armModel.x;
	if (arms < 0.5) {
		return 0.0;
	}
	float a = atan(p.y, p.x);
	float ar = u_armModel.z + max(r - u_armModel.w, 0.0) / (1.0 - u_armModel.w) * u_armModel.y + 0.55 * log(min(r, 0.15) / 0.15);
	float c = cos((a - ar) * arms - 0.9);
	float lane = smoothstep(0.45, 0.93, c);
	lane *= smoothstep(0.010, 0.026, r) * (1.0 - smoothstep(0.14, 0.22, r));
	lane *= 0.35 + 0.9 * smoothstep(0.30, 0.70, n);
	return lane;
}
void discAt(vec2 p, vec2 v, float hb, vec3 star, float la, out vec3 Em, out vec3 T, out float gas, out float A, out float dust, out float nest) {
	float r = length(p);
	vec4 S = structAtL(p, la);
	vec2 pa, pb;
	float w;
	vec4 N = flowNoise(p, la, pa, pb, w);
	// (past a squeeze of two the fine octaves only alias)
	float RZ = resolveOn();
	float det = (RZ > 0.5 ? fineDetail(pa, pb, w, blockGu(la)) : fineDetailProbe(pa, pb, w)) * (1.0 - smoothstep(0.5, 1.5, la));
	A = S.r;
	float taper = 1.0 - smoothstep(0.58, 1.3, r);
	float seg = 0.32 + 1.15 * smoothstep(0.15, 0.85, kitVnoise2(p * 2.4 + 5.0));
	float clump = clamp(N.r + mix(0.12, 0.45, RZ) * det, 0.0, 1.0);
	float cl = smoothstep(0.24, 0.84, clump);
	// two populations: old warm stars round the bulge, and the disc, which starts
	// where the warm light has faded; a gas-poor disc is old all the way out
	float Iw = 0.05 * exp(-r / 0.07);
	float Ib = 0.075 * exp(-r / 0.40) * smoothstep(0.15, 0.36, r) * taper;
	Ib *= mix(1.0, 0.4 + 1.2 * mottle(p), smoothstep(0.30, 0.85, r));
	vec3 discC = mix(vec3(0.62, 0.52, 0.42), vec3(0.20, 0.32, 1.0), u_young);
	Em = (Iw * warmsoft(vec3(1.0, 0.64, 0.32)) + Ib * discC) * (0.90 + 0.2 * cl);
	// the arms: a smooth glow, and star clouds that bunch into distinct blobs
	float Ia = 1.15 * exp(-r / 0.34) * taper * u_armGain * seg;
	float blobs = smoothstep(0.52, 0.76, clump);
	// (the glow takes the fine detail too: up close the arm's light is mottled, not a smooth sheet)
	float glow = pow(A, 1.3) * 0.42 * max(1.0 + 0.9 * RZ * det, 0.15);
	float clouds = A * A * (0.20 * cl + 1.3 * blobs);
	vec3 cA = mix(vec3(0.28, 0.52, 1.0), vec3(0.70, 0.86, 1.0), smoothstep(0.5, 1.3, clouds));
	vec3 warm = vec3(1.0, 0.70, 0.40);
	cA = mix(warm * 0.8, cA, u_young);
	float inner = 1.0 - smoothstep(0.04, 0.18, r);
	Em += Ia * (glow * mix(mix(warm * 0.55, vec3(0.26, 0.46, 1.0), u_young), warm * 0.30, inner) + clouds * mix(cA, warm * 0.45, inner));
	// feathers between the arms, only near them
	Em += Ia * 0.05 * (1.0 - A) * smoothstep(0.1, 0.5, A) * cl * mix(warm * 0.6, vec3(0.26, 0.42, 1.0), u_young);
	// the star-forming front just inside the ridge: hot pink, mottled
	float pinkM = S.a * smoothstep(0.58, 0.84, N.a + mix(0.15, 0.25, RZ) * det) * smoothstep(0.08, 0.2, r) * clamp(u_gasAmt, 0.0, 1.0);
	Em += Ia * pinkM * vec3(1.0, 0.24, 0.50) * 0.8;
	// (how many and how bright from the disc's SMOOTH light -- its populations and
	// the arm's glow, not the fine clumps: read with them, a star's light changed
	// block by block as the zoom slid it along, and it twinkled on a glide)
	float Ls = kitLum(Iw * warmsoft(vec3(1.0, 0.64, 0.32)) + Ib * discC) + Ia * (0.42 * pow(A, 1.3) + 0.45 * A * A) * 0.55;
	Em = max(Em + resolvedStars(p, v, hb, la, Ls, r, 0), vec3(0.0));
	Em += star;
	// the bulge's light falling on the inner disc's gas
	float irr = 1.0 / (1.0 + pow(r / 0.10, 2.0));
	gas = (0.25 + A) * (0.45 + 0.9 * N.a) * taper * min(u_gasAmt, 1.6);
	Em += irr * gas * LITDUST * 0.025;
	// dust: lanes on the arms' inner edges, broken by filaments; spurs across the
	// gaps; in the nucleus a dense flocculent nest. Thin in the disc: never murk.
	float fil = clamp(N.g + mix(0.45, 0.7, RZ) * det * smoothstep(0.06, 0.12, r), 0.0, 1.0);
	float wn = 1.0 - smoothstep(0.08, 0.13, r);
	float tauArm = S.g * u_laneStr * (0.15 + 1.9 * smoothstep(0.22, 0.62, fil)) * (0.6 + 0.6 * seg) * 1.6;
	float nucK = clamp(u_laneStr, 0.0, 1.0);
	float tauNuc = (1.5 * smoothstep(0.45, 0.9, S.g) + 0.2 * smoothstep(0.5, 0.85, fil) + 5.5 * (1.0 - smoothstep(0.012, 0.06, r)) * nestZ()) * nucK;
	float tau = mix(tauArm, tauNuc, wn * smoothstep(0.004, 0.012, r));
	dust = clamp(tau / 3.0, 0.0, 1.0) * wn;
	nest = (1.0 - smoothstep(0.016, 0.07, r)) * (0.55 + 0.45 * smoothstep(0.35, 0.85, S.g)) * nestZ() * nucK;
	tau += (1.0 - A) * smoothstep(0.55, 0.9, fil) * 0.6 * smoothstep(0.1, 0.3, r) * taper * clamp(u_laneStr, 0.0, 1.0);
	tau += 3.6 * nucLanes(p, r, N.g) * nucFade() * nucK;
	tau = min(tau, 7.0);
	T = exp(-tau * mix(vec3(0.55, 0.80, 1.0), vec3(0.62, 0.84, 1.0), wn));
	Em *= mix(vec3(1.0), T, 0.92) * exp(-1.8 * nest);
	Em += star * 0.6 * (1.0 - smoothstep(0.06, 0.2, r));
	// the lane's lip, facing the core, catches the bulge's light
	Em += S.b * irr * LITDUST * 0.35 * smoothstep(0.25, 0.65, fil);
}

// knots: pink gathered light (a core and a falloff) that breathes; a few bloom
vec3 knots(vec2 p) {
	vec3 c = vec3(0.0);
	float px = 1.0 / (u_zoom * u_k);
	for (int i = 0; i < 64; i++) {
		if (i >= u_nkn) {
			break;
		}
		vec4 kn = u_kn[i];
		vec2 d = p - kn.xy;
		float s = max(kn.z, 1.4 * px);
		float dd = dot(d, d);
		if (dd > 30.0 * s * s) {
			continue;
		}
		float q = sqrt(dd) / s;
		float core = exp(-q * q * 1.6), fall = exp(-q * 1.2) * 0.30;
		c += kn.w * (vec3(1.0, 0.24, 0.48) * (core + fall) + vec3(0.8, 0.9, 1.0) * exp(-q * q * 6.0) * 0.6) * 0.6;
	}
	return c;
}

// ------------------------------------------------------------------ clouds
float lobes(int ci, vec2 u) {
	float d = 0.0;
	for (int j = 0; j < 3; j++) {
		vec4 L = u_lobe[ci * 3 + j];
		vec2 dd = (u - L.xy) / (L.z * 0.74);
		d += exp(-dot(dd, dd) * 1.5);
	}
	return d;
}
float wxGate() { return u_wxOn * smoothstep(2.4, 3.2, u_zoom); }

// EMISSION: rose H-alpha billows; a cavity blown by the cluster, glowing teal
// OIII, its wall bright; dark pillars standing in the wall pointing at the
// cluster, their tips lit. Weather: lightning lighting the cloud from within.
void emissionCloud(int ci, vec2 u, float R, float seed, inout vec3 C) {
	float den = lobes(ci, u);
	if (den < 0.012) {
		return;
	}
	float t = u_time * 0.0025 * u_drift;
	vec2 q = u / R;
	vec2 w = q * 2.4 + seed;
	w += 0.5 * vec2(fbm3F(vec3(w * 0.8, t), 2.0), fbm3F(vec3(w * 0.8 + 5.2, t), 2.0));
	float f = fbm3F(vec3(w * 1.5, t * 1.4), octFor(3.6 / R));
	float rho = den * smoothstep(-0.30, 0.55, f + 0.30 * (den - 0.8));
	vec2 cc = u_lobe[ci * 3].xy * 0.6;
	vec2 rel = (u - cc) / R;
	float dc = length(rel);
	vec2 dir = rel / max(dc, 1e-4);
	float cavR = 0.28 + 0.07 * kitFbm2(dir * 1.6 + seed, 3);
	float inside = 1.0 - smoothstep(cavR - 0.12, cavR + 0.04, dc);
	float wall = exp(-pow((dc - cavR - 0.02) / 0.06, 2.0));
	float rhoC = rho * mix(1.0, 0.25, inside) + 0.35 * inside * min(den, 1.0);
	float o3 = 1.0 - smoothstep(cavR - 0.16, cavR + 0.10, dc + 0.08 * f);
	vec3 paleW = vec3(0.95, 0.78, 0.80);
	vec3 col = o3 > 0.5 ? mix(paleW, OIII, (o3 - 0.5) * 2.0) : mix(HA * vec3(1.0, 1.15, 1.1), paleW, o3 * 2.0);
	vec3 Em = col * (rhoC * rhoC * 1.5 + rhoC * 0.30) * mix(1.0, 0.45, inside);
	float ga = 1.0 / (1.0 + pow(dc / 0.13, 2.0));
	vec3 o3c = mix(OIII * vec3(0.55, 0.9, 1.0), mix(OIII, vec3(0.75, 1.0, 0.95), smoothstep(0.45, 0.9, ga)), smoothstep(0.08, 0.4, ga));
	Em += o3c * (0.02 + 0.62 * ga * ga) * inside * clamp(0.5 + 1.2 * f, 0.15, 1.7);
	Em += mix(HA * 1.2, vec3(1.0, 0.75, 0.68), 0.35) * wall * min(rho + 0.2, 1.2) * 0.9;
	float pRes = smoothstep(1.0, 2.2, u_zoom * R / 0.159);
	float pd = 0.0, rim = 0.0;
	if (pRes > 0.0) {
		for (int k = 0; k < 4; k++) {
			float fk = float(k);
			float ang = fk * 1.5708 + seed * 1.3 + 0.55 * sin(seed * 5.1 + fk * 3.3);
			vec2 dk = vec2(cos(ang), sin(ang));
			float tipD = cavR - 0.02 - 0.05 * fract(seed * 3.7 + fk * 0.618);
			vec2 A0 = dk * tipD, B0 = dk * (cavR + 0.55);
			vec2 As = vec2(A0.x, A0.y * 0.46341), Bs = vec2(B0.x, B0.y * 0.46341), rs = vec2(rel.x, rel.y * 0.46341);
			vec2 ab = Bs - As;
			float hh = clamp(dot(rs - As, ab) / dot(ab, ab), 0.0, 1.0);
			vec2 cp = As + ab * hh + vec2(-ab.y, ab.x) * 0.06 * sin(hh * 4.0 + fk * 1.7);
			float rad = mix(0.014, 0.060, pow(hh, 0.8)) * (0.85 + 0.3 * fract(seed * 1.9 + fk * 0.37));
			float dist = length(rs - cp) + rad * (0.30 * kitSnoise2(rs * 70.0 + fk * 7.0) + 0.15 * kitSnoise2(rs * 170.0 + fk * 3.0));
			float body = (1.0 - smoothstep(rad * 0.55, rad * 1.05, dist)) * (1.0 - smoothstep(0.45, 1.0, hh)) * (0.8 + 0.2 * f);
			vec2 nrm = (rs - cp) / max(length(rs - cp), 1e-4);
			vec2 toCl = -normalize(cp + 1e-5);
			float facing = clamp(dot(nrm, toCl) * 1.1 + 0.9 * (1.0 - smoothstep(0.0, 0.12, hh)), 0.0, 1.0) * (1.0 - smoothstep(0.12, 0.35, hh));
			float band = smoothstep(rad * 0.35, rad * 0.9, dist) * (1.0 - smoothstep(rad * 0.9, rad * 1.1, dist));
			pd = max(pd, body);
			rim = max(rim, band * facing);
		}
		float g = smoothstep(0.08, 0.35, den) * pRes;
		pd *= g;
		rim *= g;
	}
	C *= exp(-pd * 3.0) * exp(-min(rho, 1.5) * 1.3);
	Em *= 1.0 - 0.96 * pd;
	Em += vec3(0.010, 0.003, 0.004) * pd;
	Em += vec3(1.0, 0.80, 0.74) * rim * 1.1;
	vec4 lt = u_lt[ci];
	if (lt.x > 0.0) {
		vec2 dl = (u - lt.yz) / lt.w;
		float d2 = dot(dl, dl);
		float lit = rho * rho * (0.6 + 0.8 * smoothstep(-0.1, 0.5, f));
		Em += LIGHTNING * lt.x * wxGate() * (lit * exp(-d2 * 0.8) * 2.4 + exp(-d2 * 9.0) * 0.9 * min(rho + 0.3, 1.0));
	}
	C += Em;
}
// REFLECTION: streaky dust lit blue round its stars. Weather: light shafts.
void reflectionCloud(int ci, vec2 u, float R, float seed, inout vec3 C) {
	float den = lobes(ci, u);
	if (den < 0.012) {
		return;
	}
	float t = u_time * 0.002 * u_drift;
	vec2 q = u / R;
	vec2 sq = kitRot(seed) * q;
	sq.x *= 0.5;
	vec2 w = kitWarp2(sq * 3.0 + seed, 0.45, 2);
	float f = fbm3F(vec3(w * 1.6, t), octFor(4.8 / R));
	float rho = den * smoothstep(-0.45, 0.5, f);
	vec2 s0 = u_lobe[ci * 3].xy * 0.7, s1 = u_lobe[ci * 3 + 1].xy * 0.8;
	float d0 = length(u - s0) / R, d1 = length(u - s1) / R;
	float L = 1.0 / (1.0 + pow(d0 / 0.13, 2.0)) + 0.45 / (1.0 + pow(d1 / 0.10, 2.0));
	vec2 rel = u - s0;
	float an = atan(rel.y, rel.x) - 0.01 * u_time;
	float sh = smoothstep(0.5, 0.85, kitVnoise2(vec2(cos(an), sin(an)) * 2.6 + seed * 3.0));
	L *= 1.0 + 0.8 * sh * wxGate() * smoothstep(0.06, 0.25, d0);
	C *= exp(-min(rho, 1.5) * 0.6);
	vec3 col = mix(REFL, vec3(0.72, 0.84, 1.0), smoothstep(0.6, 2.4, L * (0.5 + rho)));
	C += col * rho * L * 1.0 + REFL * rho * 0.04;
	C += vec3(0.55, 0.72, 1.0) * 0.14 / (1.0 + pow(d0 / 0.04, 2.0));
}
// REMNANT: a hollow ragged shell of braided filaments, red outside and teal
// inside, one side brighter, with gaps. Weather: shock glimmers along it.
void remnantCloud(int ci, vec2 u, float Rr, float seed, inout vec3 C) {
	vec2 q = u / Rr;
	float rho = length(q);
	if (rho > 1.45) {
		return;
	}
	vec2 dir = q / max(rho, 1e-4);
	float an = atan(dir.y, dir.x);
	float front = 1.0 + 0.14 * kitFbm2(dir * 1.1 + seed, 3) + 0.05 * dir.x;
	float x = rho / front;
	float res = smoothstep(1.6, 3.2, u_zoom * Rr / 0.087);
	float n = kitSnoise3(vec3(dir * 1.9 + seed, x * 6.5)) + 0.45 * kitSnoise3(vec3(dir * 4.1 + seed * 2.0, x * 13.0 + 3.0));
	float strand = exp(-pow(n / 0.11, 2.0));
	float win = smoothstep(0.58, 0.88, x) * (1.0 - smoothstep(0.985, 1.05, x));
	float shell = exp(-pow((x - 0.95) / 0.07, 2.0));
	float side = 0.55 + 0.45 * kitSnoise2(dir * 0.9 + seed * 1.3);
	float gaps = smoothstep(-0.35, 0.25, kitSnoise2(dir * 2.3 + seed * 0.7));
	float glim = 0.0;
	for (int j = 0; j < 3; j++) {
		float th0 = 0.05 * u_time + float(j) * 2.094 + seed;
		glim += 0.6 * exp(-pow(wrapA(an - th0) / 0.15, 2.0));
	}
	glim *= wxGate();
	float I = (shell * mix(0.85, 0.40, res) + res * strand * win * (0.45 + 1.4 * smoothstep(0.8, 0.99, x))) * side * (0.3 + 0.7 * gaps) * (1.0 + 1.5 * glim);
	vec3 col = mix(OIII, mix(HA, vec3(1.0, 0.55, 0.5), 0.25), smoothstep(0.78, 0.93, x));
	vec3 Em = col * I * 1.9;
	Em += OIII * 0.035 * (1.0 - smoothstep(0.2, 0.95, x));
	Em += HA * 0.05 * exp(-pow((x - 1.03) / 0.06, 2.0)) * side;
	C *= 1.0 - 0.1 * clamp(I, 0.0, 1.0);
	// the blast has cleared its bubble: what lies behind it dims inside the shell,
	// so the shell reads as one object over the arm, not one more ring in its
	// texture (the showcase's A cleared it the same way)
	C *= mix(0.62, 1.0, smoothstep(0.7, 0.96, x));
	C += Em;
}
// PLANETARY: small and crisp; a thin limb-brightened ring round a hot star,
// teal inside, a thin red rim outside
void planetaryCloud(int ci, vec2 u, float R, float shape, float seed, inout vec3 C) {
	float an0 = seed * 1.7;
	vec2 a = mat2(vec2(cos(an0), -sin(an0)), vec2(sin(an0), cos(an0))) * u / (R * 0.8);
	if (dot(a, a) > 4.0) {
		return;
	}
	float rho = (shape > 0.5 && shape < 1.5) ? length(vec2(a.x / 1.3, a.y)) : length(a);
	float ang = atan(a.y, a.x);
	float x = (rho - 1.0) / (0.10 * (0.85 + 0.3 * (0.5 + 0.5 * cos(ang - 0.7))));
	float ring = exp(-x * x * 1.3) * (0.55 + 0.6 * abs(cos(ang)) + 0.45 * (kitVnoise2(a * 7.0 + seed) - 0.5));
	float rim = exp(-pow((rho - 1.17) / 0.045, 2.0));
	float fill = 1.0 - smoothstep(0.2, 0.98, rho);
	vec3 Em = OIII * (ring * 1.5 + fill * 0.25) + HA * rim * 1.1;
	if (shape > 1.5 && shape < 2.5) {
		float lb = exp(-pow(length(vec2(a.x * 1.6, abs(a.y) - 1.1)) / 0.55, 2.0));
		Em += mix(OIII, HA, 0.6) * lb * 0.55;
	}
	if (shape > 2.5) {
		vec2 dd = vec2(abs(a.x) - 1.45, a.y);
		Em += HA * exp(-dot(dd, dd) / 0.02) * 1.6;
	}
	C += Em * 0.9;
}
// DARK: dense filaments, veils that redden what shows through them, a smooth
// rim lit where the dust thins toward the light. Weather: lightning.
void darkCloud(int ci, vec2 u, float R, float seed, vec2 toC, vec3 Cb, float irr, inout vec3 C, inout vec3 cloudT) {
	if (lobes(ci, u) < 0.006) {
		return;
	}
	vec2 q = u / R * 2.2 + seed;
	vec2 wu = u + R * 0.24 * vec2(kitFbm2(q * 0.8 + 1.3, 3), kitFbm2(q * 0.8 + 7.9, 3));
	float den = lobes(ci, wu);
	if (den < 0.012) {
		return;
	}
	float t = u_time * 0.0015 * u_drift;
	vec2 w = kitWarp2(q, 0.6, 2);
	float oc = min(octFor(3.3 / R), 3.0);
	float f = fbm3F(vec3(w * 1.5, t), oc);
	float body = smoothstep(0.10, 1.05, den + 0.62 * f);
	float rho = body * (0.55 + 0.45 * smoothstep(-0.35, 0.45, f));
	float tau = 4.6 * rho;
	vec3 Tr = exp(-tau * vec3(0.70, 0.88, 1.0));
	C *= Tr;
	cloudT *= exp(-tau * vec3(0.66, 0.90, 1.0));
	float tex = 0.5 + 0.5 * fbm3F(vec3(w * 4.0 + 3.0, t), max(min(octFor(13.0 / R), 3.0), 1.0));
	C += rho * mix(vec3(0.003, 0.0026, 0.0045), vec3(0.008, 0.0065, 0.010), tex) * (0.6 + 2.0 * irr);
	float den2 = lobes(ci, wu + toC * 0.12 * R);
	float face = smoothstep(-0.05, 0.6, (den - den2) / (0.25 * den + 0.03));
	float edge = smoothstep(0.04, 0.22, rho) * (1.0 - smoothstep(0.30, 0.62, rho));
	vec3 light = LITDUST * (irr * 1.2 + 0.010) + Cb * 1.1;
	C += edge * face * light * 0.55;
	vec4 lt = u_lt[ci];
	if (lt.x > 0.0) {
		vec2 dl = (u - lt.yz) / lt.w;
		C += mix(LIGHTNING, LITDUST, 0.3) * lt.x * wxGate() * smoothstep(0.1, 0.6, rho) * exp(-dot(dl, dl)) * 0.8;
	}
}
void cloudLayer(vec2 v, float irr, float gas, inout vec3 C, inout vec3 cloudT) {
	vec3 Cb = C;
	for (int i = 0; i < 12; i++) {
		if (i >= u_ncl) {
			break;
		}
		vec4 cl = u_cl[i], ck = u_clk[i];
		vec2 u = (v - cl.xy) / u_k;
		u.y /= 0.46341;                                // clouds are drawn flattened to cloud_flat
		int kind = int(ck.x + 0.5);
		float ext = (kind == 2 || kind == 3) ? cl.w * 1.6 : cl.z * 1.9;
		if (dot(u, u) > ext * ext) {
			continue;
		}
		// the cloud lights the disc gas round it
		if (kind == 0 || kind == 1) {
			float d = length(u) / cl.z;
			C += (kind == 0 ? mix(HA, OIII, 0.15) : REFL) * gas * 0.10 * exp(-d * d * 0.9);
		}
		if (kind == 0) {
			emissionCloud(i, u, cl.z, ck.w, C);
		} else if (kind == 1) {
			reflectionCloud(i, u, cl.z, ck.w, C);
		} else if (kind == 2) {
			remnantCloud(i, u, cl.w, ck.w, C);
		} else if (kind == 3) {
			planetaryCloud(i, u, cl.w, ck.z, ck.w, C);
		} else {
			darkCloud(i, u, cl.z, ck.w, u_cdir[i].xy, Cb, irr, C, cloudT);
		}
	}
}

// ------------------------------------------------------------------ height
// Billows: gas columns rising from the arms, a soft height field marched along
// the view ray from the top down to the disc; lit warm on the slopes facing the
// core, blue-white from the arms' young stars, violet in their own shade
float colTop(vec2 p, float Hmax, out float pink) {
	float r = length(p);
	vec4 S = structAt(p);
	float base = S.r * smoothstep(0.06, 0.2, r) * (1.0 - smoothstep(0.72, 1.05, r));
	float innerB = smoothstep(0.075, 0.115, r) * (1.0 - smoothstep(0.18, 0.28, r)) * u_armModel.x / max(u_armModel.x, 1.0)
		* nucFade();
	base = max(base, innerB * (0.75 + 0.45 * S.r));
	float om = flowOm(r);
	float tt = u_time * u_drift + 20.0 * kitVnoise2(p * 2.5 + 3.3);
	vec3 fp = kitFlowPhase(tt, 20.0);
	vec2 pa = kitRot(om * fp.x * 20.0) * p, pb = kitRot(2.1 + om * fp.y * 20.0) * p;
	vec4 a = noiseRawL(pa * 0.5 + 0.31, 2.4);
#if LOW
	vec4 N = a;
#else
	vec4 b = noiseRawL(pb * 0.5 + 0.31, 2.4);
	float w = fp.z, nrm = inversesqrt((1.0 - w) * (1.0 - w) + w * w);
	vec4 N = clamp(NMID + ((a - NMID) * (1.0 - w) + (b - NMID) * w) * nrm, 0.0, 1.0);
#endif
	float vn = kitVnoise2(p * 5.0 + 1.7);
	float reg = mix(smoothstep(0.45, 0.68, vn), smoothstep(0.22, 0.50, vn), innerB);
	for (int i = 0; i < 12; i++) {
		if (i >= u_ncl) {
			break;
		}
		vec4 c = u_clp[i];
		if (c.w < 0.5) {
			continue;
		}
		vec2 d = p - c.xy;
		reg *= 1.0 - 0.9 * exp(-dot(d, d) / (c.z * c.z * 1.4));
	}
	pink = S.a * smoothstep(0.55, 0.8, N.a);
	return Hmax * base * reg * sqrt(clamp((N.b - 0.46) / 0.26, 0.0, 1.0));
}
void billowLayer(vec2 v, ivec2 dq, inout vec3 C) {
	if (u_gasAmt < 0.2 || u_form != 0) {
		return;
	}
	float Hmax = 0.040 * clamp(u_gasAmt, 0.7, 1.5);
	float pk;
#if LOW
	float h = 0.35 * Hmax;
	vec2 p = sheetP(v, h);
	float r = length(p);
	if (r > 1.1 || r < 0.05) {
		return;
	}
	float top = colTop(p, Hmax, pk);
	float rho = smoothstep(0.0, 0.2 * Hmax, top - h);
	float irr = 1.0 / (1.0 + pow(r / 0.13, 2.0));
	float Ia = 1.15 * exp(-r / 0.34) * u_armGain;
	vec3 col = irr * LITDUST * 1.4 + Ia * vec3(0.34, 0.56, 1.0) * 0.45;
	float a = rho * 0.6;
	C = C * (1.0 - a) + col * a;
#else
	int N = int(clamp(10.0 + 3.0 * u_zoom, 10.0, 24.0));
	float dh = Hmax * 1.05 / float(N);
	float j = 0.5 + 0.5 * (kitBayer4(dq) - 0.5);
	vec3 acc = vec3(0.0);
	float Tr = 1.0;
	for (int i = 0; i < 24; i++) {
		if (i >= N) {
			break;
		}
		float h = Hmax * 1.05 - (float(i) + j) * dh;
		if (h <= 0.001) {
			break;
		}
		vec2 p = sheetP(v, h);
		float r = length(p);
		if (r > 1.1 || r < 0.05) {
			continue;
		}
		float top = colTop(p, Hmax, pk);
		float rho = smoothstep(0.0, 0.18 * Hmax, top - h);
		if (rho <= 0.002) {
			continue;
		}
		vec2 toC = -p / r;
		float pk2;
		float topIn = colTop(p + toC * 0.022, Hmax, pk2);
		float slope = (top - topIn) / (0.30 * Hmax);
		float irr = 1.0 / (1.0 + pow(r / 0.13, 2.0));
		float Ia = 1.15 * exp(-r / 0.34) * u_armGain;
		float sl = clamp(0.25 + slope + 0.35 * clamp(h / max(top, 1e-4), 0.0, 1.0), 0.0, 1.0);
		float warmW = 1.0 - smoothstep(0.12, 0.26, r);
		vec3 litC = mix(vec3(0.34, 0.58, 1.0) * Ia * 0.75, vec3(1.0, 0.62, 0.28) * irr * 2.2, warmW);
		// where the core's gold and the arms' blue both light a billow, the sum is
		// a near-grey the saturation lift turned lavender-rose (plates of it beside
		// the bulge in every spiral's core view): it is made a warm cream instead
		float both = 4.0 * warmW * (1.0 - warmW);
		litC = mix(litC, vec3(kitLum(litC)) * vec3(1.05, 0.90, 0.68), both * 0.85);
		// the shade: violet out in the blue arms, umber round the bulge (violet over
		// the gold there made a mauve plate under the hole)
		vec3 shade = mix(vec3(0.10, 0.10, 0.40), vec3(0.30, 0.13, 0.05), warmW);
		vec3 col = sl * sl * litC + (1.0 - sl) * mix(Ia * 0.10, irr * 0.25, warmW) * shade
			+ pk * Ia * vec3(1.0, 0.26, 0.52) * 0.5 * clamp(u_gasAmt, 0.0, 1.0) * (1.0 - warmW);
		// (no star-forming pink in the gold-lit billows round the bulge: mixed
		// into the gold it quantised to a pale rose plate beside the hole)
		// up close the lit slopes break into finer swells and shadows (on the light,
		// not on the height: detail in the height field, sampled a step at a time
		// down the ray, drew stripes along it)
		if (u_stars_on) {
			col *= max(1.0 + 0.45 * ((u_diag & 4) != 0 ? 0.0 : crDetail(p, blockGu(0.0), 0.012, 21.0)), 0.3);
		}
		float a = 1.0 - exp(-rho * 42.0 * dh * KIT_RAY_LEN);
		acc += Tr * a * col;
		Tr *= 1.0 - a;
		if (Tr < 0.03) {
			break;
		}
	}
	C = C * Tr + acc;
#endif
}
// wisps high above the disc: thin veils lit warm by the core, faint; they thin
// as you near them
void wispLayer(vec2 v, float la, inout vec3 C) {
#if !LOW
	if (u_gasAmt < 0.2 || u_form == 1) {
		return;
	}
	vec2 p = sheetP(v, 0.085);
	float r = length(p);
	if (r > 1.0 || r < 0.06) {
		return;
	}
	// (they thin only a little as you near them: gas that vanished as you zoomed
	// in read as detail lost, Jon)
	float fade = mix(1.0, 0.75, smoothstep(3.0, 6.0, u_zoom) * zoomChanges());
	vec2 pw = kitRot(0.9 + u_time * 0.00012 * u_drift) * p * 0.85;
	// (and they resolve into finer strands as you near them)
	float f = noiseRawLA(pw, la).g + (u_stars_on ? 0.14 * ((u_diag & 4) != 0 ? 0.0 : crDetail(pw, blockGu(la) * 0.85, 0.02, 7.0)) : 0.0);
	float m = smoothstep(0.45, 0.85, f) * (1.0 - smoothstep(0.45, 0.95, r)) * smoothstep(0.14, 0.32, r) * min(u_gasAmt, 1.5);
	if (m < 0.003) {
		return;
	}
	float irr = 1.0 / (1.0 + pow(r / 0.14, 2.0));
	vec3 col = irr * LITDUST * 0.6 + 0.25 * exp(-r / 0.3) * vec3(0.45, 0.58, 1.0);
	float al = m * 0.12 * fade;
	C = C * (1.0 - al) + col * al;
#endif
}
// the dust sheet under the disc (h = -0.03): dims the halo behind, faintly lit
// from the disc above
void underSheet(vec2 v, float la, inout vec3 C) {
#if !LOW
	if (u_gasAmt < 0.2) {
		return;
	}
	vec2 pu = sheetP(v, -0.03);
	float ru = length(pu);
	if (ru > 1.25) {
		return;
	}
	float n = noiseRawLA(kitRot(2.7) * pu * 0.7, la).r;
	float du = smoothstep(0.45, 0.8, n) * (1.0 - smoothstep(0.75, 1.2, ru)) * smoothstep(0.08, 0.25, ru);
	// (it is the disc's own dust: with the solid galaxy's dissolving edge it fades out
	// as the disc does, or it hung past the faded disc as dark blotches on the halo)
	if (u_edge.w > 0.0) {
		float t = smoothstep(u_edge.x, u_edge.y, ru);
		du *= (1.0 - t) * (1.0 - t);
	}
	float Iu = 0.12 * exp(-ru / 0.25) + 0.05 * exp(-ru / 0.4);
	C = C * exp(-du * 0.9) + du * Iu * LITDUST * 0.12 * (1.0 - 0.88 * nestZ() * (1.0 - smoothstep(0.06, 0.22, ru)));
#endif
}

// ------------------------------------------------------------------ events
vec3 supernova(vec2 v, ivec2 blk) {
	if (u_sn.z <= 0.0) {
		return vec3(0.0);
	}
	ivec2 b0 = blockOf(scr(solidV(u_sn.xy)));
	ivec2 d = blk - b0;
	float g = u_sn.z;
	vec3 c = vec3(0.0);
	float L = 3.0 + 3.0 * g;
	if (d.x == 0 && d.y == 0) {
		c += FLARE * 8.0 * g;
	} else if (d.x == 0 || d.y == 0) {
		float a = float(abs(d.x) + abs(d.y));
		if (a <= L) {
			c += FLARE * 2.4 * g * pow(1.0 - (a - 1.0) / L, 2.0);
		}
	}
	vec2 dv = (v - u_sn.xy) * u_zoom;
	float dd = length(dv);
	c += FLARE * g * (0.34 * exp(-dd / 3.0) + 0.05 * exp(-dd / 9.0) + 0.008 * exp(-dd / 24.0));
	return c;
}

// how many times the lens squeezes the sky behind at S (radially or round)
float lensSqueeze(vec2 S) {
	float b = max(length(S), 1e-3);
	float e = 0.02;
	float b2 = b + e;
	float g1 = lh_behind(S) * b;
	float g2 = lh_behind(S * (b2 / b)) * b2;
	return max(abs(g2 - g1) / e, lh_behind(S));
}
// THE STARS' LIGHT KEPT AS YOU ZOOM (`ChartSky._star_debt`): what the chart's
// stars bring a plane area at a zoom, from the bake's run of zooms; the light
// they brought at the opening less what they bring now goes back into the
// patch as diffuse starlight, so a patch is as bright as at the opening.
uniform sampler2D u_debt : filter_linear, repeat_disable;
uniform vec4 u_debtP = vec4(0.0, 1.0, 1.0, 1.25);   // ln first zoom, steps per ln, zooms, plane half-width
uniform bool u_debtOn = false;
uniform float u_zopen = 0.42;
vec3 debtAt(vec2 p, float z) {
	float f = clamp((log(z) - u_debtP.x) * u_debtP.y, 0.0, u_debtP.z - 1.0);
	float i0 = floor(f);
	float i1 = min(i0 + 1.0, u_debtP.z - 1.0);
	float N = float(textureSize(u_debt, 0).y);
	vec2 uv = clamp(p / u_debtP.w * 0.5 + 0.5, vec2(0.5 / N), vec2(1.0 - 0.5 / N));
	// (nothing past the table's edge: read clamped there, a star in an edge texel
	// was smeared out to infinity along the clamped axis, and drew a slanted beam
	// of faint light down from the top of the view into the galaxy, Jon, Oct 11)
	vec2 q = abs(p / u_debtP.w);
	float inside = 1.0 - smoothstep(0.88, 0.98, max(q.x, q.y));
	vec3 s0 = texture(u_debt, vec2((i0 + uv.x) / u_debtP.z, uv.y)).rgb;
	vec3 s1 = texture(u_debt, vec2((i1 + uv.x) / u_debtP.z, uv.y)).rgb;
	return mix(s0, s1, f - i0) / (z * z) * inside;
}
vec3 starDebt(vec2 p) {
	if (!u_stars_on || !u_debtOn || (u_diag & 18) != 0) {
		return vec3(0.0);
	}
	// (out in the disc, not in the bulge: there the light is the core's, which the
	// glare control already holds -- and the bulge's own stars come in from zoom 2 --
	// and laid over the gold round the hole it flickered on a slow zoom)
	return max(debtAt(p, min(u_zopen, u_zoom)) - debtAt(p, u_zoom), vec3(0.0)) * smoothstep(0.10, 0.22, length(p));
}
vec3 starAt(ivec2 sb) {
	if (!u_stars_on || sb.x < 0 || sb.y < 0 || sb.x >= int(u_vp_size.x) || sb.y >= int(u_vp_size.y)) {
		return vec3(0.0);
	}
	return texelFetch(u_stars, sb, 0).rgb;
}

// ------------------------------------------------------------------ remnants
// WHAT A SUPERNOVA LEAVES (`ChartSky.remnants`): a ragged shell, red outside and
// teal inside (the remnant clouds' colours), growing fast at first and slower
// after, fading out over ten minutes; at the least a block and a half wide and as
// bright as a remnant cloud's shell, so it reads at the opening, and in the
// galaxy's own units, so a zoom only magnifies it.
vec3 remnants(vec2 p) {
	vec3 c = vec3(0.0);
	float px = 1.0 / (u_zoom * u_k);
	for (int i = 0; i < 16; i++) {
		if (i >= u_nrem) {
			break;
		}
		vec4 rm = u_rem[i];
		vec2 d = p - rm.xy;
		float age = rm.z;
		float R = 0.008 + 0.036 * (1.0 - exp(-age / 150.0));
		float dl = length(d);
		if (dl > R * 1.8 + 4.0 * px) {
			continue;
		}
		float w = max(0.0035, 1.6 * px);
		float an = atan(d.y, d.x);
		// ragged and broken: the front wanders and the shell has gaps
		float Rr = R * (1.0 + 0.10 * kitSnoise2(vec2(an * 1.6, rm.w)));
		float x = (dl - Rr) / w;
		float shell = exp(-x * x) * (0.45 + 0.55 * smoothstep(-0.4, 0.3, kitSnoise2(vec2(an * 2.3, rm.w + 5.0))));
		float inside = (1.0 - smoothstep(Rr * 0.4, Rr, dl)) * 0.07;
		float life = smoothstep(1.5, 8.0, age) * exp(-age / 360.0) * (1.0 - smoothstep(480.0, 600.0, age));
		c += (mix(OIII, HA, smoothstep(-0.6, 0.6, x)) * shell * 1.6 + OIII * inside) * life;
	}
	return c;
}

// ------------------------------------------------------------------ fluff
// THE GAS WITH A BODY (`ChartSky.fluff`, SIMPLIFIED only until Jon approves; Jon:
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
// the fade's dither cell: the block a point of the flat view falls in, so through the
// solid galaxy's camera the dither travels with the disc as a drag turns it, rather
// than staying on the screen while the fade slides under it (that crawl doubled the
// pixels flipping on a drag)
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

// ------------------------------------------------------------------ the solid galaxy
// THE SOLID GALAXY (`ChartSky.solid`, SIMPLIFIED only until Jon approves): the chart
// seen through a real camera instead of laid flat like a tilted poster. The galaxy
// is painted as before in its flat ("orthographic") view, o, and each block of the
// screen looks it up through the camera: a camera `u_solidW.x` gu from the core, at
// the sector map's tilt plus a little pitch and moved a little to the side, so the
// near half of the disc is nearer and bigger and the far half smaller and squashed,
// and a drag turns the view: up and down a few degrees of pitch, and sideways a sway
// of the camera (looking the same way, its picture kept on the core), so the near rim
// slides one way and the far rim the other, as a real disc's do. One projection for the sky and for everything the
// chart draws over it (`ChartSky.solid_fwd` / `solid_inv` and `StarchartScreen`'s
// `_proj` / `_to_plane`). It fixes the galaxy's centre, so a zoom (which only
// magnifies the screen about its point) never changes it. u_solidW: camera distance
// (gu), sin and cos of its elevation, sway (gu) (the uniforms, u_solid and u_solidW,
// are at the top: the bulge reads them).
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
// ------------------------------------------------------------------ the galaxy
// `la`: how many mip levels coarser to read the bakes, for a point seen through
// the lens, where a wide patch of the disc is squeezed into a few blocks and the
// bakes read at the screen's own scale alias into flicker as the zoom moves
vec3 galaxy(vec2 v, vec2 vsky, vec2 vb, ivec2 sb, ivec2 blk, ivec2 dq, float la, out float dustOut) {
	vec3 C = VOIDC / u_exp;
	dustOut = 0.0;
	vec2 p = kitViewToPlane(v, u_phi, u_k);
	vec3 star = starAt(sb) + starDebt(p);
	float r = length(p);
	float irr = 1.0 / (1.0 + pow(r / 0.10, 2.0));
	bool ball = u_form == 1;
	vec3 T = vec3(1.0), B = vec3(0.0);
	float gas = 0.0, nest = 0.0, front = 0.0, bulgeI = 0.0;
	vec3 haloJ = vec3(0.0);
	// (each layer is called ONCE whatever the galaxy's shape: a call in each
	// branch inlines it twice and the shader took seconds longer to compile)
	if (ball) {
		vec3 Bb = ellBall(v, gas);
		// close in, the ball resolves into its stars and its diffuse light thins
		// (the core's glare only: the ball's heart, never its outskirts)
		Bb *= mix(1.0, 0.3, glareOn() * smoothstep(2.4, 6.0, u_zoom) * mix(1.0 - smoothstep(0.05, 0.30, r), 1.0, zoomChanges()));
		// (no blue halo under a ball: over its red outskirts it read mauve; the
		// ball's own envelope is its halo)
		C = C * exp(-kitLum(Bb) * 120.0) + Bb + star + tailLight(p) + knots(p) + remnants(p);
	} else {
		// (with the dissolving edge the halo is most of what shows past the faded disc,
		// and its faint edge met the palette's dark steps as one flat ellipse, a second
		// plate: it is dithered there, on the palette's anchored Bayer, as the fade is;
		// what the sky behind sees of it is the halo undithered, `haloJ` taken back out,
		// or the far galaxies behind it were cut to the same checker)
		vec3 hl = halo(v);
		haloJ = u_edge.w > 0.0 ? hl * 0.5 * (kitBayer4(edgeDq(v)) - 0.5) : vec3(0.0);
		C += hl + haloJ + tailLight(p);
		underSheet(v, la, C);
		vec3 Em;
		float A, dust;
		// (the gas where the eye meets it, through its height: `fluffSeen`)
		vec2 pf = fluffSeen(p);
		discAt(pf, v, hbOf(la), star, la, Em, T, gas, A, dust, nest);
		if (u_fluff > 0.0) {
			// lit as a body of cloud: its lit side toward the core, its shade away, its
			// creases, the rim of a puff catching the core's light
			vec3 fs = fluffShade(pf);
			Em *= fs.x;
			Em += LITDUST * vec3(1.0, 0.9, 0.8) * fs.y * gas * (0.012 + 0.05 * irr);
			// the puff's own lit gas, in the arm's colour (warm near the core)
			float rf = length(pf);
			vec3 gc = mix(vec3(0.30, 0.46, 1.0) * 0.05 * exp(-rf / 0.5), LITDUST * 0.12, 1.0 / (1.0 + pow(rf / 0.12, 2.0)));
			Em += gc * fs.z * u_fluff * 2.5;
		}
		// the outer disc dissolving into the dark (`edgeMask`): the disc's light and
		// dust fade, its stars stay; dithered (a step either way of the Bayer)
		float em = edgeMask(pf);
		if (em < 0.999) {
			em = clamp(em * (1.0 + 0.5 * (kitBayer4(edgeDq(v)) - 0.5)), 0.0, 1.0);
		}
		Em = Em * em + star * (1.0 - em);
		T = mix(vec3(1.0), T, em);
		gas *= em;
		dustOut = dust;
		float Ib;
		B = bulgeLight(vb, front, Ib);
		bulgeI = Ib;
		// the nest is puffed up round the hole: seen from our angle it hides the
		// bulge's middle, so the hole sits in a dark dusty pocket
		float sv = length(vec2(vb.x, vb.y / 0.86)) / u_k;
		float nv = (1.0 - smoothstep(0.010, 0.075, sv)) * nestZ() * clamp(u_laneStr, 0.0, 1.0);
		B *= exp(-4.2 * nv * (0.5 + 0.5 * clamp(nest * 1.6, 0.0, 1.0)) * vec3(0.85, 0.95, 1.0));
		// close in, the bulge resolves into its own stars, so its diffuse light thins
		// (and those stars are drawn: the light it loses comes back as them, warm,
		// so the core does not go to a flat dim plate as you near the hole)
		vec3 bStars = resolvedStars(p, v, hbOf(la), la, kitLum(B) * 0.6, 0.0, 1);
		// (THE ONE THING THE ZOOM STILL TURNS DOWN: the core's own glare, so the gold
		// does not wash out round the hole. It touches the bulge's light alone, never
		// the gas, dust or stars round it -- and only where that light is the gold
		// itself (`Ib` over 0.003, in full from 0.07): turned down everywhere, the
		// bulge's faint outer halo over the arms went with it, and the gas just
		// outside the bulge darkened 0.6 as you zoomed, Oct 11. The step is spread
		// over a factor of 23 in the light so the turned-down gold never dips
		// below the halo beside it. The palette's probes turn it down as before, so the
		// cut, and the opening it colours, are the approved ones.)
		float goldM = mix(1.0, smoothstep(-5.81, -2.66, log(max(Ib, 1e-6))), resolveOn());
		B *= mix(1.0, 0.10, glareOn() * smoothstep(2.4, 6.0, u_zoom) * goldM);
		float bm = 0.5 + 0.5 * fbm2F(p * 9.0 + vec2(2.7, 8.1), max(4.0 - la, 1.0));
		// (and the mottle keeps resolving past its fourth octave as you near the core)
		bm += u_stars_on ? 0.4 * ((u_diag & 4) != 0 ? 0.0 : crDetail(p, blockGu(la), 0.012, 13.0)) : 0.0;
		B *= mix(1.0, max(0.62 + 0.76 * bm, 0.25), smoothstep(0.03, 0.10, sv));
		C += B * (1.0 - front);
		Em += knots(pf);
		Em += remnants(p);
		// the supernova's light echo: a ring sweeping out through the gas and dust
		if (u_echo.w > 0.0) {
			float de = length(p - u_echo.xy) - u_echo.z;
			float ring = exp(-de * de / (0.002 * 0.002));
			float dd = 1.0 - kitLum(T);
			Em += FLARE * u_echo.w * ring * (0.15 + 0.8 * gas + 2.6 * dd) * 0.5;
		}
		C = C * T + Em;
		C = max(C + bStars * mix(T, vec3(1.0), front), vec3(0.0));
	}
	vec3 cloudT = vec3(1.0);
	cloudLayer(v, irr, gas, C, cloudT);
	if (!ball) {
		float nuc = 1.0 - smoothstep(0.05, 0.11, r);
		// (through the camera the top of the bulge stands in front of the far side
		// of the disc and hides it, rather than only adding its light over it)
		float occ = u_solid ? 0.8 * front * smoothstep(0.003, 0.05, bulgeI) : 0.0;
		C = C * (1.0 - occ) + B * front * mix(vec3(1.0), T, max(nuc * (1.0 - 0.25 * front), 0.62)) * exp(-5.5 * nest * vec3(0.80, 0.92, 1.0)) * mix(vec3(1.0), cloudT, 0.97);
		billowLayer(v, dq, C);
		wispLayer(v, la, C);
	}
	vec3 frontL = max(C - VOIDC / u_exp - haloJ * T, vec3(0.0));
	// (the far nebulae keep clear of the galaxy by its light, `bgNebSeen`; with the
	// dissolving edge that light fades out over a long stretch, so they also keep
	// clear of where the disc is, out past the fade's end)
	float nebGap = (u_edge.w > 0.0 && !ball) ? smoothstep(u_edge.y + 0.05, u_edge.y + 0.45, r) : 1.0;
	C += farSky(vsky, la, bgNebSeen(frontL, u_exp) * nebGap) * T * cloudT * bgSeen(frontL, u_exp);
	return grade(max(mix(vec3(kitLum(C)), C, SAT), 0.0)) + supernova(v, blk);
}

vec3 place(vec2 v, vec2 vsc, ivec2 blk, ivec2 dq) {
	float shadow = u_holeR * u_k;                        // the shadow's radius, view px
	// THE CORE AS IT IS, through the solid galaxy's camera: about the core's place on
	// the screen at the camera's one scale there (`solidCoreK`), so the hole, its lens
	// and the bulge keep their shape however the perspective stretches the disc round
	// them; what the lens shows behind is read back through the camera, and at the
	// lens's edge, where it bends nothing, the two agree. (With the camera off this is
	// the flat view itself.)
	vec2 pc = solidV(vec2(0.0));
	float kc = solidCoreK();
	vec2 vh = u_solid ? (vsc - pc) / kc : v;
	vec2 S = lh_to_s(vh, vec2(0.0), shadow);
	// ONE call of the galaxy, at the point seen through the lens or at v: two
	// calls (one per branch) inlined the whole galaxy twice and doubled the
	// shader's compile time
	bool lens = length(S) <= lh_dims.x * 0.97;
	// what lies behind is lensed: the strong bend fades to nothing at the patch edge
	vec2 vbh = lens ? vh * lh_behind(S) : vh;
	vec2 vbs = u_solid ? pc + vbh * kc : vbh;            // where that lies on the screen (view px)
	vec2 vbg = lens ? solidO(vbs) : v;
	// (the stars behind are read where the lens shows them; holding them on a
	// coarser grid while the zoom moves drew them as dashes, so they are not)
	ivec2 sb = lens ? blockOf(scr(vbs)) : blk;
	// (read twice as coarse through the lens as it squeezes: the gas round the hole now
	// keeps its light and structure deep in, Oct 11, and squeezed into a few blocks
	// it shimmered as the zoom moved; the palette's probes read it as before, and so
	// does the opening view, which is left exactly as it was)
	float la = lens ? log2(max(lensSqueeze(S), 1.0)) * (1.0 + resolveOn() * smoothstep(0.5, 1.5, u_zoom)) : 0.0;
	float dust;
	vec3 C = galaxy(vbg, lens ? vbs : vsc, vbh, sb, blk, dq, la, dust);
	// the near side's dust lane, before the hole's own disc and shadow are laid over
	// (so it never darkens them), and read where the lane is, not through the lens
	if (u_solid && u_form != 1) {
		C *= solidLane(v);
	}
	if (!lens) {
		return C;
	}
	C *= lh_cool_chart(S, smoothstep(3.0, 6.0, u_zoom) * ((u_diag & 128) != 0 ? 0.0 : 1.0), (u_diag & 1024) != 0 || !u_stars_on) * lh_squeeze(S);
	// the disc lights the gas round it, hardest on the dense dust
	C += u_bCore * vec3(1.0, 0.55, 0.32) * (0.05 + 0.12 * dust) * lh_glow(S);
	float cap;
	vec4 d = lh_disc(S, lh_px_rs(shadow * u_zoom * kc), u_time, smoothstep(2.6, 4.0, u_zoom) * ((u_diag & 128) != 0 ? 0.0 : 1.0), lh_hot(u_time, u_wxOn), cap);
	C *= 1.0 - cap;                                      // the shadow: round, black, no rim line
	if (d.a > 0.004) {
		C = C * (1.0 - d.a) + lh_exact_hdr(d.rgb, u_exp) * d.a;
	}
	return C;
}

void fragment() {
	ivec2 blk = ivec2(floor(UV * u_vp_size));
	vec2 s = u_vp_origin + (vec2(blk) + 0.5) * 2.0;    // the block's centre, chart px
	vec2 v = (s - u_cpix) / u_zoom;
	// the dither index, anchored to the galaxy's centre (as the composite's)
	ivec2 dq = blk + ivec2(u_block0);
	vec3 C = place(solidO(v), v, blk, dq);
	// (`ChartSky.diag` 4096, a test's: the point of the disc's plane this block
	// shows, in place of its light, so the chart's marks can be checked against it)
	if ((u_diag & 4096) != 0) {
		vec2 pp = kitViewToPlane(solidO(v), u_phi, u_k);
		COLOR = vec4(pp, 0.0, 1.0);
	} else if (u_tone_out) {
		COLOR = vec4(kitToSrgb(kitTone(C * u_exp, u_burn)), 1.0);
	} else {
		COLOR = vec4(max(C, vec3(0.0)), 1.0);
	}
}
