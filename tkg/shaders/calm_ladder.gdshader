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
// THE FIELD KEYED OUT (`NavField`; Jon, Oct 18: one space under all three
// screens, the swap carrying what is in front of it): the field's picture as it
// stood when the picture was held, on the window's 2x2 blocks; a texel of the
// held picture within `key_tol` of the field under it is the field itself, so
// it is left out -- the stars stay where they are while the things in front
// move. Off (`field_on` false): the picture whole, as before.
uniform sampler2D field_tex : filter_nearest;
uniform bool field_on = false;
uniform float key_tol = 0.03;
// THE HUD'S OWN THINGS IN THE PICTURE HELD (the goal line, a fixed piece of the
// HUD that stays up through the move, drawn over the screens: the frame held
// has it too), left out where they stood -- one goal, never a second carried
// off with the picture (texels, as the picture was)
uniform vec4 cut = vec4(0.0);
uniform vec4 cut2 = vec4(0.0);
// and where the picture held runs past the map's own (its cloud, cloud:A), the
// screen's side bar and toolbar there, standing still where they were
// (`_calm_cover`), not carried with it
uniform vec4 cut3 = vec4(0.0);
uniform vec4 cut4 = vec4(0.0);
// ... and under them, the map's own sky as it was there (its cloud runs on
// under the plates): its picture (`under_tex`, the map's 960x540 sky from
// `under_at`), keyed to its void as the map keys it, thinning out to its end on
// the right as the map's cloud does (`nav_ext.gdshader`)
uniform sampler2D under_tex : filter_nearest;
uniform bool under_on = false;
uniform vec2 under_at = vec2(0.0);
uniform float under_right = 99999.0;
// (and the cloud drawn on past its end, as it was: `SystemView` `_past`)
uniform sampler2D under_past : filter_nearest, repeat_disable;
uniform bool under_past_on = false;
// A CLOUD MADE SMALLER THINS OUT AS A CLOUD (`cloud_round.gdshaderinc`): its
// texels are the screen as it was at the handoff, so the live map's own
// rounding (`nav_key`, `nav_ext`) goes on here unbroken; `cloud_k` how far in,
// on the move's own clock
#include "res://shaders/cloud_round.gdshaderinc"
uniform bool cloud_edge = false;
uniform float cloud_k = 0.0;
uniform vec2 cloud_c = vec2(480.0, 270.0);
uniform vec2 cloud_h = vec2(470.0, 245.0);
// (between LOCAL and the map: the feather's own line broken too)
uniform bool feather_noise = false;

vec4 under_texel(vec2 tc) {
	vec2 u = (tc + 0.5 - under_at) / vec2(960.0, 540.0);
	if (u.x < 0.0 || u.y < 0.0) {
		return vec4(0.0);
	}
	// (past its end the map's sky goes on as `nav_ext` draws it: `sky_wide`)
	return sky_wide(under_tex, under_past, under_past_on, u);
}

// a texel of the held picture, premultiplied, keyed against the field
vec4 held_texel(vec2 t) {
	vec2 tc = clamp(t, vec2(0.0), vp - 1.0);
	// (the goal's place filled with what lies just under it, folded up -- no
	// hole, no notch; the sky there is the sky round it)
	if (cut.z > 0.0 && tc.x >= cut.x && tc.y >= cut.y && tc.x < cut.x + cut.z && tc.y < cut.y + cut.w) {
		tc.y = 2.0 * (cut.y + cut.w) - tc.y;
	}
	if (cut2.z > 0.0 && tc.x >= cut2.x && tc.y >= cut2.y && tc.x < cut2.x + cut2.z && tc.y < cut2.y + cut2.w) {
		tc.y = 2.0 * (cut2.y + cut2.w) - tc.y;
	}
	vec4 h = texelFetch(old_lin, ivec2(tc), 0);
	if ((cut3.z > 0.0 && tc.x >= cut3.x && tc.y >= cut3.y && tc.x < cut3.x + cut3.z && tc.y < cut3.y + cut3.w)
			|| (cut4.z > 0.0 && tc.x >= cut4.x && tc.y >= cut4.y && tc.x < cut4.x + cut4.z && tc.y < cut4.y + cut4.w)) {
		return under_on ? under_texel(tc) : vec4(0.0);
	}
	if (field_on) {
		vec3 f = texture(field_tex, (tc + 0.5) / vp).rgb;
		vec3 d = abs(h.rgb - f);
		if (max(d.r, max(d.g, d.b)) <= key_tol) {
			h.a = 0.0;
		}
	}
	return vec4(h.rgb * h.a, h.a);
}

// sharp bilinear: whole texels, blended only across their own edges (by hand,
// so each texel is keyed before it is blended); premultiplied
vec4 old_at(vec2 q) {
	vec2 w = max(fwidth(q), vec2(0.0001));
	vec2 f = fract(q - 0.5);
	vec2 g = clamp((f - 0.5) / min(w, vec2(1.0)) + 0.5, 0.0, 1.0);
	vec2 b = floor(q - 0.5);
	vec4 a0 = mix(held_texel(b), held_texel(b + vec2(1.0, 0.0)), g.x);
	vec4 a1 = mix(held_texel(b + vec2(0.0, 1.0)), held_texel(b + vec2(1.0, 1.0)), g.x);
	return mix(a0, a1, g.y);
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
		if (cloud_edge && feather_noise && fw > 0.5) {
			// (and that feather's own line broken by the gas's noise, so no straight
			// side shows while the rounding draws in: Jon, "a hard-edged rectangle")
			float nb = cl_noise(q / 37.0) * 0.65 + cl_noise(q / 13.0 + 3.1) * 0.35;
			e = smoothstep(0.0, fw, lo - nb * fw * 0.9);
		}
		if (cloud_edge) {
			// (no straight side at all: the rounded thinning instead of the rect's)
			vec3 hc = texture(old_lin, (floor(q) + 0.5) / vp).rgb;
			// (with the rect's own wide feather, not instead of it: as the rounding
			// comes in, no straight side shows meanwhile)
			e *= cloud_round(q, dot(hc, vec3(0.299, 0.587, 0.114)), cloud_k, cloud_c, cloud_h);
		}
		a = alpha * e;
	}
	if (side.z > 0.0 && in_rect(p, side)) {
		a = 0.0;
	}
	if (side2.z > 0.0 && in_rect(p, side2)) {
		a = 0.0;
	}
	vec4 h = a > 0.0 ? old_pic(q) : vec4(0.0);
	COLOR = h.a > 0.0001 ? vec4(h.rgb / h.a, a * h.a) : vec4(0.0);
}
