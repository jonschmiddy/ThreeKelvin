shader_type canvas_item;
render_mode unshaded;

// LOCAL'S NEAR THINGS (`LocalSky`): the world the ship orbits, its moons, the
// rocks of a belt or the hulk of a wreck, drawn in a picture of their own and
// set over the sky here, in front of the system's band, held under the same
// readability budget as the sky (`local_grade`): from the top band down they
// are dimmed and their highlights pressed down a knee, the ease in stepped
// as a pixel artist would, in an ordered pattern.

uniform sampler2D tex : filter_nearest;
uniform vec2 ramp = vec2(70.0, 140.0);
uniform float dim = 0.55;
uniform float cap = 0.09;
uniform float soft = 0.2;

void fragment() {
	vec4 s = texture(tex, UV);
	if (s.a < 0.01) {
		discard;
	}
	vec2 bq = floor(UV * vec2(480.0, 270.0));
	float y = (bq.y + 0.5) * 2.0;
	const float B[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	ivec2 q = ivec2(bq) & ivec2(3);
	float w = floor(smoothstep(ramp.x, ramp.y, y) * 4.0 + (B[q.y * 4 + q.x] + 0.5) / 16.0) / 4.0;
	vec3 c = s.rgb;
	if (w > 0.0) {
		float L = dot(c, vec3(0.299, 0.587, 0.114));
		float Ld = L * dim;
		float Lk = Ld > cap ? cap + (Ld - cap) * soft : Ld;
		float k = L > 1e-4 ? Lk / L : dim;
		c *= mix(1.0, k, w);
	}
	COLOR = vec4(c, 1.0);
}
