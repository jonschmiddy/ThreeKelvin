shader_type canvas_item;
render_mode unshaded;

// Korvan's sparks on the GPU: every film frame's sparks were baked from the film's own throws (export.py fx,
// sparks.png: a column per spark, a row per frame). Spark i is two 1 px rects drawn once at x 4i (its head)
// and 4i + 2 (its tail a step behind), moved here to where the film had them. Why: docs/why/ShipRoomKorvan.md#cost

uniform sampler2D sparks : filter_nearest, repeat_disable;
uniform int frame = 0;
uniform int set_off = 0;
uniform vec3 palette[10];
uniform float tail_a = 0.6;

varying vec4 col;

void vertex() {
	int i = int(floor(VERTEX.x / 4.0));
	int part = int(floor(VERTEX.x / 2.0)) % 2;
	vec2 corner = VERTEX - vec2(float(4 * i + 2 * part), 0.0);
	ivec4 b = ivec4(round(texelFetch(sparks, ivec2(set_off + i, frame), 0) * 255.0));
	bool valid = b.a >= 128;
	bool tail = (b.a & 64) != 0;
	int x = b.r | ((b.g & 3) << 8);
	int y = (b.g >> 2) | ((b.b & 15) << 6);
	int c = (b.b >> 4) & 15;
	vec2 pos = vec2(float(x), float(y));
	if (part == 1) {
		pos += vec2(float(((b.a >> 3) & 7) - 2), float((b.a & 7) - 2));
	}
	if (!valid || (part == 1 && !tail)) {
		pos = vec2(-100.0);
	}
	VERTEX = pos + corner;
	col = vec4(palette[clamp(c, 0, 9)], part == 1 ? tail_a : 1.0);
}

void fragment() {
	COLOR = col;
}
