shader_type canvas_item;
render_mode unshaded, blend_mul;

// EACH WORLD'S SHADOW, thrown out across the space behind it, away from the
// star, and multiplied into what is there -- the gas and the stars -- so it dims
// them rather than laying a grey plate over them (Jon: "The shadows on the
// planet seem really flat and weird? They also don't perfectly line up when
// zoomed all the way out").
//
// A CONE, NOT A STRIP: as wide as the world's drawn disc where it leaves it, the
// dark core (umbra) narrowing to a point a few radii out while the soft edge
// (penumbra) spreads, and the whole of it fading away over a length set by the
// world's size: the core about seven radii, the tail gone by about eighteen. Worked out on the screen from where the world is DRAWN and how
// big (`bodies`: its centre as the view places its picture, its held radius),
// so it starts at the disc at every zoom.
//
// IN STEPS, per 2x2 block of the place, like the palette's: the darkness is
// rounded to a few levels, so its edges step as pixel art does instead of
// running as one hard straight line -- and it stays after the palette pass, so
// no dither punches holes in it.

// x, y on the screen as drawn; its radius as drawn (the disc, held to a least
// size); its true radius at this zoom (what the shadow's length goes by)
uniform vec4 bodies[12];
uniform int n_bodies = 0;
uniform vec2 star_at = vec2(622.0, 262.0);
uniform float x0 = 264.0;
// pixels of the map to a pixel of the screen it is drawn on (2 in the half-size place)
uniform float px_scale = 1.0;
// how dark the core is, and how many steps the darkness comes in
uniform float strength = 0.5;
uniform float steps = 5.0;

void fragment() {
	vec2 px = (floor(SCREEN_UV / SCREEN_PIXEL_SIZE) + 0.5) * px_scale;
	float k = 1.0;
	if (px.x >= x0) {
		for (int i = 0; i < n_bodies; i++) {
			vec4 b = bodies[i];
			vec2 at = b.xy;
			float r = max(b.z, 1.0);
			vec2 away = at - star_at;
			if (length(away) < 0.5) continue;
			vec2 u = normalize(away);
			vec2 dlt = px - at;
			float s = dot(dlt, u);
			if (s <= 0.0) continue;
			float w = abs(-dlt.x * u.y + dlt.y * u.x);
			// the umbra comes to a point LU out; the penumbra spreads; the whole
			// shadow is gone by LEN (both by the world's own size). Long (Jon:
			// "the shadows are good, but couldn't they be longer?"): the core
			// runs about seven radii, the soft tail fades out by about eighteen
			// (by the world's true size at this zoom, so zooming only scales it:
			// the drawn disc is held to a least size and would make it jump)
			float rt = max(b.w, 0.5);
			float LU = rt * 7.0;
			float LEN = max(rt * 18.0, r * 1.5);
			if (s >= LEN) continue;
			float hu = r * max(0.0, 1.0 - s / LU);
			float hp = r * (1.0 + 0.35 * s / LU);
			if (w >= hp) continue;
			// full in the umbra, falling off softly across the penumbra
			float across = w <= hu ? 1.0 : 0.6 * (1.0 - smoothstep(hu, hp, w));
			// full as far as the disc's edge, then fading with distance
			float along = s <= r ? 1.0 : pow(clamp(1.0 - (s - r) / (LEN - r), 0.0, 1.0), 1.25);
			float dark = strength * across * along;
			// in the palette's steps
			dark = floor(dark * steps + 0.5) / steps;
			k *= 1.0 - dark;
		}
	}
	COLOR = vec4(vec3(k), 1.0);
}
