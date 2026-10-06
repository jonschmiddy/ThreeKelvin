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

uniform sampler2D prev_state : hint_screen_texture, filter_nearest;
uniform sampler2D gbuf : filter_nearest;
uniform int u_mlen[24];
uniform vec2 vp_size = vec2(330.0, 220.0);
uniform vec2 block0 = vec2(0.0);
uniform float hys = 0.06;
uniform float hold = 40.0;
uniform bool reset = false;

// a modulo that wraps negative numbers (GLSL leaves % of a negative undefined)
ivec2 pmod(ivec2 a, ivec2 s) {
	return a - s * ivec2(floor(vec2(a) / vec2(s)));
}

void fragment() {
	ivec2 size = ivec2(vp_size);
	ivec2 slot = ivec2(floor(UV * vp_size));
	ivec2 b0 = ivec2(block0);
	ivec2 local = pmod(slot - b0, size);
	ivec2 absb = local + b0;
	ivec2 wrap = ivec2(floor(vec2(absb) / vp_size)) & ivec2(15);
	float tag = float(wrap.x * 16 + wrap.y);
	vec4 g = texelFetch(gbuf, local, 0);
	int m = clamp(int(g.r * 255.0 + 0.5), 0, 23);
	int n = max(u_mlen[m], 1);
	float lv = g.g;
	int raw = clamp(int(floor(lv * float(n))), 0, n - 1);
	vec4 p = texelFetch(prev_state, slot, 0);
	int pm = int(p.r * 255.0 + 0.5);
	int pb = int(p.g * 15.0 + 0.5);
	float cnt = floor(p.b * 255.0 + 0.5);
	float ptag = floor(p.a * 255.0 + 0.5);
	int band = raw;
	float c2 = 0.0;
	if (!reset && pm == m && ptag == tag && pb != raw && pb < n) {
		float lo = float(pb) / float(n) - hys, hi = float(pb + 1) / float(n) + hys;
		if (lv > lo && lv < hi && cnt < hold) {
			band = pb;
			c2 = cnt + 1.0;
		}
	}
	COLOR = vec4(float(m) / 255.0, float(band) / 15.0, c2 / 255.0, tag / 255.0);
}
