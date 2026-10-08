shader_type canvas_item;
render_mode unshaded, blend_add;

// LIGHT IN LOCAL'S SCENE THAT IS NOT ON A PIECE (`LocalFx`): a pulsar's beam
// sweeping the sky, a blue star's glare washing a quarter of it white, a shock
// front's shell, a comet's tails. Drawn as light (Jon: flat glowing pixels
// "bad", gathered light with falloff "WAY better"): added over the sky, smooth
// inside, its edge dithered over a few pixels on a fixed 4x4 pattern -- so a
// moving edge crosses each pixel once and never back and forth. Kept off your
// ship (a margin round it, eased) and above the event's band.
//
// Positions are this rect's own px (the subject's control, at 1:1); the caller
// works out each frame's numbers (where the beam points, how strong it is now).

uniform int mode = 0;
uniform vec3 col = vec3(0.7, 0.82, 1.0);
uniform float k = 1.0;
uniform vec4 ship = vec4(-999.0, -999.0, 0.0, 0.0);
uniform float band_y = 9999.0;
uniform float keep = 12.0;
uniform float thin = 26.0;
uniform float time = 0.0;
// MODE 0, A PULSAR'S BEAM: from `src`, pointing `ang` (radians, y down), its
// flat core `core` radians either side and a soft fall out to `soft`; dimming
// with distance over `reach` px. Only below `top_y` (the sky under the beam's
// source), so it reads as coming from there.
// MODE 1, A GLARE: round `src`, flat out to `r0`, falling off to `r1` -- reaching
// further toward `dir` (`lean` how much), its outer edge dithered.
// MODE 2, A SHOCK FRONT: a shell round `src`, its leading (inner) edge at `r0`
// and `r1` thick; grit glinting in it on its own slow clocks.
// MODE 3, A COMET'S TAILS from `src`, pointing `dir` (away from the star), `r1`
// long: the ion tail straight and narrow, the dust tail broad and bending.
uniform vec2 src = vec2(0.0);
uniform float ang = 0.0;
uniform float core = 0.05;
uniform float soft = 0.14;
uniform float reach = 700.0;
// (the beam only above the fight: gone over `floor_y` + 40 px)
uniform float floor_y = 9999.0;
uniform float r0 = 60.0;
uniform float r1 = 360.0;
uniform vec2 dir = vec2(1.0, 0.4);
uniform float lean = 0.6;
uniform vec3 col2 = vec3(1.0, 0.9, 0.7);
uniform vec2 tail_bend = vec2(0.0, -1.0);

varying vec2 local;

void vertex() {
	local = VERTEX;
}

float bayer4(vec2 p) {
	ivec2 i = ivec2(mod(floor(p), 4.0));
	int idx = i.y * 4 + i.x;
	float b = 0.0;
	// (a table: the GL compatibility compiler takes no const array indexing by a variable everywhere)
	if (idx == 0) b = 0.0; else if (idx == 1) b = 8.0; else if (idx == 2) b = 2.0; else if (idx == 3) b = 10.0;
	else if (idx == 4) b = 12.0; else if (idx == 5) b = 4.0; else if (idx == 6) b = 14.0; else if (idx == 7) b = 6.0;
	else if (idx == 8) b = 3.0; else if (idx == 9) b = 11.0; else if (idx == 10) b = 1.0; else if (idx == 11) b = 9.0;
	else if (idx == 12) b = 15.0; else if (idx == 13) b = 7.0; else if (idx == 14) b = 13.0; else b = 5.0;
	return (b + 0.5) / 16.0;
}

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// how far this pixel may be lit: none on your ship or within `keep` of it,
// easing in over `thin`; none under the band
float allowed(vec2 p) {
	vec2 lo = ship.xy;
	vec2 hi = ship.xy + ship.zw;
	vec2 d = max(max(lo - p, p - hi), vec2(0.0));
	float w = clamp((length(d) - keep) / thin, 0.0, 1.0);
	w = w * w * (3.0 - 2.0 * w);
	w *= clamp((band_y - p.y) / 14.0, 0.0, 1.0);
	return w;
}

// a soft edge `m` (1 inside, 0 outside) in whole pixels on the fixed pattern
float edge(float m, vec2 p) {
	return m >= 0.999 ? 1.0 : (m > bayer4(p) ? 1.0 : 0.0);
}

float wrap_pi(float a) {
	return atan(sin(a), cos(a));
}

void fragment() {
	vec2 p = floor(local) + 0.5;
	float a = allowed(p);
	vec3 outc = vec3(0.0);
	if (a > 0.0) {
		if (mode == 0) {
			vec2 d = p - src;
			float r = length(d);
			float da = abs(wrap_pi(atan(d.y, d.x) - ang));
			// the flat core, then a fall over the soft part (in px across it, so
			// the edge is a few pixels wide however far out)
			float m = 1.0 - clamp((da - core) / max(soft - core, 1e-3), 0.0, 1.0);
			float px_edge = (da - soft) * r;
			float e = edge(clamp(1.0 - px_edge / 4.0, 0.0, 1.0), p) * (da < soft + 4.0 / max(r, 1.0) ? 1.0 : 0.0);
			float along = 1.0 / (1.0 + r / reach) * clamp(r / 30.0, 0.0, 1.0);
			float I = (da <= soft ? (0.35 + 0.65 * m * m) : 0.35) * e * along;
			float fl = clamp((floor_y + 40.0 - p.y) / 40.0, 0.0, 1.0);
			I *= fl * fl * (3.0 - 2.0 * fl);
			outc = col * I;
		} else if (mode == 1) {
			vec2 d = p - src;
			float r = length(d);
			vec2 u = r > 0.0 ? d / r : vec2(0.0);
			// reaching further toward its lean
			float toward = 0.5 + 0.5 * dot(u, normalize(dir));
			float R1 = mix(r1 * (1.0 - lean), r1, toward * toward);
			float m = clamp((R1 - r) / max(R1 - r0, 1.0), 0.0, 1.0);
			float e = edge(clamp((R1 - r) / 5.0, 0.0, 1.0), p);
			float I = (0.25 + 0.75 * m * m) * e;
			outc = mix(col2, col, m) * I;
		} else if (mode == 2) {
			vec2 d = p - src;
			float r = length(d);
			float into = r0 - r;
			if (into > -2.0 && into < r1) {
				float lead = 1.0 - clamp(into / 5.0, 0.0, 1.0);
				float body = 1.0 - clamp(into / r1, 0.0, 1.0);
				float e = edge(clamp((into + 2.0) / 3.0, 0.0, 1.0), p) * edge(clamp((r1 - into) / 6.0, 0.0, 1.0), p);
				float I = (0.22 * body + 0.65 * lead * lead) * e;
				// grit: a speck here and there, each brightening and fading slowly
				vec2 cell = floor(p / 3.0);
				float g = h21(cell);
				if (g > 0.94 && mod(p.x, 3.0) < 1.0 && mod(p.y, 3.0) < 1.0) {
					float ph = fract(time / (3.0 + 4.0 * h21(cell + 7.0)) + g * 13.0);
					I += 0.9 * body * sin(ph * 3.14159) * sin(ph * 3.14159);
				}
				outc = mix(col2, col, lead) * I;
			}
		} else if (mode == 3) {
			vec2 d = p - src;
			vec2 ax = normalize(dir);
			vec2 nx = vec2(-ax.y, ax.x);
			float u = dot(d, ax);
			float v = dot(d, nx);
			if (u > 0.0 && u < r1) {
				float f = u / r1;
				float fall = (1.0 - f) * (1.0 - f) * clamp(u / 6.0, 0.0, 1.0);
				// the ion tail: straight, narrow, blue, faint striations drifting out
				float wi = 1.5 + 4.0 * f;
				float mi = 1.0 - clamp((abs(v) - wi) / 3.0, 0.0, 1.0);
				float stri = 0.8 + 0.2 * sin(u * 0.09 - time * 0.6);
				float Ii = edge(mi, p) * fall * 0.9 * stri;
				// the dust tail: bending back along the orbit, broad, warm
				float vb = v - dot(tail_bend, nx) * f * f * r1 * 0.35;
				float wd = 3.0 + 26.0 * f;
				float md = 1.0 - clamp((abs(vb) - wd) / 4.0, 0.0, 1.0);
				float cd = 1.0 - clamp(abs(vb) / wd, 0.0, 1.0);
				float Id = edge(md, p) * fall * (0.25 + 0.55 * cd);
				// the coma round the head
				float rc = length(d);
				float mc = 1.0 - clamp((rc - 7.0) / 4.0, 0.0, 1.0);
				float Ic = edge(mc, p) * 0.5;
				outc = col * Ii + col2 * Id + mix(col, col2, 0.5) * Ic;
			} else {
				float rc = length(d);
				float mc = 1.0 - clamp((rc - 7.0) / 4.0, 0.0, 1.0);
				outc = mix(col, col2, 0.5) * edge(mc, p) * 0.5;
			}
		}
	}
	COLOR = vec4(outc * k * a, 1.0);
}
