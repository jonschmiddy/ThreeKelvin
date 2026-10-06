shader_type canvas_item;
render_mode unshaded;

// THE YARD'S LIGHT, per pixel: the Yard Drones page's `shadeRange`, on the GPU.
// `tools/yard_install.py` worked out every lamp that holds still (summed, in
// `light_map`) and every lamp that can go out or stutter (alone, in `vary_map`);
// the floor lamps, whose pools carry the ships' shadows, are baked by
// `yard_bay.gdshader` when the ships are stood (`bay_map`). What moves is only
// how hard each light burns and which small lights are lit this tick, which
// `YardScene` hands over on its 30 Hz clock.
//
// FOUR WAYS TO BE LIT, one `mode` per material:
//   0  IN PLACE: the hall as painted, and anything drawn into it where it
//      stands (a tenant at a window, a lift car, a floor hatch). Takes the
//      light at its own pixel; a pixel that burns on its own burns at its
//      light's beat; a ceiling lamp that is out takes its painted cone with
//      it; the floor's polish gives back what burns low on the wall.
//   1  STANDING ON THE FLOOR: a walker, the forklift, a crate. The page wrote
//      each one into the frame and shaded it with the light at its feet
//      (`cell`, one per picture) -- and with any small light at each of its own
//      pixels, so the welder's arc lights his arms and not his boots.
//   2  A SHIP: the floor lamps' light along the ships' row with nothing in the
//      way (`lship_map`), falling into the hull's own shade toward its belly
//      (`ship_map`'s blue), and any small light near it.
//   3  A REFLECTION in the floor's polish: the picture's colour and fade come
//      in with the draw; it takes the light where it lies, and only on floor.
//
// Everything is in the hall's pixels: `origin` is the hall's top-left in the
// canvas, so a fragment knows where in the hall it is whatever node draws it.

uniform int mode = 0;
uniform vec2 origin = vec2(0.0);
// how many canvas pixels a hall pixel is drawn at (the cutaway zooms the yard)
uniform float zoom = 1.0;
// mode 1: the hall pixel whose light a picture standing on the floor takes
instance uniform vec2 cell = vec2(0.0);
// light_map: 766 x 964, (R, G, B, how much) high bytes above, low below
uniform sampler2D light_map : filter_nearest, repeat_disable;
// vary_map: the lamps that can go out, two to a band, bands two across
uniform sampler2D vary_map : filter_nearest, repeat_disable;
// own_map: R = the light a pixel burns with (index + 1), 255 always burns
uniform sampler2D own_map : filter_nearest, repeat_disable;
// off_map: (lamp + 1, k) twice: whose painted cone a pixel is
uniform sampler2D off_map : filter_nearest, repeat_disable;
// bay_map: the floor lamps, on the page's half grid (384 x 242), 16-bit in RG
uniform sampler2D bay_map : filter_nearest, repeat_disable;
// ship_map: R hull, G stand (the ships' masks), B the hull's shade toward its belly
uniform sampler2D ship_map : filter_nearest, repeat_disable;
// lship_map: 766 x 1, the floor lamps along the ships' row, 16-bit in RG
uniform sampler2D lship_map : filter_nearest, repeat_disable;
uniform float scale = 4.0;
uniform float vscale = 2.0;
uniform float bscale = 2.0;
uniform float lscale = 2.0;
uniform bool bay_on = false;
uniform int nvary = 0;
uniform vec4 vbox[12];
// the lamp's colour, and (weight - 1) x power: what it adds to or takes off the sum
uniform vec4 vcol[12];
// each light's beat, four to a vector: the lights by index
uniform vec4 ew[16];
// each ceiling lamp's weight, four to a vector
uniform vec4 lampw[4];
uniform int ndyn = 0;
uniform vec4 dpos[12];
// colour, then the breathing
uniform vec4 dcol[12];
uniform vec4 dk[3];
uniform float amb = 0.1;
uniform vec3 ambc = vec3(0.7, 0.8, 1.0);
uniform vec3 mainc = vec3(0.82, 0.9, 1.0);
uniform int wallrow = 207;
uniform int polish = 212;
uniform bool refl = true;
uniform float reflk = 0.4;
// Unlit, as painted: the harness's view of the picture Jon passed.
uniform bool fullbright = false;

varying vec2 sp;
varying vec4 vc;

void vertex() {
	sp = ((MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy - origin) / zoom;
	vc = COLOR;
}

float u16(vec2 hl, float s) {
	return (floor(hl.x * 255.0 + 0.5) * 256.0 + floor(hl.y * 255.0 + 0.5)) / 65535.0 * s;
}

float ew_at(int i) {
	vec4 v = ew[i / 4];
	int k = i % 4;
	return k == 0 ? v.x : (k == 1 ? v.y : (k == 2 ? v.z : v.w));
}

float lamp_at(int i) {
	vec4 v = lampw[i / 4];
	int k = i % 4;
	return k == 0 ? v.x : (k == 1 ? v.y : (k == 2 ? v.z : v.w));
}

float dk_at(int i) {
	vec4 v = dk[i / 4];
	int k = i % 4;
	return k == 0 ? v.x : (k == 1 ? v.y : (k == 2 ? v.z : v.w));
}

int own_at(ivec2 p) {
	return int(floor(texelFetch(own_map, p, 0).r * 255.0 + 0.5));
}

// The floor lamps at a pixel: the page's half grid, eased up to the picture.
float bay_at(ivec2 p) {
	if (!bay_on || p.y < wallrow) {
		return 0.0;
	}
	float fx = float(p.x) * 0.5;
	float fy = float(p.y) * 0.5;
	int cx = min(382, int(floor(fx)));
	int cy = min(240, int(floor(fy)));
	float tx = fx - float(cx);
	float ty = fy - float(cy);
	float a = u16(texelFetch(bay_map, ivec2(cx, cy), 0).rg, bscale);
	float b = u16(texelFetch(bay_map, ivec2(cx + 1, cy), 0).rg, bscale);
	float c = u16(texelFetch(bay_map, ivec2(cx, cy + 1), 0).rg, bscale);
	float d = u16(texelFetch(bay_map, ivec2(cx + 1, cy + 1), 0).rg, bscale);
	return (a * (1.0 - tx) + b * tx) * (1.0 - ty) + (c * (1.0 - tx) + d * tx) * ty;
}

// Every lamp's light at a pixel: (R, G, B, how much).
vec4 sa_at(ivec2 p) {
	vec4 hi = texelFetch(light_map, p, 0);
	vec4 lo = texelFetch(light_map, p + ivec2(0, 482), 0);
	vec4 v = (floor(hi * 255.0 + 0.5) * 256.0 + floor(lo * 255.0 + 0.5)) / 65535.0 * scale;
	for (int i = 0; i < 12; i++) {
		if (i >= nvary) {
			break;
		}
		float k = vcol[i].a;
		if (k == 0.0) {
			continue;
		}
		vec4 b = vbox[i];
		if (float(p.x) < b.x || float(p.y) < b.y || float(p.x) >= b.x + b.z || float(p.y) >= b.y + b.w) {
			continue;
		}
		int band = i / 2;
		vec4 t = texelFetch(vary_map, p + ivec2((band % 2) * 766, (band / 2) * 482), 0);
		float f = u16((i % 2 == 0) ? t.rg : t.ba, vscale);
		v += vec4(vcol[i].rgb * (f * k), f * k);
	}
	float by = bay_at(p);
	v += vec4(mainc * by, by);
	return v;
}

// The page's shading: the brightest channel is how much light, stepped in
// sixths above the first one and a half; the ratios are its colour; past full
// it overexposes a little. `dyn` is this tick's small lights: (R, G, B) and
// their weight twice, steady and breathing.
vec3 shade(vec3 base, vec3 rgb, float s, vec3 drgb, vec2 dw, bool dq) {
	vec3 A = amb * ambc;
	float s0 = s;
	float s1 = s;
	if (dq) {
		rgb += drgb;
		s0 += dw.x;
		s1 += dw.y;
	}
	float l = max(rgb.r, max(rgb.g, rgb.b));
	if (l <= 0.001) {
		return base * A;
	}
	float tq;
	float ov = 0.0;
	if (l < 0.25) {
		tq = l;
	} else {
		float q = floor(l * 6.0 + 0.5) / 6.0;
		tq = q < 1.0 ? q : 1.0;
		if (q > 1.0) {
			ov = min(q - 1.0, 0.35);
		}
	}
	if (s0 > 0.0 && s1 != s0) {
		float bm = s1 / s0;
		tq = min(tq * bm, 1.0);
		ov *= bm;
	}
	vec3 m = A * (1.0 - tq) + (vec3(1.0) - 0.45 * (vec3(1.0) - rgb / l)) * tq;
	return (base + ov * 0.3) * m;
}

// This tick's small lights at a pixel.
void dyn_at(ivec2 p, out vec3 rgb, out vec2 w, out bool dq) {
	rgb = vec3(0.0);
	w = vec2(0.0);
	dq = false;
	for (int i = 0; i < 12; i++) {
		if (i >= ndyn) {
			break;
		}
		vec4 g = dpos[i];
		vec2 d = (vec2(p) - g.xy) / g.zw;
		float dd = dot(d, d);
		if (dd >= 1.0) {
			continue;
		}
		float v = dk_at(i) * pow(1.0 - dd, 1.6);
		rgb += v * dcol[i].rgb;
		w += vec2(v, v * dcol[i].a);
		dq = true;
	}
}

// A painted cone under a ceiling lamp that is not fully on (the page's `dimLamp`).
float lamp_off(float w, float k) {
	if (w == 1.0) {
		return 1.0;
	}
	return w > 1.0 ? 1.0 + 0.12 * (1.0 - k) : 1.0 - (1.0 - k) * (1.0 - w);
}

void fragment() {
	// A picture's pixel is there or it is not (the page skips alpha under 128);
	// a reflection's fade comes in with the draw.
	vec4 t = texture(TEXTURE, UV);
	if (t.a < 0.5) {
		discard;
	}
	ivec2 p = ivec2(floor(sp));
	if (mode == 3 && (p.y < polish || vc.a < 0.002)) {
		discard;
	}
	vec3 base = t.rgb * vc.rgb;
	if (fullbright || p.x < 0 || p.y < 0 || p.x > 765 || p.y > 481) {
		COLOR = vec4(base, mode == 3 ? vc.a : 1.0);
	} else {
		vec3 drgb;
		vec2 dw;
		bool dq;
		dyn_at(p, drgb, dw, dq);
		if (mode == 2) {
			// A SHIP takes the light over it, falling into its own shade.
			vec4 sm = texelFetch(ship_map, p, 0);
			float belly = sm.b > 0.0 ? sm.b : 1.0;
			float v = u16(texelFetch(lship_map, ivec2(p.x, 0), 0).rg, lscale) * belly;
			COLOR = vec4(shade(base, mainc * v, v, drgb, dw, dq), 1.0);
		} else if (mode == 1) {
			vec4 l = sa_at(ivec2(cell));
			COLOR = vec4(shade(base, l.rgb, l.a, drgb, dw, dq), 1.0);
		} else if (mode == 3) {
			vec4 l = sa_at(p);
			COLOR = vec4(shade(base, l.rgb, l.a, drgb, dw, dq), vc.a);
		} else {
			int own = own_at(p);
			if (own > 0) {
				// IT BURNS, at its light's beat; the lens of a plinth lamp always does.
				float w = own == 255 ? 1.0 : ew_at(own - 1);
				COLOR = vec4(base * (amb + (1.0 - amb) * w), 1.0);
			} else {
				vec4 o = texelFetch(off_map, p, 0);
				int l1 = int(floor(o.r * 255.0 + 0.5));
				if (l1 > 0) {
					base = min(vec3(1.0), base * lamp_off(lamp_at(l1 - 1), o.g));
					int l2 = int(floor(o.b * 255.0 + 0.5));
					if (l2 > 0) {
						base = min(vec3(1.0), base * lamp_off(lamp_at(l2 - 1), o.a));
					}
				}
				vec4 l = sa_at(p);
				vec3 lit = shade(base, l.rgb, l.a, drgb, dw, dq);
				// THE POLISH GIVES BACK what burns low on the wall: a mirror of the
				// burning pixels, brighter the nearer the wall, only ever lighter.
				if (refl && p.y >= wallrow && p.y < wallrow + 46) {
					ivec2 q = ivec2(p.x, 2 * wallrow - 1 - p.y);
					int oq = own_at(q);
					if (oq > 0 && oq != 255 && texelFetch(ship_map, q, 0).r + texelFetch(ship_map, q, 0).g == 0.0) {
						float wq = ew_at(oq - 1);
						vec3 src = min(vec3(1.0), texelFetch(TEXTURE, q, 0).rgb * (amb + (1.0 - amb) * wq));
						float a = reflk * (1.0 - float(p.y - wallrow) / 46.0);
						lit = min(vec3(1.0), lit) + max(src - min(vec3(1.0), lit), vec3(0.0)) * a;
					}
				}
				COLOR = vec4(lit, 1.0);
			}
		}
	}
}
