shader_type canvas_item;
render_mode unshaded;

// THE FRONT DOOR'S HOVER: everything under this rect goes soft and a little
// dark, and the ship pointed at is drawn sharp over it (`YardFront`). A box
// blur of `radius` game pixels (`zoom` game pixels to a screen pixel), its
// strength `k` from 0 (off) to 1; the mockup's BoxBlur(1.8) and 13% dimming.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float k = 0.0;
uniform float radius = 1.8;
uniform float zoom = 1.0;

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE * zoom;
	float r = radius * k;
	vec3 acc = vec3(0.0);
	for (int i = -2; i <= 2; i++) {
		for (int j = -2; j <= 2; j++) {
			vec2 o = vec2(float(i), float(j)) * (r * 0.5) * px;
			acc += texture(screen_tex, SCREEN_UV + o).rgb;
		}
	}
	COLOR = vec4(acc / 25.0 * (1.0 - 0.13 * k), 1.0);
}
