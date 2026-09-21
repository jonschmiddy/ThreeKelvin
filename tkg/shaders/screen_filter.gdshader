shader_type canvas_item;

// THE DISPLAY OPTIONS, in one pass over the finished frame.
//
// IT RUNS ON THE OUTPUT, NOT ON THE FRAME. This material lives on the
// SubViewportContainer that draws the game's 960x540 render target to the
// window (see GameShell), so every fragment here is a SCREEN pixel. That is
// what makes the curve possible: there is room between one game pixel and the
// next to bend the picture through, which there was not when this ran inside
// the frame -- there it could only blur the art or stagger it.
//
// Order is fixed: the tube's geometry first, then colour (vision, contrast,
// gamma), then the tube's own marks (lines, mask, vignette), which must not be
// re-graded by the grading above them.
//
// EVERY EFFECT IS OFF AT ZERO, and GameShell hides the whole thing when nothing
// is on, so a player who touches nothing pays nothing.

// 0 none, 1 deuteranopia, 2 protanopia, 3 tritanopia. The three are the same
// correction with a different matrix, so one branch covers them.
uniform int cvd : hint_range(0, 3) = 0;
uniform float cvd_strength : hint_range(0.0, 1.0) = 1.0;
// 1.0 leaves the picture alone.
uniform float contrast : hint_range(0.5, 2.0) = 1.0;
uniform float saturation : hint_range(0.0, 2.0) = 1.0;
uniform float gamma : hint_range(0.5, 2.0) = 1.0;
// The tube. 0 is a flat screen with no lines.
uniform float curve : hint_range(0.0, 0.2) = 0.0;
uniform float scanline : hint_range(0.0, 1.0) = 0.0;
uniform float mask_amount : hint_range(0.0, 1.0) = 0.0;
uniform float vignette : hint_range(0.0, 1.0) = 0.0;
// WHAT THE TUBE COSTS, GIVEN BACK: lines, mask and vignette all take light, and
// nobody turns a CRT on in order to see less.
uniform float gain : hint_range(0.5, 3.0) = 1.0;
// THE CORNERS, which are the hardest part of a tube to draw.
//
// `overscan` pushes the picture out past the frame so the curve's corners have
// something to show instead of nothing -- what a real set did, and what its
// owners never noticed. `corner_radius` rounds the glass, in SCREEN pixels.
// `rim_shadow` darkens the last stretch before the edge, the way a tube does
// where the glass meets the frame, and `rim_light` puts the thin catch of
// light back on the very edge of it.
uniform float overscan : hint_range(1.0, 1.1) = 1.0;
uniform float corner_radius : hint_range(0.0, 80.0) = 0.0;
uniform float rim_shadow : hint_range(0.0, 1.0) = 0.0;
uniform float rim_light : hint_range(0.0, 1.0) = 0.0;
// THE BEZEL: the plastic a tube is set into, drawn rather than supplied as art.
// `bezel_px` is how far it reaches in from the frame, in screen pixels, and it
// covers the outermost pixels of the picture -- which is what a television did,
// and why broadcasts were framed with the edges expendable. Lit from the top
// left, so it reads as a moulding rather than a border.
uniform float bezel : hint_range(0.0, 1.0) = 0.0;
uniform float bezel_px : hint_range(0.0, 80.0) = 22.0;
// The game's own size, and how many screen pixels one game pixel is.
uniform vec2 tex_size = vec2(960.0, 540.0);
uniform float out_scale = 2.0;

const vec3 LUMA = vec3(0.299, 0.587, 0.114);
// Off the glass is black, not the interface's near-black blue: a tube's
// surround is unlit glass, and the blue read as a bezel nobody asked for.
const vec3 OFF_GLASS = vec3(0.0);

mat3 cvd_matrix(int kind) {
	if (kind == 1) {
		return mat3(vec3(0.2920, 0.7054, -0.0003), vec3(0.2934, 0.7089, 0.0000),
			vec3(-0.0209, 0.0270, 0.9942));
	}
	if (kind == 2) {
		return mat3(vec3(0.1121, 0.8853, -0.0005), vec3(0.1127, 0.8897, -0.0001),
			vec3(0.0045, 0.0000, 1.0019));
	}
	return mat3(vec3(1.0000, 0.1284, -0.1284), vec3(0.0000, 0.8620, 0.1380),
		vec3(-0.0040, 0.0000, 0.0040));
}

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

vec3 to_srgb(vec3 c) {
	c = max(c, vec3(0.0));
	return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}

// DALTONISE, do not simulate: the error a colourblind eye loses is pushed into
// the channels it still has, so two things that differed only in red and green
// differ in brightness and blue as well.
vec3 correct(vec3 c, int kind, float amount) {
	vec3 lin = to_linear(c);
	vec3 seen = cvd_matrix(kind) * lin;
	vec3 err = lin - seen;
	vec3 fixed_up = vec3(
		lin.r,
		lin.g + 0.7 * err.r + err.g,
		lin.b + 0.7 * err.r + err.b);
	return mix(c, to_srgb(fixed_up), amount);
}

// ONE GAME PIXEL PER SCREEN PIXEL, with the edge between two of them softened
// over exactly one screen pixel.
//
// A plain nearest tap staircases wherever the curve slides a row sideways; a
// plain linear tap is the blur this restructure exists to remove. This is the
// middle: flat inside a texel, and only the last screen pixel before the
// boundary crosses over. At out_scale 1 it degrades to linear, which is right --
// there is nothing left to keep sharp.
// WORKED OUT HERE, SAMPLED THERE. Godot's built-ins -- TEXTURE among them --
// exist only inside the processor functions, and handing the sampler to a
// function of our own makes the compiler log an error on every startup even
// though it works. So this returns the place to look and `fragment` does the
// looking.
vec2 sharp_uv(vec2 uv) {
	vec2 px = uv * tex_size;
	vec2 base = floor(px);
	vec2 frac_px = px - base;
	// THE FLAT REGION IS THE POINT. Without it -- clamping the distance from
	// the texel centre straight to half a texel -- every screen pixel at 2x
	// lands exactly on a texel BOUNDARY, so every one of them is a 50/50 blend
	// of two game pixels. That is not a soft edge, that is the whole picture
	// blurred, and it is what Jon saw. `region` is the part of a texel that
	// samples its own centre and nothing else: all of it but the last half
	// screen pixel at each side.
	vec2 region = vec2(0.5 - 0.5 / max(out_scale, 1.0));
	vec2 dist = frac_px - 0.5;
	vec2 f = (dist - clamp(dist, -region, region)) * out_scale + 0.5;
	return (base + f) / tex_size;
}

// HOW FAR THE GLASS HAS BEEN NUDGED, in UV. Nothing artistic: the container
// this shader runs on is moved a fraction of a pixel-row each frame so that
// GODOT'S OWN input transform maps the pointer to the bent pixel -- that is
// what makes the highlight and the click agree. Adding the same nudge back
// here cancels it, so the picture does not move while the rect under it does.
uniform vec2 uv_shift = vec2(0.0);

// THE SET BEING SWITCHED OFF. 0 is on, 1 is a dark screen, and the way through
// is the one every cathode tube did: the picture collapses to a bright line as
// the vertical deflection dies, the line closes to a dot as the horizontal
// follows it, and the dot burns down through the phosphor. Three movements, in
// that order, because a tube cannot do them any other way.
uniform float power_off : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// The picture's own coordinates: the rect's, with the nudge taken out.
	vec2 uv_still = UV + uv_shift;
	vec2 uv = uv_still;
	// THE COLLAPSE HAPPENS BEFORE THE GLASS, not after. The beam is what is
	// dying; the curve it is drawn through does not change while it does.
	float dead = 0.0;
	float flare = 0.0;
	if (power_off > 0.0) {
		// FOUR MOVEMENTS NOW, NOT THREE. Jon: "make it last a while." The thing
		// that lasts is the LINE -- the picture folds to it quickly, and then
		// the set sits there with a bright bar across the middle draining while
		// the whine runs, and only then does the line close. Stretching the
		// fold itself would just look slow; holding the line is what buys the
		// time, because a held line is a picture of something still happening.
		float v = clamp(power_off / 0.10, 0.0, 1.0);          // height goes
		float hold = clamp((power_off - 0.10) / 0.34, 0.0, 1.0); // the bar drains
		float h = clamp((power_off - 0.44) / 0.06, 0.0, 1.0); // then width
		// AND THE DOT SHRINKS AS IT GOES OUT, the way a spot of phosphor does:
		// it does not sit at one size and then vanish.
		float fade = clamp((power_off - 0.52) / 0.48, 0.0, 1.0);
		float shrink = 1.0 - 0.55 * fade;
		// The bar thins by a bit under half across the hold. NOT to nothing:
		// a line that closes during the hold steals the close's own moment.
		float bar = 1.0 - 0.45 * hold;
		vec2 span = vec2(mix(1.0, 0.004 * shrink, h * h),
			mix(1.0, 0.0035 * shrink * bar, v * v));
		vec2 d = (uv - 0.5) / max(span, vec2(1e-5));
		dead = (abs(d.x) > 0.5 || abs(d.y) > 0.5) ? 1.0 : 0.0;
		uv = d + 0.5;
		uv_still = uv;
		// The light has to go somewhere as the picture folds into it -- and
		// then leaks away again while the bar sits, so the close has somewhere
		// to come back up from.
		flare = v * 1.9 * (1.0 - 0.5 * hold) + h * 2.4;
	}
	float edge = 1.0;
	float rim = 1.0;      // 0 at the very edge of the glass, 1 well inside it
	if (curve > 0.0) {
		// Barrel, about the middle of the glass. The corners travel furthest,
		// which is why the frame is tested rather than clamped.
		vec2 p = (uv - 0.5) * 2.0;
		float r2 = dot(p, p);
		p *= 1.0 + curve * r2;
		p /= overscan;
		uv = p * 0.5 + 0.5;
		// The distance to the frame, in SCREEN pixels, for the corner shaping
		// below -- rounded corners and a rim need a real distance, not a
		// per-axis test.
		vec2 screen_px = tex_size * out_scale;
		vec2 from_edge = min(uv, 1.0 - uv) * screen_px;
		float d;
		if (corner_radius > 0.0) {
			// Distance to a rounded rectangle: straight sides, round corners.
			vec2 corner = max(vec2(corner_radius) - from_edge, vec2(0.0));
			d = min(min(from_edge.x, from_edge.y), corner_radius - length(corner));
		} else {
			d = min(from_edge.x, from_edge.y);
		}
		edge = smoothstep(0.0, 1.0, d);
		rim = smoothstep(0.0, max(corner_radius, 12.0), d);
		uv = clamp(uv, vec2(0.0), vec2(1.0));
	}
	vec3 c = texture(TEXTURE, sharp_uv(uv)).rgb;

	if (cvd > 0) {
		c = correct(c, cvd, cvd_strength);
	}
	if (saturation != 1.0) {
		c = mix(vec3(dot(c, LUMA)), c, saturation);
	}
	if (contrast != 1.0) {
		c = (c - 0.5) * contrast + 0.5;
	}
	if (gamma != 1.0) {
		c = pow(max(c, vec3(0.0)), vec3(1.0 / gamma));
	}

	// ONE GAME ROW LIT, ONE GAME ROW DOWN -- counted in GAME rows, so the lines
	// keep their thickness relative to the art at every window size.
	//
	// It was a cosine of the row number once and did nothing at all: every
	// fragment is sampled at a pixel centre, so the row was always a whole
	// number plus a half and the cosine returned the same value on every line.
	if (scanline > 0.0) {
		c *= 1.0 - scanline * mod(floor(uv.y * tex_size.y), 2.0);
	}
	// The shadow mask: red, green and blue struck in turn across the glass, in
	// SCREEN pixels, because that is what a mask is.
	if (mask_amount > 0.0) {
		int col = int(mod(FRAGCOORD.x, 3.0));
		vec3 m = vec3(1.0 - mask_amount);
		if (col == 0) { m.r = 1.0; } else if (col == 1) { m.g = 1.0; } else { m.b = 1.0; }
		c *= m;
	}
	if (vignette > 0.0) {
		vec2 d = (uv_still - 0.5) * 2.0;
		c *= 1.0 - vignette * pow(clamp(length(d) * 0.72, 0.0, 1.0), 1.6);
	}
	c *= gain;
	if (power_off > 0.0) {
		// Brighter as it folds, then the phosphor going out. The last third is
		// the afterglow: a tube does not stop, it fades.
		float burn = clamp((power_off - 0.52) / 0.48, 0.0, 1.0);
		// A PHOSPHOR DOES NOT FADE IN A STRAIGHT LINE. Squared, the dot sat at
		// full brightness for a second and then disappeared, which reads as
		// switching off twice.
		c = c * (1.0 + flare);
		// THE BEAM IS LIGHT, NOT PICTURE. Folded down to a dot, what is left
		// is the gun still firing at one spot -- so the last of it goes white
		// rather than whatever colour happened to be in the middle of the
		// frame. Without this the dot is as dark as the pixel it landed on.
		// The white of the beam: up with the fold, DOWN across the hold as the
		// bar drains, then hard up again as the line closes to the dot. The
		// dip is what makes the close read as an event rather than as more of
		// the same -- a bar that only ever got brighter would have nowhere to
		// go at the end.
		float core = 0.3 * clamp(power_off / 0.10, 0.0, 1.0)
				* (1.0 - 0.55 * clamp((power_off - 0.10) / 0.34, 0.0, 1.0))
			+ 0.85 * clamp((power_off - 0.44) / 0.06, 0.0, 1.0);
		c += vec3(0.95, 0.93, 0.88) * core;
		c *= pow(1.0 - burn, 2.2);
		c = mix(c, vec3(0.0), dead);
	}
	// AND THE HIGHLIGHTS ROLL OFF RATHER THAN FLATTEN. Giving back everything
	// the tube took means a gain above 2 on the arcade setting, and a straight
	// multiply would clamp every bright pixel to white -- the picture would
	// measure as bright as the flat one and read as blown out. A soft knee over
	// the top sixth keeps them apart, and leaves everything below it untouched.
	vec3 over = max(c - 0.85, vec3(0.0));
	c = min(c, vec3(0.85)) + (1.0 - 0.85) * (1.0 - exp(-over / (1.0 - 0.85)));
	// The glass meeting the frame: a shade under it, and the thin catch of
	// light on the last pixel of the curve.
	if (rim_shadow > 0.0) {
		c *= 1.0 - rim_shadow * (1.0 - rim);
	}
	if (rim_light > 0.0) {
		float lip = smoothstep(0.0, 1.0, edge) * (1.0 - smoothstep(0.0, 2.5, rim * 12.0));
		c += vec3(0.22, 0.26, 0.32) * rim_light * lip;
	}
	vec3 out_c = mix(OFF_GLASS, c, edge);
	if (bezel > 0.0) {
		// How far in from the window's own frame this pixel is, rounded at the
		// corners to the same radius as the glass, so plastic and glass share a
		// shape.
		vec2 win_px = min(uv_still, 1.0 - uv_still) * tex_size * out_scale;
		float r = max(corner_radius, 1.0);
		vec2 corner = max(vec2(r) - win_px, vec2(0.0));
		float wd = min(min(win_px.x, win_px.y), r - length(corner));
		float plastic = 1.0 - smoothstep(bezel_px - 1.5, bezel_px + 0.5, wd);
		if (plastic > 0.0) {
			// Lit from the top left: the top and left faces catch, the bottom
			// and right fall away.
			float lit = clamp((uv_still.x + uv_still.y) * 0.5, 0.0, 1.0);
			vec3 face = mix(vec3(0.055, 0.060, 0.070), vec3(0.020, 0.022, 0.028), lit);
			// A brighter lip where the plastic meets the glass, and the shadow
			// the moulding casts onto the picture just inside it.
			float lip = smoothstep(bezel_px + 1.5, bezel_px - 1.0, wd) * smoothstep(bezel_px - 4.0, bezel_px, wd);
			face += vec3(0.10, 0.11, 0.13) * lip * (1.0 - lit * 0.6);
			out_c = mix(out_c * (1.0 - 0.45 * smoothstep(bezel_px + 14.0, bezel_px, wd)),
				face, plastic) * mix(1.0, 1.0, plastic);
		}
	}
	COLOR = vec4(out_c, 1.0);
}
