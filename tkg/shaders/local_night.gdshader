shader_type canvas_item;
render_mode unshaded, blend_add;

// A SETTLED WORLD'S CITY LIGHTS (`LocalLife`): the night side of the world you
// orbit carries its towns -- each a cluster of points of light, a few brighter
// at a big town's heart, lone lights between. One instance a light (its place
// on the sphere and its strength in INSTANCE_CUSTOM), turned with the world
// here (`planet.gdshader`'s `to_body`, run backwards) a block at a time, all
// together, on the world's own 2 px blocks, shown only where the star's light
// has left the ground (eased over the terminator in steps) and not under the
// front of a ring.
//
// LIGHT AS LIGHT (draw-light-as-light): each light is its block, and a little
// glow falling off into the blocks beside it; lights near each other add
// (blend_add), so a town's middle glows and its edges are single points --
// never a flat blot. Drawn over the near picture, not in it (the play tone
// would press the lights to tan smudges). By style: SIMPLIFIED stepped light
// with a faint cross of glow; PAINTED two flat hand-picked warm tones from B's
// glow ramp, no soft glow; RADIANT a softer, wider spill through an exposure;
// LEGACY pale points only.

// the world: its middle (this sky's 960x540 px, as drawn), radius, turn
uniform vec2 ctr = vec2(0.0);
uniform float r = 100.0;
uniform float w_seed = 0.0;
uniform float spin = 0.05;
uniform float tilt = 0.0;
uniform float time = 0.0;
uniform vec3 L = vec3(-0.6, -0.6, 0.5);
// its rings in its radii (0: none)
uniform vec2 ring = vec2(0.0);
uniform int style = 0;
uniform float k = 1.0;
// how far past the half-way line the world's own light wraps (RADIANT's soft
// terminator): the lights wait for the dark
uniform float term = 0.0;

varying float v_s;

void vertex() {
	vec4 cd = INSTANCE_CUSTOM;
	vec3 b = cd.xyz;
	// THE LIGHTS TURN TOGETHER, a block at the equator at a time (the ground
	// under them glides, blended; a light is a point and can only hop): each
	// on its own clock, lights side by side hopped on different frames, and a
	// block one left as the next arrived went A, B, A -- 58 flip-backs a second
	// on a capital's night side. On one clock a town keeps its shape and no
	// block changes twice in a row.
	float stp = 2.0 / max(r, 1.0);
	float turn = floor(time * spin / stp) * stp;
	float ang = w_seed + turn, ca = cos(ang), sa = sin(ang), ct = cos(tilt), st = sin(tilt);
	// body -> the view: the spin undone, then the tilt
	float tx = b.x * ca - b.z * sa, sz = b.x * sa + b.z * ca, ty = b.y;
	vec3 sv = vec3(tx * ct + ty * st, -tx * st + ty * ct, sz);
	float d = dot(sv, L) + term;
	float kn = d > 0.12 ? 0.0 : (d < -0.12 ? 1.0 : (0.12 - d) / 0.24);
	// fewer toward the limb, where they are seen edge on
	kn *= clamp((sv.z - 0.12) * 3.5, 0.0, 1.0);
	float lvl = floor(kn * 3.0) / 3.0;
	bool hidden = sv.z <= 0.05 || lvl <= 0.0;
	// under the front of the rings (their plane as the painter has it)
	if (ring.y > 0.0) {
		vec3 RN = vec3(0.0, 0.96, -0.28);
		float s = dot(sv, RN) / 0.28;
		if (s > 0.0) {
			float rho = length(sv + vec3(0.0, 0.0, s));
			if (rho > ring.x && rho < ring.y) hidden = true;
		}
	}
	vec2 blk = floor(sv.xy * r / 2.0) * 2.0;
	// a 3 x 3 block quad round the light's block
	VERTEX = hidden ? vec2(-9999.0) : ctr + blk + vec2(1.0) + VERTEX * 6.0;
	v_s = cd.w * lvl * k;
}

void fragment() {
	ivec2 c = ivec2(floor(UV * 3.0));
	bool core = c == ivec2(1, 1);
	bool side = !core && (c.x == 1 || c.y == 1);
	float s = v_s;
	vec3 col = vec3(0.0);
	if (style == 1) {
		// PAINTED: flat tones off the glow ramp, a pixel artist's two
		if (core) col = s > 0.95 ? vec3(1.0, 0.847, 0.478) : (s > 0.45 ? vec3(1.0, 0.659, 0.235) : vec3(0.69, 0.227, 0.063));
		else if (side && s > 0.95) col = vec3(0.416, 0.11, 0.031);
	} else if (style == 3) {
		// LEGACY: pale points, three steps, nothing round them
		if (core) col = vec3(0.86, 0.8, 0.66) * (floor(min(s, 1.0) * 3.0 + 0.5) / 3.0);
	} else if (style == 2) {
		// RADIANT: through an exposure, a wider softer spill
		float x = core ? s * 1.3 : (side ? s * 0.2 : s * 0.05);
		col = (vec3(1.0) - exp(-x * vec3(1.0, 0.72, 0.42) * 1.8)) * 0.9;
		col = floor(col * 16.0 + 0.5) / 16.0;
	} else {
		// SIMPLIFIED: stepped light, a faint cross of glow
		float v = core ? (s < 0.45 ? 0.5 : (s < 0.8 ? 0.72 : (s < 1.4 ? 0.9 : 1.0))) : (side ? 0.12 * min(s, 1.6) : 0.0);
		col = vec3(1.0, 0.72, 0.34) * v;
		if (core && s >= 1.4) col = vec3(1.0, 0.93, 0.78);
	}
	COLOR = vec4(col, 1.0);
}
