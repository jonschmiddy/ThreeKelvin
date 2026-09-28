// THE SHOP'S LIGHT, per pixel: the room bench's `applyLight`, on the GPU.
//
// `tools/room_install.py` works the light out once per room and stores it in
// pieces (its docstring has the list); this puts them back together for the
// backdrop behind the wall today and for whatever a failing lamp is doing this
// frame, then says what the bench would do to the pixel under it.
//
// TWO PASSES, NOT A SCREEN READ. The bench scales a pixel's colour by m and adds
// a little overbright on top. A multiply-blended rect does the first and an
// add-blended one the second, so neither needs the screen copied -- a copy the
// pause menu's own screen shader would otherwise have read stale.

// Four stacked bands of RGBA8: the high and low bytes of (S.r, S.g, S.b, O),
// then of (F, U, B, X), each 16-bit over its range in `scales1`/`scales2`.
uniform sampler2D light_map : filter_nearest, repeat_disable;
uniform vec2 room_size = vec2(740.0, 431.0);
uniform int band_h = 216;
uniform vec4 scales1 = vec4(8.0, 8.0, 8.0, 8.0);
uniform vec4 scales2 = vec4(8.0, 32.0, 1.0, 1.0);
// The backdrop's colour, which is what an opening glows.
uniform vec3 tone = vec3(0.72, 0.80, 1.0);
// The failing lamp this frame: its light as f times its (fault-tinted) colour,
// and f alone for how far its shadow reaches. Zero when there is none.
uniform vec3 flick_col = vec3(0.0);
uniform float flick_f = 0.0;
uniform float amb = 0.30;
uniform float shadowk = 0.55;
uniform bool dither = false;
uniform vec3 amb_col = vec3(0.70, 0.78, 1.00);
uniform float levels = 6.0;
uniform float soft = 1.5;
// Screen pixels per light-map cell.
uniform int gk = 2;
// THE EXCHANGE'S VIEW, PIXEL FOR PIXEL: 1 wherever its space shows through the
// room, one channel per hold size (s, m, l) because the frame that hangs in
// front of it is the hull's, and `view_k` picks the channel; -1 is a room
// without one, which hands its windows over softly (`b.w`). See
// `room_install.view_masks`. Space is not handed over at all: a softened band
// of lamplight is glass catching the light on a lit concourse and a flat grey
// ring on black space -- round the door's edges and round everything standing
// in front of it (Jon, 2026-09-27: "why is there a weird outline ?").
uniform sampler2D view_mask : filter_nearest, repeat_disable;
uniform int view_k = -1;

const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

vec4 band_at(ivec2 g, int k) {
	return texelFetch(light_map, ivec2(g.x, g.y + k * band_h), 0);
}

vec4 unpack16(vec4 hi, vec4 lo, vec4 sc) {
	return (floor(hi * 255.0 + 0.5) * 256.0 + floor(lo * 255.0 + 0.5)) / 65535.0 * sc;
}

// What the bench does to the pixel at `uv` on the room: scale by `m`, then add
// `add` (already out of 255).
void shop_light(vec2 uv, out vec3 m, out vec3 add) {
	ivec2 p = ivec2(floor(uv * room_size));
	ivec2 g = p / gk;
	vec4 a = unpack16(band_at(g, 0), band_at(g, 1), scales1);
	vec4 b = unpack16(band_at(g, 2), band_at(g, 3), scales2);
	m = vec3(1.0);
	add = vec3(0.0);
	float ex = b.w;
	if (view_k >= 0) {
		vec4 v = texelFetch(view_mask, p, 0);
		ex = (view_k == 0 ? v.r : (view_k == 1 ? v.g : v.b)) > 0.5 ? 1.0 : 0.0;
	}
	// Seen through the wall: not this room's to light.
	if (ex >= 0.995) {
		return;
	}
	vec3 l3 = a.rgb + tone * a.a + flick_col * b.x;
	// INTENSITY IS THE BRIGHTEST CHANNEL; the ratios are the light's colour.
	float l = max(l3.r, max(l3.g, l3.b));
	float t = 0.0;
	float over = 0.0;
	vec3 tr = vec3(1.0);
	float stp = 1.0 / levels;
	if (l > 0.0) {
		if (l < soft * stp) {
			t = l;
		} else {
			float dd = 0.0;
			if (dither) {
				int i = ((g.y & 3) << 2) | (g.x & 3);
				dd = (BAYER[i] / 16.0 - 0.5) * stp;
			}
			// Math.round: halves go up.
			float q = floor((l + dd) / stp + 0.5) * stp;
			q = max(q, 0.0);
			t = min(q, 1.0);
			over = q > 1.0 ? q - 1.0 : 0.0;
		}
		tr = l3 / l;
	}
	m = amb * amb_col * (1.0 - t) + (vec3(1.0) - 0.45 * (vec3(1.0) - tr)) * t;
	float bl = b.z;
	if (flick_f > 0.003) {
		bl = max(bl, min(1.0, flick_f * b.y));
	}
	if (bl > 0.0) {
		m *= 1.0 - bl * shadowk * 0.78;
	}
	if (ex > 0.0) {
		m = m * (1.0 - ex) + ex;
	}
	float blv = over > 0.0 ? 255.0 * min(over, 0.35) * 0.30 : 0.0;
	add = blv * tr / 255.0;
}
