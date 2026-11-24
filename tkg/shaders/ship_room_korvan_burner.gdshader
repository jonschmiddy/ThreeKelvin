shader_type canvas_item;
render_mode unshaded, blend_add;

// Korvan's engine test port seen from the front (ideaB.burner): the fire's ragged rim, new ten times a
// second, stepped on the frame's grid, and the ring's heat glow. Drawn added over the room.

uniform float burn = 0.0;
uniform float heat = 0.0;
uniform float lobes[8];
uniform float lobe_k = 0.0;
uniform vec2 centre = vec2(882.0, 170.0);

varying vec2 fp;

void vertex() {
	fp = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float bay(ivec2 q) {
	float B[16] = float[](0., 8., 2., 10., 12., 4., 14., 6., 3., 11., 1., 9., 15., 7., 13., 5.);
	return B[(q.y & 3) * 4 + (q.x & 3)] / 16.0;
}

float step6(float f, ivec2 q) {
	float v = clamp(f, 0.0, 2.5) * 6.0;
	float lo = floor(v);
	float fr = v - lo;
	return (lo + ((fr > 0.75 && bay(q) < (fr - 0.75) * 4.0) ? 1.0 : 0.0)) / 6.0;
}

void fragment() {
	ivec2 q = ivec2(floor(fp));
	vec2 o = vec2(q) - centre;
	float d = length(o);
	float s = (atan(o.y, o.x) + PI) / (2.0 * PI) * 7.0;
	int i = clamp(int(floor(s)), 0, 6);
	float rag = mix(lobes[i], lobes[i + 1], s - float(i));
	float rad = 6.0 * rag * (0.55 + 0.45 * burn);
	float fire = pow(clamp(1.0 - d / max(rad, 0.5), 0.0, 1.0), 0.8) * burn;
	fire = step6(fire * (0.85 + 0.15 * lobe_k) * 1.6, q);
	vec3 add = fire * vec3(255.0, 150.0, 60.0) + clamp(fire - 0.5, 0.0, 1.0) * vec3(255.0, 255.0, 230.0);
	float ring = (d > 5.5 && d < 8.5) ? heat * 0.7 : 0.0;
	add += step6(ring, q) * vec3(200.0, 60.0, 20.0);
	COLOR = vec4(add / 255.0, 1.0);
}
