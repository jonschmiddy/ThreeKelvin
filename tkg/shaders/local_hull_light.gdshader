shader_type canvas_item;

// YOUR HULL IN THE SCENE'S LIGHT (`LocalWow` "hull", a prototype): the edge of
// the ship that faces the system's star catches its light, in the star's
// colour, falling off across the plates behind that edge -- and, orbiting a
// world, the edge facing that world takes a little of its lit colour, the way
// a ship low over a bright planet is lit from below. On the ship's own pixels
// only: nothing is drawn round it (halos and shadows round the ships were
// tried and cut: "they're odd").
//
// Set on the ShipView with its children drawing through it (`MountPoints`), so
// a module's edge facing the star catches it too. Steps are GAME pixels worked
// out from the derivatives, so a module drawn at 1.25x is lit by the pixel like
// the hull. Light as light (`draw-light-as-light`): bright at the edge, falling
// off in a few steps, the in-between steps dithered on the hull's own grid (so
// the bob carries the pattern with it and nothing swaps).

// toward the star, screen space (y down), unit
uniform vec2 l_dir = vec2(0.3, -0.95);
uniform vec3 l_col = vec3(1.0, 0.92, 0.78);
// how strong (0 off)
uniform float l_k = 0.0;
// toward the world you orbit, its lit colour, how strong
uniform vec2 b_dir = vec2(0.6, 0.8);
uniform vec3 b_col = vec3(0.8, 0.6, 0.4);
uniform float b_k = 0.0;
// how far in from the lit edge the light reaches, px; and how far the hull's
// own body shades itself away from the star (its far side a little darker:
// a lit volume, not a lit outline)
uniform int reach = 8;
uniform float body = 34.0;
uniform float self_shade = 0.24;

// How many game px in from the edge toward `dir` (1 the edge pixel itself), 0
// when the hull runs on past `n`.
int depth_toward(sampler2D tex, vec2 uv, vec2 st, vec2 dir, int n) {
	for (int i = 1; i <= 48; i++) {
		if (i > n) break;
		vec2 o = round(dir * float(i));
		if (texture(tex, uv + o * st).a < 0.5) return i;
	}
	return 0;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec4 o = c * COLOR;
	// (out of the branch: derivatives need every pixel of the quad)
	vec2 st = vec2(abs(dFdx(UV).x), abs(dFdy(UV).y));
	if (c.a >= 0.5 && (l_k > 0.0 || b_k > 0.0)) {
		ivec2 q = ivec2(floor(UV / max(st, vec2(1e-6))));
		float bay = float(((q.x & 1) * 2 + (q.y & 1) * 3) & 3) / 4.0 + 0.125;
		int dl = depth_toward(TEXTURE, UV, st, l_dir, int(body));
		float wl = 0.0;
		if (dl == 1) wl = 1.0;
		else if (dl == 2) wl = 0.72;
		else if (dl == 3) wl = 0.48;
		else if (dl > 3 && dl <= reach) wl = (1.0 - float(dl - 3) / float(max(reach - 2, 1))) > bay ? 0.3 : 0.12;
		// the body away from the light, in dithered steps (0 = through the hull)
		float far_k = dl == 0 ? 1.0 : clamp(float(dl - reach) / (body - float(reach)), 0.0, 1.0);
		float sh = floor(far_k * 3.0 + bay) / 3.0;
		int db = depth_toward(TEXTURE, UV, st, b_dir, 2);
		float wb = db == 1 ? 1.0 : (db == 2 && bay < 0.5 ? 0.5 : 0.0);
		vec3 base = o.rgb;
		// metal reflects the light it is given: its own colour lifted, and the
		// light's own colour on top (an outline pixel is near black)
		vec3 lit = base * (1.0 - self_shade * min(l_k, 1.0) * sh) + (base * 1.6 + l_col * 0.6) * (l_k * wl);
		lit += (base * 0.6 + b_col * 0.22) * (b_k * wb);
		o.rgb = min(lit, vec3(1.0));
	}
	COLOR = o;
}
