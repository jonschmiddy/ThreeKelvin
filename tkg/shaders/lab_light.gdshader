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

// THE CAMERA INTO THE GLASS (`LabZoom`, science S9, Jon's 1C): the screen's
// glass seen through as the Lab's chart comes up behind it, and the capital's
// bench looked over. All three are 0 in the room, so the room draws as it
// always did. `hole` is how far the glass has gone (0 to 1), inside
// `hole_box` (x0, y0, x1, y1 in picture px, the end exclusive); where
// `hole_masked` only the glass's own colour goes (own_map G & 8) and anything
// standing in front of it (the capital's flasks) fades with `mirror`. A bright
// pixel within `hole_k` px of a corner is the bezel's rounded corner and stays.
// `mirror` fades the rows of `mirror_box` into `mirror_sum - y`: the bezel's
// top profile turned over, where the bench hid the bottom one.
uniform float hole = 0.0;
uniform vec4 hole_box = vec4(0.0);
uniform bool hole_masked = false;
uniform float hole_k = 0.0;
uniform float mirror = 0.0;
uniform vec4 mirror_box = vec4(0.0);
uniform float mirror_sum = 0.0;

const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

bool inside(ivec2 p, vec4 b) {
	return float(p.x) >= b.x && float(p.y) >= b.y && float(p.x) < b.z && float(p.y) < b.w;
}

float pool(ivec2 g, int i) {
	vec4 t = texelFetch(light_map, ivec2(g.x, g.y + (i / 2) * band_h), 0);
	vec2 hl = (i % 2 == 0) ? t.rg : t.ba;
	return (floor(hl.x * 255.0 + 0.5) * 256.0 + floor(hl.y * 255.0 + 0.5)) / 65535.0 * scale;
}

// One room pixel lit, and whether the camera has let it go: (rgb, alpha).
vec4 shade(sampler2D tex, ivec2 p, float dith) {
	vec3 base = texelFetch(tex, p, 0).rgb;
	vec4 col;
	if (fullbright) {
		col = vec4(base, 1.0);
	} else {
		int own = int(floor(texelFetch(own_map, p, 0).r * 255.0 + 0.5)) - 1;
		if (own >= 0) {
			// AN EMITTER IS NOT LIT, IT BURNS: its own colour at its own brightness.
			float e = own_w[own];
			col = vec4(min(vec3(1.0), base * e + vec3(8.0, 10.0, 10.0) / 255.0 * e), 1.0);
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
			col = vec4(min(vec3(1.0), base * m + ov * 0.3 * m), 1.0);
		}
	}
	if (hole > 0.0 && inside(p, hole_box)) {
		bool glass = !hole_masked || (int(floor(texelFetch(own_map, p, 0).g * 255.0 + 0.5)) & 8) != 0;
		float cx = min(float(p.x) - hole_box.x, hole_box.z - 1.0 - float(p.x));
		float cy = min(float(p.y) - hole_box.y, hole_box.w - 1.0 - float(p.y));
		bool corner = cx < hole_k && cy < hole_k
			&& dot(col.rgb, vec3(0.3, 0.59, 0.11)) > 110.0 / 255.0;
		if (!corner) {
			if (glass) {
				// THE GLASS dithered out, never faded: a fade showed the glass's own
				// picture as a second rectangle going pale inside the bezel
				if (dith < hole) {
					col.a = 0.0;
				}
			} else {
				// what stands in front of it (the capital's flask tips) faded with
				// the bench, never dithered: dithered, they went as a band of dots
				col.a *= 1.0 - min(mirror, hole);
			}
		}
	}
	return col;
}

void fragment() {
	ivec2 p = ivec2(floor(UV * vec2(textureSize(TEXTURE, 0))));
	float dith = (BAYER[(p.y % 4) * 4 + (p.x % 4)] + 0.5) / 16.0;
	vec4 a = shade(TEXTURE, p, dith);
	if (mirror > 0.0 && inside(p, mirror_box)) {
		// THE BENCH LOOKED OVER: the rows turned over from above, faded in
		// (premultiplied, so a pixel let go on either side fades as it should)
		vec4 b = shade(TEXTURE, ivec2(p.x, int(mirror_sum) - p.y), dith);
		float al = mix(a.a, b.a, mirror);
		vec3 rgb = mix(a.rgb * a.a, b.rgb * b.a, mirror);
		a = vec4(al > 0.0 ? rgb / al : vec3(0.0), al);
	}
	COLOR = a;
}
