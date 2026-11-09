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
// LIGHT THAT MOVES (RADIANT, Nov 7, direction B; `LocalSky._engine_light`): the
// ship's engines light the gas behind them -- a soft plume of light down the flame
// (flattened along it), the gas's own colour brightened and a little of the
// flame's mixed in, breathing with the burn. (game px x, y; radius px; gain, 0 none)
uniform vec4 r_eng = vec4(0.0);
uniform vec3 r_eng_c = vec3(1.0, 0.62, 0.32);
// and a sun's flare lighting everything round it, falling off from the sun (sun x, y
// game px; reach px; gain now, 0 none): each thing a brighter version of itself, by
// as much of the flare as gets to it -- the dark dust between it and the sun takes
// its share (review, Nov 7: lit evenly, a flare read as the sky's exposure going up;
// shaded by what lies toward the sun, the dust's sun-facing edges catch it, the
// pillars throw their shade away from it, and the light is the sun's)
uniform vec4 r_sun = vec4(0.0);
// (how far toward the sun the dust is looked for, px; the light at which a thing is
// dust, fully and not at all; how much each of the eight reads takes)
const float SUN_LOOK = 150.0;
const vec2 SUN_DUST = vec2(0.13, 0.22);
const float SUN_TAKE = 0.16;
uniform vec3 r_sun_c = vec3(1.0);

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
	if (r_sun.w > 0.0) {
		vec2 gs = (floor(SCREEN_UV * vec2(480.0, 270.0)) + 0.5) * 2.0;
		float ds = length((gs - r_sun.xy) * vec2(1.0, 1.15)) / r_sun.z;
		float gas = 1.0 - smoothstep(0.3, 0.55, max(c.r, max(c.g, c.b)));
		// (read on the game's own pixels, so a shade's edge is a whole pixel's)
		vec2 to = r_sun.xy - gs;
		float lt = length(to);
		float tr = 1.0;
		if (lt > 2.0) {
			vec2 st = to / lt * min(lt, SUN_LOOK) / 8.0;
			for (int i = 0; i < 8; i++) {
				vec2 q = (floor((gs + st * float(i)) * 0.5) + 0.5) * 2.0;
				vec3 sq = texture(screen, q / vec2(960.0, 540.0)).rgb;
				float lq = dot(sq, vec3(0.2126, 0.7152, 0.0722));
				tr *= 1.0 - SUN_TAKE * (1.0 - smoothstep(SUN_DUST.x, SUN_DUST.y, lq));
			}
		}
		// (falling off as the square of 1/(1+d^2): a burst round the sun, not a tint
		// across the screen -- at twice the reach a twenty-fifth, was a fifth; review, Nov 7)
		float fo = 1.0 / (1.0 + ds * ds);
		c *= 1.0 + r_sun.w * gas * tr * fo * fo * r_sun_c;
	}
	if (r_eng.w > 0.0) {
		vec2 gp = (floor(SCREEN_UV * vec2(480.0, 270.0)) + 0.5) * 2.0;
		float r = length((gp - r_eng.xy) / r_eng.z * vec2(1.0, 2.1));
		float f = exp(-r * r * 2.6) * r_eng.w;
		c = c * (1.0 + 2.2 * f * mix(vec3(1.0), r_eng_c, 0.5)) + r_eng_c * f * 0.05;
	}
	COLOR = vec4(c, src.a);
}
