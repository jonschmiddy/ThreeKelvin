shader_type canvas_item;
render_mode unshaded, blend_disabled;

// R15 DATAMOSH, the world pass on the stage. Through the mosh it shows the output viewport;
// through the freeze, the broken frame held still; after the snap, the clean world with the
// ship gone, the dead blocks of the broken frame going out with the tooltip's flicker, the
// tag's mint edge hanging where the hull was, and the snap's mint/rose slip closing up.
// Why: docs/why/SeqDatamosh.md#world-pass

#include "res://shaders/jump/jump_common.gdshaderinc"
#include "res://shaders/jump/jump_r15.gdshaderinc"

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform sampler2D mosh : filter_nearest, repeat_disable;
uniform sampler2D hull : filter_nearest, repeat_disable;
uniform sampler2D sdf : filter_nearest, repeat_disable;
uniform vec4 world = vec4(0.0, 0.0, 960.0, 540.0);
uniform vec4 ship = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 ink_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform float sdf_pad = 48.0;
uniform float hull_on = 0.0;
// 0 the world as it is, 1 the mosh (or the frozen frame), 2 after the snap
uniform int mode = 0;
uniform vec4 dead[15];
uniform float dead_a[15];
uniform float ring_a = 0.0;
uniform float slip_k = 0.0;

vec3 world_at(vec2 q, vec2 px) {
	return j_world(screen, px, q, world);
}

// The clean world with the dead blocks and the hanging edge; w.a says the glitch touched it.
vec4 after_at(vec2 q, vec2 px) {
	vec3 o = world_at(q, px);
	float hit = 0.0;
	for (int i = 0; i < 15; i++) {
		vec4 r = dead[i];
		if (q.x >= r.x && q.y >= r.y && q.x < r.x + r.z && q.y < r.y + r.w) {
			o = mix(o, texture(mosh, (q + 0.5) * px).rgb, dead_a[i]);
			hit = 1.0;
		}
	}
	if (ring_a > 0.0 && hull_on > 0.5) {
		float d = j_hull_sdf(sdf, q - ship.xy, ship.zw, sdf_pad, ink_rect);
		if (abs(d) < 4.0) {
			hit = 1.0;
			if (r15_ring(hull, q, ship)) {
				o = mix(o, R15_MINT, ring_a);
			} else {
				// a 7x7 mean of the edge at 0.6, doubled and a bit: the tooltip's halo
				float g = clamp((4.0 - abs(d)) / 3.0, 0.0, 1.0) * 0.16 * 0.6 * 2.4 * ring_a;
				o = j_add_glow(o, R15_MINT * g, 7.0, q);
			}
		}
	}
	return vec4(o, hit);
}

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE;
	vec2 p = floor(SCREEN_UV / px);
	vec2 q = clamp(p, world.xy, world.xy + world.zw - 1.0);
	if (mode == 1) {
		COLOR = vec4(texture(mosh, (q + 0.5) * px).rgb, 1.0);
	} else if (mode == 2) {
		vec4 w;
		if (slip_k >= 1.0) {
			vec4 a = after_at(clamp(q + vec2(slip_k, 0.0), world.xy, world.xy + world.zw - 1.0), px);
			vec4 b = after_at(clamp(q - vec2(slip_k, 0.0), world.xy, world.xy + world.zw - 1.0), px);
			w = vec4(a.rgb * R15_WA + b.rgb * R15_WB, 1.0);
		} else {
			w = after_at(q, px);
		}
		COLOR = vec4(w.a > 0.5 ? r15_quant(w.rgb, p) : w.rgb, 1.0);
	} else {
		COLOR = vec4(world_at(q, px), 1.0);
	}
}
