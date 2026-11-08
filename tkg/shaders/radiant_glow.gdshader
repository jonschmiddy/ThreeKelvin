shader_type canvas_item;
render_mode unshaded, blend_disabled;

// RADIANT'S GLOW, step two (`RadiantGlow`, direction C of Nov 7: "glow and
// colour"; Jon: "redo radiant to be super dramatic with the lighting effects").
// One fragment a 2x2 block, over the finished, palette-cut picture:
//   * THE SHADE: the darks pushed deeper and into a coloured shade (the scene's
//     own `shade_tint`, a deep violet-navy by default), never a grey; a pixel-wise
//     map, so a flat patch stays one flat colour and the palette stays a palette.
//   * THE GLOW: what glows (`radiant_bright`) gathered through the back buffer's
//     blurred levels as layered halos, a tight hot one and wider fainter ones,
//     and the light's own rays: the bright buffer read along the line to the
//     key light (`light`), so gaps in dark dust let light stream out and the dust
//     cuts shadow shafts through it.
//   * PIXEL STEPS: the glow is cut into a few flat steps of the light's own colour,
//     each step's edge a narrow band of 4x4 Bayer dither anchored to the
//     picture (`anchor`), never a smooth airbrush. Only a hot core passes white.

uniform sampler2D src : filter_nearest;
uniform sampler2D bright : hint_screen_texture, filter_linear_mipmap;
uniform vec2 size = vec2(480.0, 270.0);
// the dither's anchor (blocks): the chart's galaxy centre, or the screen
uniform vec2 anchor = vec2(0.0);
// the glow's halos: weights of the blurred levels 1..6 (each level twice as wide)
uniform vec3 halo_a = vec3(1.1, 1.0, 0.85);
uniform vec3 halo_b = vec3(0.7, 0.5, 0.32);
uniform float gain = 1.0;
// how much a lit face itself is spared its own tight glow, from what brightness
uniform float self_k = 0.8;
uniform float self_lo = 0.35;
// the wide halos' share
uniform float wide_k = 0.6;
uniform float steps = 6.0;
// the dithered band at each step's edge (share of a step)
uniform float band = 0.45;
// the key light's rays: its place (uv; negative none), strength, reach (uv)
uniform vec2 light = vec2(-1.0);
uniform float rays = 0.0;
// a black hole's shadow at the light (radius, blocks; 0 none): no glow falls in it,
// so the shadow stays black against its burning ring
uniform float hole = 0.0;
uniform float ray_len = 0.6;
// THE SHADE: below `dark_hi` (linear) the darks go toward the tint at their own
// brightness, `shade` of the way, and are pressed down by `crush`
uniform vec3 shade_tint = vec3(0.32, 0.18, 0.75);
uniform float shade = 0.55;
uniform float dark_hi = 0.06;
uniform float crush = 0.35;
// mid-tone colour: chroma lifted in the mids (never the whites, never the void)
uniform float vib = 0.25;
// the play (LOCAL): from y = play.x to play.y (uv) the glow is kept to play_k
uniform vec2 play = vec2(2.0, 3.0);
uniform float play_k = 1.0;
// THE FIELD UNDER IT (`nav_key`): the chart and the map are keyed onto the
// shared field of stars, the void let through and only a near-black (the hole,
// a shadow) kept. A dark pressed below `keep_lo` (sRGB luma) would read as the
// hole's black and plate the field over with black: a pixel is never pressed
// below the lesser of its own luma and this. 0: off (LOCAL, drawn whole).
uniform float keep_lo = 0.0;
// a light keeps its own colour: past full brightness its hue is held, and only
// light past `white_at` times full passes white (a true hot core, a few pixels)
uniform float white_at = 2.4;
// THE KEY LIGHT'S BREATH NOW (A+B+C, Nov 7): its glow's strength against its steady
// one (a sun's corona breathing and flickering, the chart's core breathing). Taken
// out of the glow before it is stepped and put back after, so the steps and their
// dither stay where the steady light puts them and only their brightness breathes:
// stepped with it, every step's edge and the wide halo's dither crept a pixel at a
// time round the sun, rings of single-pixel shimmer. A flare is not a breath: it is
// an event, eased in and let go, and its glow grows out through the steps.
uniform float pulse = 1.0;

vec3 lin(vec3 c) { return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c)); }
vec3 srgb(vec3 c) { c = max(c, 0.0); return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c)); }
float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
float bayer4(ivec2 b) {
	const float B[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	ivec2 m = b & ivec2(3);
	return (B[m.y * 4 + m.x] + 0.5) / 16.0;
}
vec3 br(vec2 uv, float l) { vec3 t = textureLod(bright, uv, l).rgb; return t * t; }

void fragment() {
	ivec2 b = clamp(ivec2(floor(SCREEN_UV * size)), ivec2(0), ivec2(size) - 1);
	// the block's centre: the glow is one value a block
	vec2 uv = (vec2(b) + 0.5) / size;
	vec3 c = lin(texelFetch(src, b, 0).rgb);
	vec3 c0 = c;
	// ---- the shade
	float L = lum(c);
	float dk = 1.0 - smoothstep(0.0, dark_hi, L);
	vec3 tint = shade_tint * (L / max(lum(shade_tint), 1e-4));
	// (only a grey dark takes the shade's colour: a faint light of a colour, a
	// ball's amber halo, a red dust's edge, keeps its own and is only pressed
	// darker, so it fades in its own colour to black, never to a violet fog)
	float cm0 = max(c.r, max(c.g, c.b));
	float sat0 = cm0 > 1e-5 ? 1.0 - min(c.r, min(c.g, c.b)) / cm0 : 0.0;
	c = mix(c, tint, shade * dk * (1.0 - smoothstep(0.25, 0.7, sat0)));
	c *= mix(1.0, pow(clamp(L / dark_hi, 0.0, 1.0), crush), dk);
	// ---- mid-tone colour
	float mx = max(c.r, max(c.g, c.b));
	float mid = smoothstep(0.02, 0.12, mx) * (1.0 - smoothstep(0.55, 0.9, mx));
	c = max(mx - (mx - c) * (1.0 + vib * mid), 0.0);
	// ---- the glow: the tight halos (levels 1-3, a few blocks) and the wide ones
	// (4-6, tens of blocks), kept apart: the tight ones are the layered rings
	vec3 gn = br(uv, 1.0) * halo_a.x + br(uv, 2.0) * halo_a.y + br(uv, 3.0) * halo_a.z;
	vec3 gw = br(uv, 4.0) * halo_b.x + br(uv, 5.0) * halo_b.y + br(uv, 6.0) * halo_b.z;
	if (rays > 0.0 && light.x >= 0.0) {
		vec2 d = light - uv;
		float dl = length(d * vec2(size.x / size.y, 1.0));
		vec2 stp = d * min(1.0, ray_len / max(dl, 1e-4)) / 14.0;
		vec2 p = uv;
		vec3 r = vec3(0.0);
		float w = 1.0;
		for (int i = 0; i < 14; i++) {
			p += stp;
			r += br(p, 1.0) * w;
			w *= 0.9;
		}
		gn += r * rays / 6.0 * (1.0 - smoothstep(ray_len * 0.4, ray_len, dl));
	}
	float pk = gain * mix(1.0, play_k, smoothstep(play.x, play.y, uv.y));
	if (hole > 0.0 && light.x >= 0.0) {
		pk *= smoothstep(hole * 0.8, hole * 1.15, length((uv - light) * size));
	}
	gn *= pk / pulse;
	gw *= pk * wide_k / pulse;
	float bay = bayer4(b + ivec2(anchor));
	// the tight halos in flat steps of the light's colour, a dithered band at each edge
	float gi = max(gn.r, max(gn.g, gn.b));
	vec3 hue = gn / max(gi, 1e-5);
	float n = gi * steps;
	float lo = floor(n);
	float up = smoothstep(1.0 - band, 1.0, n - lo) > bay ? 1.0 : 0.0;
	float gq = min(lo + up, steps * 3.0) / steps;
	// the wide ones finely, by dither alone: stepped coarsely, a broad lit field
	// drew big rings across the sky
	float wi = max(gw.r, max(gw.g, gw.b));
	vec3 whue = gw / max(wi, 1e-5);
	float wq = floor(wi * 24.0 + bay) / 24.0;
	// (a light's own face keeps its own detail: its glow, tight and wide, goes
	// round it, not over it, so a sun is a disc of its own colour in a halo and
	// not a white blob. Judged on the face as drawn, before any glow)
	float own = smoothstep(self_lo, 1.0, cm0);
	float spare = 1.0 - self_k * own;
	vec3 o = c + (whue * wq * 0.55 + hue * gq * 0.55) * spare * pulse;
	// a light keeps its colour: past full its hue is held (a red sun stays red),
	// and only light far past full passes white
	float om = max(o.r, max(o.g, o.b));
	vec3 held = o / max(om, 1.0);
	o = mix(held, vec3(1.0), clamp((om - white_at) / white_at, 0.0, 0.85));
	vec3 s = srgb(o);
	if (keep_lo > 0.0) {
		vec3 s0 = srgb(c0);
		const vec3 W = vec3(0.299, 0.587, 0.114);
		float fl = min(dot(s0, W), keep_lo);
		float ls = dot(s, W);
		if (ls < fl) {
			s = ls > 1e-4 ? s * (fl / ls) : s0;
		}
	}
	COLOR = vec4(s, 1.0);
}
