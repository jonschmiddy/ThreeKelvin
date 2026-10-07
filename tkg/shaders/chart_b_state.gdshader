shader_type canvas_item;
render_mode unshaded, blend_disabled;

// THE PAINTED CHART'S BAND MEMORY (`ChartSky`, style PAINTED): band-edge
// hysteresis, so a band edge never flickers as the view moves. A block keeps
// the band it had until its light moves `hys` past the band's edge, and gives
// it up anyway after `hold` frames (the lock must let go, or a slow gradient
// freezes). The state is last frame's picture of this same viewport (it is
// never cleared), one texel a block, addressed by the block's place on the
// galaxy (wrapped round the viewport), so a pan carries every block's memory
// with it: (material / 255, band / 15, frames held / 255, which wrap / 255).
//
// AND IT TURNS WITH THE GALAXY (Jon: PAINTED "has weird pops as it rotates,
// it's not smooth"). A memory pinned to the screen held each band where the
// picture had been while the galaxy turned out from under it, then let whole
// runs of an edge go at once. Each block now reads what it remembered from
// where its piece of the galaxy stood a frame ago (the plane turned back by
// the frame's turn, `phi_d`), so a held band rides with the gas it belongs
// to; and how long a block may hold is its own (`hold` times 0.55 to 1.45 by a
// hash of its place), so no stretch of an edge is let go on one frame.
//
// AND IT ZOOMS WITH IT (Jon: "when zooming in and out of painted, it seems
// like the clouds change quite frequently"). A zoom holds the block grid to
// the screen, so every block read the memory of the screen block it sat on
// while the gas grew out from under it: about 5% of the picture kept bands
// from where the gas had been, and once the zoom stopped they were let go over
// the next second and a half -- the cloud changing on its own after every turn
// of the wheel. Each block now reads the memory of where its piece of the
// galaxy was drawn last frame, through last frame's view (`zoom0`, `cpix0`,
// `origin0`, `block00`): the same mapping as the turn's, and the identity when
// nothing moved. And what the zoom truly changed (the gas redrawn at a new
// scale, its finest octaves fading in or out) is let go while the zoom moves:
// `hold` is cut by how far the zoom moved the frame (`ChartPainted.push`).
//
// BANDS AS A PAINTER DRAWS THEM (Jon: "still has harsh seams"): a block's light
// is first averaged with its neighbours of the same material (3x3, the middle
// weighted), so a band's edge follows the light's own smooth contour instead
// of every wobble of its texture -- round curves at the block's scale, no one-
// block teeth -- and the step to the next band is placed with a small ordered
// offset per block, so along a shallow diagonal the edge breaks up gently
// instead of running as a long stair, and as the galaxy turns the blocks of an
// edge cross one at a time instead of a whole run at once. How far into its
// band each block's light is goes out too, for the paint pass to place its
// checker transitions only where the light truly nears the next band.
// Out: (material / 255, band / 15, (frames held + 64 x quarter into the band) / 255, wrap / 255).

uniform sampler2D prev_state : hint_screen_texture, filter_nearest;
uniform sampler2D gbuf : filter_nearest;
uniform int u_mlen[24];
uniform vec2 vp_size = vec2(330.0, 220.0);
uniform vec2 block0 = vec2(0.0);
uniform float hys = 0.06;
uniform float hold = 40.0;
uniform bool reset = false;
// THE TURN: how far the galaxy turned since the last frame (radians), and the
// view to undo it in -- the place pass's frame origin, the galaxy centre's
// pixel and the zoom (`chart_b_place`'s u_vp_origin, u_cpix, u_zoom)
uniform float phi_d = 0.0;
uniform vec2 origin = vec2(-2.0);
uniform vec2 cpix = vec2(327.0, 214.0);
uniform float zoom = 1.0;
// last frame's view: its zoom, galaxy centre pixel, frame origin and block anchor
uniform float zoom0 = 1.0;
uniform vec2 cpix0 = vec2(327.0, 214.0);
uniform vec2 origin0 = vec2(-2.0);
uniform vec2 block00 = vec2(0.0);
const float TILT = 0.38;
// the ordered offset of a band step, in bands (see BANDS AS A PAINTER DRAWS THEM)
const float JIT = 0.16;

// a modulo that wraps negative numbers (GLSL leaves % of a negative undefined)
ivec2 pmod(ivec2 a, ivec2 s) {
	return a - s * ivec2(floor(vec2(a) / vec2(s)));
}

// the materials whose bands are smoothed: the masses of light (not the sky's
// tints and far sprites, the sparkles, the hole's own rings or the bolt)
bool smoothMat(int m) { return m >= 1 && m <= 11 && m != 2; }
float bayer4(ivec2 b) {
	const float B[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	ivec2 q = b & ivec2(3);
	return (B[q.y * 4 + q.x] + 0.5) / 16.0;
}

float hashB(ivec2 p) {
	uint h = uint(p.x) * 374761393u + uint(p.y) * 668265263u;
	h = (h ^ (h >> 13u)) * 1274126177u;
	return float((h ^ (h >> 16u)) & 0xffffu) / 65535.0;
}

void fragment() {
	ivec2 size = ivec2(vp_size);
	ivec2 slot = ivec2(floor(UV * vp_size));
	ivec2 b0 = ivec2(block0);
	ivec2 local = pmod(slot - b0, size);
	ivec2 absb = local + b0;
	ivec2 wrap = ivec2(floor(vec2(absb) / vp_size)) & ivec2(15);
	float tag = float(wrap.x * 16 + wrap.y);
	// where this block's piece of the galaxy stood last frame (the plane turned
	// back), and that block's memory
	ivec2 from = slot;
	float ftag = tag;
	if (phi_d != 0.0 || zoom0 != zoom || cpix0 != cpix || origin0 != origin || block00 != block0) {
		vec2 v = (origin + (vec2(local) + 0.5) * 2.0 - cpix) / zoom;
		vec2 q = vec2(v.x, v.y / TILT);
		float c = cos(phi_d), sn = sin(phi_d);
		vec2 r = vec2(c * q.x + sn * q.y, -sn * q.x + c * q.y);
		vec2 s2 = cpix0 + vec2(r.x, r.y * TILT) * zoom0;
		ivec2 abs2 = ivec2(floor((s2 - origin0) * 0.5)) + ivec2(block00);
		from = pmod(abs2, size);
		ivec2 w2 = ivec2(floor(vec2(abs2) / vp_size)) & ivec2(15);
		ftag = float(w2.x * 16 + w2.y);
	}
	vec4 g = texelFetch(gbuf, local, 0);
	int m = clamp(int(g.r * 255.0 + 0.5), 0, 23);
	int n = max(u_mlen[m], 1);
	float lv = g.g;
	// (the far sky's sprites, sid 251, keep their own few blocks as drawn)
	int gsid = int(g.b * 255.0 + 0.5);
	bool far = gsid == 251;
	// (an arm's own gas keeps its texture -- its bright young stars are the detail
	// of it -- and only its heaps of billows are smoothed)
	bool soft = smoothMat(m) && !far && (m != 1 || gsid != 0);
	if (soft) {
		float sw = 4.0;
		float sl = lv * 4.0;
		for (int j = -1; j <= 1; j++) {
			for (int i = -1; i <= 1; i++) {
				if (i == 0 && j == 0) {
					continue;
				}
				vec4 gn = texelFetch(gbuf, clamp(local + ivec2(i, j), ivec2(0), size - 1), 0);
				if (int(gn.r * 255.0 + 0.5) == m) {
					float w = (i == 0 || j == 0) ? 2.0 : 1.0;
					sl += gn.g * w;
					sw += w;
				}
			}
		}
		lv = sl / sw;
	}
	// the step to the next band placed with a small ordered offset per block
	// (its place on the galaxy's block grid, so a pan carries it)
	float jit = soft ? (bayer4(absb) - 0.5) * JIT : 0.0;
	int raw = clamp(int(floor(lv * float(n) + jit)), 0, n - 1);
	vec4 p = texelFetch(prev_state, from, 0);
	int pm = int(p.r * 255.0 + 0.5);
	int pb = int(p.g * 15.0 + 0.5);
	float cnt = mod(floor(p.b * 255.0 + 0.5), 64.0);
	float ptag = floor(p.a * 255.0 + 0.5);
	int band = raw;
	float c2 = 0.0;
	if (!reset && pm == m && ptag == ftag && pb != raw && pb < n) {
		float lo = float(pb) / float(n) - hys, hi = float(pb + 1) / float(n) + hys;
		if (lv > lo && lv < hi && cnt < hold * (0.55 + 0.9 * hashB(absb))) {
			band = pb;
			c2 = cnt + 1.0;
		}
	}
	// how far into the band it holds the block's light is, in quarters
	float into = clamp(lv * float(n) - float(band), 0.0, 0.999);
	COLOR = vec4(float(m) / 255.0, float(band) / 15.0, (min(c2, 63.0) + 64.0 * floor(into * 4.0)) / 255.0, tag / 255.0);
}
