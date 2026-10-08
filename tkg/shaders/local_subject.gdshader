shader_type canvas_item;
render_mode unshaded;

// AN ENCOUNTER'S SUBJECT, GROUNDED IN LOCAL'S SCENE (`LocalSubject`): a sprite
// lit from the system's star side and shaded on the far side, in steps (pixel
// light, not a smooth wash), its star-facing edge caught by the star's own
// colour; a far one dimmed toward the sky; and its colours set to the system's
// own palette where LOCAL has one (SIMPLIFIED, RADIANT, LEGACY), as the sky's
// are. PAINTED has no palette: its light is stepped harder instead.
//
// `to_star` is in the sprite's own pixels (its rotation taken out by the caller).
// A painter rock (`use_mask`) is lit by PlanetView already: its mask cuts the
// lumpy outline and darkens the cut, and the directional terms are left at 0.

uniform vec2 to_star = vec2(-1.0, 0.0);
uniform vec3 star_col = vec3(1.0);
uniform float lit = 0.32;
uniform float shade = 0.5;
uniform float far = 0.0;
// a cold hull (no heat, no lights): its colours drained and darkened toward the
// sky before the star lights it, so a lit window goes out with the rest
uniform float dark = 0.0;
uniform vec3 sky_col = vec3(0.035, 0.045, 0.075);
uniform bool use_mask = false;
uniform sampler2D mask : filter_nearest;
uniform bool stepped = false;
uniform vec3 pal[72];
uniform int pal_n = 0;
// how far toward its palette colour a pixel is pulled (all the way flattens
// a sprite's own shading into the sky's few colours)
uniform float pal_k = 0.55;
// A LUMPY ROCK (`LocalSubject._rock`): TEXTURE is its form -- RG its slope, B the
// depth in from its edge, A inside -- and this lights it from the star in its
// world's six rock colours (`ramp`, darkest first): lumps and ridges from noise
// (`grain` px across), craters [x, y, radius, depth] in its own pixels, a
// dithered terminator, a rim caught in the star's colour.
uniform bool rock = false;
uniform vec3 ramp[6];
uniform float rock_seed = 0.0;
uniform float grain = 14.0;
uniform vec4 craters[8];
uniform int n_craters = 0;
// A PIECE TURNED BY `pixel_turn.gdshader` (`PixelTurn`, off unless asked): its
// picture's alpha carries a count, so it is snapped at a half; the picture is
// a box round the turned piece, so the light's reach across it is the piece's
// own (`span_px`, screen px; 0: the picture's).
uniform bool snap_alpha = false;
uniform float span_px = 0.0;
// (SOFT, a trial: the turned picture's colour is premultiplied by its coverage)
uniform bool unpremul = false;
// STILL (a trial, `PixelTurn`): a glint rolling across the hull as it would
// tumble -- a band across the light's direction, `glint_at` px along it from
// the middle, `glint_w` px wide with a dithered edge, `glint` strong
uniform float glint = 0.0;
uniform float glint_at = 0.0;
uniform float glint_w = 2.0;
// WHAT THE PLACE HAS DONE TO IT (`LocalSubject`, a stage's `bake` / `dust` /
// `silhouette` / `dirt`): its star-facing side baked hot amber where the light
// cooked the plating; its star-facing side dusted over; seen only as a dark
// shape against a glare, its edge toward the star caught; a body of ice dirtied.
uniform float bake = 0.0;
uniform float dust = 0.0;
uniform vec3 dust_col = vec3(0.52, 0.36, 0.26);
uniform float silhouette = 0.0;
uniform float dirt = 0.0;

float rh(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float rnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(rh(i), rh(i + vec2(1.0, 0.0)), u.x), mix(rh(i + vec2(0.0, 1.0)), rh(i + vec2(1.0, 1.0)), u.x), u.y);
}

// the surface's own relief, px of height: lumps on two scales and sharp ridges,
// and each crater's bowl with its raised lip
float relief(vec2 p) {
	vec2 q = p / grain + vec2(rock_seed, rock_seed * 1.7);
	float h = rnoise(q) * 2.2 + rnoise(q * 2.1 + 3.1) * 1.1;
	float rd = 1.0 - abs(rnoise(q * 0.8 + 7.7) * 2.0 - 1.0);
	h += rd * rd * 2.0;
	for (int i = 0; i < 8; i++) {
		if (i >= n_craters) {
			break;
		}
		vec4 cr = craters[i];
		float d = distance(p, cr.xy) / cr.z;
		if (d < 1.0) {
			h -= (1.0 - d * d) * cr.z * 0.55 * cr.w;
		} else if (d < 1.45) {
			float t = (d - 1.0) / 0.45;
			h += (1.0 - t) * (1.0 - t) * cr.z * 0.22 * cr.w;
		}
	}
	return h;
}

// `t` its form at this pixel, `out_a` the form one pixel and a half toward the
// star (sampled by the caller: a sampler handed to a function upsets the GL
// compatibility compiler)
vec3 rock_lit(vec4 t, float out_a, vec2 uv, vec2 sz) {
	vec2 p = floor(uv * sz) + 0.5;
	vec3 n = vec3(t.r * 2.0 - 1.0, t.g * 2.0 - 1.0, 0.0);
	n.z = sqrt(max(0.05, 1.0 - dot(n.xy, n.xy)));
	// the relief's slope, fading out toward the rim so the outline stays clean
	float e = 1.0;
	vec2 g = vec2(relief(p + vec2(e, 0.0)) - relief(p - vec2(e, 0.0)), relief(p + vec2(0.0, e)) - relief(p - vec2(0.0, e))) / (2.0 * e);
	float inner = smoothstep(0.02, 0.18, t.b);
	n = normalize(vec3(n.xy / n.z - g * 1.0 * inner, 1.0));
	// the star low across it, so the light falls off over the rock and a
	// terminator crosses it: its far side in the dark
	vec3 L = normalize(vec3(to_star, 0.38));
	float dl = dot(n, L);
	// a dithered step down the ramp: lit face, terminator, dark side
	float v = clamp(dl * 0.78 + 0.18, 0.0, 1.0) * 5.0;
	vec2 cell = mod(floor(uv * sz), 2.0);
	float dith = (cell.x == cell.y ? 0.25 : -0.25);
	int idx = int(clamp(floor(v + 0.5 + dith), 0.0, 5.0));
	vec3 col = ramp[idx];
	// the dark side keeps a little of the sky's light, never black
	col = max(col, sky_col * 1.4);
	// the rim toward the star: the next pixel that way is outside the rock
	float rim = out_a < 0.5 ? 1.0 : 0.0;
	if (rim > 0.0 && dl > -0.1) {
		col = mix(ramp[min(idx + 2, 5)], ramp[5] * star_col * 1.15, 0.5);
	}
	// lit pixels take the star's colour
	col *= mix(vec3(1.0), star_col, clamp(dl, 0.0, 1.0) * 0.5);
	return col;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (unpremul && c.a > 0.0) {
		c.rgb /= c.a;
	}
	if (snap_alpha) {
		c.a = c.a >= 0.5 ? 1.0 : 0.0;
	}
	vec3 col = vec3(0.0);
	if (rock) {
		float out_a = texture(TEXTURE, UV + to_star * TEXTURE_PIXEL_SIZE * 1.5).a;
		col = rock_lit(c, out_a, UV, 1.0 / TEXTURE_PIXEL_SIZE);
		if (c.a < 0.5) {
			discard;
		}
		c.a = 1.0;
	} else {
		if (use_mask) {
			vec4 m = texture(mask, UV);
			c.a *= m.r;
			c.rgb *= mix(1.0, 0.45, m.g);
		}
		if (c.a < 0.02) {
			discard;
		}
		if (dark > 0.0) {
			float l = dot(c.rgb, vec3(0.3, 0.5, 0.2));
			vec3 cold = mix(vec3(l), c.rgb, 0.3) * 0.5 + sky_col * 0.4;
			c.rgb = mix(c.rgb, cold, clamp(dark, 0.0, 1.0));
		}
		vec2 px = TEXTURE_PIXEL_SIZE;
		vec2 sz = 1.0 / px;
		vec2 p = (floor(UV * sz) + 0.5) - sz * 0.5;
		float span = span_px > 0.0 ? span_px : max(length(sz) * 0.5, 1.0);
		float s = clamp(dot(p, to_star) / span, -1.0, 1.0);
		float k = s > 0.0 ? s * lit : s * shade;
		// the edge facing the star: the next pixel toward it is clear
		float na = texture(TEXTURE, UV + to_star * px * 1.5).a;
		float rim = (snap_alpha ? na < 0.5 : na < 0.3) ? 1.0 : 0.0;
		if (use_mask) {
			rim = 0.0;
		}
		k += rim * lit * 0.9;
		if (glint > 0.0 && s > -0.25) {
			float gd = abs(dot(p, to_star) - glint_at);
			ivec2 ip = ivec2(floor(UV * sz));
			bool chk = ((ip.x + ip.y) & 1) == 0;
			if (gd < glint_w || (gd < glint_w + 1.5 && chk)) {
				k += glint;
			}
		}
		float steps = stepped ? 3.0 : 4.0;
		k = floor(k * steps + 0.5) / steps;
		col = c.rgb * (1.0 + min(k, 0.0)) + c.rgb * star_col * max(k, 0.0);
		// (stepped across the hull, as the light is: the half toward the star)
		float side = clamp(floor((s + 0.15) * 3.0 + 0.5) / 3.0, 0.0, 1.0);
		if (bake > 0.0) {
			float l = dot(c.rgb, vec3(0.3, 0.5, 0.2));
			vec3 hot = mix(vec3(0.32, 0.12, 0.04), vec3(1.0, 0.66, 0.3), clamp(l * 1.6, 0.0, 1.0));
			col = mix(col, hot * (0.8 + 0.4 * rim), bake * side);
		}
		if (dust > 0.0) {
			float l = dot(col, vec3(0.3, 0.5, 0.2));
			col = mix(col, dust_col * (0.6 + 0.8 * l), dust * (0.35 + 0.65 * side));
		}
		if (silhouette > 0.0) {
			vec3 shape = sky_col * 0.7 + c.rgb * 0.06;
			col = mix(col, shape + star_col * rim * 0.45, silhouette);
		}
	}
	if (dirt > 0.0) {
		float l = dot(col, vec3(0.3, 0.5, 0.2));
		col = mix(col, vec3(0.5, 0.42, 0.34) * l * 1.1, dirt);
	}
	col = mix(col, sky_col, clamp(far, 0.0, 1.0) * 0.6);
	if (pal_n > 0) {
		vec3 q = col * 255.0;
		float best = 1e9;
		vec3 pick = col;
		for (int i = 0; i < pal_n; i++) {
			vec3 d = q - pal[i] * 255.0;
			float dd = d.r * d.r * 2.0 + d.g * d.g * 4.0 + d.b * d.b * 3.0;
			if (dd < best) {
				best = dd;
				pick = pal[i];
			}
		}
		col = mix(col, pick, pal_k);
	}
	COLOR = vec4(col, c.a);
}
