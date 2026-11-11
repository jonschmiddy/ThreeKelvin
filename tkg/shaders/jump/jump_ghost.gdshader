shader_type canvas_item;
render_mode unshaded, blend_add;

// R5's probable ships (`JumpGhosts`): the hull's ghost texture stamped as density into a
// light buffer, each instance weighted and sent to one channel: R the ships behind the
// hull, G the ships in front, B the frozen cloud the haze is blurred from after the snap.
// The quarter-size haze buffer reads the texture through its mipmaps, so a ghost drawn at
// a quarter is the mean of its pixels, as the film's box blur had it.
// Why: docs/why/JumpGhosts.md#ghosts

#include "res://shaders/jump/jump_light.gdshaderinc"

uniform sampler2D ghost : filter_linear, repeat_disable;
uniform sampler2D ghost_mip : filter_linear_mipmap, repeat_disable;
uniform float mip = 0.0;

varying flat vec4 v_c;

void vertex() {
	v_c = INSTANCE_CUSTOM;
}

void fragment() {
	float g = mip > 0.5 ? texture(ghost_mip, UV).r : texture(ghost, UV).r;
	// the texture holds the ghost over 2; a smaller ghost is drawn a little brighter
	g *= 2.0 * v_c.x * (1.0 + 0.6 * (1.0 - v_c.z)) * J_LIGHT_K;
	int ch = int(v_c.y + 0.5);
	COLOR = vec4(ch == 0 ? g : 0.0, ch == 1 ? g : 0.0, ch == 2 ? g : 0.0, 1.0);
}
