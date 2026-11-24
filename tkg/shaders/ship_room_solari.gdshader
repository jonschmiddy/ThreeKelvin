shader_type canvas_item;
render_mode unshaded;

// SOLARI'S CASTING BED, lit as show18 lights it (the light: ship_room_solari.gdshaderinc).
//   mode 0  the room: albedo x m x 1.7, the burning layer over it; the furnaces' fire breathes, moves
//           (10 shape changes a second) and flares toward white while its pour runs or furnace 2 roars
//   1  a thing drawn into the room's albedo (the bed, the jibs, the handlers): rgb x m x 1.7
//   2  a hull: core2's key from the furnace wall, the room's hull lights, the floor's bounce, the rim
//      only where the outline faces a light, the brass catching the fire; the hall's air 1/12 over it
//   3  a thing in front of the hulls (the lamp tech, the carriers, the welder): rgb x m
//   (1 and 3: a pixel of alpha 0.5 burns unlit, 0.25 multiplies by its red, 0.75 takes the gain)
//   4  a post: as 1, with the hall's air 1/12 over it
// Why: docs/why/ShipRoomSolari.md#light

#include "res://shaders/ship_room_solari.gdshaderinc"

uniform int mode = 0;
uniform sampler2D albedo : filter_nearest, repeat_disable;
uniform sampler2D emissive : filter_nearest, repeat_disable;
uniform sampler2D masks : filter_nearest, repeat_disable;
uniform float t_room = 0.0;
uniform float lamp_k = 1.0;
// the fire's own flare toward white (pour_flare; furnace 2's roar x 1.5)
uniform float eflare[6];
// mode 2: the room's hull lights (x, y, radius, 0) and (colour, 0); the brass's catch
uniform int n_hl = 0;
uniform vec4 hl_pos[20];
uniform vec4 hl_col[20];
uniform float brass = 0.45;
instance uniform vec2 rows = vec2(0.0, 1.0);
instance uniform vec3 bounce = vec3(0.0);

varying vec2 fp;

void vertex() {
	fp = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float hash1(float a, float b, float c) {
	return fract(sin(12.9898 * a + 25.9796 * b + 38.9694 * c + 78.233) * 43758.5453);
}

vec4 em_at(ivec2 p) {
	return texelFetch(emissive, p, 0);
}

int fire_of(ivec2 p) {
	return int(round(texelFetch(masks, p, 0).r * 255.0 / 40.0)) - 1;
}

vec4 room_emissive(ivec2 p) {
	vec4 e = em_at(p);
	int fi = fire_of(p);
	if (fi < 0) {
		return e;
	}
	float tx = TAPS[fi];
	if (abs(float(p.x) - tx) <= 40.0 && float(p.x) >= tx - 40.0 && float(p.x) < tx + 40.0) {
		float tick = floor(mod(t_room, 30.0) * 10.0);
		float h = hash1(0.0, floor(float(p.x) / 2.0), tick);
		int s = h < 0.33 ? -1 : (h > 0.66 ? 1 : 0);
		if (s != 0) {
			ivec2 q = ivec2(p.x, clamp(p.y + s, 60, 137));
			if (fire_of(q) >= 0) {
				e = em_at(q);
			}
		}
	}
	e.rgb = min(e.rgb * fk[fi], vec3(1.0));
	float w = min(0.8, 0.5 * eflare[fi]);
	if (w > 0.0 && e.a > 0.0) {
		e.rgb = mix(e.rgb, vec3(255.0, 238.0, 180.0) / 255.0, w);
	}
	return e;
}

float hull_alpha(sampler2D tx, vec2 uv, vec2 px, float dx, float dy) {
	return texture(tx, uv + vec2(dx, dy) * px).a > 0.0 ? 1.0 : 0.0;
}

bool hull_edge(sampler2D tx, vec2 uv, vec2 px, float dx, float dy) {
	if (hull_alpha(tx, uv, px, dx, dy) == 0.0) {
		return false;
	}
	return hull_alpha(tx, uv, px, dx - 1.0, dy) * hull_alpha(tx, uv, px, dx + 1.0, dy)
		* hull_alpha(tx, uv, px, dx, dy - 1.0) * hull_alpha(tx, uv, px, dx, dy + 1.0) == 0.0;
}

// The softened silhouette (two 3x3 box blurs) at an offset, for the outline's normal.
float hull_soft(sampler2D tx, vec2 uv, vec2 px, float ox, float oy) {
	const float W5[5] = float[](1.0, 2.0, 3.0, 2.0, 1.0);
	float s = 0.0;
	for (int i = 0; i < 5; i++) {
		for (int j = 0; j < 5; j++) {
			s += W5[i] * W5[j] * hull_alpha(tx, uv, px, ox + float(i - 2), oy + float(j - 2));
		}
	}
	return s / 81.0;
}

vec3 hull_lit(sampler2D tx, vec4 c, vec2 uv, vec2 px) {
	float u = clamp((floor(fp.y) - rows.x) / max(1.0, rows.y - rows.x), 0.0, 1.0);
	float key = 1.45 * (1.0 - 0.42 * pow(u, 1.2));
	vec3 Lh = key * vec3(1.0, 0.9, 0.78) + 0.10 * AMBC;
	vec2 X = floor(fp);
	for (int i = 0; i < n_hl; i++) {
		vec4 l = hl_pos[i];
		float d = length(vec2(X.x - l.x, (X.y - l.y) * 1.15)) / l.z;
		float f = clamp((1.0 - d) / 0.55, 0.0, 1.0);
		Lh += f * f * (3.0 - 2.0 * f) * hl_col[i].rgb * 0.6;
	}
	Lh += u * u * (0.42 + 0.9 * bounce) * vec3(1.0, 0.66, 0.40);
	vec3 rgb = c.rgb * Lh;
	bool edge = hull_edge(tx, uv, px, 0.0, 0.0);
	bool edge2 = !edge && (hull_edge(tx, uv, px, 1.0, 0.0) || hull_edge(tx, uv, px, -1.0, 0.0)
		|| hull_edge(tx, uv, px, 0.0, 1.0) || hull_edge(tx, uv, px, 0.0, -1.0));
	if (edge || edge2) {
		vec2 g = vec2(hull_soft(tx, uv, px, 1.0, 0.0) - hull_soft(tx, uv, px, -1.0, 0.0),
			hull_soft(tx, uv, px, 0.0, 1.0) - hull_soft(tx, uv, px, 0.0, -1.0)) * 0.5;
		vec2 n = -g / (length(g) + 1e-6);
		vec3 acc = vec3(0.0);
		for (int i = 0; i < n_hl; i++) {
			vec4 l = hl_pos[i];
			vec2 dv = l.xy - X;
			float d = length(vec2(dv.x, dv.y * 1.15)) / l.z;
			float f = clamp((1.0 - d) / 0.55, 0.0, 1.0);
			float face = clamp(dot(n, dv) / (length(dv) + 1e-6), 0.0, 1.0);
			acc += f * f * (3.0 - 2.0 * f) * face * hl_col[i].rgb;
		}
		float lv = max(acc.r, max(acc.g, acc.b));
		float st = lv > 0.45 ? 1.0 : (lv > 0.22 ? 0.6 : (lv > 0.08 ? 0.3 : 0.0));
		vec3 rim = st * acc / max(lv, 1e-6);
		if (edge) {
			rgb = rgb * (1.0 + 0.35 * max(rim.r, max(rim.g, rim.b))) + rim * 0.42;
		} else {
			rgb += rim * 0.14;
		}
	}
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	if (lum > 105.0 / 255.0 && c.r - c.b > 60.0 / 255.0) {
		rgb *= 1.22 + 0.35 * brass;
	}
	return clamp(rgb, 0.0, 1.0);
}

void fragment() {
	if (mode == 0) {
		ivec2 p = ivec2(floor(fp));
		vec3 a = texelFetch(albedo, p, 0).rgb;
		vec3 lit = clamp(a * light_m(fp) * lamp_k * 1.7, 0.0, 1.0);
		vec4 e = room_emissive(p);
		COLOR = vec4(mix(lit, e.rgb, e.a), 1.0);
	} else {
		vec4 c = texture(TEXTURE, UV) * COLOR;
		if (mode == 2) {
			vec3 rgb = hull_lit(TEXTURE, c, UV, TEXTURE_PIXEL_SIZE);
			COLOR = vec4(hazed(rgb, fp, 1.0 / 12.0), c.a);
		} else if ((mode == 1 || mode == 3) && c.a > 0.15 && c.a < 0.85) {
			// a painted pixel's alpha says what it is: 0.5 burns unlit, 0.25 darkens what is
			// under it by its red, 0.75 is lit with the room's gain in front of the hulls
			if (c.a < 0.35) {
				COLOR = vec4(0.0, 0.0, 0.0, 1.0 - c.r);
			} else if (c.a < 0.6) {
				COLOR = vec4(c.rgb, 1.0);
			} else {
				COLOR = vec4(clamp(c.rgb * light_m(fp) * lamp_k * 1.7, 0.0, 1.0), 1.0);
			}
		} else {
			vec3 m = light_m(fp) * lamp_k;
			vec3 rgb = c.rgb * m * (mode == 3 ? 1.0 : 1.7);
			if (mode == 4) {
				rgb = hazed(clamp(rgb, 0.0, 1.0), fp, 1.0 / 12.0);
			}
			COLOR = vec4(clamp(rgb, 0.0, 1.0), c.a);
		}
	}
}
