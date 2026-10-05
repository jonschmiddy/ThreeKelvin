shader_type canvas_item;

// THE CHART'S MARKS (`StarchartScreen.MapChart`): everything the chart draws
// over the sky passes through untouched, except its dark rims -- the rim round
// a system's glyph, the underlay under a route, a ring, the trail and the YOU
// label. Those are drawn in a key colour (pure green, `MapChart._UNDER`), and
// here become the void, as strong as the key's alpha says only where the sky
// under them is bright (the bulge, bright gas) and fading to nothing over dark
// sky, where a glyph already reads ("these are kinda too thick you know in the
// border", Jon, of a solid rim everywhere).

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform vec3 void_col = vec3(0.027, 0.039, 0.07);

void fragment() {
	vec4 c = COLOR;
	if (c.g > 0.5 && c.r < 0.02 && c.b < 0.02) {
		vec3 s = texture(screen_tex, SCREEN_UV).rgb;
		float l = dot(s, vec3(0.299, 0.587, 0.114));
		COLOR = vec4(void_col, c.a * smoothstep(0.08, 0.3, l));
	}
}
