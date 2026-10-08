shader_type canvas_item;
// (premultiplied onto a cleared picture, as `pixel_turn.gdshader` writes: what
// shows it unpremultiplies)
render_mode unshaded, blend_premul_alpha;

// A RING OF MODULES SPINNING ABOUT ITS OWN AXIS (`LocalSubject`, a piece's
// `spin`; counterweight): the ring unwrapped by angle round its ellipse into a
// strip (`strip`: a column an angle, each the ring's cross-section from inside
// to out), re-projected with the turn `phi`: each pixel looks back along the
// ellipse to where its module was, so the modules travel round it. The band's
// thickness at each angle stays the picture's own (`geo`), and so does its
// light (`env`: the take's light and shade averaged along the ring, taken out
// where a module was and put back where it is drawn) -- a module brightens
// coming round to the lit side and dims going round the back. Soft: 16 points
// a pixel averaged in linear light, edges partly clear, never stepped.

uniform sampler2D strip : filter_nearest, repeat_disable;
uniform sampler2D env : filter_linear, repeat_enable;
uniform sampler2D geo : filter_nearest, repeat_enable;
uniform vec2 out_size = vec2(1.0);
// the picture's own size, and the room round it in this one
uniform float pad = 8.0;
uniform float n = 1.0;
uniform float m = 1.0;
uniform float r0 = 0.55;
uniform float r1 = 1.5;
uniform vec2 centre = vec2(0.0);
uniform vec2 radii = vec2(1.0);
uniform float tilt = 0.0;
// the turn, radians round the ellipse
uniform float phi = 0.0;

float band_in(float j) { return texture(geo, vec2((j + 0.5) / n, 0.5)).r * 255.0 / 255.0 * m; }
float band_out(float j) { return texture(geo, vec2((j + 0.5) / n, 0.5)).g * 255.0 / 255.0 * m; }

vec4 look(vec2 q) {
	vec2 d = q - centre;
	float ct = cos(tilt);
	float st = sin(tilt);
	vec2 e = vec2(d.x * ct + d.y * st, -d.x * st + d.y * ct) / radii;
	float th = atan(e.y, e.x);
	float rho = length(e);
	float j = floor(mod((th + PI) / TAU * n, n));
	float i0 = band_in(j);
	float o0 = band_out(j);
	float r = (rho - r0) / (r1 - r0) * m;
	float f = (r - i0) / max(o0 - i0, 1.0);
	float js = floor(mod((th - phi + PI) / TAU * n, n));
	float i1 = band_in(js);
	float o1 = band_out(js);
	float rs = i1 + f * (o1 - i1);
	if (rs < 0.0 || rs >= m) {
		return vec4(0.0);
	}
	vec4 c = texelFetch(strip, ivec2(int(js), int(rs)), 0);
	if (c.a < 0.5) {
		return vec4(0.0);
	}
	// the light where it is drawn, over the light where it was
	float fc = clamp(f, 0.0, 1.0);
	float l_here = texture(env, vec2((j + 0.5) / n, fc)).r;
	float l_was = texture(env, vec2((js + 0.5) / n, fc)).r;
	float k = clamp(l_here / max(l_was, 0.04), 0.35, 2.6);
	vec3 lin = pow(c.rgb, vec3(2.2)) * k;
	return vec4(lin, 1.0);
}

void fragment() {
	vec2 p = UV * out_size - vec2(pad);
	vec3 acc = vec3(0.0);
	float a = 0.0;
	for (int y = 0; y < 4; y++) {
		for (int x = 0; x < 4; x++) {
			vec4 s = look(p + (vec2(float(x), float(y)) + 0.5) / 4.0 - vec2(0.5));
			acc += s.rgb * s.a;
			a += s.a;
		}
	}
	if (a <= 0.0) {
		COLOR = vec4(0.0);
	} else {
		vec3 c = pow(clamp(acc / a, 0.0, 1.0), vec3(1.0 / 2.2));
		float al = a / 16.0;
		COLOR = vec4(c * al, al);
	}
}
