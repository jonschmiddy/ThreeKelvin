// TORN AWAY: THE DWARF'S CLOUDS TORN WITH IT (`ChartTorn.cloud_tear`; Jon, Nov 8:
// "nebula in the dwarf galaxy should dissapear or become distorted as the galaxy is
// eated"). A named cloud over the dwarf shears a little as the dwarf is stripped; one
// the torn edge has passed is drawn out toward the giant, slides that way, breaks into
// streaks and crumbles away, never cut at the edge (a cloud sliced in half mid-run read
// wrong, Nov 8's review). The chart's drawing only: where the cloud stands for the
// game (`NebulaField`) is unchanged. Every style reads its clouds in its own frame:
// it hands the way to the giant in that frame (`u_tornClD`: xy the screen's, round as
// the clouds are drawn; zw the galaxy's plane). All zero (whole, as drawn today) off
// TORN AWAY and for every cloud outside the dwarf: nothing here changes them.
#ifndef TORN_CLOUD_INC
#define TORN_CLOUD_INC
uniform vec4 u_tornCl[12];    // gone 0..1 (it fades), drawn out (its length 1 + this), slid toward the giant (gu), shear
uniform vec4 u_tornClD[12];   // the way to the giant: the screen's (round frame) x, y; the plane's x, y

float tornClHash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
// smooth value noise, 0..1 (held on the cloud: it never crawls)
float tornClNoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = tornClHash(i), b = tornClHash(i + vec2(1.0, 0.0));
	float c = tornClHash(i + vec2(0.0, 1.0)), d = tornClHash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

bool tornClOn(int i) {
	vec4 T = u_tornCl[i];
	return T.x > 1e-4 || T.y > 1e-4 || T.w > 1e-4;
}

// THE TEAR'S STRAIGHT PART (a ray's analytic shells take it whole): a point u of the
// cloud's own frame (gu about its middle) where it shows, to where it lay in the cloud
// as drawn whole; d the way to the giant in that frame. Slid toward the giant, sheared,
// drawn out along the way more than back (a tail, not a stretch both ways) and thinned
// across. Straight on either side of its middle: `tornClAffD` is its way for a ray.
vec2 tornClAff(int i, vec2 u, vec2 d) {
	vec4 T = u_tornCl[i];
	vec2 n = vec2(-d.y, d.x);
	float a = dot(u, d), b = dot(u, n);
	a -= T.z + T.w * b;
	a /= a > 0.0 ? 1.0 + T.y : 1.0 + 0.3 * T.y;
	b *= 1.0 + 0.35 * T.y;
	return d * a + n * b;
}
// the same as one straight map for a ray (RADIANT's: its bounds and shells), the giant's
// side's all through: it takes in all the whole tear does, the back drawn in further
vec2 tornClAffR(int i, vec2 u, vec2 d) {
	vec4 T = u_tornCl[i];
	vec2 n = vec2(-d.y, d.x);
	float a = dot(u, d), b = dot(u, n);
	a -= T.z + T.w * b;
	a /= 1.0 + T.y;
	b *= 1.0 + 0.35 * T.y;
	return d * a + n * b;
}
// the same for a ray's direction (no slide), on the giant's side of the middle
vec2 tornClAffD(int i, vec2 v, vec2 d) {
	vec4 T = u_tornCl[i];
	vec2 n = vec2(-d.y, d.x);
	float a = dot(v, d), b = dot(v, n);
	a -= T.w * b;
	a /= 1.0 + T.y;
	b *= 1.0 + 0.35 * T.y;
	return d * a + n * b;
}
// and back: a point q of the cloud as drawn whole to where it shows now (its own stars,
// its lightning: they go with its gas)
vec2 tornClFwd(int i, vec2 q, vec2 d) {
	if (!tornClOn(i)) {
		return q;
	}
	vec4 T = u_tornCl[i];
	vec2 n = vec2(-d.y, d.x);
	float a = dot(q, d), b = dot(q, n);
	b /= 1.0 + 0.35 * T.y;
	a *= a > 0.0 ? 1.0 + T.y : 1.0 + 0.3 * T.y;
	a += T.z + T.w * b;
	return d * a + n * b;
}

// THE WHOLE TEAR (where it is read point by point): the straight part, with the cloud
// broken into streaks along the way -- each strip across slid along by its own amount,
// more the further it is drawn out. R the cloud's size (gu).
vec2 tornClWarp(int i, vec2 u, vec2 d, float R) {
	if (!tornClOn(i)) {
		return u;
	}
	vec4 T = u_tornCl[i];
	vec2 n = vec2(-d.y, d.x);
	float b = dot(u, n);
	float st = 2.0 * tornClNoise(vec2(b / max(0.16 * R, 0.003), 3.1 * float(i) + 0.7)) - 1.0;
	u -= d * st * 0.3 * R * min(T.y, 2.5);
	return tornClAff(i, u, d);
}

// how much of cloud i is left at q (a point of it as drawn whole): all of it while
// whole; as it goes it crumbles, its thinner parts first, to nothing
float tornClKeep(int i, vec2 q, float R) {
	float g = u_tornCl[i].x;
	if (g <= 1e-4) {
		return 1.0;
	}
	if (g >= 0.999) {
		return 0.0;
	}
	float nz = 0.65 * tornClNoise(q / max(0.22 * R, 0.003) + 7.7 * float(i)) + 0.35 * tornClNoise(q / max(0.07 * R, 0.002) + 3.3 * float(i));
	return smoothstep(1.2 * g - 0.2, 1.2 * g, nz) * (1.0 - 0.5 * g);
}
#endif
