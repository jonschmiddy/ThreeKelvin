shader_type canvas_item;
render_mode unshaded;

// THE TIER'S GALAXY, its body: a dithered glow in the galaxy's shape on a
// 112 x 112 canvas, in whole pixels (Jon's LAUNCH A RUN v2, Nov 9). The stars
// and flares are drawn over it by `TierGalaxy`. `form`: 0 a spiral, 1 a disc,
// 2 a ball, 3 the torn dwarf (a big spiral eating it, a stream between).
uniform int form = 0;
uniform float t = 0.0;
uniform float omega = 0.12;
uniform float pulse = 1.0;
uniform float bloom = 0.65;
uniform float glare = 0.0;
uniform float heat = 0.0;
uniform float tilt = 0.52;
uniform float rot = 0.0;
uniform vec3 mid = vec3(0.47, 0.59, 0.88);
uniform vec3 core = vec3(1.0, 0.96, 0.86);
uniform vec3 cool = vec3(0.55, 0.65, 0.9);
uniform vec3 panel = vec3(0.067, 0.094, 0.137);
const float G = 112.0;

vec2 bez(float u) {
	vec2 p0 = vec2(90.0, 86.0);
	vec2 p1 = vec2(66.0, 112.0);
	vec2 p2 = vec2(24.0, 100.0);
	vec2 p3 = vec2(46.0, 60.0);
	float v = 1.0 - u;
	return v * v * v * p0 + 3.0 * v * v * u * p1 + 3.0 * v * u * u * p2 + u * u * u * p3;
}

// six levels, a 2x2 ordered dither between them, up to nine for the overexposed core
float levels_of(float inten, vec2 px) {
	float q = clamp(inten, 0.0, 1.6) * 6.0;
	float base = floor(q);
	float thr;
	int bx = int(mod(px.x, 2.0));
	int by = int(mod(px.y, 2.0));
	if (by == 0) { thr = bx == 0 ? 0.2 : 0.7; } else { thr = bx == 0 ? 0.95 : 0.45; }
	return clamp(base + ((q - base) > thr ? 1.0 : 0.0), 0.0, 9.0) / 6.0;
}

vec3 ramp(float lev, vec3 m, vec3 c) {
	vec3 dark = mix(panel, m, 0.35);
	float tt = clamp(lev, 0.0, 1.0);
	vec3 col = tt < 0.5 ? mix(dark, m, tt / 0.5) : mix(m, c, (tt - 0.5) / 0.5);
	float hot = clamp((lev - 1.0) / 0.6, 0.0, 1.0);
	return col + (vec3(1.0) - col) * hot;
}

void fragment() {
	vec2 px = floor(UV * G);
	float x = px.x - G / 2.0 + 0.5;
	float y = px.y - G / 2.0 + 0.5;
	float th = omega * t;
	float c = cos(-rot);
	float s = sin(-rot);
	float ux = x * c - y * s;
	float uy = (x * s + y * c) / tilt;
	float d = sqrt(ux * ux + uy * uy);
	float body = 0.0;
	float spiral = 0.0;
	if (form == 0) {
		float ang = atan(uy, ux);
		float arms = 0.5 + 0.5 * cos(2.0 * (ang - th) - 2.1 * log(1.0 + d / 6.0));
		body = exp(-d / (16.0 * bloom)) * 1.1 + 0.55 * arms * exp(-d / 30.0) * (d > 6.0 ? 1.0 : 0.0);
	} else if (form == 1) {
		body = exp(-d / (14.0 * bloom)) * 1.2 + 0.45 * exp(-((d - 30.0) * (d - 30.0)) / 260.0) + 0.25 * exp(-d / 40.0);
	} else if (form == 2) {
		body = exp(-d / (15.0 * bloom)) * 1.25 + 0.22 * exp(-d / 34.0);
	} else {
		// the big spiral, core and arms, turning slowly; the small dwarf being pulled in
		float gx = px.x + 0.5 - 34.0;
		float gy = (px.y + 0.5 - 30.0) / 0.55;
		float gd = sqrt(gx * gx + gy * gy);
		float gang = atan(gy, gx);
		float arms = 0.5 + 0.5 * cos(2.0 * (gang - th * 0.3) - 2.1 * log(1.0 + gd / 7.0));
		arms = arms * arms;
		spiral = exp(-gd / 9.0) * 1.5 + 0.8 * arms * exp(-gd / 34.0) * (gd > 6.0 ? 1.0 : 0.0) + 0.12 * exp(-gd / 30.0);
		float dx = px.x + 0.5 - 90.0;
		float dy = px.y + 0.5 - 86.0;
		float dd = sqrt(dx * dx + dy * dy);
		body = exp(-dd / 5.0) * 1.1 * pulse;
		// the stream: a glow band along the hook, fading as it falls in
		float sd = 1.0e9;
		float su = 0.0;
		for (int k = 0; k < 24; k++) {
			float u = float(k) / 23.0;
			vec2 p = bez(u);
			float dist = distance(vec2(px.x + 0.5, px.y + 0.5), p);
			if (dist < sd) {
				sd = dist;
				su = u;
			}
		}
		body += exp(-(sd * sd) / (2.0 * 3.2 * 3.2)) * (0.55 - 0.3 * su) * pulse;
	}
	float gxx = x;
	float gyy = y;
	if (form == 3) {
		gxx = px.x + 0.5 - 90.0;
		gyy = px.y + 0.5 - 86.0;
	}
	float gl = glare * exp(-abs(gyy) / 1.2) * exp(-abs(gxx) / (22.0 + 18.0 * heat)) * 0.9;
	gl += glare * 0.5 * exp(-abs(gxx) / 1.2) * exp(-abs(gyy) / 14.0);
	// a soft round window: the glow is gone well before the canvas edge
	float window;
	if (form == 3) {
		window = exp(-(pow(abs(x) / 53.0, 10.0) + pow(abs(y) / 53.0, 10.0)));
	} else {
		float rr = sqrt(x * x + y * y);
		window = exp(-pow(rr / 46.0, 6.0));
	}
	float lev;
	vec3 col;
	if (form == 3) {
		float lev_s = levels_of(spiral * 0.95 * window, px);
		float lev_d = levels_of((body + gl) * 0.95 * window, px);
		vec3 cs = ramp(lev_s, cool, vec3(1.0, 0.925, 0.784));
		vec3 cd = ramp(lev_d, mid, core);
		float w = lev_d / (lev_s + lev_d + 1.0e-6);
		col = mix(cs, cd, w);
		lev = max(lev_s, lev_d);
	} else {
		lev = levels_of((body * pulse + gl) * 0.95 * window, px);
		col = ramp(lev, mid, core);
	}
	COLOR = vec4(col, clamp(lev * 2.2, 0.0, 1.0));
}
