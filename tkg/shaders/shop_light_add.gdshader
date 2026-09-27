shader_type canvas_item;
render_mode blend_add, unshaded;

// The shop's light, second pass: the overbright a lamp puts on what is nearest
// it, added over the scaled room. See `shop_light.gdshaderinc`.
#include "res://shaders/shop_light.gdshaderinc"

void fragment() {
	vec3 m;
	vec3 add;
	shop_light(UV, m, add);
	COLOR = vec4(add, 1.0);
}
