// Shared by the jump films' passes (tkg/scripts/ui/jump). Pixel arithmetic as the approved
// films' Python did it: whole screen pixels, Bayer dithers, tone-mapped stepped light.
// Why: docs/why/JumpStage.md#shader-includes

const float J_B2[4] = float[4](0.0, 0.5, 0.75, 0.25);
const float J_B4[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

// Light colours shared by the films: violet, lilac, white, rose (no ion blue, no warm orange).
const vec3 J_VIO = vec3(0.62, 0.34, 1.00);
const vec3 J_LIL = vec3(0.88, 0.76, 1.00);
const vec3 J_WHT = vec3(1.00, 0.97, 1.00);
const vec3 J_ROSE = vec3(1.00, 0.42, 0.70);

// 2x2 Bayer at integer pixel p ([y%2][x%2]).
float j_dith2(vec2 p) {
	ivec2 i = ivec2(mod(p, 2.0));
	return J_B2[i.y * 2 + i.x];
}

// 4x4 Bayer at integer pixel p, offset half a step so no threshold sits on zero.
float j_dith4(vec2 p) {
	ivec2 i = ivec2(mod(p, 4.0));
	return J_B4[i.y * 4 + i.x] / 16.0 + 1.0 / 32.0;
}

// Tone map and step: glow (dithered) and lines (not).
float j_glow_q(float L, float levels, vec2 p) {
	float v = 1.0 - exp(-L);
	return clamp(floor(v * levels + j_dith2(p) * min(1.0, v * 4.0)) / levels, 0.0, 1.0);
}

float j_line_q(float L, float levels) {
	float v = 1.0 - exp(-L);
	return clamp(floor(v * levels + 0.35) / levels, 0.0, 1.0);
}

// Light added over a picture: its brightest channel sets the step, its hue is kept.
vec3 j_add_glow(vec3 img, vec3 L, float levels, vec2 p) {
	float lm = max(L.r, max(L.g, L.b));
	if (lm <= 0.0) {
		return img;
	}
	return img + j_glow_q(lm, levels, p) * (L / lm);
}

vec3 j_add_line(vec3 img, vec3 L, float levels) {
	float lm = max(L.r, max(L.g, L.b));
	if (lm <= 0.0) {
		return img;
	}
	return img + j_line_q(lm, levels) * (L / lm);
}

// A gaussian splat of light, with an optional vertical squash.
vec3 j_splat(vec2 p, vec2 at, float r, vec3 col, float k, float sy) {
	vec2 d = p - at;
	float d2 = d.x * d.x + (d.y * sy) * (d.y * sy);
	return k * exp(-d2 / (2.0 * r * r)) * col;
}

float j_ease(float u) {
	u = clamp(u, 0.0, 1.0);
	return u * u * (3.0 - 2.0 * u);
}

float j_hsh(float i, float salt) {
	return fract(sin(i * 12.9898 + salt * 78.233) * 43758.5453);
}

// A fixed per-pixel random in 0..1 (a texture of noise would do the same).
float j_noise(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// The screen at integer pixel q, clamped into the world window (the HUD is never sampled).
vec3 j_world(sampler2D screen, vec2 px_size, vec2 q, vec4 world) {
	vec2 c = clamp(q, world.xy, world.xy + world.zw - 1.0);
	return texture(screen, (c + 0.5) * px_size).rgb;
}

// The hull's signed distance at canvas pixel h (any distance, px): the baked field inside its
// padded box; outside, the distance to a capsule through the ink (its far field is that smooth),
// blended over the pad's last 16 px. `ink` is the ink's rect in canvas px.
float j_hull_sdf(sampler2D sdf, vec2 h, vec2 size, float pad, vec4 ink) {
	vec2 q = h + pad;
	vec2 ps = size + 2.0 * pad;
	vec2 qc = clamp(q, vec2(0.0), ps - 1.0);
	vec4 s = texture(sdf, (qc + 0.5) / ps);
	float d_tex = (s.r * 255.0 * 256.0 + s.g * 255.0) / 65535.0 * 512.0 - 128.0 + length(q - qc);
	float r = ink.w * 0.5;
	vec2 a = vec2(ink.x + r, ink.y + r);
	vec2 b = vec2(ink.x + ink.z - r, ink.y + r);
	vec2 ab = b - a;
	float u = clamp(dot(h - a, ab) / max(dot(ab, ab), 1e-6), 0.0, 1.0);
	float d_cap = length(h - a - ab * u) - r;
	vec2 edge = min(q, ps - 1.0 - q);
	float inside = min(edge.x, edge.y);
	float w = smoothstep(0.0, 16.0, inside);
	return mix(d_cap, d_tex, w);
}

// The hull's picture at canvas pixel h: rgba, 0 outside the canvas.
vec4 j_hull_px(sampler2D hull, vec2 h, vec2 size) {
	if (h.x < 0.0 || h.y < 0.0 || h.x >= size.x || h.y >= size.y) {
		return vec4(0.0);
	}
	return texture(hull, (h + 0.5) / size);
}
