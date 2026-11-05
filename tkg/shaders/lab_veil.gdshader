shader_type canvas_item;
render_mode unshaded;

// THE ROOM'S EDGE, LET GO (`LabZoom`, the camera into the Lab's screen). Once
// the HUD and the deck rail have gone, the lab's painted room stood as a
// hard-edged rectangle on the dark, and the camera carried its top and left
// edges out of the window (Jon: "the square is kinda weird and harsh"). This
// lays the window's own dark over everything round the room and lets the
// room's last `feather` px fall away into it, its corners rounded off, so the
// room has no edge to see. On a ColorRect over the whole window, under the
// screen's frame; `room` is where the room's picture is on screen this frame
// (x0, y0, x1, y1), so the fall-off moves with the camera.

uniform vec4 room = vec4(0.0);
uniform float feather = 40.0;
uniform vec4 field : source_color = vec4(0.039, 0.055, 0.082, 1.0);
uniform float amount = 1.0;
// The rect's size in px: UV times this is the window px.
uniform vec2 size = vec2(960.0, 540.0);

void fragment() {
	vec2 p = UV * size;
	// how far outside the room's inner rect (the room less `feather` all round):
	// 0 inside it, `feather` at the room's edge (more at its corners)
	vec2 lo = room.xy + vec2(feather);
	vec2 hi = room.zw - vec2(feather);
	vec2 c = (lo + hi) * 0.5;
	vec2 half = max((hi - lo) * 0.5, vec2(0.0));
	vec2 q = abs(p - c) - half;
	float d = length(max(q, vec2(0.0)));
	// the room shows as smootherstep of how far in it is: flat at the edge (a
	// bright thing cut by it, the capital's tank, rose over 4 px on smoothstep)
	float e = 1.0 - clamp(d / max(feather, 0.001), 0.0, 1.0);
	float shown = e * e * e * (e * (e * 6.0 - 15.0) + 10.0);
	COLOR = vec4(field.rgb, (1.0 - shown) * amount);
}
