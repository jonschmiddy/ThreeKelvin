shader_type canvas_item;
render_mode unshaded;

// THE LAB SCREEN'S BLOOM (science S9, the mockup's `finish`): what glows on the
// board -- a running step's ring and icon, the next step's, the arms that are
// lit, DATA on its way in, the key's word -- blurred twice (sigma 2 and 6),
// each blur stepped in five levels and dithered, and added over the screen at
// 0.55 and 0.35. Drawn into its own viewport only when what glows changes
// (`LabZoom`), so the blur is not paid every frame.

// What glows, drawn alone on black (`LabBoard.light`), in board px.
uniform sampler2D light : filter_linear, repeat_disable;
uniform vec2 size = vec2(960.0, 540.0);

float bayer(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int m[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return float(m[y * 4 + x]) / 16.0;
}

vec3 bloom(vec4 bl, vec2 p, float gain) {
	vec3 rgbp = bl.rgb * bl.a;
	float inten = max(rgbp.r, max(rgbp.g, rgbp.b));
	if (inten <= 0.0001) {
		return vec3(0.0);
	}
	float q = clamp(floor(inten * 5.0 + bayer(p)) / 5.0, 0.0, 1.0);
	return rgbp * (q / inten) * gain;
}

void fragment() {
	vec2 p = floor(UV * size);
	vec2 uv = (p + 0.5) / size;
	// sigma 2, every texel to 4 out
	vec4 a = vec4(0.0);
	float wa = 0.0;
	for (int j = -4; j <= 4; j++) {
		for (int i = -4; i <= 4; i++) {
			float w = exp(-float(i * i + j * j) / 8.0);
			a += texture(light, uv + vec2(float(i), float(j)) / size) * w;
			wa += w;
		}
	}
	// sigma 6, to 13 out, each tap the mean of a 2x2 (the filter's own)
	vec4 b = vec4(0.0);
	float wb = 0.0;
	for (int j = -6; j <= 6; j++) {
		for (int i = -6; i <= 6; i++) {
			vec2 o = vec2(float(i) * 2.0 + 0.5, float(j) * 2.0 + 0.5);
			float w = exp(-dot(o, o) / 72.0);
			b += texture(light, uv + o / size) * w;
			wb += w;
		}
	}
	COLOR = vec4(bloom(a / wa, p, 0.55) + bloom(b / wb, p, 0.35), 1.0);
}
