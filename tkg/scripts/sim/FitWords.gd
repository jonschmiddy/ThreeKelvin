extends Harness

## The longest rail string sets the width, so measure it as a table, not by eye.
## Why: docs/why/FitWords.md#word-widths

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
	print("fitwords: measured, nothing judged")
