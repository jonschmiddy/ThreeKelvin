shader_type canvas_item;
render_mode unshaded, blend_disabled;

// THE HOLE'S LENS (`ChartSky`): what lies behind the black hole, bent round
// it. A point lens moves the sky by te^2 / r away from the hole, so a block r
// out shows the sky at r - te^2 / r: tiny far out, so it runs all the way out
// and is only eased to nothing over a long stretch (and before the innermost
// ring, so the systems' sky never bends), and nothing is clamped -- inside the
// Einstein ring the field is the same field, turned inside out and squeezed.
// Colours are copied whole; only a point source the bend stretches brightens.
//
// NO SEAMS ("weird visual artifacts ... at different magnifications", Jon):
// the bend is eased out over a long stretch, never inside its own range (it
// used to stop at the innermost ring, which since the hole stopped shrinking
// with zoom sits just outside it, so the bend stopped sharply in a thin pale
// ellipse right over the shadow); and the inverted field inside the ring,
// which reaches far off the picture, is drawn in toward the hole smoothly
// rather than read back reflected at the picture's edge (the reflection's
// seams and tiles showed through the disc as patches and a line). The near side of the swirl is in front
// of the hole, so it is left alone (alpha 0.75 and 0.25, from the field).

#include "res://shaders/chart_galaxy.gdshaderinc"

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform vec2 vp_size = vec2(330.0, 220.0);
// the hole's block, and its centre in screen pixels from that block's corner
uniform vec2 hv = vec2(165.0, 110.0);
uniform float te = 10.0;
uniform float rbl = 100.0;
uniform float eff = 0.38;

float mir(float q, float n) {
	for (int k = 0; k < 4; k++) {
		if (q >= 0.0 && q <= n - 1.0) {
			break;
		}
		q = q < 0.0 ? -q : 2.0 * (n - 1.0) - q;
	}
	return clamp(q, 0.0, n - 1.0);
}

vec4 at(vec2 b) {
	return texelFetch(screen_tex, ivec2(int(mir(b.x, vp_size.x)), int(mir(b.y, vp_size.y))), 0);
}

void fragment() {
	vec2 vp = floor(UV * vp_size);
	vec4 own = at(vp);
	COLOR = own;
	float rl = max(te * 6.0, 40.0), rin = te * 1.2;
	vec2 d = (vp - hv) * 2.0;
	float r = length(d) + 0.01;
	bool keep = abs(own.a - 0.75) < 0.1 || abs(own.a - 0.25) < 0.1;
	if (r < rl && !keep) {
		float rdk = length(vec2(d.x, d.y / eff));
		float rbe = max(rbl, rl * 1.2);
		float taper = (r <= rin ? 1.0 : 1.0 - g_sm(rin, rl, r)) * (1.0 - g_sm(0.4 * rbe, rbe, rdk));
		float e = te * te / (r * r) * taper;
		// where it reads from, in blocks from the hole; inside the ring that
		// reaches ever further off, so there it fades to the field's mean
		// colour further out instead (`inner`) -- never read back reflected at
		// the picture's edge, never streaked
		vec2 sv = d * (1.0 - e) * 0.5;
		float inner = 0.0;
		if (e > 1.0) {
			float tb = te * 0.5;
			inner = g_sm(0.25 * tb, 1.2 * tb, length(sv));
			sv *= min(1.0, 1.2 * tb / max(length(sv), 1e-3));
		}
		vec2 src = hv + floor(sv + 0.5);
		if (src != vp) {
			vec4 c = at(src);
			float mu = 1.0 / max(0.02, abs(1.0 - e * e));
			if (mu > 1.4) {
				vec3 s4 = at(src + vec2(-1.0, 0.0)).rgb + at(src + vec2(1.0, 0.0)).rgb
					+ at(src + vec2(0.0, -1.0)).rgb + at(src + vec2(0.0, 1.0)).rgb;
				float m = (s4.r + s4.g + s4.b) * 255.0 / 4.0;
				if ((c.r + c.g + c.b) * 255.0 > m + 45.0) {
					float g = min(1.25, 1.0 + 0.12 * log2(mu));
					c = vec4(min(c.rgb * g, vec3(1.0)), 0.5);
				}
			}
			if (inner > 0.0) {
				// the field further out, averaged round a ring: what the
				// inverted picture inside the ring would mostly show
				float tb = te * 0.5;
				vec3 cc = vec3(0.0);
				for (int j = 0; j < 8; j++) {
					float an = float(j) * 0.785 + 0.2;
					cc += at(hv + floor(vec2(cos(an), sin(an) * eff) * tb * 1.3)).rgb;
				}
				c = vec4(mix(c.rgb, cc / 8.0, inner), c.a);
			}
			COLOR = c;
		}
	}
}
