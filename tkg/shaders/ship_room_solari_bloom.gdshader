shader_type canvas_item;
render_mode unshaded;

// SOLARI'S BLOOM (show18's round bloom, round 14: gaussian, never a box round a pour): what burns
// brightest, spread narrow (1.5 px) and wide (4.5 px), stepped in fifths, added in its own colour.
// Why: docs/why/ShipRoomSolari.md#air

uniform sampler2D screen : hint_screen_texture, filter_nearest;

varying vec2 fp;

void vertex() {
	fp = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

vec3 src(vec2 uv) {
	vec3 c = texture(screen, uv).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114)) * 255.0;
	return l > 185.0 ? c * clamp((l - 185.0) / 70.0, 0.0, 1.0) : vec3(0.0);
}

void fragment() {
	vec2 k = SCREEN_PIXEL_SIZE / max(dFdx(fp.x), 1e-4);
	vec3 c = texture(screen, SCREEN_UV).rgb;
	vec3 a = vec3(0.0);
	float wa = 0.0;
	for (int i = -2; i <= 2; i++) {
		for (int j = -2; j <= 2; j++) {
			float w = exp(-float(i * i + j * j) / (2.0 * 2.25));
			a += src(SCREEN_UV + vec2(float(i), float(j)) * k) * w;
			wa += w;
		}
	}
	vec3 b = vec3(0.0);
	float wb = 0.0;
	for (int i = -4; i <= 4; i++) {
		for (int j = -4; j <= 4; j++) {
			float w = exp(-float(i * i + j * j) * 9.0 / (2.0 * 20.25));
			b += src(SCREEN_UV + vec2(float(i), float(j)) * 3.0 * k) * w;
			wb += w;
		}
	}
	vec3 o = a / wa * 0.55 + b / wb * 0.40;
	float m = max(o.r, max(o.g, o.b));
	if (m > 0.0) {
		float st = floor(clamp(m * 1.6, 0.0, 1.0) * 5.0) / 5.0 / 1.6;
		c += o / m * st;
	}
	COLOR = vec4(c, 1.0);
}
