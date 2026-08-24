extends Harness

## What still has no art, and what has art of the wrong size:
##   godot --headless --path . -- artcheck
##
## THE COVERAGE GATE for the module and card art batch. Scope is Korvan,
## unbranded and the malfunctions — 43 modules and 76 cards — and everything
## else is deliberately out, so a manufacturer that has not been drawn yet does
## not read as a hundred failures.
##
## IT PASSES WITH EVERYTHING MISSING, and that is the point. A module without a
## sprite draws its silhouette and a card without an illustration draws its
## glyph; both are the designed fallback rather than a fault, so missing art is
## COUNTED and listed, never failed on. What fails is art that exists and is
## wrong — the wrong size for the box it has to sit in, which is the one mistake
## that cannot be seen from a filename and is invisible on screen until you know
## what you are looking for.
##
## THE BOX IS A GUIDE, NOT A FRAME, so this does not demand an exact size. A
## sprite is generated at the width its cells ask for and cropped to its own ink
## -- nothing is resampled -- so its height is whatever the art needed. A gun
## standing a row or two proud of its mount is a gun. What is checked is that it
## does not miss by a WIDE margin: far over and it hangs off the hull, far under
## and there is nothing to see at fifteen pixels.
##
## The size a module wants is arithmetic, not a constant: MountPoints sizes a
## fitted part from the hold's cell at half scale, so it is derived here from
## the same numbers rather than written down twice.


## Cards in scope come from modules of these houses, plus the malfunctions.
## `&""` is unbranded, which is a real key and not a missing one.
const HOUSES: Array[StringName] = [&"korvan", &""]

## How far past its box a part may stand before it is a fault, in art pixels.
## Half a cell. Beyond that it is not a gun on a mount, it is a gun beside one.
const PROUD := 8

## CARD ART IS 92 WIDE AND THE WINDOW IS 93, and that one pixel is not a bug.
## `create_image_pixflux` refuses an odd side at this size -- it answers 93x60
## with "Use 92x60 instead" -- so the art is generated one column short and
## centred, which leaves half a pixel of margin against a window that is already
## a recessed dark box. Height is exact.
const CARD_ART := Vector2i(92, 60)


func run() -> void:
	var mods := _modules()
	print("\n=== MODULES (%d in scope) ===" % mods.size())
	print("  %-22s %-8s %-9s %-9s %s"
		% ["module", "cells", "wants", "has", ""])
	var m_missing := 0
	var m_wrong := 0
	for m in mods:
		var want := _module_box(m)
		var has := "-"
		var note := "no art yet"
		if m.sprite != null:
			has = "%dx%d" % [m.sprite.get_width(), m.sprite.get_height()]
			var over := Vector2i(m.sprite.get_width() - int(want.x),
				m.sprite.get_height() - int(want.y))
			var fits := over.x <= PROUD and over.y <= PROUD
			var tiny := (m.sprite.get_width() * 2 < int(want.x)
				or m.sprite.get_height() * 2 < int(want.y))
			note = "ok"
			if not fits:
				note = "OVERHANGS by %d,%d" % [maxi(0, over.x), maxi(0, over.y)]
			elif tiny:
				note = "UNDERSIZED"
			elif over.x > 0 or over.y > 0:
				note = "proud %d,%d" % [maxi(0, over.x), maxi(0, over.y)]
			if not fits or tiny:
				m_wrong += 1
		else:
			m_missing += 1
		print("  %-22s %-8s %-9s %-9s %s" % [m.id,
			"%dx%d" % [maxi(1, m.size.x), maxi(1, m.size.y)],
			"%dx%d" % [int(want.x), int(want.y)], has, note])

	var cards := _cards()
	print("\n=== CARDS (%d in scope) ===" % cards.size())
	var c_missing := 0
	var c_wrong := 0
	var want_card := Vector2(CARD_ART)
	for row in cards:
		var c: CardData = row["card"]
		var tex: Texture2D = DB.card_art(c.art_key())
		if tex == null:
			c_missing += 1
			continue
		if (tex.get_width() != int(want_card.x)
				or tex.get_height() != int(want_card.y)):
			c_wrong += 1
			print("  %-28s %-18s %dx%d, wants %dx%d" % [c.art_key(), row["from"],
				tex.get_width(), tex.get_height(),
				int(want_card.x), int(want_card.y)])

	print("\n  modules  %d drawn, %d still procedural" % [mods.size() - m_missing,
		m_missing])
	print("  cards    %d drawn, %d still on glyphs (art window %dx%d)"
		% [cards.size() - c_missing, c_missing, int(want_card.x), int(want_card.y)])
	_ok("every module sprite that exists sits within a cell of its box", m_wrong == 0)
	_ok("every card illustration that exists is the size the window wants",
		c_wrong == 0)
	verdict("artcheck")


## THE BOX A FITTED PART OCCUPIES, in art pixels, at the refit screen's own
## scale. Derived from the same three numbers MountPoints.part_rect uses, so
## retuning the hold cannot leave this check vouching for the old size.
##
## `k` is 1 because that is what ShipScreen passes to magnify() unzoomed, and
## the unzoomed view is the one the asset has to be authored for — the zoom then
## draws the same file at a whole 2.
func _module_box(m: ModuleData) -> Vector2:
	var f := Vector2(maxi(1, m.size.x), maxi(1, m.size.y))
	var q := 1.0 / ModuleIcon.HOLD_K
	var cell := float(HoldGrid.CELL) * q
	var gap := float(HoldGrid.GAP) * q
	return (f * (cell + gap) - Vector2(gap, gap)).round()


func _modules() -> Array[ModuleData]:
	var out: Array[ModuleData] = []
	for id in DB.modules:
		var m: ModuleData = DB.modules[id]
		if m.manufacturer in HOUSES:
			out.append(m)
	out.sort_custom(func(a: ModuleData, b: ModuleData) -> bool:
		return str(a.id) < str(b.id))
	return out


## Every card in scope, with where it came from. A SHARED card reached through
## two modules is ONE illustration and is counted once — the cards are the same
## card, which is the whole reason SHARED exists.
func _cards() -> Array[Dictionary]:
	var seen := {}
	var out: Array[Dictionary] = []
	for m in _modules():
		for c in m.cards:
			var k := c.art_key()
			if seen.has(k):
				continue
			seen[k] = true
			out.append({"card": c, "from": str(m.id)})
	for row in DB.MALFUNCTIONS:
		var c := DB.malfunction(row[0])
		var k := c.art_key()
		if seen.has(k):
			continue
		seen[k] = true
		out.append({"card": c, "from": "malfunction"})
	return out
