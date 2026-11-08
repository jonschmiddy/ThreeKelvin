shader_type canvas_item;
render_mode unshaded, blend_disabled;

// RADIANT'S GLOW, step one (`RadiantGlow`, direction C of Nov 7: "glow and
// colour"): what of the finished picture is bright enough to glow. One texel a
// 2x2 block. Out: the light above the threshold, in its own colour pushed
// toward its hue (a lamp's spill is the lamp's colour, never grey), stored as a
// square root so the faint tails keep their steps in 8 bits. The glow pass
// reads this through the back buffer's blurred levels (`radiant_glow`).

uniform sampler2D src : filter_nearest;
// where light starts to glow (linear, the brightest channel) and how soft the knee is
uniform float thr = 0.32;
uniform float knee = 0.18;
// how much a saturated light outglows a white one of the same brightness
uniform float hue_k = 1.6;

vec3 lin(vec3 c) { return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c)); }

void fragment() {
	vec3 c = lin(texture(src, UV).rgb);
	float m = max(c.r, max(c.g, c.b));
	float e = max(m - thr, 0.0);
	// a soft knee: the threshold is not a line round every lamp
	e = e * e / (e + knee);
	vec3 hue = c / max(m, 1e-4);
	float sat = 1.0 - min(hue.r, min(hue.g, hue.b));
	// coloured light carries further than white: the spill is the source's colour
	hue = pow(hue, vec3(1.0 + sat * 0.8));
	COLOR = vec4(sqrt(clamp(hue * e * (1.0 + hue_k * sat), 0.0, 1.0)), 1.0);
}
