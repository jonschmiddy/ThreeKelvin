shader_type canvas_item;
render_mode unshaded, blend_mul;

// THE LAB SCREEN'S TUBE, over everything on the glass (science S9, the
// mockup's `finish`): scanlines, every other row at 80%, and the glass's inner
// shadow under the bezel, its three rows and columns at 40, 62 and 82%.
// Multiplied, so it darkens what is under it and nothing else.

uniform vec2 gsize = vec2(908.0, 488.0);
uniform float amount = 1.0;

void fragment() {
	vec2 l = min(floor(UV * gsize), gsize - 1.0);
	float m = mod(l.y, 2.0) >= 1.0 ? 0.8 : 1.0;
	float sh[3] = float[3](0.4, 0.62, 0.82);
	for (int k = 0; k < 3; k++) {
		float fk = float(k);
		if (l.y == fk || l.y == gsize.y - 1.0 - fk) {
			m *= sh[k];
		}
		if (l.x == fk || l.x == gsize.x - 1.0 - fk) {
			m *= sh[k];
		}
	}
	COLOR = vec4(vec3(mix(1.0, m, amount)), 1.0);
}
