shader_type canvas_item;

// THE LAST FRAMES OF A RUN (`DeathHandoff`): the whole picture under it, read
// back and changed: dimmed and drained (A, the linger). B's pull back and C's
// dying feed were retired Nov 14.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
// how far dimmed and drained, 0 to 1
uniform float dim = 0.0;

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 c = texture(screen_tex, uv).rgb;
	c = mix(c, vec3(luma(c)), dim * 0.85);
	c *= 1.0 - dim * 0.62;
	COLOR = vec4(c, 1.0);
}
