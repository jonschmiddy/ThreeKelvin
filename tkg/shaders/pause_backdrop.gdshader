shader_type canvas_item;

// THE GAME BEHIND THE ESCAPE MENU, "pixel + split": the screen breaks into
// 4 px blocks, red and blue pull 2 px apart, and it darkens 45% toward the
// background colour. Jon picked it from twenty backdrops and twelve mixes; the
// look is the pixel art going out of focus the way pixel art would, and the
// signal from the ship going soft.
//
// A SCREEN SHADER on a full-rect ColorRect, so it reads whatever was drawn
// before it -- the whole run -- and the drawer, added after it, stays sharp.
// With the project's viewport stretch at 960x540, one SCREEN pixel is one game
// pixel, so a 4 px block is four game pixels at every window size.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
// 0 is the game untouched, 1 is the full effect. PauseMenu tweens it with the
// drawer, so the picture breaks up as the menu arrives.
uniform float amount : hint_range(0.0, 1.0) = 1.0;
uniform float block_px = 4.0;
uniform float split_px = 2.0;
uniform float wash = 0.45;
uniform vec4 void_colour : source_color = vec4(0.039, 0.055, 0.082, 1.0);

// The average of one block, sampled on its own pixel grid. A single centre tap
// would alias; sixteen taps is the block's true colour, as the mockup had it.
vec3 block_colour(vec2 origin, float b, vec2 px) {
	vec3 sum = vec3(0.0);
	float n = 0.0;
	for (float j = 0.0; j < 4.0; j += 1.0) {
		for (float i = 0.0; i < 4.0; i += 1.0) {
			if (i < b && j < b) {
				sum += texture(screen_tex, (origin + vec2(i, j) + 0.5) * px).rgb;
				n += 1.0;
			}
		}
	}
	return sum / max(n, 1.0);
}

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE;
	vec2 at = floor(SCREEN_UV / px);
	// Whole pixels only, growing with the tween: 1 (sharp) up to block_px.
	float b = max(1.0, floor(1.0 + (block_px - 1.0) * amount + 0.5));
	float s = floor(split_px * amount + 0.5);
	vec2 origin = floor(at / b) * b;
	vec3 mid = block_colour(origin, b, px);
	vec3 right = block_colour(floor((at + vec2(s, 0.0)) / b) * b, b, px);
	vec3 left = block_colour(floor((at - vec2(s, 0.0)) / b) * b, b, px);
	vec3 c = vec3(right.r, mid.g, left.b);
	COLOR = vec4(mix(c, void_colour.rgb, wash * amount), 1.0);
}
