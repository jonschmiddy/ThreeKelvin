shader_type canvas_item;
render_mode unshaded;

// TRIAL (`-- smoke=S2`): the heat haze under the lift jets. The picture under each
// jet, from the belly to the floor, is read back shifted sideways by whole pixels
// on a held field that changes ten times a second; strongest just under the jet,
// none at its edges, nothing while the jets are cold.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform vec2 rect_size = vec2(960.0, 540.0);
uniform int n = 0;
// x, belly row, floor row, half width
uniform vec4 jets[6];
uniform float k = 0.0;
uniform float tstep = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 p = floor(UV * rect_size) + 0.5;
	float w = 0.0;
	for (int i = 0; i < 6; i++) {
		if (i >= n) {
			break;
		}
		vec4 j = jets[i];
		if (p.y < j.y || p.y > j.z + 4.0) {
			continue;
		}
		float u = (p.y - j.y) / max(j.z - j.y, 1.0);
		float half_w = j.w * (1.0 + 1.6 * u);
		float dx = abs(p.x - j.x) / half_w;
		if (dx < 1.0) {
			w = max(w, (1.0 - dx) * (1.0 - 0.6 * u));
		}
	}
	w *= k;
	if (w < 0.05) {
		discard;
	}
	// a held field of whole-pixel shifts, mostly sideways, in rows that wobble
	float row = floor(p.y / 2.0);
	float h = hash(vec2(row, tstep)) - 0.5;
	float shift = floor(h * 2.0 * (1.5 + 3.0 * w) + 0.5);
	float vshift = floor((hash(vec2(row + 17.0, tstep)) - 0.5) * 1.4 * w + 0.5);
	// screen pixels per picture pixel, so a shift is whole picture pixels
	vec2 per = vec2(length(dFdx(UV * rect_size)), length(dFdy(UV * rect_size)));
	vec2 off = vec2(shift, vshift) * SCREEN_PIXEL_SIZE / max(per, vec2(0.0001));
	vec3 c = texture(screen_tex, SCREEN_UV + off).rgb;
	// a faint warm lift where the air is hottest
	c += vec3(0.05, 0.025, 0.0) * w;
	COLOR = vec4(c, 1.0);
}
