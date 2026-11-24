shader_type canvas_item;
render_mode unshaded;

// SOLARI'S HALL AIR, over the room and its back life, under the hulls (show18.post, in its order):
// the worn deck's smeared sheen of the bright wall above it, the depth haze glowing with the light
// round it (twelfths), and furnace 2's beam through the haze while it roars.
// Why: docs/why/ShipRoomSolari.md#air

#include "res://shaders/ship_room_solari.gdshaderinc"

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform sampler2D masks : filter_nearest, repeat_disable;
uniform float beam_op = 0.0;

varying vec2 fp;

void vertex() {
	fp = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

vec3 bright(vec2 uv) {
	vec3 c = texture(screen, uv).rgb;
	return dot(c, vec3(0.299, 0.587, 0.114)) > 200.0 / 255.0 ? c : vec3(0.0);
}

void fragment() {
	vec2 k = SCREEN_PIXEL_SIZE / max(dFdx(fp.x), 1e-4);
	vec2 f = floor(fp);
	vec3 c = texture(screen, SCREEN_UV).rgb;
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
