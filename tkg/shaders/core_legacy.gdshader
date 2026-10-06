shader_type canvas_item;
render_mode unshaded, blend_disabled;

// THE CORE'S BLACK HOLE ON THE SYSTEM MAP, every style (`CoreLegacy`): direction C's
// hole, Jon's pick for every style ("This is the best black hole rendition we
// have gotten. I love this shape and perspective."), from the shared include
// the star chart draws its core with (`legacy_hole.gdshaderinc`): a wide round
// shadow seen at the plane's tilt, a thick banded ring (cream, amber, orange,
// red-brown), the lensed underside arc two bands cooler, rings of gas slipping
// past one another, clumps falling in, a hot spot now and then.
//
// Sized among the orbits: the shadow's radius `hole_px` on the map, so the
// disc's outer edge (three shadow radii) is where the fabric and the orbit
// lines stop round it. Grounded, as Jon asked of the hole before ("it looks
// copy + pasted in"): the map behind it -- nebula, stars, grid, orbits, far
// worlds -- is read back off the screen and bent through the hole's own lens,
// squeezed dark round the shadow so the disc reads against it, and lit by the
// disc in warm stepped light.
//
// Drawn among the worlds, over a square round the hole, after a copy of the
// screen; in the place's 2x2 blocks (one fragment a block). Outside the lens's
// reach nothing is written.

uniform sampler2D screen : hint_screen_texture, filter_nearest, repeat_disable;
// the hole's centre in the place's own pixels (blocks), and map px to a block
uniform vec2 centre_scene = vec2(240.0, 135.0);
uniform float px_scale = 2.0;
// the shadow's radius, map pixels
uniform float hole_px = 38.67;
uniform float time = 0.0;
// the hot spot every 30 s (0 with reduced motion)
uniform float hot_on = 1.0;
// THE WEATHER (`SkyWeather`): a hot spot riding the disc (radius in the old
// hole's map px at `drawn_zoom`, angle, strength), a flash running round the
// photon ring (its angle, its age; -1 none), the flare echo's swell
uniform vec4 hs = vec4(0.0);
uniform vec2 rf = vec2(0.0, -1.0);
uniform float breath_add = 0.0;
uniform float kz = 1.0;
// PAINTED (direction B, as the painted chart draws this hole): the disc in its
// own bands and nothing between them -- a thin edge a checker over what is
// behind, never half alpha, its darkest band left out (drawn solid it was a dark
// rim round the disc) -- the lensed sky read as the paint pass left it, the thin
// dark ring round the shadow in one step, no dithered glow; the flare's flash a
// band hotter where it runs.
uniform bool painted = false;
uniform bool warm_glow = false;

#include "res://shaders/legacy_hole.gdshaderinc"

const float BAY[4] = float[](0.0, 2.0, 3.0, 1.0);

vec3 to_lin(vec3 s) { s = max(s, 0.0); return mix(s / 12.92, pow((s + 0.055) / 1.055, vec3(2.4)), step(0.04045, s)); }
vec3 to_srgb(vec3 c) { c = max(c, 0.0); return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c)); }
float hd_adiff(float a, float b) { return abs(mod(a - b + LH_PI, LH_TAU) - LH_PI); }

void fragment() {
	vec2 here = floor(FRAGCOORD.xy) + 0.5;
	vec2 d = (here - centre_scene) * px_scale;
	vec2 S = lh_to_s(d, vec2(0.0), hole_px);
	if (length(S) > lh_dims.x * 0.97) discard;
	ivec2 ip = ivec2(floor(FRAGCOORD.xy));
	float dth = (BAY[(ip.y & 1) * 2 + (ip.x & 1)] + 0.5) / 4.0;
	// THE MAP BEHIND, BENT: read where the lens says this block shows
	vec2 src = centre_scene + (here - centre_scene) * lh_behind(S);
	// SOFTENED NEAR THE HOLE: the gas bent into rings under the disc read as a
	// dish its shadow sat in, its rings drawn hard. Near the shadow the bent sky
	// is dimmed and its colour drawn together, so the rings are a low murmur of
	// light round the hole. (Blurred from five reads, it shimmered on every zoom:
	// each read crossed the dither on its own.)
	src = clamp(floor(src), vec2(0.0), 1.0 / SCREEN_PIXEL_SIZE - 1.0);
	vec3 C = to_lin(textureLod(screen, (src + 0.5) * SCREEN_PIXEL_SIZE, 0.0).rgb);
	float rr0 = length(S) / LH_SHADOW;
	// (under the disc only, where the rings showed: above it the disc hides
	// them, and round its sides the gas it lights stays lit)
	float soft = (1.0 - smoothstep(2.6, 5.5, rr0)) * smoothstep(0.15, -0.45, S.y / max(length(S), 1e-3));
	float lum0 = dot(C, vec3(0.2126, 0.7152, 0.0722));
	// (its brightness drawn toward a dim even tone, so the rings lose their edges)
	float lumS = mix(lum0, 0.02, 0.75 * soft);
	C = mix(C, vec3(lumS) * vec3(1.05, 0.95, 0.9), 0.75 * soft) * (1.0 - 0.88 * soft);
	// squeezed into a thin dark ring round the shadow (in steps, so it stays pixel art)
	float sq = lh_squeeze(S);
	sq = floor(sq * 5.0 + dth) / 5.0;
	C *= lh_cool(S, 0.6) * sq;
	// the disc's warm light on what is round it: it lights the gas there (the
	// cloud's own light already falls off from the disc), never the empty dark
	float gw = lh_glow(S) * (1.0 + 0.8 * breath_add);
	// (`warm_glow`, all but LEGACY: the light by its strength on the gas, in the
	// disc's own amber -- multiplied into the gas's mauve it came out salmon-pink)
	vec3 gc = warm_glow ? vec3(dot(C, vec3(0.45, 0.4, 0.15))) : C;
	C += gc * vec3(1.0, 0.55, 0.25) * floor(gw * 6.0 + 0.5) / 6.0 * 2.2;
	// THE HOLE: its own hot spot, or the weather's riding the disc (the old
	// hole's radii mapped onto this disc's: 1.16 .. 7.3 shadow radii to 3 .. 7.8 rs)
	vec3 hot = lh_hot(time, hot_on);
	if (hs.z > hot.y) {
		float u = hs.x / max(15.0 * kz, 1e-3);
		hot = vec3(hs.y, hs.z, 3.0 + clamp((u - 1.16) / 6.14, 0.0, 1.0) * 4.8);
	}
	float cap;
	vec4 dc = lh_disc(S, lh_px_rs(hole_px / px_scale), time, 1.0, hot, cap);
	C *= 1.0 - cap;
	if (dc.a > 0.004) {
		vec3 col = dc.rgb;
		// a flash running round the photon ring, and the flare echo's swell:
		// the disc a step hotter where they pass
		float rr = length(S) / LH_SHADOW;
		if (rf.y >= 0.0 && rr < 1.6) {
			float f = exp(-pow((hd_adiff(atan(S.y, S.x), rf.x) - 5.2 * rf.y) / 0.3, 2.0)) * (1.0 - smoothstep(0.5, 0.7, rf.y))
				+ 0.5 * smoothstep(0.4, 0.7, rf.y) * exp(-max(rf.y - 0.7, 0.0) / 1.5);
			col = mix(col, lh_pal[7], step(dth, f * 0.8));
		}
		if (breath_add > 0.0) col = mix(col, lh_pal[6], step(dth, breath_add * 0.5));
		C = mix(C, col, dc.a);
	}
	if (painted) {
		bool chk = ((ip.x + ip.y) & 1) == 1;
		vec3 P = textureLod(screen, (src + 0.5) * SCREEN_PIXEL_SIZE, 0.0).rgb;
		if (lh_squeeze(S) < 0.5) P = vec3(0.0);
		if (dc.a > 0.004) {
			vec3 col = dc.rgb;
			float rr = length(S) / LH_SHADOW;
			if (rf.y >= 0.0 && rr < 1.6) {
				float f = exp(-pow((hd_adiff(atan(S.y, S.x), rf.x) - 5.2 * rf.y) / 0.3, 2.0)) * (1.0 - smoothstep(0.5, 0.7, rf.y))
					+ 0.5 * smoothstep(0.4, 0.7, rf.y) * exp(-max(rf.y - 0.7, 0.0) / 1.5);
				if (f > 0.45) col = lh_pal[7];
			}
			if (breath_add > 0.3 && chk) col = lh_pal[6];
			bool dark = distance(col, lh_pal[1]) < 1e-4 || distance(col, lh_pal[0]) < 1e-4;
			if (!dark && (dc.a > 0.55 || (dc.a > 0.18 && chk))) P = to_srgb(col);
		}
		if (cap > 0.5) P = vec3(0.0);
		COLOR = vec4(P, 1.0);
	} else {
		COLOR = vec4(to_srgb(C), 1.0);
	}
}
