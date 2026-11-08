extends Harness

## Missing art is counted, never failed on; only art of the wrong size, by a wide margin, fails.
## Why: docs/why/ArtCheck.md#coverage-gate


## Cards come from these manufacturers' modules plus malfunctions.
## The empty name is unbranded, a real key.
const MANUFACTURERS: Array[StringName] = [&"korvan", &"", &"solari"]

## How far past its box a part may stand before it is a fault, in art pixels.
## Half a cell. Beyond that it is not a gun on a mount, it is a gun beside one.
const PROUD := 8

## Card art is 92 wide in a 93 window: `create_image_pixflux` refuses an odd side at this size.
## Why: docs/why/ArtCheck.md#card-art-width
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

	# `artcheck cards` is tab separated for scripts and carries `glyph_kind`, the game's taxonomy.
	# Why: docs/why/ArtCheck.md#card-dump
	if "cards" in OS.get_cmdline_user_args():
		print("
=== CARD MANIFEST ===")
		for row in cards:
			var c: CardData = row["card"]
			var src: ModuleData = DB.modules.get(StringName(str(row["from"])))
			# Description, type and glyph are included so briefs know what a card does.
			# Why: docs/why/ArtCheck.md#card-dump
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


## Shop room data fails silently with no designed fallback, so each fault is counted.
## Why: docs/why/ArtCheck.md#shop-rooms
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
	# The Exchange's view, pixel for pixel: a missing or blank mask lights the view like the room.
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
		# A hold is judged by what is drawn: Jon hangs frames with margins past the wall.
		# Why: docs/why/ArtCheck.md#hold-judging
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


## Missing is not a failure: with no files every loader returns null, which gates the seam.
## Why: docs/why/ArtCheck.md#drawn-families

## A sprite must fit the enemy canvas but need not fill it; the Control crops to the ink.
const ENEMY_CANVAS := Vector2i(EnemyArt.W, EnemyArt.H)

## Narrowest sector arena (460 x 378, `docs/briefs/ART_SIZES.md`); wider cannot be seen whole.
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


## Named, not derived from `NodeType`, as the picture does not follow the type; START is empty.
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


## Derived from the numbers `MountPoints.part_rect` uses, so retuning the hold keeps this honest.
## Why: docs/why/ArtCheck.md#module-box
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


## A SHARED card reached through two modules is one illustration and is counted once.
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
