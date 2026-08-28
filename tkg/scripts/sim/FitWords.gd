extends Harness

## How wide a word is on a rail button:
##   godot --headless --path . -- fitwords
##
## Every button on both combat rails is cut to `PileView.W`, so that width is set
## by the LONGEST string any of them ever shows -- and picking that string by eye
## is how the rail went to 100 to hold "NOT NEGOTIATING". This measures the
## candidates at the real font and the real size, against the widths the rail
## could plausibly be, so the choice is a table rather than a guess.
##
## The button's own stylebox eats some of the width. `PAD` is the horizontal
## content margin the flat boxes on FLEE and HAIL use, doubled.

## `UITheme.flat(..., 0, 0, 6)` on both, so six each side.
const PAD := 12

const WORDS: Array[String] = [
	"NO CONTACT",
	"NO CHANNEL",
	"NO REPLY",
	"NO ANSWER",
	"WON'T TALK",
	"NOT TALKING",
	"UNREACHABLE",
	"NO TERMS",
	"CLOSED",
	"SHUT",
	"NO ESCAPE",
	"NO EXIT",
	"CANNOT RUN",
	"HELD",
	"NOT NEGOTIATING",
	"NOT TALKING",
	"NO NEGOTIATION",
	"WON'T TALK",
	"NO ANSWER",
	"NO REPLY",
	"NO TERMS",
	"REFUSED",
	"SILENT",
	"NO DEAL",
	"CANNOT RUN",
	"NO ESCAPE",
	"TOO CLOSE",
	"PINNED",
	"COMMITTED",
	"END TURN",
	"HAIL",
	"FLEE",
	"ENERGY",
	"DISCARD",
]

## The rail widths worth considering. 68 is what it was before the long string,
## 100 is what it is now.
const RAILS: Array[int] = [68, 76, 84, 100]


func run() -> void:
	var f := UITheme.pixel_font()
	var s := UITheme.FS_SMALL
	print("\n  %-18s %6s %6s   %s" % ["string", "text", "+pad", "fits at"])
	for w in WORDS:
		var tw := f.get_string_size(w, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x
		var need := tw + float(PAD)
		var fits: Array[String] = []
		for r in RAILS:
			if need <= float(r):
				fits.append(str(r))
		print("  %-18s %6.0f %6.0f   %s"
			% [w, tw, need, ", ".join(fits) if not fits.is_empty() else "none"])
	print("\n  PileView.W is %d today." % SectorScreen.PileView.W)
	_ok("measured", true)
	verdict("fitwords")
