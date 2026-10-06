shader_type canvas_item;
render_mode unshaded;

// THE WELDER'S ARC, on everything round it: the Yard Drones page's `weldLight`,
// which brightened the finished frame -- hall, hull, lift and welder alike --
// in a disc round the torch, harsh at the middle and dithered at its edge. It
// reads what is already on screen (a BackBufferCopy of the viewport, taken only
// while the arc burns) and lays it back brighter, bluer toward the middle.

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform vec2 origin = vec2(0.0);
// how many canvas pixels a hall pixel is drawn at (the cutaway zooms the yard)
uniform float zoom = 1.0;
uniform vec2 arc = vec2(0.0);
uniform float fl = 1.0;

varying vec2 sp;

void vertex() {
	sp = ((MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy - origin) / zoom;
}

void fragment() {
	vec2 p = floor(sp);
	float d = length(p - arc) / 16.0;
	if (d > 1.0) {
		discard;
	}
	float odd = mod(p.x + p.y, 2.0);
	float k = fl * (d < 0.35 ? 0.4 : (d < 0.7 ? 0.2 : (odd > 0.5 ? 0.08 : 0.0)));
	vec3 c = texture(screen, SCREEN_UV).rgb;
	COLOR = vec4(min(vec3(1.0), c * (vec3(1.0) + k * vec3(0.85, 0.95, 1.15))), 1.0);
}
