shader_type canvas_item;
render_mode unshaded, blend_disabled;

// R15 DATAMOSH, the output: the state as broken video, in r15.py's order. The rows come
// pixel-sorted from the sort pass (`jump_r15_sort`), the picture slips mint and rose by row
// bands, blocks repeat along the
// heading, the hull still being sent slips a pixel and nothing else, the drive's pulses show
// the hull as a glitching tag, scanlines come up, the tooltip's tears rip across, and what the
// glitch changed is snapped to the scene's palette. Nothing here feeds back into the state.
// Why: docs/why/SeqDatamosh.md#output-pass

#include "res://shaders/jump/jump_common.gdshaderinc"
#include "res://shaders/jump/jump_r15.gdshaderinc"

uniform sampler2D state : filter_nearest, repeat_disable;
uniform sampler2D sorted_tex : filter_nearest, repeat_disable;
uniform sampler2D live : filter_nearest, repeat_disable;
uniform sampler2D info : filter_nearest, repeat_disable;
uniform sampler2D rows : filter_nearest, repeat_disable;
uniform sampler2D hull : filter_nearest, repeat_disable;
uniform sampler2D sdf : filter_nearest, repeat_disable;
uniform vec4 world = vec4(0.0, 0.0, 960.0, 540.0);
uniform vec4 ship = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 ink_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 ink_s = vec4(0.0);
uniform float sdf_pad = 48.0;
uniform vec2 grid = vec2(120.0, 68.0);
uniform float hull_on = 0.0;
uniform float mask_all = 0.0;
uniform float moshing = 0.0;
uniform vec4 stamp[16];
uniform vec2 stamp_s[16];
uniform int stamp_n = 0;
uniform float k1 = 0.0;
uniform float pulse_k = 0.0;
uniform float tag_a = 0.0;
uniform float tag_ph = 0.0;
uniform float scan_a = 0.0;
uniform float scan_ph = 0.0;
uniform vec4 tear_r[16];
uniform float tear_d[16];
uniform int tear_n = 0;
uniform float rip_k = -1.0;
// One pixel in the viewport's UV (set from its size).
uniform vec2 PX = vec2(0.00104167, 0.00185185);

vec2 clampw(vec2 q) {
	return clamp(q, world.xy, world.xy + world.zw - 1.0);
}

vec3 S0(vec2 q) {
	return texture(state, (clampw(q) + 0.5) * PX).rgb;
}

float alpha(vec2 q) {
	return hull_on > 0.5 ? r15_alpha(hull, q, ship) : 0.0;
}

// The hull still being sent (r15.py `keep`): never sorted, stamped or slipped by more than a pixel.
bool keep(vec2 q) {
	if (alpha(q) <= 0.5) {
		return false;
	}
	return rip_k < 0.0 || q.x < ink_s.x + ink_s.z * (1.0 - rip_k) - 6.0 * sin(q.y * 0.7);
}

bool moving(vec2 q) {
	if (mask_all > 0.5) {
		return true;
	}
	vec2 b = floor(clampw(q) / 8.0);
	int fl = int(texture(info, (b + 0.5) / grid).r * 255.0 + 0.5);
	return (fl & 5) != 0;
}

vec4 row_at(float y) {
	return texture(rows, vec2((y + 0.5) * PX.y, 0.5));
}

vec3 sorted(vec2 q) {
	return texture(sorted_tex, (clampw(q) + 0.5) * PX).rgb;
}

// The mint/rose slip, by row band, where the picture is broken.
vec3 slipped(vec2 q) {
	float k = floor(row_at(q.y).b * 255.0 + 0.5) - 128.0;
	if (k == 0.0 || !moving(q)) {
		return sorted(q);
	}
	return sorted(clampw(q + vec2(k, 0.0))) * R15_WA + sorted(clampw(q - vec2(k, 0.0))) * R15_WB;
}

// Blocks repeated along the heading: the last stamp over q wins, reading the picture before any stamp.
vec3 stamped(vec2 q) {
	for (int i = stamp_n - 1; i >= 0; i--) {
		vec4 s = stamp[i];
		if (q.y < s.y || q.y >= s.y + s.w) {
			continue;
		}
		float dx = q.x - s.x;
		float k = floor(dx / stamp_s[i].x);
		if (k >= 1.0 && k <= stamp_s[i].y && dx - k * stamp_s[i].x < s.z) {
			return slipped(vec2(q.x - k * stamp_s[i].x, q.y));
		}
	}
	return slipped(q);
}

vec3 sent(vec2 q) {
	if (moshing > 0.5 && keep(q)) {
		return S0(q + vec2(k1, 0.0)) * R15_WA + S0(q - vec2(k1, 0.0)) * R15_WB;
	}
	return stamped(q);
}

bool hull_near(vec2 q, float k) {
	for (int i = -3; i <= 3; i++) {
		if (abs(float(i)) <= k && alpha(q + vec2(float(i), 0.0)) > 0.5) {
			return true;
		}
	}
	return false;
}

// On a drive pulse the hull slips mint/rose by 1-3 px for two frames.
vec3 pulsed(vec2 q) {
	if (pulse_k > 0.0 && hull_near(q, pulse_k)) {
		return sent(clampw(q + vec2(pulse_k, 0.0))) * R15_WA + sent(clampw(q - vec2(pulse_k, 0.0))) * R15_WB;
	}
	return sent(q);
}

float hull_d(vec2 q) {
	return j_hull_sdf(sdf, q - ship.xy, ship.zw, sdf_pad, ink_rect);
}

// The hull as a tag: its scanlines and its 1 px mint edge, with a glow off the edge.
vec3 tagged(vec2 q, out bool ring) {
	vec3 o = pulsed(q);
	ring = false;
	if (tag_a <= 0.0) {
		return o;
	}
	if (alpha(q) > 0.5) {
		if (int(mod(q.y + tag_ph, 3.0)) == 1) {
			o = o * (1.0 - 0.5 * tag_a) + R15_SCAN * 0.5 * tag_a;
		}
		return o;
	}
	ring = r15_ring(hull, q, ship);
	if (ring) {
		return mix(o, R15_MINT, tag_a);
	}
	float d = abs(hull_d(q));
	float g = clamp((3.5 - d) / 2.5, 0.0, 1.0) * 0.22 * 2.0 * 0.5 * tag_a;
	return j_add_glow(o, R15_MINT * g, 7.0, q);
}

// Whether q is broken (the mask), without drawing it.
void scanned_mask(vec2 q, out bool m) {
	m = moving(q) || (tag_a > 0.0 && r15_ring(hull, q, ship)) || (pulse_k > 0.0 && hull_near(q, pulse_k));
}

vec3 scanned(vec2 q, out bool m) {
	bool ring;
	vec3 o = tagged(q, ring);
	m = moving(q) || ring || (pulse_k > 0.0 && hull_near(q, pulse_k));
	if (scan_a > 0.0 && m && int(mod(q.y + scan_ph, 3.0)) == 1) {
		float a = 0.26 * scan_a;
		o = o * (1.0 - a) + R15_SCAN * a;
	}
	return o;
}

void fragment() {
	vec2 p = clampw(floor(SCREEN_UV / SCREEN_PIXEL_SIZE));
	// the tooltip's tear, at movie scale: the band drawn again d px over, its gap in dark
	// fill, scanlines inside it, 1 px mint caps; the last tear over p wins
	bool torn = false;
	bool cap = false;
	bool gap = false;
	bool scan_in = false;
	vec2 at = p;
	for (int i = tear_n - 1; i >= 0; i--) {
		vec4 r = tear_r[i];
		float d = tear_d[i];
		if (p.y < r.x || p.y >= r.x + r.y) {
			continue;
		}
		float c0 = max(r.z + d, world.x), c1 = min(r.w + d, world.x + world.z);
		if (c1 <= c0) {
			continue;
		}
		float g0 = d > 0.0 ? r.z : max(r.w + d, r.z);
		float g1 = d > 0.0 ? min(r.z + d, r.w) : r.w;
		if (p.x >= c0 && p.x < c1) {
			at = vec2(p.x - d, p.y);
			scan_in = int(mod(p.y - r.x - 1.0, 3.0)) == 0 && p.y > r.x;
			cap = p.x == c0 || p.x == c1 - 1.0;
			torn = true;
			break;
		}
		if (g1 > g0 && p.x >= max(g0, world.x) && p.x < min(g1, world.x + world.z)) {
			gap = true;
			torn = true;
			break;
		}
	}
	bool m;
	vec3 o = scanned(at, m);
	if (torn) {
		bool mp;
		scanned_mask(p, mp);
		m = mp;
	}
	if (gap) {
		o = R15_FILL;
	} else if (cap) {
		o = R15_MINT;
	} else if (scan_in) {
		o = o * 0.55 + R15_SCAN * 0.45;
	}
	bool live_px = keep(p) && pulse_k <= 0.0;
	if ((m || torn) && !(live_px && !torn)) {
		vec3 cl = texture(live, (p + 0.5) * PX).rgb;
		vec3 dd = abs(o - cl);
		if (torn || max(dd.r, max(dd.g, dd.b)) > 5.0 / 255.0) {
			o = r15_quant(o, p);
		}
	}
	// the caps glow: the tooltip's mint halo, as light (a 3x5 mean of the caps)
	if (!cap && tear_n > 0) {
		float n = 0.0;
		for (int i = 0; i < tear_n; i++) {
			vec4 r = tear_r[i];
			float c0 = max(r.z + tear_d[i], world.x), c1 = min(r.w + tear_d[i], world.x + world.z);
			if (c1 <= c0) {
				continue;
			}
			float rows_in = max(0.0, min(p.y + 1.0, r.x + r.y - 1.0) - max(p.y - 1.0, r.x) + 1.0);
			n += (abs(c0 - p.x) <= 2.0 ? rows_in : 0.0) + (abs(c1 - 1.0 - p.x) <= 2.0 ? rows_in : 0.0);
		}
		if (n > 0.0) {
			o = j_add_glow(o, R15_MINT * 0.9 * 1.4 * n / 15.0, 7.0, p);
		}
	}
	COLOR = vec4(clamp(o, 0.0, 1.0), 1.0);
}
