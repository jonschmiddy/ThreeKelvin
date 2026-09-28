shader_type canvas_item;
render_mode unshaded;

// THE LABORATORY'S BIG SCREEN, over the recipe rows: Five Labs, Lit's
// `SCREEN_FX`. `LabScene._Glass` works out what the screen is doing this tick
// -- which bands have slipped, whether the picture has jolted or sagged, where
// the snow and the scan and the rim light are -- and this draws it over a copy
// of the glass, rows and all, taken by the `BackBufferCopy` just behind it.
//
// Every mark is on the picture's 2x2 grid. Everything is in the glass's own
// pixels, (0, 0) its top-left.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform vec2 gsize = vec2(1.0);
// The glass's left edge in room pixels: the snow is patterned by room column,
// so a band of it does not slide when the glass is somewhere else.
uniform float gx0 = 0.0;

// BAD SIGNAL. A band is (top, height, how far it slipped, where it came from).
// The slips are drawn from the glass as it was before the jolt, as the
// prototype draws them from its snapshot.
uniform vec4 bands[4];
uniform int nbands = 0;
// The whole picture dropped this many pixels (the top rows stay).
uniform float jolt = 0.0;
// THE SAG: the glass times this, and a flash added coming back.
uniform float sag = 1.0;
uniform vec3 flash = vec3(0.0);
// Lines of snow: (top, pattern seed).
uniform vec2 snow[3];
uniform int nsnow = 0;
uniform vec3 snow_col = vec3(0.0);
// THE SCAN: (top, left, right, strength); the power-on's reveal, or the sweep.
uniform vec4 scan = vec4(-100.0, 0.0, 0.0, 0.0);
// THE RIM LIGHT: cells (x, y, strength).
uniform vec3 rim[16];
uniform int nrim = 0;
uniform vec3 rim_col = vec3(0.0);

// The prototype's `hash`. On the GPU its large arguments lose precision, which
// changes which cells snow and not how much.
float hash(float v) {
	return fract(sin(v * 127.1) * 43758.5453);
}

void fragment() {
	vec2 p = floor(UV * gsize);
	vec2 src = p;
	if (jolt > 0.0 && p.y >= jolt) {
		src.y = p.y - jolt;
	}
	for (int i = 0; i < 4; i++) {
		if (i >= nbands) {
			break;
		}
		vec4 b = bands[i];
		if (p.y >= b.x && p.y < b.x + b.y) {
			// The band lands `b.z` along; what it uncovers keeps what was there.
			bool covered = b.z > 0.0 ? p.x >= b.z : (b.z < 0.0 ? p.x < gsize.x + b.z : true);
			if (covered) {
				src = vec2(p.x - b.z, b.w + (p.y - b.x));
			}
		}
	}
	vec3 c = texture(screen_tex, SCREEN_UV + (src - p) * SCREEN_PIXEL_SIZE).rgb;
	c = c * sag + flash;
	for (int i = 0; i < 3; i++) {
		if (i >= nsnow) {
			break;
		}
		if (p.y >= snow[i].x && p.y < snow[i].x + 2.0) {
			float rx = gx0 + floor(p.x / 2.0) * 2.0;
			if (hash(rx * 0.131 + snow[i].y) > 0.62) {
				c += snow_col;
			}
		}
	}
	if (p.y >= scan.x && p.y < scan.x + 2.0 && p.x >= scan.y && p.x < scan.z) {
		c += vec3(12.0, 36.0, 40.0) / 255.0 * scan.w;
	}
	for (int i = 0; i < 16; i++) {
		if (i >= nrim) {
			break;
		}
		if (p.x >= rim[i].x && p.x < rim[i].x + 2.0 && p.y >= rim[i].y && p.y < rim[i].y + 2.0) {
			c += rim_col * rim[i].z;
		}
	}
	COLOR = vec4(min(c, vec3(1.0)), 1.0);
}
