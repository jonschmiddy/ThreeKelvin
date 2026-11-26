shader_type canvas_item;
render_mode unshaded;

// THE OLD HANGAR's DUST: one instance a mote, its track baked offline from the film (A5.py's snapped
// drift, glints and the dust a gust shakes off the tarps). A row a mote: 300 frame columns of
// (dx + 128, dy + 128, brightness) from its base, then the base (x lo, y lo, x hi | y hi << 2 | halo << 4).
// The brightness already holds how lit the air is where it floats; the lamp's level scales it, and it
// is screened onto what is under it in the sodium colour, as the film did.
// Why: docs/why/ShipRoomOld.md#dust

uniform sampler2D motes : filter_nearest, repeat_disable;
uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform int frame = 0;
uniform float level = 1.0;

const vec3 SOD = vec3(255.0, 208.0, 142.0) / 255.0;

varying vec2 lp;
varying float bright;
varying float halo;

void vertex() {
	int i = INSTANCE_ID;
	ivec3 b = ivec3(round(texelFetch(motes, ivec2(300, i), 0).rgb * 255.0));
	vec2 base = vec2(float(b.x + (b.z & 3) * 256), float(b.y + ((b.z >> 2) & 3) * 256));
	halo = float((b.z >> 4) & 1);
	vec3 m = round(texelFetch(motes, ivec2(frame, i), 0).rgb * 255.0);
	bright = m.z / 255.0;
	lp = VERTEX;
	VERTEX = base + m.xy - vec2(128.0) + VERTEX;
}

void fragment() {
	ivec2 q = ivec2(floor(lp));
	// a dot, or a near mote's dot with two dimmer pixels right and below
	float k = q == ivec2(0) ? 1.0 : (halo > 0.5 && q.x + q.y == 1 ? 0.35 : 0.0);
	vec3 c = bright * k * level * SOD;
	// unlit, a mote is not there: never paste the screen copy back over what was drawn since
	if (k * bright * level <= 0.0) {
		discard;
	}
	vec3 dst = texture(screen, SCREEN_UV).rgb;
	COLOR = vec4(1.0 - (1.0 - dst) * (1.0 - c), 1.0);
}
