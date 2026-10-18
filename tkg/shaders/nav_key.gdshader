shader_type canvas_item;

// THE MAP'S AND THE CHART'S EMPTY SKY KEYED AWAY ONTO THE FIELD (`NavField`;
// Jon, Oct 18: stars edge to edge, the panels built on top). With their own far
// stars and galaxies off, what is left of each picture's sky is the void -- one
// or two near-blacks of the palette, the same deep navy as the field's -- and
// that is let through to the field beneath; everything else (the gas, the dust,
// the worlds, the star, the galaxy, the hole's black) stands over it. A pixel
// a little brighter than the void (the faintest gas) is let through in part.

// the void's luminance band: at or below `lo` (but above `dark`) all field, at
// `hi` all picture; below `dark` (the hole, a shadow) the picture again
uniform float lo = 0.046;
uniform float hi = 0.085;
uniform float dark = 0.018;
uniform float dark_w = 0.010;
// off: the picture as drawn (a harness's before)
uniform bool on = true;

void fragment() {
	// (COLOR comes in as the texture under the item's modulate)
	vec4 c = COLOR;
	if (on) {
		float L = dot(c.rgb, vec3(0.299, 0.587, 0.114));
		float a = max(smoothstep(lo, hi, L), 1.0 - smoothstep(dark - dark_w, dark, L));
		c.a *= a;
	}
	COLOR = c;
}
