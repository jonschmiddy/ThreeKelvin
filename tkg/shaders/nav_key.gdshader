shader_type canvas_item;
#include "res://shaders/cloud_round.gdshaderinc"

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
// THE PICTURE'S EDGE, NOT A BOX (Jon, Oct 18: "why is there a box around the
// galaxy panel?"): its frame (viewport px) is no line now, and what the
// picture holds (the galaxy's halo, the gas, a far orbit) is clipped there --
// so it fades out over `fade` px inside it instead of stopping at a cut
uniform vec4 frame = vec4(0.0);
uniform float fade = 24.0;
// (the map going small into the chart, a cloud: `cloud_round.gdshaderinc`)
uniform float round_k = 0.0;
uniform vec2 round_c = vec2(480.0, 270.0);
uniform vec2 round_h = vec2(470.0, 245.0);

void fragment() {
	// (COLOR comes in as the texture under the item's modulate)
	vec4 c = COLOR;
	if (on) {
		float L = dot(c.rgb, vec3(0.299, 0.587, 0.114));
		float a = max(smoothstep(lo, hi, L), 1.0 - smoothstep(dark - dark_w, dark, L));
		c.a *= a;
		c.a *= cloud_round(FRAGCOORD.xy, L, round_k, round_c, round_h);
		if (frame.z > 0.0) {
			vec2 p = FRAGCOORD.xy;
			float d = min(min(p.x - frame.x, p.y - frame.y), min(frame.x + frame.z - p.x, frame.y + frame.w - p.y));
			c.a *= smoothstep(0.0, fade, d);
		}
	}
	COLOR = c;
}
