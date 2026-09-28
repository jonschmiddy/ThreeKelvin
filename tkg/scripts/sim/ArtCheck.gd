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


## Cards in scope come from modules of these manufacturers, plus the malfunctions.
## `&""` is unbranded, which is a real key and not a missing one.
const MANUFACTURERS: Array[StringName] = [&"korvan", &""]

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

	# `-- artcheck cards` dumps every illustration owed, one per line, with what
	# the card IS. Writing seventy-one prompts off the card gallery means reading
	# them off a screen one at a time; this is the same list as a file.
	#
	# TAB SEPARATED, because the consumer is a script. `glyph_kind` is in it
	# because it is the game's OWN answer to "what does this card look like" --
	# the procedural art has been sorting cards into slug, burst, charge, pyre,
	# brace and the rest all along, and a prompt that ignores that is inventing a
	# second taxonomy for the same objects.
	if "cards" in OS.get_cmdline_user_args():
		print("
=== CARD MANIFEST ===")
		for row in cards:
			var c: CardData = row["card"]
			var src: ModuleData = DB.modules.get(StringName(str(row["from"])))
			# `describe()` and the type line are in it because a DESIGN SHEET is
			# written off this file, not off the card gallery, and a brief for a
			# picture that does not know what the card does is how four cards
			# ended up asking for the same muzzle flash. `type` and `glyph` are
			# both here on purpose: they are the game's two existing answers to
			# "what is this", and where they agree across many cards is exactly
			# where the illustrations are about to collide.
			print("%s	%s	%s	%s	%s	%s	%s	%s	%s	%s" % [
				c.art_key(),
				"DONE" if DB.card_art(c.art_key()) != null else "TODO",
				c.name, c.glyph_kind(), c.type_name(),
				c.describe().replace("
", " "),
				c.manufacturer if c.manufacturer != &"" else "-",
				str(row["from"]),
				src.name if src != null else "-",
				(src.flavour if src != null else "").replace("
", " ")])

	var e := _enemies()
	var p := _places()

	print("\n  modules  %d drawn, %d still procedural" % [mods.size() - m_missing,
		m_missing])
	print("  cards    %d drawn, %d still on glyphs (art window %dx%d)"
		% [cards.size() - c_missing, c_missing, int(want_card.x), int(want_card.y)])
	print("  enemies  %d drawn, %d still procedural (canvas %dx%d)"
		% [e["drawn"], e["missing"], ENEMY_CANVAS.x, ENEMY_CANVAS.y])
	print("  places   %d drawn, %d still procedural" % [p["drawn"], p["missing"]])
	var lay := _shop_rooms()
	_ok("every module sprite that exists sits within a cell of its box", m_wrong == 0)
	_ok("every card illustration that exists is the size the window wants",
		c_wrong == 0)
	_ok("every enemy sprite that exists fits its canvas", int(e["wrong"]) == 0)
	_ok("every sector place sprite that exists fits its arena", int(p["wrong"]) == 0)
	_ok("every shop and Exchange room is installed whole: its pictures load, its light "
		+ "reads, every level has one", int(lay["bad"]) == 0)
	verdict("artcheck")


## THE SHOP ROOMS AS INSTALLED. Jon's fifteen rooms are data -- `rooms.json`
## and the pictures beside it, written by `tools/room_install.py` -- and the
## mistakes that data invites are the silent ones: a picture the game cannot
## load draws nothing, a light file of the wrong size lights nothing, a level
## with no room gets a shop with no walls. Each is counted here as a fault,
## because unlike a module with no sprite there is no designed fallback.
func _shop_rooms() -> Dictionary:
	var bad := 0
	var d := ShopScene.doc()
	var rooms: Array = d.get("rooms", [])
	print("\n=== SHOP ROOMS (%d) ===" % rooms.size())
	if rooms.is_empty():
		print("  nothing installed -- run tools/room_install.py")
		return {"bad": 1}
	var levels: Dictionary = d.get("levels", {})
	for dev in MapGen.Development.values():
		var names: Array = levels.get(ShopScene.level_name(dev), [])
		if names.is_empty():
			bad += 1
			print("  %s has no room" % ShopScene.level_name(dev))
		# Every backdrop that level can draw has the colour its openings glow.
		for bd in StationRoom.BACKDROPS.get(dev, []):
			if not (d.get("tones", {}) as Dictionary).has(String(bd)):
				bad += 1
				print("  no glow colour for backdrop %s" % bd)
	var ls: Array = d.get("light_size", [0, 0])
	for r in rooms:
		bad += _room_faults(r, ls)
	# THE EXCHANGE, the second deck in the same file: one room per level, a hold
	# of three frames where the rack was, and its level's sky's glow colour.
	var ex: Dictionary = (d.get("decks", {}) as Dictionary).get("exchange", {})
	var ex_rooms: Array = ex.get("rooms", [])
	print("\n=== EXCHANGE ROOMS (%d) ===" % ex_rooms.size())
	for dev in MapGen.Development.values():
		var lv := ShopScene.level_name(dev)
		if ((ex.get("levels", {}) as Dictionary).get(lv, []) as Array).is_empty():
			bad += 1
			print("  %s has no Exchange" % lv)
		if not (d.get("tones", {}) as Dictionary).has("space_" + lv):
			bad += 1
			print("  no glow colour for space_%s" % lv)
	for r in ex_rooms:
		bad += _room_faults(r, ls)
	return {"bad": bad}


## One installed room's faults, printed; 1 if it has any. A shop room has a
## rack and an Exchange a hold, and both have a counter.
func _room_faults(r: Dictionary, ls: Array) -> int:
	var room: Dictionary = r
	var notes: Array[String] = []
	var files: Array[String] = [String(room.plate), String(room.till.art)]
	if room.has("rack"):
		files.append(String(room.rack.art))
	for f in (room.get("hold", {}) as Dictionary).get("frames", {}).values():
		files.append(String((f as Dictionary).art))
	if room.has("hold") and ((room.hold as Dictionary).get("frames", {}) as Dictionary).size() != 3:
		notes.append("the hold has %d frames" % ((room.hold as Dictionary).get("frames", {}) as Dictionary).size())
	for layer in ["back", "front"]:
		for q in room.get(layer, []):
			if (q as Dictionary).has("art"):
				files.append(String(q.art))
	for o in room.get("openings", []):
		var od: Dictionary = o
		if od.has("art"):
			files.append(String(od.art))
		if od.has("frame"):
			files.append("../" + String(od.frame))
		if String(od.type) == "open" and not od.has("runs") 				and StationRoom._hole_runs(StringName(od.skin)).is_empty():
			notes.append("opening %s has no hole" % od.skin)
	for l in room.get("lamps", []):
		files.append(String(l.art))
		files.append(String(l.glass))
	for g in room.get("glass", []):
		files.append(String(g.art))
	for f in files:
		var path := ShopScene.ROOMS_DIR + f
		if not ResourceLoader.exists(path) or load(path) == null:
			notes.append("cannot load %s" % f)
	var lf := ShopScene.ROOMS_DIR + String(room.light.file)
	var img := Image.new()
	if not FileAccess.file_exists(lf) or img.load_png_from_buffer(
			FileAccess.get_file_as_bytes(lf)) != OK:
		notes.append("no light")
	elif img.get_width() != int(ls[0]) or img.get_height() != int(ls[1]) * 4:
		notes.append("light is %dx%d" % [img.get_width(), img.get_height()])
	# THE EXCHANGE'S VIEW, pixel for pixel (`room_install.view_masks`): the
	# room's size, with space showing for every size of hold. A missing or blank
	# one lights the view like the room, which is the grey ring round it back.
	if room.has("hold"):
		var vf := ShopScene.ROOMS_DIR + String((room.light as Dictionary).get("view", ""))
		var vi := Image.new()
		if not FileAccess.file_exists(vf) or vi.load_png_from_buffer(
				FileAccess.get_file_as_bytes(vf)) != OK:
			notes.append("no view")
		elif vi.get_size() != Vector2i(ShopScene.PANEL):
			notes.append("view is %dx%d" % [vi.get_width(), vi.get_height()])
		else:
			vi.convert(Image.FORMAT_RGB8)
			var px := vi.get_data()
			var seen := [false, false, false]
			for i in range(0, px.size(), 3):
				for c in 3:
					if px[i + c] > 127:
						seen[c] = true
				if seen[0] and seen[1] and seen[2]:
					break
			for c in 3:
				if not seen[c]:
					notes.append("no view for a %s hold" % ExchangeScene.VIEW_SIZES[c])
	for key in ["rack", "hold", "till"]:
		if not room.has(key):
			continue
		var fr: Dictionary = room[key]
		# A HOLD IS JUDGED BY WHAT IS DRAWN, at each of its sizes: the frame's
		# painted pixels, and the grid standing in its opening. Its box is the
		# heavy frame's picture, clear margins and all, and Jon hangs his with
		# those margins past the wall's edge -- four of his five Exchanges,
		# every painted pixel inside (2026-09-27).
		if key == "hold":
			var panel := Rect2(Vector2.ZERO, ShopScene.PANEL).grow(0.5)
			for z in (fr.get("frames", {}) as Dictionary):
				var f: Dictionary = (fr.frames as Dictionary)[z]
				var at := ExchangeScene.frame_at(fr, String(z))
				var op: Array = f.opening
				if not panel.encloses(Rect2(at.position + Vector2(float(op[0]), float(op[1])),
						Vector2(float(op[2]), float(op[3])))):
					notes.append("the %s hold's grid off the room" % z)
				var path := ShopScene.ROOMS_DIR + String(f.art)
				if ResourceLoader.exists(path):
					var used := (load(path) as Texture2D).get_image().get_used_rect()
					if not panel.encloses(Rect2(at.position + Vector2(used.position), Vector2(used.size))):
						notes.append("the %s frame off the room" % z)
			continue
		var box := Rect2(float(fr.x), float(fr.y), float(fr.w), float(fr.h))
		if box.position.x < 0.0 or box.end.x > ShopScene.PANEL.x + 0.5 \
				or box.end.y > ShopScene.PANEL.y + 0.5:
			notes.append("%s off the room" % key)
	print("  %-22s %d pictures  %s" % [room.slug, files.size(),
		"ok" if notes.is_empty() else ", ".join(notes)])
	return 0 if notes.is_empty() else 1


## ---------------- the three families that are still drawn ----------------
##
## Same philosophy as the two above and it is worth restating, because these
## three start at zero: MISSING IS NOT A FAILURE. Every one of them has a
## procedural drawing behind it that is the designed fallback, so what is
## counted is coverage and what is FAILED is a file that exists and is the wrong
## size -- the one mistake that cannot be seen from a filename.
##
## THIS IS ALSO THE SEAM'S OWN GATE. The screens these appear on are not
## reproducible frame to frame -- the station strobes, the beacon's rings and the
## enemy bob all move on wall-clock time, and two runs of identical code differ
## by tens of thousands of pixels -- so "the picture did not change" cannot be
## tested by comparing shots. What CAN be tested is that with no files on disk
## every loader answers null and every drawing site therefore takes the path it
## always took. That is what the counts below are for.

## The enemy canvas, from `EnemyArt`. A sprite has to fit inside it; it does not
## have to fill it, and it never will -- a hull is about 150x40 in a 240x120
## frame, and the Control crops to the ink afterwards.
const ENEMY_CANVAS := Vector2i(240, 120)

## The sector arena, in game pixels, at its narrowest. The row splits its width
## between the ship slot and the place, and `EncounterView` records the arena as
## 378 rows; 460 is the measured slot width in `docs/briefs/ART_SIZES.md`. A
## place wider than this cannot be seen whole, which is a fault in the art.
const PLACE_ARENA := Vector2i(460, 378)


func _enemies() -> Dictionary:
	var drawn := 0
	var missing := 0
	var wrong := 0
	var ids: Array = DB.enemies.keys()
	ids.sort()
	var shown := false
	for raw in ids:
		var id: StringName = raw
		var t = DB.enemies[id]
		var tex: Texture2D = DB.enemy_sprite(id)
		if tex == null:
			missing += 1
			continue
		drawn += 1
		var w := tex.get_width()
		var h := tex.get_height()
		var note := "ok"
		if w > ENEMY_CANVAS.x or h > ENEMY_CANVAS.y:
			note = "TOO BIG for the %dx%d canvas" % [ENEMY_CANVAS.x, ENEMY_CANVAS.y]
			wrong += 1
		if not shown:
			print("\n=== ENEMIES (%d kinds) ===" % ids.size())
			shown = true
		print("  %-14s %-10s %-9s %s" % [id, t.art if t != null else "-",
			"%dx%d" % [w, h], note])
	return {"drawn": drawn, "missing": missing, "wrong": wrong}


## The pictures a sector can show. Named rather than derived from `NodeType`,
## because the picture does not follow the type -- see
## `EncounterView.AreaView._place_name`, which is the one line that decides.
## START is not here on purpose: empty space is the picture.
const PLACES: Array[StringName] = [&"station", &"derelict", &"battlefield",
	&"battlefield_cleared", &"beacon", &"core", &"pulsar"]


func _places() -> Dictionary:
	var drawn := 0
	var missing := 0
	var wrong := 0
	var shown := false
	for name in PLACES:
		var tex: Texture2D = DB.place_sprite(name)
		if tex == null:
			missing += 1
			continue
		drawn += 1
		var w := tex.get_width()
		var h := tex.get_height()
		var note := "ok"
		if w > PLACE_ARENA.x or h > PLACE_ARENA.y:
			note = "TOO BIG for the %dx%d arena" % [PLACE_ARENA.x, PLACE_ARENA.y]
			wrong += 1
		if not shown:
			print("\n=== SECTOR PLACES (%d) ===" % PLACES.size())
			shown = true
		print("  %-22s %-9s %s" % [name, "%dx%d" % [w, h], note])
	return {"drawn": drawn, "missing": missing, "wrong": wrong}


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
		if m.manufacturer in MANUFACTURERS:
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
