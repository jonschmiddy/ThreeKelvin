shader_type canvas_item;

// THE CALM MOVE'S HELD PICTURE (`ZoomLadder`, Jon's pick A): the screen being
// left, as the last frame it drew, carried on the one camera move over the
// screen arriving (live underneath, on the same move). One affine map: the
// point `to_pt` on screen shows the held picture's `from_pt`, scaled by `scl`
// -- your ship, at both, so the two pictures always agree on where it is. Only
// the held picture's own rect (`pic`) is carried: the chrome round it is the
// ladder's (`ChromeSlide`, `SideBand`, `SideSwap`), which stands still. It
// leaves by `alpha`, a crossfade over a stretch of the move, never a cut; and
// made smaller, its edge feathers so it is never a card laid on the other.

uniform sampler2D old_lin : filter_linear;
uniform vec2 vp = vec2(960.0, 540.0);
uniform vec2 rect_pos = vec2(0.0);
uniform vec2 rect_size = vec2(960.0, 540.0);
uniform vec4 pic = vec4(0.0, 0.0, 960.0, 540.0);
uniform vec2 from_pt = vec2(480.0, 270.0);
uniform vec2 to_pt = vec2(480.0, 270.0);
uniform vec2 scl = vec2(1.0);
uniform float alpha = 1.0;
// the feather at its widest, screen px (none at rest size, all of it by half)
uniform float feather = 28.0;
// the side bar's and the toolbar's rects (screen px; z 0 for none): their
// chrome is drawn over them, so the held picture leaves them alone
uniform vec4 side = vec4(0.0);
uniform vec4 side2 = vec4(0.0);

// sharp bilinear: whole texels, blended only across their own edges
vec4 old_at(vec2 q) {
	vec2 w = max(fwidth(q), vec2(0.0001));
	vec2 f = fract(q - 0.5);
	vec2 g = clamp((f - 0.5) / min(w, vec2(1.0)) + 0.5, 0.0, 1.0);
	return texture(old_lin, (floor(q - 0.5) + 0.5 + g) / vp);
}

// minified smoothly (a 2x2 box) when it shrinks, so no rows drop out
vec4 old_pic(vec2 q) {
	if (scl.x < 0.85) {
		vec2 h = 0.25 / scl;
		return (old_at(q + vec2(-h.x, -h.y)) + old_at(q + vec2(h.x, -h.y))
			+ old_at(q + vec2(-h.x, h.y)) + old_at(q + vec2(h.x, h.y))) * 0.25;
	}
	return old_at(q);
}

bool in_rect(vec2 q, vec4 r) {
	return q.x >= r.x && q.y >= r.y && q.x < r.x + r.z && q.y < r.y + r.w;
}

void fragment() {
	vec2 p = rect_pos + UV * rect_size;
	vec2 q = from_pt + (p - to_pt) / scl;
	float a = 0.0;
	if (in_rect(q, pic) && alpha > 0.0) {
		// distance inside the held rect, on screen px
		float lo = min(min(q.x - pic.x, q.y - pic.y), min(pic.x + pic.z - q.x, pic.y + pic.w - q.y)) * scl.x;
		float fw = feather * clamp((1.0 - scl.x) * 2.0, 0.0, 1.0);
		float e = fw > 0.5 ? smoothstep(0.0, fw, lo) : 1.0;
		a = alpha * e;
	}
	if (side.z > 0.0 && in_rect(p, side)) {
		a = 0.0;
	}
	if (side2.z > 0.0 && in_rect(p, side2)) {
		a = 0.0;
	}
	COLOR = a > 0.0 ? vec4(old_pic(q).rgb, a) : vec4(0.0);
}
