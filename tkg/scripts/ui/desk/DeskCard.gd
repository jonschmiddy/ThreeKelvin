class_name DeskCard
extends RefCounted

## What the desk's monitor shows, at the glass's art size (150 x 140): the title card (the page's
## `buildTitle`, its 3x5 font and petri-dish emblem, naming the science site; Jon's ruling, Nov 19)
## and the reading's outcome, typed in the same phosphor green. With no site named, the card is the
## page's own (CULTURE DISH), so `-- sheet=DeskRooms` can be held to the page's frames.
## Why: docs/why/DeskScene.md#jons-rulings-nov-19

const W := 150
const H := 140
const PAGE_NAME: Array[String] = ["CULTURE", "DISH"]
const PAGE_BLURB: Array[String] = ["DROP SEEDS SO THE GROWING CULTURE", "REACHES EVERY FOOD SPECK", "AND NO STAIN."]
const PROMPT := "> TAP TO BEGIN"
const FIELD := Color8(7, 13, 11)
const G := [140, 236, 172]
const GD := [70, 130, 96]
const GB := [190, 255, 214]
## The page's font, and the few marks an outcome's sentence needs that the page never typed.
const F35 := {
	"A": "010101111101101", "B": "110101110101110", "C": "011100100100011", "D": "110101101101110",
	"E": "111100110100111", "F": "111100110100100", "G": "011100101101011", "H": "101101111101101",
	"I": "111010010010111", "J": "001001001101010", "K": "101101110101101", "L": "100100100100111",
	"M": "101111111101101", "N": "110101101101101", "O": "010101101101010", "P": "110101110100100",
	"Q": "010101101110011", "R": "110101110101101", "S": "011100010001110", "T": "111010010010010",
	"U": "101101101101111", "V": "101101101101010", "W": "101101111111101", "X": "101101010101101",
	"Y": "101101010010010", "Z": "111001010100111", "0": "010101101101010", "1": "010110010010111",
	"2": "110001010100111", "3": "110001010001110", "4": "101101111001001", "5": "111100110001110",
	"6": "011100110101010", "7": "111001010010010", "8": "010101010101010", "9": "010101011001110",
	"-": "000000111000000", ">": "100010001010100", ".": "000000000000010", ",": "000000000010100",
	"/": "001001010100100", " ": "000000000000000", "!": "010010010000010",
	"'": "010010000000000", ":": "000010000010000", "?": "110001010000010", "+": "000010111010000",
	"(": "001010010010001", ")": "100010010010100", "%": "101001010100101",
}


static func _put(img: Image, x: int, y: int, c: Array, a: float = 0.0) -> void:
	if x < 0 or y < 0 or x >= W or y >= H:
		return
	img.set_pixel(x, y, Color(float(c[0]), float(c[1]), float(c[2]), a))


static func _text(img: Image, s: String, x0: int, y0: int, sc: int, c: Array, a: float = 0.0) -> void:
	for n in s.length():
		var g: String = F35.get(s[n], F35[" "])
		for gy in 5:
			for gx in 3:
				if g[gy * 3 + gx] == "1":
					for sy in sc:
						for sx in sc:
							_put(img, x0 + n * 4 * sc + gx * sc + sx, y0 + gy * sc + sy, c, a)


static func _wide(s: String, sc: int) -> int:
	return s.length() * 4 * sc - sc


static func _ctr(img: Image, s: String, y: int, sc: int, c: Array, a: float = 0.0) -> void:
	_text(img, s, int(round((W - _wide(s, sc)) / 2.0)), y, sc, c, a)


## Words fitted to `cols` characters a line (the font's whole set: upper case, unknowns a space).
static func wrap_words(words: String, cols: int) -> Array[String]:
	var out: Array[String] = []
	var line := ""
	for w: String in words.to_upper().split(" ", false):
		var clean := ""
		for ch in w:
			clean += ch if F35.has(ch) else " "
		if line == "":
			line = clean
		elif line.length() + 1 + clean.length() <= cols:
			line += " " + clean
		else:
			out.append(line)
			line = clean
	if line != "":
		out.append(line)
	return out


## The title card (RGBAF, 0..255 a channel; alpha 1 on the prompt, which blinks). `name` empty: the page's.
## `tell`: a mini game's one line and control icons ({text, controls}), under the name.
static func title(name: String, tell: Dictionary = {}) -> Image:
	var img := Image.create(W, H, false, Image.FORMAT_RGBAF)
	img.fill(Color(7, 13, 11, 0))
	_text(img, "SCI-TERM 03", 5, 5, 1, GD)
	for x in range(5, 145, 2):
		_put(img, x, 12, GD)
	var cx := 75
	var cy := 36
	for y in range(cy - 17, cy + 18):
		for x in range(cx - 17, cx + 18):
			var d := Vector2(x - cx, y - cy).length()
			if d <= 16.5 and d > 14.6:
				_put(img, x, y, GB)
			elif d <= 14.6 and d > 13.6:
				_put(img, x, y, GD)
			elif d <= 13.6:
				var cl := Vector2(x - cx + 3, y - cy + 2).length() < 6.5 or Vector2(x - cx - 4, y - cy - 3).length() < 4.2 \
					or Vector2(x - cx + 1, y - cy - 5).length() < 3.2
				_put(img, x, y, G if cl else [34, 70, 52])
	var lines: Array[String] = PAGE_NAME if name == "" else wrap_words(name, 12)
	if lines.size() > 2:
		lines = wrap_words(name, 36).slice(0, 4)
		for n in lines.size():
			_ctr(img, lines[n], 62 + n * 9, 1, GB)
	else:
		for n in lines.size():
			_ctr(img, lines[n], 58 + n * 19, 3, GB)
	if name == "":
		for n in PAGE_BLURB.size():
			_ctr(img, PAGE_BLURB[n], 98 + n * 7, 1, GD)
	elif not tell.is_empty():
		_tell(img, String(tell.get("text", "")).to_upper(), tell.get("controls", []))
	_ctr(img, PROMPT, 127, 1, G, 1.0)
	return img


## The game's one line with its control icons before it (Jon, Nov 17: no action words), in the
## card's phosphor: the icons' light parts bright, their mid tones the card's green.
## Why: docs/why/MiniGame.md#the-shell
static func _tell(img: Image, words: String, kinds: Array) -> void:
	var icons := MiniPix.new(64, 24)
	icons.clear(Color(0, 0, 0, 0))
	var iw := 0
	for k: String in kinds:
		var bits := k.split(":")
		iw += icons.icon(bits[0], iw, 10, 0.0, bits[1] if bits.size() > 1 else "") + 4
	var x0 := int(round((W - (iw + 1 + _wide(words, 1))) / 2.0))
	for y in 24:
		for x in iw:
			var c := icons.img.get_pixel(x, y)
			var l := 0.3 * c.r + 0.59 * c.g + 0.11 * c.b
			if c.a > 0.0 and l > 0.25:
				_put(img, x0 + x, 90 + y, GB if l > 0.6 else G)
	_text(img, words, x0 + iw + 1, 104, 1, GB)


## The card as a still picture for the glass's picture phase (RGBA8): what squeezes away if you
## leave before the reading.
static func still(card: Image) -> Image:
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	for y in H:
		for x in W:
			var c := card.get_pixel(x, y)
			img.set_pixel(x, y, Color8(int(c.r), int(c.g), int(c.b)))
	return img


## The reading's outcome on the glass (RGBA8): the terminal's header, the sentence, the way out.
static func outcome(text: String) -> Image:
	var img := Image.create(W, H, false, Image.FORMAT_RGBAF)
	img.fill(Color(7, 13, 11, 0))
	_text(img, "SCI-TERM 03", 5, 5, 1, GD)
	for x in range(5, 145, 2):
		_put(img, x, 12, GD)
	_text(img, "> READING", 5, 20, 1, G)
	var lines := wrap_words(text, 35)
	for n in mini(lines.size(), 13):
		_text(img, lines[n], 5, 32 + n * 7, 1, GB)
	_text(img, "> TAP TO LEAVE", 5, 127, 1, G)
	return still(img)
