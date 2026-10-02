shader_type canvas_item;
render_mode unshaded, blend_disabled;

// THE CORE'S LIGHT RAYS, traced once. Every pixel of the hole's 330 x 210
// picture is a ray fired from the eye, bent round the hole step by step (the
// mockup's `trace` in BH, `sysmap/page/index.html`, the same integrator, the
// same step sizes, the same 2000-step limit), and what it met is written out:
// whether it fell in, where it first landed on the disc (radius and angle),
// how many times it crossed the disc's plane before that, whether that
// landing is on the near half in front of the hole, and where in the sky
// behind its light came from. The mockup did this once per shape and cached
// it; so does `CoreView`, by drawing this once into a SubViewport and reading
// the picture back. Tracing per frame would be 2000 steps a pixel for a
// picture that never changes.
//
// The answers are packed into four bands of the W x 4H bake (330 x 840 at
// zoom 1), as 16-bit numbers split over two 8-bit channels, because the
// Compatibility renderer gives a 2D viewport 8 bits a channel:
//   rows   0 - H-1   radius (R, G) and the flags (B)
//   rows  H - 2H-1   angle
//   rows 2H - 3H-1   sky x
//   rows 3H - 4H-1   sky y
// ZOOMED (`kz`), the hole is traced again at kz times the size: the picture,
// the hole, the disc and the ranges the radii and sky are packed over all kz
// times bigger, the rays in the hole's own units the same.
// The GPU traces in 32-bit floats where the mockup used 64; rays that skim the
// photon sphere are chaotic, so a pixel or two at the ring's edge may land
// differently. Nothing else does.

uniform float tilt = 0.38;
uniform float rh = 15.0;
uniform float rin = 17.4;
uniform float rout = 110.0;
// the zoom, and the picture's size at it (330 x 210 at zoom 1)
uniform float kz = 1.0;
uniform vec2 size = vec2(330.0, 210.0);

// how far behind the hole the sky sits, as the mockup's L
const float SKY_L = 9.0;
// at zoom 1: how far out radii are packed, and the span the sky is packed over
const float R_MAX = 140.0;
const float SKY_SPAN = 2048.0;

vec3 pack16(float q01, float b) {
	float q = floor(clamp(q01, 0.0, 1.0) * 65535.0 + 0.5);
	float hi = floor(q / 256.0);
	return vec3(hi, q - hi * 256.0, b) / 255.0;
}

void fragment() {
	float W = size.x, H = size.y;
	vec2 pix = floor(UV * vec2(W, H * 4.0));
	float band = floor(pix.y / H);
	float x = pix.x, y = pix.y - band * H;
	float cx = W / 2.0, cy = H / 2.0;
	float u = x - cx, v = y - cy;
	float k = rh / 2.598, rinR = rin / k, routR = rout / k;
	float se = tilt, ce = sqrt(1.0 - tilt * tilt);
	float z0 = -(routR + 6.0), far = routR + 8.0;
	vec3 p = vec3(u / k, v / k, z0);
	vec3 vel = vec3(0.0, 0.0, 1.0);
	float h2 = p.x * p.x + p.y * p.y;
	float s0 = p.y * ce + p.z * se;
	int kind = 0;
	int ord = 0;
	bool hit = false;
	float hr = 0.0, ha = 0.0;
	int hord = 0;
	bool front = false;
	for (int n = 0; n < 2000; n++) {
		float r2 = dot(p, p), r = sqrt(r2);
		if (r < 1.0) { kind = 1; break; }
		float dt = min(0.8, max(0.015, 0.05 * (r - 1.0)));
		float acc = -1.5 * h2 / (r2 * r2 * r);
		vel += p * acc * dt;
		vec3 q = p;
		p += vel * dt;
		float s1 = p.y * ce + p.z * se;
		if ((s0 < 0.0) != (s1 < 0.0)) {
			float f = s0 / (s0 - s1);
			vec3 X = q + (p - q) * f;
			float Zc = X.y * se - X.z * ce, rr = length(vec2(X.x, Zc));
			// the first landing on the disc is what you see; the ray goes on
			// regardless, to learn what lies behind thin parts of the disc
			if (!hit && rr >= rinR * 0.55 && rr <= routR) {
				hit = true;
				hr = rr * k;
				ha = atan(Zc, X.x);
				hord = ord;
				front = ord == 0 && Zc > 0.0;
			}
			ord++;
		}
		s0 = s1;
		if (r > far && dot(p, vel) > 0.0) break;
	}
	int fl = (hit ? 2 : kind) + (hord > 0 ? 4 : 0) + (front ? 8 : 0) + (kind == 1 ? 0 : 16);
	// where its light came from: the outgoing line taken back to the hole's
	// own plane and carried on to a sky L behind it
	float sx = cx, sy = cy;
	if (kind != 1) {
		float vn = length(vel);
		if (vn == 0.0) vn = 1.0;
		float ou, ov, du, dv;
		if (vel.z > 0.25 * vn) { float bk = p.z / vel.z; ou = p.x - vel.x * bk; ov = p.y - vel.y * bk; du = vel.x / vel.z; dv = vel.y / vel.z; }
		else { ou = p.x; ov = p.y; du = vel.x / vn * 4.0; dv = vel.y / vn * 4.0; }
		sx = cx + ou * k + du * k * SKY_L;
		sy = cy + ov * k + dv * k * SKY_L;
	}
	vec3 c;
	// divided by the zoom-1 constant first, then by kz, so zoom 1 is as it was
	float off = SKY_SPAN * 0.5 * kz;
	if (band < 0.5) c = pack16(hr / R_MAX / kz, float(fl));
	else if (band < 1.5) c = pack16((ha + PI) / TAU, 0.0);
	else if (band < 2.5) c = pack16((sx + off) / SKY_SPAN / kz, 0.0);
	else c = pack16((sy + off) / SKY_SPAN / kz, 0.0);
	COLOR = vec4(c, 1.0);
}
