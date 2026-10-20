shader_type canvas_item;

// THE HULL FAILING: A TEXT'S OWN LETTERS, HIDDEN WHERE THE NOISE GOES
// (`HullScramble`). Set on a Label's, a Button's or a RichTextLabel's canvas
// item through the RenderingServer (never its `material` property) for as long
// as some of its letters are scrambled, and taken off again after.
//
// Inside each cell (a letter's advance by its line's height, in the control's
// own pixels) the text's glyphs are not drawn; the scramble glyph is drawn over
// the gap by a canvas item of `HullScramble`'s own, parented to the control's,
// so it clips, fades and moves with the control. Everything else the control
// draws -- its plate, its focus ring, an icon, an underline -- is untouched:
// only fragments read from a font's glyph atlas are masked, and those are the
// big white atlases the TextServer caches glyphs in (the game's plates are
// flat or small pixel bezels).
//
// IT NEVER CHANGES A STRING OR A SIZE. The control lays out and draws exactly
// as it would; a letter's pixels are just left out for a few frames.

uniform vec4 cells[8];
uniform int n = 0;

varying vec2 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	if (n > 0) {
		vec4 t = texture(TEXTURE, UV);
		ivec2 ts = textureSize(TEXTURE, 0);
		if (ts.x >= 128 && t.r > 0.98 && t.g > 0.98 && t.b > 0.98) {
			for (int i = 0; i < 8; i++) {
				if (i >= n) {
					break;
				}
				vec4 c = cells[i];
				if (lp.x >= c.x && lp.y >= c.y && lp.x < c.x + c.z && lp.y < c.y + c.w) {
					COLOR.a = 0.0;
				}
			}
		}
	}
}
