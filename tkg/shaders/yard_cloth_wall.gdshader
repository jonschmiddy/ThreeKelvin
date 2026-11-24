shader_type canvas_item;
render_mode unshaded, blend_disabled;

// THE BANNERS' SHADOW ON THE WALL (`YardCloth`, docs/why/YardBanner.md#pixels): each banner's cloth, rod
// and chains thrown onto the wall (8 px behind) from its shadow light, as a mask of its strength (0-255).
// part 0 the cloth (its picture's holes left out), 1 the rod's pixels, 2 the chains' at half strength.


uniform sampler2D state : filter_nearest;
#define STATE state
#include "res://shaders/yard_cloth.gdshaderinc"
uniform sampler2D atlas : filter_nearest;
uniform int part = 0;
uniform float bx[7];
// each banner's shadow light (x, y, z or a direction, 1 a point) and its strength, whole 0-255
uniform vec4 sl[7];
uniform float ss[7];

varying vec2 tuv;
varying flat int bi;

vec2 on_wall(int b, vec3 q) {
	vec4 L = sl[b];
	if (L.w > 0.5) {
		float t = (L.z + 8.0) / (L.z - q.z);
		return L.xy + (q.xy - L.xy) * t;
	}
	return q.xy - L.xy / L.z * (q.z + 8.0);
}

void vertex() {
	if (part == 0) {
		int i = int(UV.x + 0.5);
		int jj = int(UV.y + 0.5);
		int b = jj / NY;
		int j = jj - b * NY;
		vec3 P = tk_node(i, j, b, tk_rod(b));
		tuv = vec2(tk_u(i), tk_v(j));
		bi = b;
		VERTEX = on_wall(b, vec3(bx[b] + P.x, CT + P.y, P.z));
	} else {
		int id = int(UV.x + 0.5);
		int b = id / 1000;
		id -= b * 1000;
		int corner = int(UV.y + 0.5);
		float rod = tk_rod(b);
		float rs = sign(rod) * floor(abs(rod) + 0.5);
		vec2 px;
		if (part == 2) {
			int y = 18 + id % 16;
			px = vec2(bx[b] + (id < 16 ? 6.0 : 42.0) + floor(rs * float(y - 18) / 15.0 + 0.5), float(y));
		} else {
			int xo = id / 4;
			float dy = (xo <= 2 || xo >= 53) ? 1.0 : 0.0;
			px = vec2(bx[b] - 4.0 + rs + float(xo), 34.0 + float(id % 4) + dy);
		}
		bi = b;
		tuv = vec2(0.0);
		VERTEX = floor(on_wall(b, vec3(px + 0.5, 0.0))) + vec2(float(corner & 1), float(corner >> 1));
	}
}

void fragment() {
	float s = ss[bi];
	if (part == 2) {
		s = floor(s / 2.0);
	}
	if (s <= 0.0) {
		discard;
	}
	if (part == 0) {
		ivec2 t = ivec2(clamp(int(floor(tuv.x)), 0, 47) + 48 * bi, clamp(int(floor(tuv.y)), 0, 99));
		if (texelFetch(atlas, t, 0).a < 0.25) {
			discard;
		}
	}
	COLOR = vec4(s / 255.0, 0.0, 0.0, 1.0);
}
