shader_type canvas_item;

// THE LAST FRAMES OF A RUN (`DeathHandoff`): the whole picture under it, read
// back and changed. `look` 0 dims and drains it (A linger, B pull back);
// `look` 2 is a dying feed (C): scanlines thicken, colour drains, bands tear
// sideways in held steps, and it collapses to a dim horizontal line.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform int look = 0;
// A, B: how far dimmed and drained, 0 to 1
uniform float dim = 0.0;
// C: how far gone, 0 to 1
uniform float t = 0.0;
// the picture's height in its own pixels (rows are whole pixels)
uniform float rows = 540.0;

float hash(float n) {
	return fract(sin(n * 127.1 + 311.7) * 43758.5453);
}

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec2 uv = SCREEN_UV;
	if (look != 2) {
		vec3 c = texture(screen_tex, uv).rgb;
		c = mix(c, vec3(luma(c)), dim * 0.85);
		c *= 1.0 - dim * 0.62;
		COLOR = vec4(c, 1.0);
	} else {
		float k = clamp(t, 0.0, 1.0);
		// THE COLLAPSE: the picture squashed onto its middle row, last third
		float sq = smoothstep(0.6, 0.9, k);
		float hgt = mix(1.0, 1.5 / rows, sq);
		float y = (uv.y - 0.5) / hgt + 0.5;
		if (y < 0.0 || y > 1.0) {
			COLOR = vec4(0.0, 0.0, 0.0, 1.0);
		} else {
			// TEARS: a few bands pushed sideways, changing in held steps
			float step_t = floor(k * 14.0);
			float band = floor(y * 30.0);
			float on = step(0.9 - 0.3 * k, hash(band * 1.7 + step_t * 13.0));
			float tear = on * (hash(band * 3.1 + step_t) - 0.5) * 0.12 * smoothstep(0.08, 0.45, k);
			vec3 c = texture(screen_tex, vec2(fract(uv.x + tear), y)).rgb;
			// colour drains
			c = mix(c, vec3(luma(c)) * vec3(0.85, 1.0, 0.95), smoothstep(0.0, 0.55, k));
			// SCANLINES THICKEN: one dark row in three, then two in three
			float row = floor(y * rows);
			float dark = mix(0.0, 2.2, smoothstep(0.02, 0.55, k));
			if (mod(row, 3.0) < dark) {
				c *= 0.22;
			}
			c *= 1.0 - 0.45 * k;
			// the line: bright as it closes, then dim
			float line = smoothstep(0.82, 0.9, k) * (1.0 - smoothstep(0.92, 1.0, k));
			c = mix(c, vec3(0.75, 0.85, 0.8), line * 0.35);
			c *= 1.0 - 0.8 * smoothstep(0.92, 1.0, k);
			COLOR = vec4(c, 1.0);
		}
	}
}
