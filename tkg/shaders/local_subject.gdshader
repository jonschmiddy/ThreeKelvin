shader_type canvas_item;
render_mode unshaded;

// AN ENCOUNTER'S SUBJECT, GROUNDED IN LOCAL'S SCENE (`LocalSubject`): a sprite
// lit from the system's star side and shaded on the far side, in steps (pixel
// light, not a smooth wash), its star-facing edge caught by the star's own
// colour; a far one dimmed toward the sky; and its colours set to the system's
// own palette where LOCAL has one (SIMPLIFIED, RADIANT, LEGACY), as the sky's
// are. PAINTED has no palette: its light is stepped harder instead.
//
// `to_star` is in the sprite's own pixels (its rotation taken out by the caller).
// A painter rock (`use_mask`) is lit by PlanetView already: its mask cuts the
// lumpy outline and darkens the cut, and the directional terms are left at 0.

uniform vec2 to_star = vec2(-1.0, 0.0);
uniform vec3 star_col = vec3(1.0);
uniform float lit = 0.32;
uniform float shade = 0.5;
uniform float far = 0.0;
// a cold hull (no heat, no lights): its colours drained and darkened toward the
// sky before the star lights it, so a lit window goes out with the rest
uniform float dark = 0.0;
uniform vec3 sky_col = vec3(0.035, 0.045, 0.075);
uniform bool use_mask = false;
uniform sampler2D mask : filter_nearest;
uniform bool stepped = false;
uniform vec3 pal[72];
uniform int pal_n = 0;
// how far toward its palette colour a pixel is pulled (all the way flattens
// a sprite's own shading into the sky's few colours)
uniform float pal_k = 0.55;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (use_mask) {
		vec4 m = texture(mask, UV);
		c.a *= m.r;
		c.rgb *= mix(1.0, 0.45, m.g);
	}
	if (c.a < 0.02) {
		discard;
	}
	if (dark > 0.0) {
		float l = dot(c.rgb, vec3(0.3, 0.5, 0.2));
		vec3 cold = mix(vec3(l), c.rgb, 0.3) * 0.5 + sky_col * 0.4;
		c.rgb = mix(c.rgb, cold, clamp(dark, 0.0, 1.0));
	}
	vec2 px = TEXTURE_PIXEL_SIZE;
	vec2 sz = 1.0 / px;
	vec2 p = (floor(UV * sz) + 0.5) - sz * 0.5;
	float span = max(length(sz) * 0.5, 1.0);
	float s = clamp(dot(p, to_star) / span, -1.0, 1.0);
	float k = s > 0.0 ? s * lit : s * shade;
	// the edge facing the star: the next pixel toward it is clear
	float rim = texture(TEXTURE, UV + to_star * px * 1.5).a < 0.3 ? 1.0 : 0.0;
	if (use_mask) {
		rim = 0.0;
	}
	k += rim * lit * 0.9;
	float steps = stepped ? 3.0 : 4.0;
	k = floor(k * steps + 0.5) / steps;
	vec3 col = c.rgb * (1.0 + min(k, 0.0)) + c.rgb * star_col * max(k, 0.0);
	col = mix(col, sky_col, clamp(far, 0.0, 1.0) * 0.6);
	if (pal_n > 0) {
		vec3 q = col * 255.0;
		float best = 1e9;
		vec3 pick = col;
		for (int i = 0; i < pal_n; i++) {
			vec3 d = q - pal[i] * 255.0;
			float dd = d.r * d.r * 2.0 + d.g * d.g * 4.0 + d.b * d.b * 3.0;
			if (dd < best) {
				best = dd;
				pick = pal[i];
			}
		}
		col = mix(col, pick, pal_k);
	}
	COLOR = vec4(col, c.a);
}
