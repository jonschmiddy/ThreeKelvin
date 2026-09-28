shader_type canvas_item;
render_mode unshaded;

// THE LABORATORY'S LIGHT, per pixel: Five Labs, Lit's `lightAt` and `frame`,
// on the GPU. `tools/lab_install.py` worked each light's pool out once; what
// moves is only how hard each one burns, which `LabScene` hands over every
// tick of its 30 Hz clock.
//
// A WEIGHT IS [steady, breathing]. The steady part (the power-on) sets where a
// light's bands fall; the breathing part (a pulse, a flutter, a fault's
// stutter) only brightens and dims them after the stepping. Breathing fed into
// the bands crept their edges a pixel at a time, which Jon saw as "weird single
// pixel shimmers" on the capital.
//
// ONE PASS, NOT THE SHOP'S TWO. The shop splits multiply from add so its light
// can lie over live furniture; a lab is one picture, so this draws it lit.

// The lights' pools: a GW x GH band per two lights, each 16-bit, (A.hi, A.lo,
// B.hi, B.lo), over 0..`scale`.
uniform sampler2D light_map : filter_nearest, repeat_disable;
// Per room pixel: R the emitter it belongs to (0 none, else index + 1).
uniform sampler2D own_map : filter_nearest, repeat_disable;
uniform int nlights = 0;
uniform int band_h = 216;
uniform float scale = 2.0;
// Each light's colour, and in .a its power.
uniform vec4 lcol[8];
// Each light's weight, steady then breathing.
uniform vec2 lw[8];
// Each emitter's brightness this tick (steady times breathing).
uniform float own_w[8];
// The room between the lights: the lab's ambient times its power-on.
uniform float amb = 0.2;
uniform vec3 ambc = vec3(1.0);
uniform float levels = 6.0;
uniform float soft = 1.5;
// Unlit, as painted: `stationshot` compares against Jon's pictures with it.
uniform bool fullbright = false;

float pool(ivec2 g, int i) {
	vec4 t = texelFetch(light_map, ivec2(g.x, g.y + (i / 2) * band_h), 0);
	vec2 hl = (i % 2 == 0) ? t.rg : t.ba;
	return (floor(hl.x * 255.0 + 0.5) * 256.0 + floor(hl.y * 255.0 + 0.5)) / 65535.0 * scale;
}

void fragment() {
	vec3 base = texture(TEXTURE, UV).rgb;
	if (fullbright) {
		COLOR = vec4(base, 1.0);
	} else {
		ivec2 p = ivec2(floor(UV * vec2(textureSize(TEXTURE, 0))));
		int own = int(floor(texelFetch(own_map, p, 0).r * 255.0 + 0.5)) - 1;
		if (own >= 0) {
			// AN EMITTER IS NOT LIT, IT BURNS: its own colour at its own brightness.
			float e = own_w[own];
			COLOR = vec4(min(vec3(1.0), base * e + vec3(8.0, 10.0, 10.0) / 255.0 * e), 1.0);
		} else {
			ivec2 g = p / 2;
			vec3 l3 = vec3(0.0);
			float s0 = 0.0;
			float s1 = 0.0;
			for (int i = 0; i < 8; i++) {
				if (i >= nlights) {
					break;
				}
				float k = lw[i].x * lcol[i].a;
				if (k <= 0.001) {
					continue;
				}
				float v = pool(g, i);
				if (v > 0.0) {
					v *= k;
					l3 += v * lcol[i].rgb;
					s0 += v;
					s1 += v * lw[i].y;
				}
			}
			// INTENSITY IS THE BRIGHTEST CHANNEL; the ratios are the light's colour.
			float l = max(l3.r, max(l3.g, l3.b));
			vec3 m = amb * ambc;
			float ov = 0.0;
			if (l > 0.0) {
				float stp = 1.0 / levels;
				float tq;
				if (l < soft * stp) {
					tq = l;
				} else {
					// Math.round: halves go up.
					float q = floor(l / stp + 0.5) * stp;
					tq = min(q, 1.0);
					ov = q > 1.0 ? min(q - 1.0, 0.35) : 0.0;
				}
				float bm = s1 / s0;
				tq = min(1.0, tq * bm);
				ov *= bm;
				vec3 tr = l3 / l;
				m = amb * ambc * (1.0 - tq) + (vec3(1.0) - 0.45 * (vec3(1.0) - tr)) * tq;
			}
			COLOR = vec4(min(vec3(1.0), base * m + ov * 0.3 * m), 1.0);
		}
	}
}
