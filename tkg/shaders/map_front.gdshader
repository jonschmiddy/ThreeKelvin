shader_type canvas_item;
render_mode unshaded, blend_add;

// WOW `flarefront` (`SectorWow`, SIMPLIFIED only, off by default): A FLARE'S
// LIGHT TRAVELS. When a prominence erupts, its light runs out through the thin
// dust in the system's plane as a ring (`front`: its radius on the plane and its
// strength, `SystemView.front_now`), catching the dust in clumps as it passes --
// a light echo -- so it reads as light in dust, never as one more clean ellipse
// beside the orbits. In plane units, so zooming only magnifies it; in the
// place's 2x2 blocks, under the worlds' shadows (which cut it) and the palette
// pass, which sets its steps.

uniform vec2 origin = vec2(480.0, 270.0);
uniform float zoom = 1.0;
uniform float tilt = 0.38;
uniform vec3 star_col = vec3(1.0, 0.86, 0.62);
// where the system ends on the plane: the dust thins away past it
uniform float edge = 350.0;
uniform vec2 front = vec2(-1.0, 0.0);

float bh(vec2 p) {
	ivec2 q = ivec2(floor(p));
	uint h = (uint(q.x) * 374761393u) ^ (uint(q.y) * 668265263u);
	h = (h ^ (h >> 13u)) * 1274126177u;
	return float(h ^ (h >> 16u)) / 4294967296.0;
}
float bn(vec2 p) {
	vec2 i = floor(p), f = p - i;
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = bh(i), b = bh(i + vec2(1.0, 0.0)), c = bh(i + vec2(0.0, 1.0)), d = bh(i + vec2(1.0, 1.0));
	return a + (b - a) * u.x + (c - a) * u.y + (a - b - c + d) * u.x * u.y;
}

void fragment() {
	vec2 px = floor(UV * vec2(960.0, 540.0));
	vec2 b = px - mod(px, 2.0) + 1.0;
	vec2 p = (b - origin) / max(zoom, 1e-3);
	vec2 pl = vec2(p.x, p.y / tilt);
	float rho = length(pl);
	float dd = (rho - front.x) / 12.0;
	if (front.y <= 0.0 || abs(dd) > 3.0) {
		discard;
	}
	// the dust's clumps, fixed on the plane: the ring lights them, and little
	// between them
	float clump = smoothstep(0.3, 0.78, bn(pl / 13.0 + 5.0)) * (0.7 + 0.3 * bn(pl / 5.0 + 9.0));
	float thin = 1.0 - smoothstep(edge * 0.75, edge * 1.1, rho);
	float I = front.y * exp(-dd * dd) * (0.3 + 1.0 * clump) * thin;
	COLOR = vec4(star_col * I, 1.0);
}
