shader_type canvas_item;

// THE HULL IS FAILING (`LowHull`). One pass over the finished game frame, on a
// layer of its own above the screens and the HUD and under the escape menu:
//
//   a faint red at the edges of the picture, breathing, which leaves the middle
//   of the screen exactly as it was; and
//   up to four short glitches, each inside ONE text control's rect: a one- or
//   two-pixel horizontal slip of a few rows, a red/cyan split, or a letter-wide
//   cell dimmed. A glitch lasts a few frames and `LowHull` decides where.
//
// IT ONLY EVER MOVES PIXELS, never a control: everything under it keeps its
// rect, its hover and its click, because the rect that draws this ignores the
// mouse and nothing here is layout.
//
// Everything is in the game's own pixels (960x540): the layer is inside the
// shell's SubViewport, so a "one-pixel" slip is one pixel of the art.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;

// How much red at the very edge, 0 is none. Already eased and breathing.
uniform float red = 0.0;
// How far in it reaches, in game pixels, across and down.
uniform vec2 reach = vec2(150.0, 100.0);

// The glitches. `g_rect` is the text's rect (x, y, w, h); `g_par` is
// (kind, a, b, d): kind 0 none, 1 slip (rows a..a+b shifted d px), 2 split
// (red one way and blue the other by d px), 3 letter (columns a..a+b dimmed to d).
uniform vec4 g_rect[4];
uniform vec4 g_par[4];

vec3 tap(vec2 px, vec2 inv) {
	return texture(screen_tex, (px + 0.5) * inv).rgb;
}

void fragment() {
	vec2 inv = SCREEN_PIXEL_SIZE;
	vec2 size = 1.0 / inv;
	vec2 px = floor(SCREEN_UV * size);
	vec3 c = tap(px, inv);
	for (int i = 0; i < 4; i++) {
		vec4 p = g_par[i];
		if (p.x < 0.5) {
			continue;
		}
		vec4 r = g_rect[i];
		if (px.x < r.x || px.y < r.y || px.x >= r.x + r.z || px.y >= r.y + r.w) {
			continue;
		}
		if (p.x < 1.5) {
			if (px.y >= p.y && px.y < p.y + p.z) {
				c = tap(px - vec2(p.w, 0.0), inv);
			}
		} else if (p.x < 2.5) {
			c = vec3(tap(px - vec2(p.w, 0.0), inv).r, c.g, tap(px + vec2(p.w, 0.0), inv).b);
		} else {
			if (px.x >= p.y && px.x < p.y + p.z) {
				c *= p.w;
			}
		}
	}
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
