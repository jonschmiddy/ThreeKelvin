shader_type canvas_item;
#include "res://shaders/cloud_round.gdshaderinc"

// THE MAP'S CLOUD PAST ITS PICTURE (Jon, Oct 18, cloud:A -- of a system inside
// a gas cloud, the map's picture "reads as a lit rectangle"): the map's own sky
// (`SystemView`'s scene: the cloud, the star's light, the dust), drawn again
// round the picture across the screens' area, keyed onto the field as the
// picture is (`nav_key.gdshader`'s void band, `sky_key`), fading out over `fade` px at the
// area's edges and its own. Inside the picture the picture draws it; at the
// picture's soft edge this gives exactly what is missing, so the two add to one
// layer of the same gas: e = k (1 - fp) / (1 - k fp), with fp the picture's own
// edge fade there and k the key.

// the picture (its own soft edge), and where this may draw (viewport px)
uniform vec4 inner = vec4(0.0);
uniform vec4 outer = vec4(0.0, 0.0, 960.0, 540.0);
uniform float fade = 24.0;
// (the map going small into the chart, a cloud: `cloud_round.gdshaderinc`)
uniform float round_k = 0.0;
uniform vec2 round_c = vec2(480.0, 270.0);
uniform vec2 round_h = vec2(470.0, 245.0);
// the map's own sky ends short of the screens' right edge (the side panel's
// side): this is drawn wider than it (`span`, its size over the sky's), and
// past its end the sky goes on as gas no screen shows (`sky_past`) -- at full
// strength to the screens' edge, under the plates (Jon: "Why is there a missing
// part when the panel comes in?")
uniform vec2 span = vec2(1.0);
// ... the same cloud drawn on past its end (`SystemView` `_past`; `sky_wide`)
uniform sampler2D past_tex : filter_nearest, repeat_disable;
uniform bool past_on = false;
// (the map's own fade in and out, its modulate: the picture has it, so this
// gives the rest of what the two make)
varying vec4 mod_c;

void vertex() {
	mod_c = COLOR;
}

float inside(vec2 p, vec4 r) {
	return min(min(p.x - r.x, p.y - r.y), min(r.x + r.z - p.x, r.y + r.w - p.y));
}

void fragment() {
	vec4 w = sky_wide(TEXTURE, past_tex, past_on, UV * span);
	float k = w.a;
	vec4 c = vec4(k > 0.0001 ? w.rgb / k : vec3(0.0), 1.0);
	float am = mod_c.a;
	float L = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec2 p = FRAGCOORD.xy;
	float fp = inner.z > 0.0 ? smoothstep(0.0, fade, inside(p, inner)) : 0.0;
	// (the cloud's rounding is on the picture too: what the picture lets through
	// here is k m fp, so this gives the rest of k m)
	float m = cloud_round(p, L, round_k, round_c, round_h);
	float e = am * k * m * (1.0 - fp) / max(1.0 - am * k * m * fp, 0.001);
	e *= smoothstep(0.0, fade, inside(p, outer));
	COLOR = vec4(c.rgb, clamp(e, 0.0, 1.0));
}
