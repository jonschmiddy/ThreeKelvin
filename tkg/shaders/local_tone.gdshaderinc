// LOCAL'S PLAY TONE (`local_grade`, `local_near`): below the top band the
// fight is played, and the sky there is turned into a soft backdrop, still the
// same lit scene: its range is pressed in toward a mid-tone (`mid`, sRGB luma)
// -- the light above it brought down to `keep_hi` of its distance, the dark
// below it lifted a touch (`keep_lo`) -- and the very brightest (a star, a
// lit rim) pressed further down a knee over `cap`. Its colour is kept: the
// whole pixel is scaled. Nothing is drawn behind the ships or their words:
// they stand on this alone.

uniform float mid = 0.13;
uniform float keep_lo = 0.9;
uniform float keep_hi = 0.55;
uniform float cap = 0.3;
uniform float soft = 0.3;

vec3 play_tone(vec3 c, float w) {
	if (w <= 0.0) {
		return c;
	}
	float L = dot(c, vec3(0.299, 0.587, 0.114));
	float Lt = mid + (L - mid) * (L > mid ? keep_hi : keep_lo);
	if (Lt > cap) {
		Lt = cap + (Lt - cap) * soft;
	}
	vec3 t;
	if (Lt <= L) {
		t = L > 1e-4 ? c * (Lt / L) : c;
	} else {
		// (lifted: what light is there kept, the lift itself neutral)
		t = c + vec3(Lt - L);
	}
	return mix(c, t, w);
}
