// The warp field, shared by R3 THE RIFT and R8 MAELSTROM: the world and the stand-in hull are
// drawn first (the film's ship pass), copied, then bent together by the warp pass, which
// samples nine taps a pixel in linear light (the films' 3x3 SOFT rule) with the sky past the
// window mirrored back in, and adds the film's stepped light. As rift.py and maelstrom.py did it.
// Why: docs/why/JumpWarpField.md#warp-field

const float JW_B4[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
// the films' 3x3 sub-samples a pixel, (i + 0.5) / 3 - 0.5
const vec2 JW_SUB[9] = vec2[9](vec2(-0.3333, -0.3333), vec2(0.0, -0.3333), vec2(0.3333, -0.3333),
	vec2(-0.3333, 0.0), vec2(0.0, 0.0), vec2(0.3333, 0.0),
	vec2(-0.3333, 0.3333), vec2(0.0, 0.3333), vec2(0.3333, 0.3333));

// The films' DITH: the 4x4 Bayer anchored at the frame's corner, no offset.
float jw_dith(vec2 p) {
	ivec2 i = ivec2(mod(p, 4.0));
	return JW_B4[i.y * 4 + i.x] / 16.0;
}

// `stepped`: tone-mapped, quantised, the dither growing with the light.
float jw_stepped(float L, float levels, vec2 p) {
	float v = 1.0 - exp(-L);
	return clamp(floor(v * levels + jw_dith(p) * min(1.0, v * 5.0)) / levels, 0.0, 1.0);
}

// `add_light`: a coloured light added to a linear picture in steps, its brightest channel stepping.
vec3 jw_add_light(vec3 img, vec3 L, vec2 p) {
	float lum = max(L.r, max(L.g, L.b));
	if (lum <= 0.0) {
		return img;
	}
	return img + jw_stepped(lum, 7.0, p) * (L / lum) * 0.9;
}

vec3 jw_lin(vec3 c) {
	return pow(c, vec3(2.2));
}

vec3 jw_srgb(vec3 c) {
	return pow(max(c, vec3(0.0)), vec3(1.0 / 2.2));
}

// numpy's reflect index (`_refl`): the sky past the window is the window mirrored, as the films padded it.
float jw_refl(float i, float n) {
	float p = 2.0 * n - 2.0;
	i = mod(i, p);
	return i >= n ? p - i : i;
}

// The picture so far at the nearest pixel to q, mirrored back into the window `win`.
vec3 jw_world(sampler2D screen, vec2 px_size, vec2 q, vec4 win) {
	vec2 i = floor(q + 0.5) - win.xy;
	i = vec2(jw_refl(i.x, win.z), jw_refl(i.y, win.w));
	return texture(screen, (win.xy + i + 0.5) * px_size).rgb;
}

vec2 jw_rot(vec2 v, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(v.x * c - v.y * s, v.x * s + v.y * c);
}

// A wrapped angle in (-pi, pi], numpy's `angle(exp(1j * a))`.
float jw_wrap(float a) {
	return mod(a + PI, TAU) - PI;
}

// The films' `hash01`, in 32-bit integer steps: the same numbers numpy drew from it.
float jw_hash2(int a, int b) {
	uint h = 0u;
	h = h * 1000003u + uint(a) * 7919u + 12345u;
	h = h * 1000003u + uint(b) * 7919u + 12345u;
	return float(h * 2654435761u) / 4294967296.0;
}

float jw_hash3(int a, int b, int c) {
	uint h = 0u;
	h = h * 1000003u + uint(a) * 7919u + 12345u;
	h = h * 1000003u + uint(b) * 7919u + 12345u;
	h = h * 1000003u + uint(c) * 7919u + 12345u;
	return float(h * 2654435761u) / 4294967296.0;
}

// A point's rolled number `k` (0..1): a fixed draw for point i, the same on every GPU.
float jw_roll(int i, int k) {
	uint h = uint(i) * 747796405u + uint(k) * 2891336453u + 1u;
	h = ((h >> ((h >> 28u) + 4u)) ^ h) * 277803737u;
	h = (h >> 22u) ^ h;
	return float(h) / 4294967296.0;
}
