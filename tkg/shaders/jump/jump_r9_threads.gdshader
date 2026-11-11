shader_type canvas_item;
render_mode unshaded, blend_add;

// R9 UNRAVEL's threads as light, summed into a light buffer (`jump_r9_threads.gdshaderinc`).
// Why: docs/why/SeqUnravel.md#threads

#include "res://shaders/jump/jump_r9_threads.gdshaderinc"

void fragment() {
	if (v_col.a <= 0.0) {
		discard;
	}
	if (mode == 1) {
		// a ray: bright at its foot, fading up; mint to violet-magenta
		float jj = floor(v_jj);
		float fz = jj / max(v_col.y, 1.0);
		float wr = v_col.x * exp(-fz * 2.2);
		vec3 c = mix(MINT, VIO * 0.6 + MAG * 0.4, clamp(fz, 0.0, 1.0));
		COLOR = v_c.x > 0.5 ? vec4(vec3(wr * max(c.r, max(c.g, c.b))), 1.0) : vec4(c * wr, 1.0);
	} else {
		COLOR = v_col;
	}
}
