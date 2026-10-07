shader_type canvas_item;
render_mode unshaded, blend_disabled;

// THE PAINTED SECTOR MAP'S BAND MEMORY (`SectorPainted`, style PAINTED), one
// texel a block. The far picture -- the sky, the cloud, the dust sheets, the
// weather in them, all drawn as SIMPLIFIED draws them into their own viewport
// -- is read here a block at a time and each block given one entry of the
// scene's curated palette (bible 4.2, never cut): the nearest, in OKLab. A
// block KEEPS the entry it had while that entry is still within `hys` of the
// nearest, and gives it up after `hold` frames anyway (the lock must let go, or
// a slow gradient freezes), so a band edge never flickers as the light moves.
// The memory is last frame's picture of this same viewport (never cleared).
//
// IT RIDES WITH THE CLOUD, AND IT NEVER HOLDS A BAND BEHIND A MOVING LIGHT
// (Jon: "If I change the magnification on painted and then pan left or right
// I get some lag in the nebula"; "when zooming in and out of painted, it seems
// like the clouds change quite frequently"). The memory was pinned to the
// screen and held every band edge it could for 40 frames whatever moved. The
// sun's light moves with the plane -- a pan carries it across the gas at the
// pan's own speed, a zoom opens it out -- so the lit bands' edges were held
// where the light had been, a crescent of the hot zone trailing the sun (56 px
// wide at the median of a 6 px-a-frame pan at zoom 2.5, 108 at worst; 4 and 18
// now); and every block caught on the same frame was let go
// on the same frame 40 later, so after a zoom whole stretches of the cloud
// changed at once. Now a block reads its memory from where its piece of the
// cloud stood last frame (`slide`, the cloud's slide in blocks); `hold` is
// cut by the caller to what the light moved this frame (a band edge may trail
// it by about a block, `SectorPainted.push`), and each block's own hold is
// `hold` times 0.55 to 1.45 by a hash of its place on the sky, so no stretch
// of an edge is let go on one frame.
//
// Also marked here, for the paint: which blocks are stars, and how grand a
// sparkle each one gets (bible 4.1: tier 1 a block, 2 a plus, 3 a four-point
// star with glints, at most a dozen on screen).
//
// Out: (entry / 255, frames held / 255, star tier / 3, 1).

uniform sampler2D prev_state : hint_screen_texture, filter_nearest;
uniform sampler2D src : filter_nearest;
uniform vec3 u_lab[96];
uniform int u_n = 1;
// entries a star centre may take (the sparkle ramp)
uniform int u_star0 = 0;
uniform int u_star_n = 0;
uniform float hys = 0.03;
uniform float hold = 40.0;
uniform bool reset = false;
// how far the far picture slid since the last frame, in blocks: last frame's
// memory of this block's piece of the sky is at b + slide
uniform vec2 slide = vec2(0.0);
// the far picture's slide in blocks: the sparkles' rarity hash rides the sky
uniform vec2 sky_blk = vec2(0.0);
uniform bool low = false;
// how much the far picture's chroma is pushed before it is matched (`SectorPainted.chroma_boost`)
uniform float cboost = 1.0;
// a clear sky: more of its stars wear pluses and sparkles (B's start view: the
// brightest of the near fields are four-point stars, a dozen to a screen)
uniform bool calm = false;
// THE STAR'S LIGHT ON A CLEAR SKY (B's halo): four warm rings stepped out round
// the star, the last a thin checker into the black, set here by where a block
// is, never by its colour (matched, the band's navy caught the faintest ring's
// plum, and the rings came out wherever the glow happened to cross a step).
// The first of the four entries (-1 none), the star in the place picture's
// pixels, and its drawn radius (B's rings at 1.6, 2.3, 3.2 and 4.4 of it, round:
// a light, not the plane).
uniform int u_halo0 = -1;
uniform vec2 star_px = vec2(480.0, 270.0);
uniform float sun_r = 10.0;
// THE GALAXY'S BAND ON A CLEAR SKY (B's): two tones of navy across the view,
// broad and wandering, the inner tone in lumps, and the far gas's faint wisps
// in it, set here by where a block lies on the sky (the far picture's glow,
// matched, came out as one flat plate with a cut edge). The band's normal and
// offset per system, and the wisps' entries (-1 none).
uniform vec2 band_n = vec2(0.387, 0.922);
uniform float band_off = -60.0;
uniform int u_wisp0 = -1;

vec3 lin(vec3 c) { return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c)); }
vec3 oklab(vec3 c) {
	vec3 l3 = lin(c);
	float l = pow(max(0.4122214708 * l3.r + 0.5363325363 * l3.g + 0.0514459929 * l3.b, 0.0), 1.0 / 3.0);
	float m = pow(max(0.2119034982 * l3.r + 0.6806995451 * l3.g + 0.1073969566 * l3.b, 0.0), 1.0 / 3.0);
	float s = pow(max(0.0883024619 * l3.r + 0.2817188376 * l3.g + 0.6299787005 * l3.b, 0.0), 1.0 / 3.0);
	return vec3(0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
		1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
		0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s);
}
// (chroma counts a little more than lightness: a dim rose must stay rose, not
// fall to the nearest grey-violet of the same lightness)
float dist2(vec3 a, vec3 b) {
	vec3 d = (a - b) * vec3(1.0, 1.35, 1.35);
	return dot(d, d);
}
float lum(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }
float hsh(vec2 p) {
	uvec2 q = uvec2(ivec2(p) + 65536);
	uint h = (q.x * 374761393u) ^ (q.y * 668265263u);
	h = (h ^ (h >> 13u)) * 1274126177u;
	return float(h ^ (h >> 16u)) / 4294967296.0;
}

// value noise, -1..1
float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hsh(i), b2 = hsh(i + vec2(1.0, 0.0)), c2 = hsh(i + vec2(0.0, 1.0)), d = hsh(i + vec2(1.0));
	return mix(mix(a, b2, f.x), mix(c2, d, f.x), f.y) * 2.0 - 1.0;
}

void fragment() {
	ivec2 b = ivec2(floor(UV * vec2(480.0, 270.0)));
	vec3 c = texelFetch(src, b, 0).rgb;
	vec3 L = oklab(c);
	// (not in the dark: a near-black pushed picked tinted darks and the void set in
	// blue and brown plates)
	L.yz *= mix(1.0, cboost, smoothstep(0.16, 0.34, L.x));
	// A STAR: a block much brighter than all four round it
	float lc = lum(c);
	float ln = max(max(lum(texelFetch(src, b + ivec2(1, 0), 0).rgb), lum(texelFetch(src, b - ivec2(1, 0), 0).rgb)),
		max(lum(texelFetch(src, b + ivec2(0, 1), 0).rgb), lum(texelFetch(src, b - ivec2(0, 1), 0).rgb)));
	int tier = 0;
	// (dim stars too, a block each in the stars' own dim steps: B's sky is a fine
	// sprinkle of warm and cool stars, and the dim ones fell to the void)
	if (lc > 0.12 && lc - ln > 0.07 && u_star_n > 0) {
		tier = 1;
		float h = hsh(vec2(b) + sky_blk);
		float t2 = calm ? 0.42 : 0.70, t3 = calm ? 0.55 : 0.85;
		if (!low && lc > t2 && h < (calm ? 0.4 : 0.22)) tier = 2;
		if (!low && lc > t3 && h < (calm ? 0.16 : 0.05)) tier = 3;
		// in bright gas only the grandest: a speck of every young star there read as
		// a field of crosses
		if (ln > 0.3 && tier < 3) tier = 0;
	}
	int i0 = tier > 0 ? u_star0 : 0;
	int i1 = tier > 0 ? u_star0 + u_star_n : u_n;
	int best = i0;
	float bd = 1e9;
	for (int i = 0; i < 96; i++) {
		if (i >= i1) break;
		if (i < i0) continue;
		// (the stars' own steps are for stars alone: a cloud matched to them turned olive and slate)
		if (tier == 0 && i >= u_star0 && i < u_star0 + u_star_n) continue;
		if (u_halo0 >= 0 && i >= u_halo0 && i < u_halo0 + 4) continue;
		if (u_wisp0 >= 0 && i >= u_wisp0 && i < u_wisp0 + 2) continue;
		float e = dist2(L, u_lab[i]);
		if (e < bd) {
			bd = e;
			best = i;
		}
	}
	// the band, on the black (B's rule, on the sky's own place: it slides with it)
	bool ring = false;
	if (calm && tier == 0 && best == 0) {
		vec2 wl = (vec2(b) + sky_blk) * 2.0 + 1.0 - vec2(480.0, 270.0);
		float wob = 0.26 * vn(wl / 260.0) + 0.14 * vn(wl / 90.0 + 3.0);
		float e = abs(dot(wl, band_n) - band_off) / (190.0 * (1.0 + 0.45 * vn(wl / 520.0 + 9.0))) + wob;
		if (e < 1.0) {
			best = 1;
			ring = true;
		}
		if (e < 0.46 && vn(wl / 140.0 + 5.0) > -0.45) best = 2;
		// and the far gas's wisps, a few faint streaks along the band's heart
		// (long along the band, thin across it: in the sky's own square lattice they
		// came out as violet plates)
		vec2 bt = vec2(dot(wl, vec2(band_n.y, -band_n.x)), dot(wl, band_n));
		bt += 36.0 * vec2(vn(wl / 130.0 + 41.0), vn(wl / 130.0 + 57.0));
		float w = 0.65 * vn(bt / vec2(150.0, 30.0) + 13.0) + 0.35 * vn(bt / vec2(55.0, 14.0) + 29.0);
		if (u_wisp0 >= 0 && e < 0.42 && w > 0.4) best = u_wisp0;
	}
	// the halo's rings, over the sky's own steps (the black and the band)
	if (u_halo0 >= 0 && tier == 0) {
		vec2 sv = vec2(b) * 2.0 + 1.0 - star_px;
		// (B's sun is drawn bigger than ours: its rings by a third more)
		float d = length(sv) / max(sun_r * 1.35, 1.0);
		vec2 dir = sv / max(length(sv), 1e-3);
		d *= 1.0 - 0.04 * vn(dir * 3.0 + 21.0);
		int lv = d < 1.6 ? 4 : (d < 2.3 ? 3 : (d < 3.2 ? 2 : (d < 4.4 || (d < 5.6 && ((b.x + b.y) & 1) == 0 && hsh(vec2(b) + sky_blk) < 0.5) ? 1 : 0)));
		if (lv > 0) {
			best = u_halo0 + lv - 1;
			ring = true;
		}
	}
	ivec2 pb = b + ivec2(round(slide));
	// (a block that slid in from off the edge has no memory)
	vec4 p = (pb.x < 0 || pb.y < 0 || pb.x >= 480 || pb.y >= 270) ? vec4(0.0) : texelFetch(prev_state, pb, 0);
	int pe = int(p.r * 255.0 + 0.5);
	float cnt = floor(p.g * 255.0 + 0.5);
	int e = best;
	float c2 = 0.0;
	if (!reset && tier == 0 && !ring && p.a > 0.5 && pe != best && pe < u_n && cnt < hold * (0.55 + 0.9 * hsh(vec2(b) + sky_blk + vec2(311.0, 173.0)))) {
		if (sqrt(dist2(L, u_lab[pe])) < sqrt(bd) + hys) {
			e = pe;
			c2 = cnt + 1.0;
		}
	}
	COLOR = vec4(float(e) / 255.0, c2 / 255.0, float(tier) / 3.0, 1.0);
}
