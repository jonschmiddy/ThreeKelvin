shader_type canvas_item;
render_mode unshaded, blend_disabled;

// ONE PALETTE FOR THE WHOLE VIEW (Jon: "kinda lost the pixel game aesthetic
// ... the stars, planets, starfield behind all need to have that same type of
// pixelated vibe"; then "even more pixelated"). Everything drawn so far -- the
// sky, the gas, the star's light, the belts, the shadows, the star -- is set to
// its nearest colour in the system's own short palette (`SystemPalette.gd`
// finds it from the system's own picture), and dithered in 2x2 cells with the
// next nearest only where it truly falls between two colours that are near
// each other and not both dark: a flat area stays flat, dark sky stays clean
// (a grid of near-blacks read as "a grid like pattern all over the whole
// background"), a gradient becomes steps with a pattern at each step.
//
// Drawn before the worlds and the lines, which keep their own colours.

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform vec3 pal[72];
uniform int pal_n = 0;
uniform float x0 = 264.0;
// a cell of the dither is this many game pixels across
uniform int cell = 2;

const float BAYER4[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void fragment() {
	vec4 src = texture(screen, SCREEN_UV);
	vec2 px = floor(SCREEN_UV / SCREEN_PIXEL_SIZE);
	if (pal_n == 0 || px.x < x0) {
		COLOR = src;
	} else {
		vec3 c = floor(src.rgb * 255.0 / 8.0) * 8.226;
		int a = 0, s = 0;
		float ad = 1e9, sdd = 1e9;
		for (int k = 0; k < pal_n; k++) {
			vec3 p = pal[k] * 255.0, dv = c - p;
			float d = dv.r * dv.r * 2.0 + dv.g * dv.g * 4.0 + dv.b * dv.b * 3.0;
			if (d < ad) { s = a; sdd = ad; a = k; ad = d; } else if (d < sdd) { s = k; sdd = d; }
		}
		vec3 A = pal[a] * 255.0, S = pal[s] * 255.0, v = S - A;
		float vv = dot(v, v);
		float f = vv > 0.0 ? dot(c - A, v) / vv : 0.0;
		f = clamp(f, 0.0, 0.5);
		if (vv < 26.0 * 26.0 || max(A.r, max(A.g, A.b)) + max(S.r, max(S.g, S.b)) < 90.0) f = 0.0;
		ivec2 q = ivec2(px) / cell;
		float thr = (BAYER4[(q.y & 3) * 4 + (q.x & 3)] + 0.5) / 16.0;
		COLOR = vec4((f > thr ? S : A) / 255.0, 1.0);
	}
}
