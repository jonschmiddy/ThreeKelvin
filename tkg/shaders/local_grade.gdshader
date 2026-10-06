shader_type canvas_item;
render_mode unshaded, blend_disabled;

// LOCAL'S READABILITY BUDGET (`LocalSky`): the fight is played across the
// view below its top band -- the ships, the shots, the damage numbers, the hand
// at the bottom -- and the sky behind it must never be brighter or busier than
// they are. Everything drawn so far is read back and, from the top band down
// (eased in over `ramp` in a checker of blocks, so no line shows), dimmed and its highlights pressed
// down a soft knee: no bright gas, star or weather light behind a ship,
// whatever the sky. The band above it -- the sun, the worlds, the brightest
// gas -- keeps all of its light. The budget it keeps is measured
// (`LocalShot stats=`).

uniform sampler2D screen : hint_screen_texture, filter_nearest;
// where the dimming starts and where it is whole (game px, down the frame)
uniform vec2 ramp = vec2(70.0, 140.0);
// inside it: everything times `dim`, and anything brighter than `cap` (sRGB
// luma) only `soft` as bright again beyond it
uniform float dim = 0.55;
uniform float cap = 0.09;
uniform float soft = 0.2;

void fragment() {
	vec4 src = texture(screen, SCREEN_UV);
	float y = (floor(SCREEN_UV.y * 270.0) + 0.5) * 2.0;
	// THE EASE IN, AS A PIXEL ARTIST STEPS IT: four steps of dimming, each block
	// on one of them, dithered between the two either side in an ordered
	// pattern down the ramp. A smooth ramp went
	// through the palette as one hard line across the sky (a flat cloud has a
	// single step there), and the palette keeps a checker as it is.
	const float B[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	ivec2 q = ivec2(floor(SCREEN_UV * vec2(480.0, 270.0))) & ivec2(3);
	float w = floor(smoothstep(ramp.x, ramp.y, y) * 4.0 + (B[q.y * 4 + q.x] + 0.5) / 16.0) / 4.0;
	vec3 c = src.rgb;
	if (w > 0.0) {
		float L = dot(c, vec3(0.299, 0.587, 0.114));
		float Ld = L * dim;
		float Lk = Ld > cap ? cap + (Ld - cap) * soft : Ld;
		float k = L > 1e-4 ? Lk / L : dim;
		c *= mix(1.0, k, w);
	}
	COLOR = vec4(c, src.a);
}
