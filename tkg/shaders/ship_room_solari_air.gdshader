shader_type canvas_item;
render_mode unshaded;

// SOLARI'S HALL AIR, over the room and its back life, under the hulls (show18.post, in its order):
// the worn deck's smeared sheen of the bright wall above it, the depth haze glowing with the light
// round it (twelfths), and furnace 2's beam through the haze while it roars; show21's air first:
// the heat shimmer over the furnaces and a pouring bed, the warm haze under the roof.
// Why: docs/why/ShipRoomSolari.md#air

#include "res://shaders/ship_room_solari.gdshaderinc"

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform sampler2D masks : filter_nearest, repeat_disable;
uniform float beam_op = 0.0;
// the hot air's bands this frame (x0, x1, y0, y1), in atmos.shimmer's order, and its tick (3 a second)
uniform int n_shim = 0;
uniform vec4 shim[12];
uniform float shim_tick = 0.0;

varying vec2 fp;

void vertex() {
	fp = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

vec3 bright(vec2 uv) {
	vec3 c = texture(screen, uv).rgb;
	return dot(c, vec3(0.299, 0.587, 0.114)) > 200.0 / 255.0 ? c : vec3(0.0);
}

float h3(float a, float b, float c) {
	return fract(sin(12.9898 * a + 25.9796 * b + 38.9694 * c + 78.233) * 43758.5453);
}

void fragment() {
	vec2 k = SCREEN_PIXEL_SIZE / max(dFdx(fp.x), 1e-4);
	vec2 f = floor(fp);
	// heat shimmer: 2-row bands of what is behind shifted a whole pixel sideways
	float sx = 0.0;
	for (int i = 0; i < n_shim; i++) {
		vec4 b = shim[i];
		float x0 = max(1.0, b.x);
		float x1 = min(959.0, b.y);
		if (f.y < b.z || f.y >= b.w) {
			continue;
		}
		float yb = b.z + 2.0 * floor((f.y - b.z) / 2.0);
		float hv = h3(float(i), floor(yb / 2.0), shim_tick);
		if (hv < 0.6) {
			continue;
		}
		float s = hv > 0.8 ? 1.0 : -1.0;
		if (f.x >= x0 + s && f.x < x1 + s) {
			sx = s;
		}
	}
	vec3 c = texture(screen, SCREEN_UV - vec2(sx, 0.0) * k).rgb;
	if (f.y < 62.0) {
		// the ceiling haze: three levels, their boundaries pair-dithered, lit by the furnace glow below
		vec3 mg = light_m(vec2(fp.x, 100.0));
		float glow = clamp((mg.r + mg.g + mg.b) / 3.0 - 0.2, 0.0, 1.4);
		vec3 hc = (vec3(40.0, 26.0, 18.0) + glow * vec3(120.0, 70.0, 34.0)) / 255.0;
		float a = f.y < 22.0 ? 0.24 : (f.y < 42.0 ? 0.16 : 0.08);
		bool pair = mod(f.x + f.y, 2.0) != 0.0;
		if (pair && (f.y == 20.0 || f.y == 21.0)) {
			a = 0.16;
		} else if (pair && (f.y == 40.0 || f.y == 41.0)) {
			a = 0.08;
		}
		c = c * (1.0 - a) + hc * a;
	}
	vec4 mk = texelFetch(masks, ivec2(f), 0);
	if (mk.b > 0.0) {
		// the sheen: the wall's bright things mirrored about its foot, stretched, smeared into streaks
		vec3 acc = vec3(0.0);
		float n = 0.0;
		for (int dy = -8; dy <= 8; dy += 2) {
			float y = f.y + float(dy);
			if (y < FOOT || y >= 372.0) {
				n += 5.0;
				continue;
			}
			float src = FOOT - floor((y - FOOT) * 1.25);
			float fade = clamp(1.0 - (y - FOOT) / 165.0, 0.0, 1.0) * 0.34;
			for (int dx = -6; dx <= 6; dx += 3) {
				vec2 uv = SCREEN_UV + vec2(float(dx), src - f.y) * k;
				acc += bright(uv) * fade;
				n += 1.0;
			}
		}
		vec3 o = acc / n;
		float m = max(o.r, max(o.g, o.b));
		if (m > 0.0) {
			float st = floor(clamp(m * 3.0, 0.0, 1.0) * 4.0) / 4.0 / 3.0;
			c += o / m * st;
		}
	}
	float a = floor(mk.g * 12.0 + 0.01) / 12.0;
	c = hazed(c, fp, a);
	if (beam_op > 0.0 && f.y >= 104.0 && f.y < FOOT && abs(f.x - 206.0) < 30.0) {
		float u = clamp((f.y - 104.0) / (FOOT - 104.0), 0.0, 1.0);
		float s = 0.34 * beam_op * (1.0 - 0.6 * u) * (abs(f.x - 206.0) < 18.0 ? 1.0 : 0.55);
		c += floor(clamp(s, 0.0, 1.0) * 8.0) / 8.0 * vec3(1.0, 0.94, 0.8) * 0.9;
	}
	COLOR = vec4(c, 1.0);
}
