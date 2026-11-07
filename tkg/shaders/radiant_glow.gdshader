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
	// ---- the shade
	float L = lum(c);
	float dk = 1.0 - smoothstep(0.0, dark_hi, L);
	vec3 tint = shade_tint * (L / max(lum(shade_tint), 1e-4));
	c = mix(c, tint, shade * dk);
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
	gn *= pk;
	gw *= pk * wide_k;
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
	c += whue * wq * 0.55;
	// (a light's own face keeps its own detail: its tight glow goes round it,
	// not over it, so a sun is a disc with a halo and not a white blob)
	float own = smoothstep(self_lo, 1.0, max(c.r, max(c.g, c.b)));
	vec3 o = c + hue * gq * 0.55 * (1.0 - self_k * own);
	// only a hot core passes white
	float om = max(o.r, max(o.g, o.b));
	o = mix(min(o, vec3(1.0)), vec3(1.0), clamp((om - 1.0) * 0.8, 0.0, 1.0));
	COLOR = vec4(srgb(o), 1.0);
}
