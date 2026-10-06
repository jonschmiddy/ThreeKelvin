shader_type canvas_item;
render_mode unshaded;

// LOCAL'S NEAR THINGS (`LocalSky`): the world the ship orbits, its moons, the
// rocks of a belt or the hulk of a wreck, drawn in a picture of their own and
// set over the sky here, in front of the system's band, held under the same
// play tone as the sky (`local_grade`): from the top band down their range is
// pressed in toward a mid-tone, eased in down the same ramp.

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
	vec3 c = s.rgb;
	c = play_tone(c, w);
	COLOR = vec4(c, 1.0);
}
