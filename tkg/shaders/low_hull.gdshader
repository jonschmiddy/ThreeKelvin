shader_type canvas_item;

// THE HULL IS FAILING (`LowHull`). One pass over the finished game frame, on a
// layer of its own above the screens and the HUD and under the escape menu:
//
//   a faint red at the edges of the picture, breathing, which leaves the middle
//   of the screen exactly as it was. (The words' scramble is not drawn here:
//   it is `HullScramble`'s, on each text itself.)
//
// IT ONLY EVER TINTS PIXELS, never a control: everything under it keeps its
// rect, its hover and its click, because the rect that draws this ignores the
// mouse and nothing here is layout.
//
// Everything is in the game's own pixels (960x540): the layer is inside the
// shell's SubViewport.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;

// How much red at the very edge, 0 is none. Already eased and breathing.
uniform float red = 0.0;
// How far in it reaches, in game pixels, across and down.
uniform vec2 reach = vec2(150.0, 100.0);

vec3 tap(vec2 px, vec2 inv) {
	return texture(screen_tex, (px + 0.5) * inv).rgb;
}

void fragment() {
	vec2 inv = SCREEN_PIXEL_SIZE;
	vec2 size = 1.0 / inv;
	vec2 px = floor(SCREEN_UV * size);
	vec3 c = tap(px, inv);
	if (red > 0.0) {
		// THE EDGE, as a rectangle and not an oval: the screen is wide, and an
		// oval reaches the middle of the top and bottom long before it gets to
		// the sides. Each edge's own falloff, combined so the corners hold the
		// most, and squared so it ends softly rather than at a line.
		vec2 from = min(px, size - 1.0 - px);
		vec2 f = vec2(1.0) - smoothstep(vec2(0.0), reach, from);
		float w = 1.0 - (1.0 - f.x) * (1.0 - f.y);
		w *= w;
		float k = red * w;
		// The cool channels pulled down, and a little dark red put back, so a
		// black edge goes red rather than staying black, and a lit one is
		// warmed rather than washed over.
		c = c * (vec3(1.0) - k * vec3(0.05, 0.6, 0.55)) + vec3(0.32, 0.015, 0.02) * k;
	}
	COLOR = vec4(c, 1.0);
}
