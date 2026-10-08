shader_type canvas_item;
render_mode unshaded;

// LOCAL'S NEAR THINGS (`LocalSky`): the world the ship orbits, its moons, the
// rocks of a belt or the hulk of a wreck, drawn in a picture of their own and
// set over the sky here, in front of the system's band. They are solid
// bodies, not gas: from the top band down their LIGHT is pressed as the gas's
// is (`local_tone.gdshaderinc`, the same ramp), but their dark is never
// lifted -- with the gas's lift a dark crust went milky and a world read
// see-through (RADIANT worst, PAINTED a little).

uniform sampler2D tex : filter_nearest;
uniform vec2 ramp = vec2(70.0, 140.0);
// how much of the press is on: 1 always, but 0 while the zoom ladder hands the
// map's own world over (it is drawn unpressed on the map), eased in after
uniform float tone_k = 1.0;
#include "res://shaders/local_tone.gdshaderinc"

void fragment() {
	vec4 s = texture(tex, UV);
	if (s.a < 0.01) {
		discard;
	}
	vec2 bq = floor(UV * vec2(480.0, 270.0));
	float y = (bq.y + 0.5) * 2.0;
	float w = smoothstep(ramp.x, ramp.y, y) * tone_k;
	// (handed over from the map, untoned: the picture exactly as the map draws
	// it, its rim of air laid over the sky as the map lays it)
	// (the near picture is drawn over a clear ground, so what it holds is the
	// colour already weighted by its cover: taken back out, laid over once)
	COLOR = tone_k <= 0.0 ? vec4(s.rgb / max(s.a, 0.0001), s.a) : vec4(play_tone(s.rgb, w), mix(s.a, 1.0, clamp(tone_k, 0.0, 1.0)));
}
