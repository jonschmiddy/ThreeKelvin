shader_type canvas_item;
render_mode unshaded;

// THE SHIP-SELECT ROOMS' STATIC LIGHT (PORT.md, "Lighting"): the light map is the room's
// stepped light / 2, so lit = albedo x 2 light x gain; what burns by itself goes on unlit.
// Each room's own class may replace this with its film's light; this is the package's rule.
//   mode 0  the room as painted: albedo, light and emissive at the frame's own pixels
//   1  a thing standing in the room (a post, a crate): its own colour, lit as the room is
//   2  a hull or a tarp: rgb x (amb + 0.5 L) x rows, rows 1.08 at its top to 0.78 at its foot
// Everything is in frame pixels: a fragment knows where it is from MODEL_MATRIX.

uniform int mode = 0;
uniform sampler2D albedo : filter_nearest, repeat_disable;
uniform sampler2D light : filter_nearest, repeat_disable;
uniform sampler2D emissive : filter_nearest, repeat_disable;
uniform float gain = 1.0;
uniform float hull_amb = 0.6;
// the lamps' beat this frame (a launch's stutter, Old's hum): it scales the light, not the emissive
uniform float lamp_k = 1.0;
// Solari's warm under-light on hulls: colour and strength, rising with row cubed
uniform vec4 under = vec4(0.0);
// mode 2: the hull's top and foot rows in the frame
instance uniform vec2 rows = vec2(0.0, 1.0);

varying vec2 fp;

void vertex() {
	fp = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

vec3 light_at(vec2 p) {
	vec2 uv = (floor(p) + 0.5) / vec2(960.0, 540.0);
	return texture(light, uv).rgb * lamp_k;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (mode == 0) {
		vec2 uv = (floor(fp) + 0.5) / vec2(960.0, 540.0);
		vec3 a = texture(albedo, uv).rgb;
		vec3 lit = a * 2.0 * light_at(fp) * gain;
		vec4 e = texture(emissive, uv);
		COLOR = vec4(mix(lit, e.rgb, e.a), 1.0);
	} else if (mode == 1) {
		COLOR = vec4(c.rgb * 2.0 * light_at(fp) * gain, c.a);
	} else {
		float u = clamp((floor(fp.y) - rows.x) / max(1.0, rows.y - rows.x), 0.0, 1.0);
		vec3 L = clamp(light_at(fp) * 2.0, 0.0, 1.0);
		vec3 rgb = c.rgb * (hull_amb + 0.5 * L) * mix(1.08, 0.78, u);
		rgb += under.rgb * pow(u, 3.0) * under.a / 255.0 * (c.rgb + 0.15);
		COLOR = vec4(rgb, c.a);
	}
}
