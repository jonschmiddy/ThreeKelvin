// The films' light buffers (`JumpStage.light`): additive SubViewports the size of the window,
// 8-bit, so light is written pre-scaled by J_LIGHT_K and read back unscaled here. A buffer
// holds light summed before the tone map, as the films' numpy arrays did.
// Why: docs/why/JumpStage.md#light-buffers

const float J_LIGHT_K = 0.25;

// The buffer at screen pixel p (whole px), as light.
vec3 j_light(sampler2D buf, vec2 p, vec4 world) {
	return texture(buf, (p - world.xy + 0.5) / world.zw).rgb / J_LIGHT_K;
}

// The buffer at a point between pixels (bilinear), for the blurs.
vec3 j_light_at(sampler2D buf, vec2 at, vec4 world) {
	return texture(buf, (at - world.xy) / world.zw).rgb / J_LIGHT_K;
}
