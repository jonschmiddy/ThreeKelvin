shader_type canvas_item;
render_mode unshaded, blend_disabled;

// THE PALETTE'S LOOKUP, made once per palette (`ChartSky`): for each of the
// 32768 colours a 15-bit key can name, the nearest colour of the palette, the
// next nearest, how far toward the second the colour lies (the dither's
// share, capped at half, and zero where the two are far apart or both dark:
// the sector map's rule), and the same share uncapped. 256 x 128 texels.

uniform sampler2D pal : filter_nearest;
uniform int n = 0;

void fragment() {
	ivec2 p = ivec2(floor(UV * vec2(256.0, 128.0)));
	int key = p.y * 256 + p.x;
	vec3 c = vec3(float((key >> 10) & 31), float((key >> 5) & 31), float(key & 31)) * 8.226;
	int a = 0, s = 0;
	float ad = 1e9, sdd = 1e9;
	for (int k = 0; k < 128; k++) {
		if (k >= n) {
			break;
		}
		vec3 q = texelFetch(pal, ivec2(k, 0), 0).rgb * 255.0;
		vec3 dv = c - q;
		float d = dv.r * dv.r * 2.0 + dv.g * dv.g * 4.0 + dv.b * dv.b * 3.0;
		if (d < ad) {
			s = a;
			sdd = ad;
			a = k;
			ad = d;
		} else if (d < sdd) {
			s = k;
			sdd = d;
		}
	}
	vec3 pa = texelFetch(pal, ivec2(a, 0), 0).rgb * 255.0;
	vec3 ps = texelFetch(pal, ivec2(s, 0), 0).rgb * 255.0;
	vec3 v = ps - pa;
	float vv = dot(v, v);
	float f = vv > 0.0 ? dot(c - pa, v) / vv : 0.0;
	float rawf = clamp(f, 0.0, 1.0);
	f = clamp(f, 0.0, 0.5);
	if (vv < 26.0 * 26.0 || max(pa.r, max(pa.g, pa.b)) + max(ps.r, max(ps.g, ps.b)) < 90.0) {
		f = 0.0;
	}
	COLOR = vec4(float(a), float(s), floor(f * 32.0 + 0.5), floor(rawf * 63.0 + 0.5)) / 255.0;
}
