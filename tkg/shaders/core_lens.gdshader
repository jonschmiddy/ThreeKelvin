shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;

// THE MAP BENT ROUND THE CORE (Jon, of the hole on its own: "it looks copy +
// pasted in"). Whatever is already drawn behind the hole -- nebula, stars,
// grid, orbits, the far worlds -- is read back off the screen and bent by a
// point lens: a pixel r from the hole shows what lies at r(1 - TE^2/r^2), so
// the sky is pushed out round a ring of radius TE and turned inside out
// within it. Where the bend stretches the sky, it brightens, so stars near
// the ring become arcs. The bend fades out over the outer half of a 160 px
// patch, so the patch has no seam. The mockup's `coreLens`
// (`sysmap/template.html`), CORE_TE = sqrt(52) * 15 / 2.598, CORE_R = 160.
//
// The mockup bends at the canvas's 2x and its palette pass then keeps the
// top-left screen pixel of each game pixel, so a game pixel d from the hole
// reads the screen pixel round(2 d k) / 2 from it: that is what is sampled
// here, whole game pixels, nearest.
//
// Drawn opaque over a 321 x 321 square centred on the hole; outside the
// circle nothing is written. ZOOMED k times, `CoreView` sets te and radius k
// times bigger and the square to 2 * extent + 1, extent = ceil(radius). It needs the screen copied just before it, which
// `CoreView` does with a BackBufferCopy.

uniform sampler2D screen : hint_screen_texture, filter_nearest, repeat_disable;
uniform float te = 41.565;
uniform float radius = 160.0;
// half the square's side, in whole pixels (radius, rounded up)
uniform float extent = 160.0;
// map pixels to a screen pixel: 2 when the place is drawn half size
uniform float px_scale = 1.0;

void fragment() {
	float n = extent * 2.0 + 1.0;
	vec2 dp = floor(UV * n) - extent;
	float r2 = dot(dp, dp);
	if (r2 > radius * radius) discard;
	float r = sqrt(r2) + 0.01;
	float f = r < radius * 0.5 ? 1.0 : pow(max(0.0, 1.0 - (r - radius * 0.5) / (radius * 0.5)), 2.0);
	float e = te * te / (r * r) * f, k = 1.0 - e;
	vec2 src = floor(floor(dp * k * 2.0 + 0.5) / 2.0);
	src = clamp(src, vec2(-radius), vec2(radius));
	// this pixel on the screen, and the one it shows
	vec2 here = floor(FRAGCOORD.xy);
	vec2 at = clamp(here + floor((src - dp) / px_scale + 0.5), vec2(0.0), 1.0 / SCREEN_PIXEL_SIZE - 1.0);
	vec3 c = floor(textureLod(screen, (at + 0.5) * SCREEN_PIXEL_SIZE, 0.0).rgb * 255.0 + 0.5);
	float mu = 1.0 / max(0.02, abs(1.0 - e * e));
	if (mu > 1.4) {
		float g = min(1.7, 1.0 + 0.3 * log2(mu));
		c = floor(min(vec3(255.0), c * g));
	}
	COLOR = vec4(c / 255.0, 1.0);
}
