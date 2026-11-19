shader_type canvas_item;
render_mode unshaded;

// The picture's mean colour, as the page's tube samples it (every 9th canvas pixel over the glass),
// for the light the screen throws on its bezel. Two pixels, the whole part and the fraction
// (8 bits alone was a step off on the bezel); `desk_tube` reads them.
// Why: docs/why/DeskScene.md#the-plan

#include "res://shaders/desk_canvas.gdshaderinc"

void fragment() {
	vec3 s = vec3(0.0);
	float n = 0.0;
	for (int j = 0; j < 78; j++) {
		for (int k = 0; k < 84; k++) {
			s += canvas_px(ivec2(GLASS_C.x + 9 * k, GLASS_C.y + 9 * j));
			n += 1.0;
		}
	}
	vec3 m = s / n;
	COLOR = vec4(FRAGCOORD.x < 1.0 ? floor(m) / 255.0 : m - floor(m), 1.0);
}
