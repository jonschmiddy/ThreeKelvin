shader_type canvas_item;
render_mode unshaded, blend_disabled;

// R9 UNRAVEL's hull paint near the threads' roots, opaque, into the matter buffer: the back
// band's alpha a half, the front's whole, so the world pass lays each on its side of the hull
// (`jump_r9_threads.gdshaderinc`, mode 2).
// Why: docs/why/SeqUnravel.md#threads

#include "res://shaders/jump/jump_r9_threads.gdshaderinc"

void fragment() {
	if (v_col.a <= 0.0) {
		discard;
	}
	COLOR = v_col;
}
