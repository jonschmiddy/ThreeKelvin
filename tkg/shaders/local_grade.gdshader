shader_type canvas_item;
render_mode unshaded, blend_disabled;

// LOCAL'S PLAY TONE (`LocalSky`): the fight is played across the view below
// its top band -- the ships, the shots, the numbers, the hand at the bottom --
// and the sky behind it is made a soft backdrop there: everything drawn so far
// is read back and, from the top band down (eased in over `ramp`), its range
// pressed in toward a mid-tone, its light and colour kept
// (`local_tone.gdshaderinc`). (It was dimmed whole, and
// Jon: "why is the bottom half of the local view so dark?") The ships and
// their words stand on this tone alone; `LocalShot stats=` reports how they
// read against it.

uniform sampler2D screen : hint_screen_texture, filter_nearest;
// where the play tone starts and where it is whole (game px, down the frame)
uniform vec2 ramp = vec2(70.0, 140.0);
// the ease in stepped (PAINTED, before its paint: its ramps pick a step by
// brightness, and a smooth ease through them is one hard line across the sky)
uniform bool stepped = false;
#include "res://shaders/local_tone.gdshaderinc"

void fragment() {
	vec4 src = texture(screen, SCREEN_UV);
	float y = (floor(SCREEN_UV.y * 270.0) + 0.5) * 2.0;
	// THE EASE IN, smooth where the palette cut after it dithers it. (It was
	// stepped in four everywhere, dithered between steps in a 4x4 pattern, back
	// when the play was dimmed whole and a smooth ramp crossed the palette as one
	// hard line; under the gentler tone the two dithers beat into rows of
	// strokes like text.)
	// (PAINTED's ease, as a pixel artist steps it: four steps, each block on
	// one, dithered between them in an ordered pattern)
	float w = smoothstep(ramp.x, ramp.y, y);
	// THE DARK SKY'S EASE, dithered whole (the core's void, a clear sky): the
	// palette cut after this keeps two near blacks flat, undithered, so a smooth
	// lift of the void crossed from one to the other on one row -- a hard line
	// right across the view (the core: 93% of the row changing at game y 112).
	// Here each block of a dark pixel is lifted all or not at all, as many of
	// them as the ease asks for, in an ordered pattern: the palette sees two
	// clean colours and the ease reads as a dithered fall, not a seam. (Only the
	// dark: where the palette dithers itself, two dithers beat into strokes.)
	bool dark = max(src.r, max(src.g, src.b)) < 0.16;
	if (dark && !stepped && w > 0.0 && w < 1.0) {
		const float BD[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
		ivec2 qd = ivec2(floor(SCREEN_UV * vec2(480.0, 270.0))) & ivec2(3);
		w = w > (BD[qd.y * 4 + qd.x] + 0.5) / 16.0 ? 1.0 : 0.0;
	}
	if (stepped) {
		const float B[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
		ivec2 q = ivec2(floor(SCREEN_UV * vec2(480.0, 270.0))) & ivec2(3);
		w = floor(w * 4.0 + (B[q.y * 4 + q.x] + 0.5) / 16.0) / 4.0;
	}
	vec3 c = src.rgb;
	c = play_tone(c, w);
	COLOR = vec4(c, src.a);
}
