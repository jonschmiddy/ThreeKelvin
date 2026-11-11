shader_type canvas_item;
render_mode unshaded, blend_disabled;

// The films' finish, shared: bloom on what is already bright (R4), the full-frame flash,
// the chromatic fringe radial from the event, and the whole-pixel shake. It samples the
// composite the world pass and the specks drew, never outside the world window, so the
// HUD neither moves nor blooms.
// Why: docs/why/JumpStage.md#finish-pass

#include "res://shaders/jump/jump_common.gdshaderinc"

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform vec4 world = vec4(0.0, 0.0, 960.0, 540.0);
uniform vec2 shake = vec2(0.0);
uniform vec2 centre = vec2(480.0, 270.0);
uniform float fringe = 0.0;
uniform float flash = 0.0;
uniform float flash_floor = 0.10;
uniform float flash_sy = 1.3;
// the flash's falloff (R4: 2.6 e^(-r/110)), its colour (zero: white-lilac), and an optional
// bar of it along a line (amp, y, width, x from which it ramps in over 220 px; R10's rail)
uniform float flash_k = 2.6;
uniform float flash_r = 110.0;
uniform vec3 flash_col = vec3(0.0);
uniform vec4 flash_bar = vec4(0.0);
uniform float bloom = 0.0;

vec3 pick(vec2 q, vec2 px) {
	return j_world(screen, px, q, world);
}

void fragment() {
	vec2 p = floor(SCREEN_UV / SCREEN_PIXEL_SIZE);
	vec2 px = SCREEN_PIXEL_SIZE;
	vec2 q = p + shake;
	vec3 img = pick(q, px);
	// the fringe first, so the bloom and the flash land on the fringed picture
	if (fringe >= 0.5) {
		vec2 d = q - centre;
		float dl = length(d) + 1e-3;
		vec2 u = d / dl;
		float kk = clamp(dl / 300.0, 0.0, 1.0) * fringe;
		img.r = pick(floor(q - u * kk + 0.5), px).r;
		img.b = pick(floor(q + u * kk + 0.5), px).b;
	}
	if (bloom > 0.0) {
		// box(box(.,4),4)*1.2 + box(box(.,14),14)*0.4 on pixels past 200/255, as sparse taps:
		// the narrow one 3x3 at stride 3, the wide 5x5 at stride 7, each a mean.
		vec3 bl = vec3(0.0);
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec3 s = pick(q + vec2(float(x), float(y)) * 3.0, px);
				float lm = max(s.r, max(s.g, s.b));
				bl += s * clamp((lm - 200.0 / 255.0) / (55.0 / 255.0), 0.0, 1.0) * (1.2 / 9.0);
			}
		}
		for (int y = -2; y <= 2; y++) {
			for (int x = -2; x <= 2; x++) {
				vec3 s = pick(q + vec2(float(x), float(y)) * 7.0, px);
				float lm = max(s.r, max(s.g, s.b));
				bl += s * clamp((lm - 200.0 / 255.0) / (55.0 / 255.0), 0.0, 1.0) * (0.4 / 25.0);
			}
		}
		img = j_add_glow(img, bl * bloom, 7.0, p);
	}
	if (flash > 0.0) {
		float r = length(vec2(q.x - centre.x, (q.y - centre.y) * flash_sy));
		float fk = flash_floor + flash_k * exp(-r / flash_r);
		if (flash_bar.x > 0.0) {
			fk += flash_bar.x * exp(-pow((q.y - flash_bar.y) / flash_bar.z, 2.0)) * clamp((q.x - flash_bar.w) / 220.0, 0.0, 1.0);
		}
		vec3 fc = flash_col == vec3(0.0) ? J_WHT * 0.6 + J_LIL * 0.4 : flash_col;
		img = j_add_glow(img, flash * fk * fc, 16.0, p);
	}
	COLOR = vec4(clamp(img, 0.0, 1.0), 1.0);
}
