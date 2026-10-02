shader_type canvas_item;
render_mode unshaded, blend_mix;

// THE FABRIC OF SPACE ON THE GPU. The grid is a mesh of short lines laid out
// once on the plane (`SystemView._Fabric`); each frame this sinks every point
// into the star's well and each body's (the same sum as `SystemLayout.sink`),
// turns it to the screen at the camera's zoom and pan, and fades it, so moving
// the camera costs the CPU nothing (Jon: "why is the frame rate SOOO BAD when
// zooming in?" -- it was this grid, rebuilt in GDScript every frame).
// The star's disc and each world's are left clear.

uniform vec2 origin = vec2(480.0, 270.0);
uniform float zoom = 1.0;
uniform float tilt = 0.38;
uniform float edge = 350.0;
uniform float star_d = 36.8;
uniform float star_w = 68.4;
// each body's well: x, z on the plane, depth, width
uniform vec4 wells[16];
uniform int n_wells = 0;
// the star's clear ellipse on screen, half-widths
uniform vec2 hole = vec2(18.0);
// each world's clear disc on screen: x, y, radius
uniform vec3 worlds[16];
uniform int n_worlds = 0;

varying vec2 sp;

void vertex() {
	float x = VERTEX.x, z = VERTEX.y;
	float r2 = x * x + z * z;
	float d0 = star_d * star_w * star_w / (r2 + star_w * star_w);
	for (int i = 0; i < n_wells; i++) {
		vec4 w = wells[i];
		float dx = x - w.x, dz = z - w.y;
		d0 += w.z * w.w * w.w / (dx * dx + dz * dz + w.w * w.w);
	}
	float d = 45.0 * tanh(d0 / 45.0);
	vec2 s = origin + vec2(x, z * tilt + d * 2.2) * zoom;
	float fade = max(0.0, 1.0 - pow(sqrt(r2) / edge, 2.0));
	float far = 0.6 + 0.4 * (z + edge) / (2.0 * edge);
	float deep = min(1.0, d / 40.0);
	COLOR = vec4(0.62, 0.64, 0.68, (0.06 + deep * 0.1) * fade * far);
	sp = s;
	VERTEX = s;
}

void fragment() {
	vec2 q = (sp - origin) / hole;
	if (dot(q, q) < 1.0) discard;
	for (int i = 0; i < n_worlds; i++) {
		vec3 w = worlds[i];
		vec2 e = sp - w.xy;
		if (dot(e, e) < w.z * w.z) discard;
	}
}
