// THE BANNERS' CLOTH (`YardCloth`, docs/why/YardBanner.md#gpu): the state texture's layout and the grid.
// Texel (i + 13 k, j + 25 b) holds value k (Px Py Pz Ox Oy Oz) of node (i, j) of banner b as 24-bit fixed
// point, q = (v + 256) x 32768 in RGB, alpha 165 marking it written; texel (0, 25 b) is the rod's swing.
// A shader that reads the state defines STATE (its sampler) before including this: samplers are not passed on.

const int NX = 13;
const int NY = 25;
const float CW = 48.0;
const float CH = 100.0;
const float CT = 38.0;
const float HS = 1.0 / 120.0;
const float BAY[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

float tk_dec(vec4 c) {
	vec3 b = floor(c.rgb * 255.0 + 0.5);
	return (b.r * 65536.0 + b.g * 256.0 + b.b) / 32768.0 - 256.0;
}

// rounded half to even before the offset: v + 256 first would round the negatives to a finer grid, then up
vec4 tk_enc(float v) {
	float q = clamp(roundEven(v * 32768.0) + 8388608.0, 0.0, 16777215.0);
	float r = floor(q / 65536.0);
	float g = floor((q - r * 65536.0) / 256.0);
	float b = q - r * 65536.0 - g * 256.0;
	return vec4(r, g, b, 165.0) / 255.0;
}

float tk_u(int i) {
	return float(i) * 4.0;
}

float tk_v(int j) {
	return float(j) * 100.0 / 24.0;
}

// The page's 4x4 dither, offset half a level: (v + 0.5) / 16 at a frame pixel.
float tk_bay(ivec2 p) {
	return (BAY[(p.y & 3) * 4 + (p.x & 3)] + 0.5) / 16.0;
}

float tk_sstep(float a, float b, float v) {
	float u = clamp((v - a) / (b - a), 0.0, 1.0);
	return u * u * (3.0 - 2.0 * u);
}

#ifdef STATE
float tk_rod(int b) {
	return tk_dec(texelFetch(STATE, ivec2(0, NY * b), 0));
}

// A node's place in its cloth: the rod's row hangs where the rod has swung.
vec3 tk_node(int i, int j, int b, float rod) {
	if (j == 0) {
		return vec3(tk_u(i) + rod, 0.0, 0.0);
	}
	int y = j + NY * b;
	return vec3(tk_dec(texelFetch(STATE, ivec2(i, y), 0)), tk_dec(texelFetch(STATE, ivec2(i + NX, y), 0)),
		tk_dec(texelFetch(STATE, ivec2(i + 2 * NX, y), 0)));
}

// The cloth's normal at a node: across the row cross down the column, as the page projects it.
vec3 tk_normal(int i, int j, int b, float rod) {
	vec3 t = tk_node(min(NX - 1, i + 1), j, b, rod) - tk_node(max(0, i - 1), j, b, rod);
	vec3 d = tk_node(i, min(NY - 1, j + 1), b, rod) - tk_node(i, max(0, j - 1), b, rod);
	vec3 n = cross(t, d);
	float l = length(n);
	return l > 0.0 ? n / l : n;
}
#endif
