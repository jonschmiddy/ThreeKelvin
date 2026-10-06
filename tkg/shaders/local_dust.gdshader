shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;

// LOCAL'S FOREGROUND DUST (`LocalDust`), drawn per game pixel: finer and softer
// than the far sky, never a square. Each mote is gathered light -- a small
// bright core and a 1 px falloff in an ordered dither -- or, a few of them, a
// very faint out-of-focus disc with a dithered rim; the wisps are 1 px strands,
// half there. Every pattern is anchored to its own mote, so a mote that moves a
// pixel moves whole, the same pixels lit; and a mote's visibility (`vis`, eased
// on the CPU) thins or fills its pattern a step at a time, never on or off.
// Nothing is drawn inside a ship's picture, a label or a gauge (`keep`).
// LIGHT, NOT PAINT: a mote adds its light to what is behind it (`glow`,
// premultiplied with no cover), so it reads as gathered light over dark sky and
// bright gas alike, faint and never a dark blot. Each ring adds one fixed step,
// so over PAINTED's flat tones a mote is flat tones too; PAINTED also holds a
// brighter highlight at its middle pixel. (Solid painted motes read as dark
// dirt over the bright gas.)

const int N = 96;
const int K = 40;
// per mote: x, y (this control's px, whole), radius (px), kind (0 mote, 1 disc,
// 2 wisp); and its visibility 0..1, a seed, the wisp's length, its lit side
uniform vec4 motes[N];
uniform vec4 extra[N];
uniform int n_motes = 0;
uniform vec4 keep[K];
uniform int n_keep = 0;
uniform bool painted = false;
// the light a mote adds (linear-ish, added): at its core, its first ring, the rest
uniform vec3 glow = vec3(0.3, 0.27, 0.24);
uniform vec3 glow_k = vec3(0.34, 0.17, 0.08);
uniform vec2 view_size = vec2(944.0, 491.0);

float bayer4(ivec2 b) {
	const float B[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	ivec2 q = b & ivec2(3);
	return (B[q.y * 4 + q.x] + 0.5) / 16.0;
}

void fragment() {
	vec2 p = floor(UV * view_size) + 0.5;
	for (int k = 0; k < K; k++) {
		if (k >= n_keep) {
			break;
		}
		vec4 r = keep[k];
		if (p.x >= r.x && p.y >= r.y && p.x < r.x + r.z && p.y < r.y + r.w) {
			discard;
		}
	}
	float lift = 0.0;
	bool hit = false;
	for (int i = 0; i < N; i++) {
		if (i >= n_motes || hit) {
			break;
		}
		vec4 m = motes[i];
		vec4 e = extra[i];
		float vis = e.x;
		if (vis <= 0.0) {
			continue;
		}
		vec2 c = m.xy + 0.5;
		vec2 d = p - c;
		ivec2 rel = ivec2(floor(d)) + ivec2(int(e.y * 4.0), int(e.y * 16.0));
		float th = bayer4(rel);
		int kind = int(m.w + 0.5);
		if (kind == 2) {
			// a wisp: a 1 px strand along a slow wave, half there, tapering
			float L = e.z;
			if (abs(d.x) > L * 0.5 || abs(d.y) > 6.0) {
				continue;
			}
			float yl = round(sin(d.x * 0.06 + e.y * 6.28) * 3.0);
			float tap = 1.0 - abs(d.x) / (L * 0.5);
			if (abs(floor(d.y) - yl) < 0.5 && th < 0.5 * vis * tap) {
				lift = glow_k.z;
				hit = true;
			}
			continue;
		}
		float R = m.z;
		float dist = length(d);
		if (dist > R + 0.75) {
			continue;
		}
		if (kind == 1) {
			// an out-of-focus disc: a very faint fill and a dithered rim
			float rim = 1.0 - smoothstep(0.0, 1.0, abs(dist - R));
			float dens = (0.16 + 0.3 * rim) * vis;
			if (th < dens) {
				lift = glow_k.z * (0.6 + 0.6 * rim);
				hit = true;
			}
			continue;
		}
		// a mote: its core, and its light falling off a pixel at a time
		float core = R < 2.0 ? 0.75 : 1.25;
		float dens = dist <= core ? 1.0 : pow(clamp(1.0 - (dist - core) / max(R - core, 0.5), 0.0, 1.0), 1.4) * 0.85;
		if (th < dens * vis) {
			bool lit = dot(d, vec2(e.w, -0.5)) > 0.0;
			lift = dist <= core ? glow_k.x : (dist <= core + 1.0 ? glow_k.y * (lit ? 1.2 : 0.8) : glow_k.z);
			// (PAINTED: the mote's middle pixel a held highlight, one flat step
			// brighter: it is the same pixel of the mote wherever the mote is)
			if (painted && dist < 0.25) {
				lift = glow_k.x * 1.6;
			}
			hit = true;
		}
	}
	if (!hit) {
		discard;
	}
	COLOR = vec4(glow * lift, 0.0);
}
