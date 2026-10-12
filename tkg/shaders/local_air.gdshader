shader_type canvas_item;
render_mode unshaded, blend_add;

// THE AIR OF THE WORLD YOU ORBIT, LIT (`LocalLife`): a thin bright shell of
// atmosphere on the limb that faces the star, the light the air scatters --
// brightest just outside the edge, falling off over a few pixels, wrapping a
// little past the terminator, a faint forward glow all round when the star is
// behind the world -- and a softer brightening just inside the limb. Added as
// light over the near picture (the play tone pressed the painter's own thin air
// to almost nothing), on the world's own 2 px blocks, in the air's colour, not
// under the front of a ring (the ring is in front of it).
//
// By style: SIMPLIFIED four dithered steps; PAINTED a crisp line, two flat
// tones, no dither (a pixel artist's rim); RADIANT through an exposure, finer
// steps, gentler (its painter already wraps the world in a lit shell);
// LEGACY its old blue-greys, three steps.

// the world's centre and radius, frame px (the sky's 960x540)
uniform vec2 ctr = vec2(700.0, 380.0);
uniform float r = 150.0;
// the light on the world (x right, y down, z toward you), unit
uniform vec3 L = vec3(-0.6, -0.6, 0.5);
uniform vec3 col = vec3(0.5, 0.7, 1.0);
uniform float k = 0.0;
// the shell's depth outside the edge, px
uniform float w = 6.0;
// rings, in the world's radii (0: none), seen squashed by `squash`
uniform vec2 ring = vec2(0.0);
uniform float squash = 0.28;
uniform int style = 0;

void fragment() {
	vec2 blk = floor(UV * vec2(480.0, 270.0));
	vec2 p = (blk + 0.5) * 2.0;
	vec2 q = p - ctr;
	float d = length(q);
	vec2 n = q / max(d, 1e-3);
	// lit: the side toward the star, wrapping a little past the terminator; and
	// forward scattering, the whole rim glowing when the star is behind it
	vec2 l2 = normalize(L.xy + vec2(1e-4, 0.0));
	float lit = clamp((dot(n, l2) * length(L.xy) + 0.25) / 1.25, 0.0, 1.0);
	lit = lit * lit + 0.6 * max(0.0, -L.z);
	float I = 0.0;
	float h = 0.0;
	bool outside = d >= r && d < r + w;
	if (outside) {
		h = (d - r) / w;
		I = lit * pow(1.0 - h, 1.6);
	} else if (d < r && d > r - 2.5 * w) {
		h = (r - d) / (2.5 * w);
		I = 0.45 * lit * pow(1.0 - h, 2.2);
	}
	// under the front of the rings
	if (ring.y > 0.0 && q.y > 0.0) {
		float rho = length(vec2(q.x, q.y / squash)) / r;
		if (rho > ring.x && rho < ring.y) I = 0.0;
	}
	// the dither, on the world's own block grid (anchored to its centre, so the
	// pattern moves with it)
	ivec2 b = ivec2(blk - floor(ctr / 2.0)) & ivec2(1);
	float th = (float((b.x * 2 + b.y * 3) & 3) + 0.5) / 4.0;
	vec3 o;
	if (style == 1) {
		// PAINTED: the first block out the air's light colour, the next a darker
		// flat tone, only on the lit side; nothing inside the limb
		float s = 0.0;
		if (outside && lit > 0.3) s = d < r + 2.0 ? 0.95 : (d < r + 4.0 && lit > 0.55 ? 0.45 : 0.0);
		o = mix(col, vec3(1.0), 0.25) * s;
	} else if (style == 2) {
		// RADIANT: light through the style's exposure, in fine dithered steps
		vec3 x = col * I * 1.6;
		o = vec3(1.0) - exp(-x);
		o = floor(o * 12.0 + th) / 12.0;
	} else if (style == 3) {
		// LEGACY: its blue-greys
		o = mix(col, vec3(0.62, 0.69, 0.78), 0.55) * (floor(I * 3.0 + th) / 3.0);
	} else {
		o = col * (floor(I * 4.0 + th) / 4.0);
	}
	COLOR = vec4(o * k, 1.0);
}
