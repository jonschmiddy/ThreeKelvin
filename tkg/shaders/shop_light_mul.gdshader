shader_type canvas_item;
render_mode blend_mul, unshaded;

// The shop's light, first pass: every pixel of the room scaled by the bench's
// m. See `shop_light.gdshaderinc`.
#include "res://shaders/shop_light.gdshaderinc"

void fragment() {
	vec3 m;
	vec3 add;
	shop_light(UV, m, add);
	COLOR = vec4(m, 1.0);
}
