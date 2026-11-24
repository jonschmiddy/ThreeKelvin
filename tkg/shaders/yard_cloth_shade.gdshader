shader_type canvas_item;
render_mode blend_mul;

// THE BANNERS' SHADOW, MULTIPLIED INTO THE ROOM (`YardCloth`, the last thing in the room's `under`): the
// wall mask (`yard_cloth_wall`), with a dithered penumbra one pixel wide round it, as the page's drawWall.

#include "res://shaders/yard_cloth.gdshaderinc"

uniform sampler2D mask : filter_nearest;
uniform bool off = false;

const vec2 SZ = vec2(960.0, 208.0);

float m(ivec2 p) {
	if (p.x < 0 || p.y < 0 || p.x >= 960 || p.y >= 208) {
		return 0.0;
	}
	return floor(texture(mask, (vec2(p) + 0.5) / SZ).r * 255.0 + 0.5);
}

void fragment() {
	ivec2 p = ivec2(floor(UV * SZ));
	float v = off ? 0.0 : m(p);
	if (v == 0.0 && !off) {
		float nb = max(max(m(p + ivec2(-1, 0)), m(p + ivec2(1, 0))), max(m(p + ivec2(0, -1)), m(p + ivec2(0, 1))));
		if (nb > 0.0 && tk_bay(p) < 0.5) {
			v = nb;
		}
	}
	float k = 1.0 - v / 255.0;
	COLOR = vec4(k, k, k, 1.0);
}
