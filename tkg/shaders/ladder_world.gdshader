shader_type canvas_item;

// THE WORLD HANDED OVER BY THE ZOOM LADDER (`LocalSky.adopt_near`, 2C), while it
// moves: the map's own world drawn in a picture of its own at the near layer's
// size (half, 2x2 blocks, as everything it is drawn in), and that picture laid
// over the sky shifted by any fraction of a pixel -- sampled between its blocks,
// the blocks kept square -- so the world slides on one smooth line instead of
// stepping two pixels at a time. Toned as `local_near` tones it, eased in by
// `tone_k`. At rest (an even shift) every block lands on its own pixels.

uniform sampler2D tex : filter_linear;
uniform vec2 tex_px = vec2(480.0, 270.0);
uniform vec2 frame = vec2(960.0, 540.0);
uniform vec2 shift = vec2(0.0);
uniform vec2 ramp = vec2(70.0, 140.0);
uniform float tone_k = 0.0;
#include "res://shaders/local_tone.gdshaderinc"

void fragment() {
	vec2 p = UV * frame - shift;
	vec2 q = p * (tex_px / frame);
	vec2 w = max(fwidth(q), vec2(0.0001));
	vec2 f = fract(q - 0.5);
	vec2 g = clamp((f - 0.5) / min(w, vec2(1.0)) + 0.5, 0.0, 1.0);
	vec4 s = texture(tex, (floor(q - 0.5) + 0.5 + g) / tex_px);
	if (s.a < 0.01) {
		discard;
	}
	float y = (floor(UV.y * frame.y * 0.5) + 0.5) * 2.0;
	float wt = smoothstep(ramp.x, ramp.y, y) * tone_k;
	COLOR = tone_k <= 0.0 ? vec4(s.rgb / max(s.a, 0.0001), s.a)
		: vec4(play_tone(s.rgb, wt), mix(s.a, 1.0, clamp(tone_k, 0.0, 1.0)));
}
