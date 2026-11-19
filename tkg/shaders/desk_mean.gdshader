shader_type canvas_item;
render_mode unshaded;

// The picture's mean colour, as the page's tube samples it (every 9th canvas pixel over the glass),
// for the light the screen throws on its bezel. One pixel; `desk_tube` reads it.
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
	COLOR = vec4(s / n / 255.0, 1.0);
}
