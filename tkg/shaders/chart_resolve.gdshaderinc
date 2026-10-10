// THE CHART RESOLVES AS YOU ZOOM IN, every style's (Oct 10 polish; Jon: "zooming
// in causes ... dust disappearing, dust looking flat and not visually
// interesting"). The bakes the place passes read are made once, at a fixed
// resolution: past about zoom 1.4 a bake texel is bigger than a block, so up
// close the gas was a magnified, blurred texture the palette cut into flat
// plates, and the stars were the chart's own few hundred, thinning across the
// screen as it grew. The rule here: detail only ever INCREASES as you zoom.
//
//   * crStars: the stars a patch of the disc resolves into. Fixed in the disc's
//     own plane (they turn with the galaxy and never swim), one block each, on
//     grids that halve as the zoom doubles. A grid comes in only once its cells
//     span 8 to 16 screen px, its stars brightening from nothing as it does, so
//     no star pops and none ever goes: a coarser grid's stars stay where they
//     were. The caller says how many (its own light there) and how bright.
//   * crDetail: the gas's structure past the bake's resolution, octave by
//     octave. An octave comes in once its wavelength spans 4 to 8 blocks and
//     stays (nothing finer than four blocks, so the zoom never makes it
//     shimmer), and octaves only ever ADD: the value is never renormalised, so
//     the broad shapes keep their contrast as the fine ones arrive.
// Needs `chart_kit.gdshaderinc`.

// one candidate a cell, plane units (gu); `pv` the block's view point at zoom 1
// (the place passes' `v`), `hb` half a block in those units (1 / zoom, or larger
// where a lens squeezes the picture). (found 0/1, brightness 0..1 with the
// grid's fade, temperature 0..1, spare)
vec4 crStars(vec2 p, vec2 pv, float hb, float phi, float k, float zoom, float c0, float prob, int seed) {
	vec4 best = vec4(0.0);
	if (prob <= 0.0) {
		return best;
	}
	float cs = cos(phi), sn = sin(phi);
	for (int L = 0; L < 6; L++) {
		float c = c0 / exp2(float(L));
		float w = smoothstep(8.0, 16.0, c * zoom * k);
		if (w <= 0.0) {
			break;
		}
		ivec2 c0i = ivec2(floor(p / c));
		for (int j = -1; j <= 1; j++) {
			for (int i = -1; i <= 1; i++) {
				ivec2 cc = c0i + ivec2(i, j);
				vec3 h = kitHash3(cc + ivec2(seed * 7919 + L * 104729, seed * 3571 + L * 1299709));
				// a soft gate, not a cut: the light that sets `prob` is read at the
				// block, which slides under the star as the zoom moves, so a star
				// near the line dims and brightens rather than blinking
				float gate = smoothstep(0.0, 0.1, prob - h.z);
				if (gate <= 0.0) {
					continue;
				}
				vec2 ps = (vec2(cc) + 0.08 + 0.84 * h.xy) * c;
				// the star's view point at zoom 1 (kitViewToPlane's inverse)
				vec2 vs = vec2(ps.x * cs + ps.y * sn, (ps.y * cs - ps.x * sn) * KIT_TILT) * k;
				vec2 d = vs - pv;
				if (d.x >= -hb && d.x < hb && d.y >= -hb && d.y < hb) {
					vec3 g = kitHash3(cc + ivec2(seed * 131 + 17 + L * 31, seed * 977 + 5 + L * 57));
					float br = w * g.x * gate;
					if (br > best.y) {
						best = vec4(1.0, br, g.y, g.z);
					}
				}
			}
		}
	}
	return best;
}

// the gas's structure below `lam0` (gu), for a block `pxGu` gu across: signed,
// about -1..1 once every octave is in, 0 while none is
float crDetail(vec2 p, float pxGu, float lam0, float seed) {
	float s = 0.0, a = 0.5;
	for (int i = 0; i < 5; i++) {
		float lam = lam0 / exp2(float(i));
		float w = smoothstep(4.0, 8.0, lam / pxGu);
		if (w <= 0.0) {
			break;
		}
		s += a * w * kitSnoise2(p / lam + vec2(seed * 3.7 + float(i) * 17.3, seed * 1.9 + float(i) * 9.1));
		a *= 0.62;
	}
	return s;
}
