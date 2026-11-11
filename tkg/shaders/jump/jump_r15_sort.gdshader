shader_type canvas_item;
render_mode unshaded, blend_disabled;

// R15 DATAMOSH, the sort: the state with the dealt rows pixel-sorted, for the output pass.
// A pass of its own so the output reads it as a texture: inlined into the output's chain of
// slips and stamps, its loops made the shader too big to compile in reasonable time.
// Why: docs/why/SeqDatamosh.md#output-pass

#include "res://shaders/jump/jump_common.gdshaderinc"
#include "res://shaders/jump/jump_r15.gdshaderinc"

uniform sampler2D state : filter_nearest, repeat_disable;
uniform sampler2D rows : filter_nearest, repeat_disable;
uniform vec4 world = vec4(0.0, 0.0, 960.0, 540.0);
uniform vec4 sort_e[64];
uniform float sort_thr = 1.0;
uniform float sort_tip = 0.0;
uniform vec2 PX = vec2(0.00104167, 0.00185185);

vec2 clampw(vec2 q) {
	return clamp(q, world.xy, world.xy + world.zw - 1.0);
}

vec3 S0(vec2 q) {
	return texture(state, (clampw(q) + 0.5) * PX).rgb;
}

vec4 row_at(float y) {
	return texture(rows, vec2((y + 0.5) * PX.y, 0.5));
}

// A fake pixel sort: in a dealt span, the bright run round q (ends found on the band's middle
// row, so they are shared down the band, in chunks of 128 px) is read at 16 taps, the taps are
// sorted dark to bright, and q takes the tap of its rank. The run's leading end burns mint.
vec3 sorted(vec2 q) {
	vec4 r = row_at(q.y);
	int first = int(r.r * 255.0 + 0.5) - 1;
	int cnt = int(r.g * 255.0 + 0.5);
	if (first < 0 || cnt <= 0) {
		return S0(q);
	}
	for (int e = first; e < first + cnt && e < 64; e++) {
		vec4 se = sort_e[e];
		if (q.x < se.x || q.x >= se.y) {
			continue;
		}
		if (r15_lum(S0(vec2(q.x, se.z))) <= sort_thr) {
			return S0(q);
		}
		float c0 = se.x + floor((q.x - se.x) / 128.0) * 128.0;
		float c1 = min(c0 + 128.0, se.y);
		float a = q.x;
		for (int i = 0; i < 128; i++) {
			if (a - 1.0 < c0 || r15_lum(S0(vec2(a - 1.0, se.z))) <= sort_thr) {
				break;
			}
			a -= 1.0;
		}
		float b = q.x + 1.0;
		for (int i = 0; i < 128; i++) {
			if (b >= c1 || r15_lum(S0(vec2(b, se.z))) <= sort_thr) {
				break;
			}
			b += 1.0;
		}
		float n = min(16.0, b - a);
		if (n < 6.0) {
			return S0(q);
		}
		vec3 tap[16];
		float key[16];
		int ni = int(n);
		for (int i = 0; i < 16; i++) {
			if (i >= ni) {
				break;
			}
			tap[i] = S0(vec2(floor(a + (float(i) + 0.5) * (b - a) / n), q.y));
			key[i] = r15_lum(tap[i]);
		}
		for (int i = 1; i < 16; i++) {
			if (i >= ni) {
				break;
			}
			for (int j = i; j > 0; j--) {
				if (key[j - 1] <= key[j]) {
					break;
				}
				float tk = key[j]; key[j] = key[j - 1]; key[j - 1] = tk;
				vec3 tc = tap[j]; tap[j] = tap[j - 1]; tap[j - 1] = tc;
			}
		}
		int rk = clamp(int(floor((q.x - a) / (b - a) * n)), 0, ni - 1);
		vec3 o = tap[rk];
		if (sort_tip > 0.25 && q.x == b - 1.0) {
			o = max(o, 0.55 * o + 0.45 * R15_MINT);
		}
		return o;
	}
	return S0(q);
}

void fragment() {
	COLOR = vec4(sorted(clampw(floor(SCREEN_UV / SCREEN_PIXEL_SIZE))), 1.0);
}
