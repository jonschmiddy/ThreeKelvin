// What the star chart's four sky layers share (`StarchartScreen.MapChart`).
//
// Every layer is a mesh of empty quads, six vertices each, laid out once. The
// vertex shader works out from VERTEX_ID which star, tile or particle a quad is,
// reads what it needs, and puts the quad on the pixel the old per-frame
// GDScript loop put its `draw_rect` on -- or hides it, which is what that loop's
// `continue` did. So panning, zooming and the clock cost uniforms, not a repaint.
//
// THE ARITHMETIC MIRRORS THE GDSCRIPT IT REPLACED, step for step, because the
// look was tuned by eye on that arithmetic and a star that lands one pixel over
// is a different picture. The test for any change here is `-- sheet=ChartSheet`
// before and after, diffed.

// One chart pixel in drawn pixels. 1 today; a layer drawn into a half-size
// viewport shown at 2x would set 2, and every star would then snap to, and be
// as big as, one of THOSE pixels.
uniform float px_scale = 1.0;
// Always 0. Added to a product to keep the GPU from fusing the multiply into
// the add that follows: GDScript rounds `a * b` to a float and then adds, and
// a fused multiply-add rounds once, which moves the odd star across a pixel
// boundary. The GPU cannot fold a uniform away, so the product is rounded alone.
uniform float zero = 0.0;

const vec2 HIDE = vec2(-100000.0);
const vec2 CORNER[6] = vec2[](vec2(0.0, 0.0), vec2(1.0, 0.0), vec2(1.0, 1.0),
	vec2(0.0, 0.0), vec2(1.0, 1.0), vec2(0.0, 1.0));

// `a * b` rounded on its own before whatever it is added to (see `zero`).
float mul(float a, float b) {
	return a * b + zero;
}

vec2 mul2(vec2 a, float b) {
	return a * b + zero;
}

// Vector2.length(): sqrt(x*x + y*y), each square rounded first.
float len(vec2 d) {
	return sqrt(mul(d.x, d.x) + mul(d.y, d.y));
}

// Vector2.round(): halves away from zero, which GLSL's round() does not promise.
vec2 round_away(vec2 q) {
	return sign(q) * floor(abs(q) + 0.5);
}

// To the drawn pixel grid.
vec2 snap(vec2 q) {
	return round_away(q / px_scale) * px_scale;
}

// One rect's corner: `draw_rect(Rect2(at, size))` as two triangles.
vec2 quad_corner(int vid, vec2 at, vec2 size) {
	return at + CORNER[vid % 6] * size * px_scale;
}

// Color.darkened, as Godot computes it.
vec4 darkened(vec4 c, float amount) {
	return vec4(c.rgb * (1.0 - amount), c.a);
}

// MapChart._hash2: the tile hash, in 31 bits. GDScript does it in 64-bit ints
// and masks; the low 31 bits of a product depend only on the low bits of its
// factors, so wrapping 32-bit arithmetic gives the same number.
uint hash2(int i, int j, int salt) {
	uint h = (uint(i) * 374761393u + uint(j) * 668265263u + uint(salt) * 144665u) & 0x7fffffffu;
	h = (h ^ (h >> 13u)) & 0x7fffffffu;
	h = (h * 1274126177u) & 0x7fffffffu;
	return (h ^ (h >> 16u)) & 0x7fffffffu;
}

// The star field's linear congruential generator, one step.
uint lcg(uint s) {
	return (s * 1103515245u + 12345u) & 0x7fffffffu;
}

// The same generator n steps on, without taking them: a step is an affine map
// mod 2^31, and powers of it compose by squaring, so the 1,050th draw of a tile
// costs eleven multiplies instead of 1,050.
uint lcg_jump(uint s, uint n) {
	uint a = 1103515245u;
	uint c = 12345u;
	uint ra = 1u;
	uint rc = 0u;
	while (n > 0u) {
		if ((n & 1u) != 0u) {
			ra = ra * a;
			rc = rc * a + c;
		}
		c = c * a + c;
		a = a * a;
		n = n >> 1u;
	}
	return (ra * s + rc) & 0x7fffffffu;
}

// `(seed >> 13) % 10000`: a roll in ten-thousandths, kept as the integer.
//
// COMPARE A ROLL WITH A FIXED THRESHOLD AS THIS INTEGER, never as the float.
// GDScript divides in double precision, exactly; the GPU's divide can come out
// one bit high, and a roll of exactly 6200 then reads as more than 0.62 --
// which in the halo turned a few stars a brightness step up. `x > 6200` is
// what `x / 10000.0 > 0.62` meant in GDScript, tie included.
uint roll_i(uint s) {
	return (s >> 13u) % 10000u;
}

// The same roll as the float the arithmetic wants.
float roll(uint s) {
	return float(roll_i(s)) / 10000.0;
}

// MapChart's old `_lens`: where a background point appears once the black hole
// has bent the light from it, and whether it is visible at all.
//
// The deep field is drawn BEFORE the galaxy and nothing used to mask it, so
// distant stars showed straight through the hole -- the one object light does
// not come out of was the most transparent thing on screen. And a black hole
// does not merely block what is behind it, it wraps it: an approximate
// Einstein deflection pushes background points radially outward by r_s^2 / d,
// which piles them into a bright arc just outside the shadow and clears a true
// void inside. Anything that lands within the shadow is behind the hole and is
// not drawn. False when the point is swallowed.
bool lens(vec2 p, vec2 centre, float r_s, out vec2 o) {
	vec2 d = p - centre;
	float far = len(d);
	o = p;
	if (far < 0.001 || far <= r_s) {
		return false;
	}
	float shifted = far + (r_s * r_s) / far;
	o = centre + mul2(d, shifted / far);
	return true;
}
