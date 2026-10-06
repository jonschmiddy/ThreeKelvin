shader_type canvas_item;
render_mode unshaded, blend_add;

// THE SIMPLIFIED CHART'S STARS (`ChartSky`), splatted into a block-res buffer the
// place pass reads (`chart_c_place`'s u_stars): one quad a star, placed here
// from its index, added up. The showcase's `KIT.chartStars` on the GPU: the
// chart's own star field (`MapChart._build_stars`), only the stars bright
// enough to be seen one at a time, SPARSE -- at the opening view about 40% of
// those at luminance 150 and up, thinned by a fixed hash per star (brightness
// in the field is quantised, so a threshold cannot thin them), more fading in
// as you zoom, all of them by zoom 2 and down to luminance 60 by zoom 3, each
// keeping its hash so nothing pops on a pan. The brightest wear a faint plus.
// Close in, the core's own crowd runs right up to the hole; below zoom 2 a
// globular cluster is a tight knot of stars; the knots' young clusters fade in
// from zoom 1; and the clouds' own stars (an emission cloud's cluster, a
// reflection cloud's lamps, a planetary's hot star, a pulsar's beat) come per
// frame as `extra`.
//
// Data, one star a texel, SKY_TEX_W to a row:
//   st_a  (plane x, plane y, luminance 0-255, kind)
//         kind 0 a disc star, 1 the core's, 2 a globular's member, 3 a knot's
//         young star (lum = the knot's index), 4 a globular as a knot (lum = its
//         size; the colour texel holds the member's angle and hashes)
//   st_b  (linear r, g, b, the star's fixed hash)
//   st_c  (two more hashes, for the core's crowd)

uniform sampler2D st_a : filter_nearest;
uniform sampler2D st_b : filter_nearest;
uniform sampler2D st_c : filter_nearest;
uniform int tex_w = 2048;
uniform int n_star = 0;
uniform vec4 extra_pos[128];   // block x, y, plus (0/1), 0
uniform vec4 extra_col[128];   // linear r, g, b, 0
uniform int n_extra = 0;
uniform float kn_amp[64];

uniform vec2 vp_origin = vec2(-2.0);
uniform vec2 cpix = vec2(327.0, 214.0);
uniform vec2 res = vec2(655.0, 429.0);
uniform float zoom = 0.42;     // effective, in the showcase's units
uniform float k = 622.25;
uniform float phi = 0.0;
uniform float bulge_r = 0.128;

varying vec3 v_col;
varying vec2 v_loc;
varying float v_plus;

const vec2 CORNER[6] = vec2[](vec2(0.0, 0.0), vec2(1.0, 0.0), vec2(1.0, 1.0),
	vec2(0.0, 0.0), vec2(1.0, 1.0), vec2(0.0, 1.0));

float sm(float a, float b, float x) {
	float u = clamp((x - a) / (b - a), 0.0, 1.0);
	return u * u * (3.0 - 2.0 * u);
}

vec2 toScreen(vec2 p) {
	float c = cos(phi), s = sin(phi);
	vec2 v = vec2(p.x * c + p.y * s, (p.y * c - p.x * s) * 0.38) * k;
	return cpix + v * zoom;
}

// as the showcase's star buffer adds them: a little desaturated, so the place
// pass's saturation lift brings them back to their own colour
vec3 soften(vec3 c) {
	float l = 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
	return vec3(l) + (c - vec3(l)) / 1.5;
}

void vertex() {
	int id = VERTEX_ID / 6;
	vec2 corner = CORNER[VERTEX_ID % 6];
	vec3 col = vec3(0.0);
	vec2 blk = vec2(-100.0);
	float plus = 0.0;
	float lz = log(zoom);
	if (id < n_star) {
		ivec2 at = ivec2(id % tex_w, id / tex_w);
		vec4 a = texelFetch(st_a, at, 0);
		vec4 b = texelFetch(st_b, at, 0);
		int kind = int(a.w + 0.5);
		vec2 p = a.xy;
		vec2 s = toScreen(p);
		if (kind <= 2) {
			float lum = a.z;
			float L = zoom <= 0.6 ? 150.0 : (zoom >= 3.0 ? 60.0 : 150.0 + (60.0 - 150.0) * (lz - log(0.6)) / (log(3.0) - log(0.6)));
			float keep = zoom <= 0.6 ? 0.4 : (zoom >= 2.0 ? 1.0 : 0.4 + 0.6 * (lz - log(0.6)) / (log(2.0) - log(0.6)));
			bool show = lum >= L;
			if (kind == 1 && zoom < 2.0 && length(p) < bulge_r) {
				show = false;
			}
			if (kind == 2 && zoom < 2.0) {
				show = false;
			}
			float kk = kind == 1 ? keep * 0.25 : keep;
			float hs = b.w;
			if (hs >= kk) {
				show = false;
			}
			if (show) {
				float fade = min(1.0, (lum - L) / 30.0 + 0.15) * min(1.0, (kk - hs) / 0.08 + 0.15);
				float it = 0.9 * fade * pow(lum / 255.0, 2.0) * 2.2;
				col = b.rgb * it;
				plus = it > 1.5 ? 1.0 : 0.0;
				blk = floor((s - vp_origin) * 0.5);
			}
			// close in, the core's own crowd: faint, right up to the hole
			float cz = sm(2.2, 4.0, zoom);
			if (kind == 1 && cz > 0.0) {
				vec4 c2 = texelFetch(st_c, at, 0);
				if (c2.x >= 0.25) {
					float it2 = cz * (0.55 + 0.9 * sm(3.0, 6.0, zoom)) * pow(lum / 255.0, 1.2) * (0.5 + c2.y);
					col += b.rgb * it2;
					blk = floor((s - vp_origin) * 0.5);
				}
			}
		} else if (kind == 3) {
			// a knot's young cluster, breathing with its knot
			float kg = sm(0.9, 1.8, zoom);
			if (kg > 0.0) {
				float amp = kn_amp[clamp(int(a.z + 0.5), 0, 63)];
				float q = kg * b.x * amp * 0.9;
				col = vec3(0.8, 0.9, 1.15) * q;
				blk = floor((s - vp_origin) * 0.5);
			}
		} else {
			// a globular below zoom 2: a hot middle, four members at fixed
			// offsets on the screen, so they open out as you zoom
			float gg = 1.0 - sm(1.6, 2.2, zoom);
			if (gg > 0.0) {
				float amt = 0.5 * gg * min(1.3, a.z / 60.0);
				if (b.w < 0.0) {
					col = vec3(amt, amt * 0.88, amt * 0.72);
					blk = floor((s - vp_origin) * 0.5);
				} else {
					float an = b.x * 6.283;
					float d = (2.0 + 3.0 * sqrt(b.y)) * zoom * 0.5;
					float q = amt * (0.10 + 0.14 * b.z) * min(1.0, d / 1.2);
					col = vec3(q, q * 0.9, q * 0.76);
					blk = floor((s + vec2(cos(an) * d * 2.0, sin(an) * d * 1.6) - vp_origin) * 0.5);
				}
			}
		}
		if (s.x < 0.0 || s.y < 0.0 || s.x >= res.x || s.y >= res.y) {
			blk = vec2(-100.0);
		}
	} else if (id - n_star < n_extra) {
		int e = id - n_star;
		blk = extra_pos[e].xy;
		col = extra_col[e].rgb;
		plus = extra_pos[e].z;
	}
	col = soften(col);
	v_col = col;
	v_plus = plus;
	// a plus covers the 3x3 round its block; a plain star its own block
	vec2 lo = plus > 0.5 ? blk - 1.0 : blk;
	vec2 sz = plus > 0.5 ? vec2(3.0) : vec2(1.0);
	v_loc = corner * sz;
	VERTEX = lo + corner * sz;
}

void fragment() {
	float w = 1.0;
	if (v_plus > 0.5) {
		ivec2 c = ivec2(floor(v_loc));
		int dx = abs(c.x - 1), dy = abs(c.y - 1);
		w = (dx == 0 && dy == 0) ? 1.0 : ((dx + dy == 1) ? 0.18 : 0.0);
	}
	COLOR = vec4(v_col * w, 1.0);
}
