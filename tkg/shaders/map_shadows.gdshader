shader_type canvas_item;
render_mode unshaded, blend_mul;

// EACH WORLD'S SHADOW, thrown out across the plane away from the star (Light
// B, "shafts and shadows ... not so intense"): a strip as wide as the world,
// widening and fading over 170 px, multiplied into what is under it. The
// plane is seen at a slant (`tilt`), so a screen pixel is turned back into a
// point on the plane first. A pulsar throws none.

uniform vec4 bodies[12];   // x, z on the plane; radius; unused
uniform int n_bodies = 0;
uniform vec2 star_at = vec2(622.0, 262.0);
uniform float tilt = 0.38;
uniform float x0 = 264.0;
// the map's zoom: a world's plane position goes out from the star this many
// times further, and its shadow is that much longer (its width comes in zoomed)
uniform float zoom = 1.0;
// pixels of the map to a pixel of the screen it is drawn on (2 in the half-size place)
uniform float px_scale = 1.0;

void fragment() {
	vec2 px = (floor(SCREEN_UV / SCREEN_PIXEL_SIZE) + 0.5) * px_scale;
	float k = 1.0;
	if (px.x >= x0) {
		// ON THE SCREEN, NOT THE PLANE (Jon: "shadow doesn't match up"). The
		// shadow behind a ball is a tube, and a tube looks as wide as the ball
		// from any side; worked out flat on the slanted plane it was squashed to
		// a third of the world's height whenever it ran across the view.
		for (int i = 0; i < n_bodies; i++) {
			vec4 b = bodies[i];
			vec2 at = star_at + vec2(b.x, b.y * tilt) * zoom;
			vec2 u = normalize(at - star_at + vec2(1e-4));
			vec2 dlt = px + 0.5 - at;
			float s = dot(dlt, u), w = abs(-dlt.x * u.y + dlt.y * u.x);
			float len = 170.0 * zoom, wd = b.z;
			if (s <= 0.0 || s >= len) continue;
			float ww = wd * (1.0 + s / len * 0.5);
			if (w > ww) continue;
			k *= 1.0 - 0.4 * (1.0 - s / len) * min(1.0, (ww - w) / 2.5);
		}
	}
	// SMOOTH, AND AFTER THE PALETTE PASS (Jon: "the shadow abruptly ends", then
	// of a dither: "why is there holes"). Before the pass, the fade was snapped
	// from one palette colour to the next in one hard step; after it, nothing
	// rounds it, so it darkens solid by the world and fades evenly away.
	COLOR = vec4(vec3(k), 1.0);
}
