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
#include "res://shaders/local_tone.gdshaderinc"

void fragment() {
	vec4 s = texture(tex, UV);
	if (s.a < 0.01) {
		discard;
	}
	vec2 bq = floor(UV * vec2(480.0, 270.0));
	float y = (bq.y + 0.5) * 2.0;
	float w = smoothstep(ramp.x, ramp.y, y);
	COLOR = vec4(play_tone(s.rgb, w), 1.0);
}
