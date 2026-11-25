shader_type canvas_item;
render_mode unshaded;

// THE OLD HANGAR's LIGHT (Jon, Nov 24, A17): two layers, the ambient alone and the sodium lamp's,
// each stepped offline by the film's own code (amb.png, lamp.png). A frame is ambient + lamp x level,
// so with the lamp out it is the ambient frame exactly: no pool, cone or glow left, the fixture dark.
// Why: docs/why/ShipRoomOld.md#two-layers
//   mode 0  the room: albedo x light, the bulb over it, the bulb's stepped halo screened on
//   1  a thing standing in the room (a post, a hose): its colour x the light at its pixel
//   2  a tarp in moving air (tarp_wind.py): each pixel offset by the billow field, its folds
//      re-shaded toward the lamp, then lit as the film lit sprites: rgb x (0.35 + 0.5 L) x rows

uniform int mode = 0;
uniform sampler2D albedo : filter_nearest, repeat_disable;
uniform sampler2D amb : filter_nearest, repeat_disable;
uniform sampler2D lamp : filter_nearest, repeat_disable;
uniform sampler2D emissive : filter_nearest, repeat_disable;
// the lamp's level this frame: hum, dips and drop-outs (0 is out), times a launch's beat
uniform float level = 1.0;
// the room's clock, seconds into the film's 10 s loop (the tarps' wind)
uniform float t = 0.0;
// (set by YardStandSet for the package's shader; the tarps here measure their own rows)
instance uniform vec2 rows = vec2(0.0, 1.0);

const vec3 SOD = vec3(255.0, 208.0, 142.0) / 255.0;
const vec2 LAMP = vec2(483.0, 30.0);
const int PAD = 6;

varying vec2 fp;
varying float wind;

void vertex() {
	fp = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	// a tarp's draw colour carries its wind (0 while it drops, easing to 1 once it has settled)
	wind = COLOR.r;
}

// the light at a frame pixel: ambient + (lamp on - ambient) x level, the floor's lift with the lamp
vec3 light_at(ivec2 p) {
	if (p.x < 0 || p.y < 0 || p.x >= 960 || p.y >= 540) {
		return vec3(1.0);
	}
	vec3 a = texelFetch(amb, p, 0).rgb * (255.0 / 48.0);
	vec4 l = texelFetch(lamp, p, 0);
	float f = 1.0 + (1.0 - l.a) * (255.0 / 48.0);
	return a + ((a + l.rgb * (255.0 / 48.0)) * f - a) * level;
}

// the film's 2x2 ordered dither (mock.BAYER)
float bayer2(ivec2 p) {
	int i = (p.y & 1) * 2 + (p.x & 1);
	return i == 0 ? 0.0 : (i == 1 ? 0.5 : (i == 2 ? 0.75 : 0.25));
}

// the bulb's glow: 4 stepped levels round the lamp's mouth, the top 40 % of each step dithered
float halo(ivec2 p) {
	vec2 d = vec2(float(p.x) - LAMP.x, (float(p.y) - (LAMP.y - 6.0)) / 0.8);
	float k = pow(clamp(1.0 - length(d) / 30.0, 0.0, 1.0), 1.5) * 4.0;
	float lo = floor(k);
	float fr = k - lo;
	float up = (fr > 0.6 && bayer2(p) < (fr - 0.6) * 2.5 * 0.5 + 0.25) ? 1.0 : 0.0;
	return (lo + up) / 4.0 * 0.7;
}

float smoothx(float a, float b, float x) {
	float u = clamp((x - a) / (b - a), 0.0, 1.0);
	return u * u * (3.0 - 2.0 * u);
}

// the gust (tarp_wind.Gust(1.0, -40, 260, 1.0)): a quick rise, a long fall, gone by the loop's end
float gust(float X) {
	float a = t - 1.0 - abs(X + 40.0) / 260.0;
	float up = clamp(a / 0.35, 0.0, 1.0);
	float e = a < 0.0 ? 0.0 : (a < 0.35 ? up * up * (3.0 - 2.0 * up) : exp(-max(a - 0.35, 0.0) / 1.3));
	return e * smoothx(10.0, 9.2, t);
}

// the hold field's texel unpacked: (W, edge, pull, v)
vec4 unpack(vec4 d) {
	return vec4(d.r * 2.0, d.g, d.b, (d.a * 255.0 - 1.0) / 254.0);
}

// (functions cannot read TEXTURE, so the fragment fetches through these)
#define HOLD(q) unpack(texelFetch(TEXTURE, ivec2(PAD + (q).x, h + PAD + (q).y), 0))
#define CLOTH(q) ((q).x >= 0 && (q).y >= 0 && (q).x < w && (q).y < h && texelFetch(TEXTURE, ivec2(PAD + (q).x, (q).y), 0).a > 0.0)

// the billow h at sprite pixel q with hold d (tarp_wind.Tarp.field)
float billow(vec4 d, ivec2 q, float X0, vec3 ph) {
	float X = X0 + float(q.x);
	float g = gust(X);
	float w1 = sin(TAU * (X / 70.0 - 0.9 * t) + ph.x);
	float w2 = sin(TAU * (X / 37.0 + float(q.y) / 50.0 - 1.6 * t) + ph.y);
	float br = sin(TAU * t / 5.0 + X / 90.0 + ph.z) * (0.4 + 0.6 * d.a);
	return d.r * (g * 1.8 * (0.7 * w1 + 0.3 * w2) + 0.6 * br);
}

// whole pixels: a pixel steps out once the field is 0.75 past it (the film's hysteresis, held stateless)
float snapx(float v) {
	return sign(v) * floor(abs(v) + 0.25);
}

// the cloth's pixel, its folds re-shaded by slope `sl` (inside the cloth only, held to +-0.18), held to
// the cloth's own lightest and darkest `lh`, then lit as the film lit sprites at frame pixel f
vec4 lit_tarp(vec4 px, float sl, vec2 lh, ivec2 f, float r) {
	vec3 rgb = clamp(px.rgb * 255.0 * clamp(1.0 + 1.4 * sl, 0.82, 1.18), 0.0, 255.0);
	float lum = (rgb.r + rgb.g + rgb.b) / 3.0;
	rgb *= clamp(lum, lh.x, lh.y) / max(lum, 0.001);
	vec3 L = clamp(light_at(f), 0.0, 1.0);
	return vec4(clamp(rgb * (0.35 + 0.5 * L) * r, 0.0, 255.0) / 255.0, px.a);
}

void fragment() {
	ivec2 p = ivec2(floor(fp));
	if (mode == 0) {
		vec3 a = texelFetch(albedo, p, 0).rgb;
		vec3 lit = min(a * light_at(p), vec3(1.0));
		vec4 e = texelFetch(emissive, p, 0);
		lit = mix(lit, e.rgb * level, e.a);
		vec3 c = halo(p) * min(1.0, level) * SOD;
		COLOR = vec4(1.0 - (1.0 - lit) * (1.0 - c), 1.0);
	} else if (mode == 1) {
		vec4 c = texture(TEXTURE, UV);
		COLOR = vec4(min(c.rgb * light_at(p), vec3(1.0)), c.a);
	} else {
		ivec2 ts = textureSize(TEXTURE, 0);
		int w = ts.x - 2 * PAD;
		int h = (ts.y - PAD - 1) / 2;
		ivec2 loc = ivec2(floor(UV * vec2(ts)));
		ivec2 o = ivec2(loc.x - PAD, loc.y);
		vec2 pos = vec2(p - o);
		vec2 lh = texelFetch(TEXTURE, ivec2(0, 2 * h + PAD), 0).rg * 255.0;
		vec3 ph = texelFetch(TEXTURE, ivec2(1, 2 * h + PAD), 0).rgb * 6.28;
		ivec2 c = clamp(o, ivec2(0), ivec2(w - 1, h - 1));
		vec4 d = HOLD(c);
		float X = pos.x + float(c.x);
		float g = gust(X);
		float w1 = sin(TAU * (X / 70.0 - 0.9 * t) + ph.x);
		float flap = d.g * g * smoothx(0.0, 0.6, g) * 1.2 * sin(TAU * 3.3 * t + X / 9.0);
		float dx = billow(d, c, pos.x, ph) + flap;
		float dy = -d.r * g * 1.4 * (0.6 + 0.4 * w1) * d.a - d.b * g * 1.4 + 0.4 * flap;
		ivec2 sp = o - ivec2(int(snapx(dx * wind)), int(snapx(dy * wind)));
		vec4 px = vec4(0.0);
		if (sp.x >= 0 && sp.y >= 0 && sp.x < w && sp.y < h) {
			px = texelFetch(TEXTURE, ivec2(PAD + sp.x, sp.y), 0);
		}
		float sl = 0.0;
		ivec2 ex = ivec2(1, 0);
		ivec2 ey = ivec2(0, 1);
		if (wind > 0.0 && CLOTH(c) && CLOTH(c + ex) && CLOTH(c - ex) && CLOTH(c + ey) && CLOTH(c - ey)) {
			float gx = (billow(HOLD(c + ex), c + ex, pos.x, ph) - billow(HOLD(c - ex), c - ex, pos.x, ph)) * 0.5;
			float gy = (billow(HOLD(c + ey), c + ey, pos.x, ph) - billow(HOLD(c - ey), c - ey, pos.x, ph)) * 0.5;
			vec2 l = normalize(LAMP - (pos + vec2(float(w), float(h)) * 0.5));
			sl = (gx * l.x + gy * l.y) * wind;
		}
		float r = mix(1.08, 0.78, float(o.y) / float(h + PAD - 1));
		COLOR = px.a > 0.0 ? lit_tarp(px, sl, lh, p, r) : vec4(0.0);
	}
}
