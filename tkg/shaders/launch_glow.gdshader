shader_type canvas_item;
render_mode blend_add, unshaded;

// Light added over the yard by the heavy lift (`ShipLift`): up to eight soft
// lights, summed, then stepped in six levels with a 4x4 ordered dither, so it
// reads as light and stays pixel art.

uniform vec2 rect_size = vec2(960.0, 540.0);
uniform int n = 0;
// x, y, radius x, radius y
uniform vec4 gpos[8];
// colour, strength
uniform vec4 gcol[8];

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int i = x + y * 4;
	float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[i] + 0.5) / 16.0;
}

void fragment() {
	vec2 p = floor(UV * rect_size) + 0.5;
	float th = bayer4(p);
	vec3 acc = vec3(0.0);
	for (int i = 0; i < 8; i++) {
		if (i >= n) {
			break;
		}
		vec2 d = (p - gpos[i].xy) / gpos[i].zw;
		float dd = dot(d, d);
		if (dd < 1.0) {
			float f = 1.0 - dd;
			acc += gcol[i].rgb * gcol[i].a * f * f;
		}
	}
	float l = max(acc.r, max(acc.g, acc.b));
	if (l <= 0.004) {
		discard;
	}
	float q = floor(clamp(l, 0.0, 1.5) / 1.5 * 6.0 + th) / 6.0 * 1.5;
	COLOR = vec4(acc / l * q, 1.0);
}
