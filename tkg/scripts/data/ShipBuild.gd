class_name ShipBuild
extends RefCounted

## One ship, described well enough to draw it — and small enough to send.
##
## Every screen used to draw the player's ship by reaching into `Run` for the
## hull, the fitted modules, the hull points and the heat. That is correct for
## exactly one ship: yours. A party has up to four, three of which are being
## flown on other machines, so the renderer needs a SUBJECT rather than a
## global. This is that subject, and `ShipView` now takes one.
##
## Two rules decide what is in here and what is not.
##
## **It carries what is drawn, not what is played.** No cards, no affixes, no
## rolled stats. A partner's Chatterbox has an affix on it and a scrap value and
## eleven other fields; none of that changes a single pixel, and every one of
## them would be on the wire four times a second. What changes pixels is the
## hull's weight and maker, which hardpoint each part sits on, who built it, and
## the two gauges the art reacts to — heat and damage.
##
## **Identity travels as ids, never as objects.** `to_wire()` sends a
## manufacturer and a weight class rather than a `HullData`, and a module id
## rather than a `ModuleData`. Both machines already hold the same content
## tables — `NetSession.content_fingerprint()` refuses the join otherwise — so
## sending the tables again would be sending a copy of something already agreed.
##
## A looted hull is a `duplicate()` of a catalogue frame with its numbers rolled
## up, so maker plus weight names its APPEARANCE exactly. Tier is not sent for
## that reason: an A-tier Korvan Frigate and a C-tier one are the same picture.

## Who is flying it. Empty for your own ship, which needs no label.
var pilot: String = ""
var hull: HullData = null
## What is bolted on, as `{slot, mount, maker, id}`. Plain dictionaries rather
## than `ModuleData` on purpose: a remote part has to be resolved from the
## catalogue, and the catalogue entry is SHARED — writing the sender's `mount`
## onto `DB.modules[id]` would move that hardpoint on every ship in the game.
var parts: Array = []

var hp: int = 1
var max_hp: int = 1
var heat: int = 0
var heat_cap: int = 1
var dead: bool = false


## The ship you are flying, as it stands right now.
static func local() -> ShipBuild:
	var b := ShipBuild.new()
	b.hull = Run.hull
	# Before a run, and on the title screen. Every gauge below sums over the
	# hull, so asking one of them here is an error rather than a zero.
	if b.hull == null:
		return b
	for m in Run.installed:
		b.parts.append({
			"slot": int(m.slot),
			"mount": maxi(m.mount, 0),
			"maker": m.manufacturer,
			"id": m.id,
		})
	b.hp = Run.hp
	b.max_hp = maxi(1, Run.max_hp())
	b.heat = Run.heat
	b.heat_cap = maxi(1, Run.heat_cap())
	b.dead = Run.dead
	return b


## A hull nobody owns yet: bare, cold and undamaged.
##
## This is what the chassis select shows, and it replaces the `preview` flag
## `ShipView` used to carry. A showroom ship is not a special MODE of the
## renderer — it is an ordinary build that happens to have no parts on it and
## full hull points, so every "suppress this when previewing" branch in the
## drawing code stopped needing to exist.
static func showroom(h: HullData) -> ShipBuild:
	var b := ShipBuild.new()
	b.hull = h
	if h != null:
		b.hp = maxi(1, h.max_hull)
		b.max_hp = maxi(1, h.max_hull)
		b.heat_cap = maxi(1, h.heat_cap)
	return b


## Heat as a fraction of capacity, which is what the palette shift reads.
## Capped at 1.7 because past that the ship is already white and the extra
## only moves numbers.
func heat_ratio() -> float:
	return minf(1.7, float(heat) / float(maxi(1, heat_cap)))


## How beaten up, 0 to 1. Drives where the scorch marks go.
func damage() -> float:
	return 1.0 - float(hp) / float(maxi(1, max_hp))


# --- the wire -------------------------------------------------------------

func to_wire() -> Dictionary:
	return {
		"pilot": pilot,
		"maker": hull.manufacturer if hull != null else &"",
		"weight": int(hull.weight) if hull != null else int(HullData.Weight.MEDIUM),
		"parts": parts,
		"hp": hp,
		"max_hp": max_hp,
		"heat": heat,
		"heat_cap": heat_cap,
		"dead": dead,
	}


## Everything read here came off a socket, so everything read here is checked.
##
## Not because a peer is expected to lie — the handshake already refused anyone
## whose content tables differ — but because this is the only door remote data
## uses to reach the renderer, and the renderer dereferences a hull. A weight
## class of 99 resolves to no hull at all, and the convoy slot that asks that
## hull for its manufacturer takes the sector screen down with it.
static func from_wire(d: Dictionary) -> ShipBuild:
	var b := ShipBuild.new()
	b.pilot = String(d.get("pilot", ""))
	var w := clampi(int(d.get("weight", int(HullData.Weight.MEDIUM))),
		int(HullData.Weight.LIGHT), int(HullData.Weight.HEAVY)) as HullData.Weight
	b.hull = DB.hull_for(StringName(d.get("maker", &"")), w)
	# Falling back to the unbranded frame of the same class rather than to
	# nothing. A maker the catalogue does not build in that class cannot happen
	# behind the content fingerprint, so this is not a compatibility path — it is
	# the difference between a partner drawn as the wrong hull and a partner not
	# drawn at all, and the first one is far easier to notice and report.
	if b.hull == null:
		b.hull = DB.hull_for(&"", w)
	var sent: Variant = d.get("parts", [])
	b.parts = sent if sent is Array else []
	b.hp = int(d.get("hp", 1))
	b.max_hp = maxi(1, int(d.get("max_hp", 1)))
	b.heat = int(d.get("heat", 0))
	b.heat_cap = maxi(1, int(d.get("heat_cap", 1)))
	b.dead = bool(d.get("dead", false))
	return b


## What the sprite would be. The catalogue entry, NOT a copy — nothing here
## writes to it. Null while a module has no art, which is most of them: see
## `art/ART_CONTRACT.md` for the order the assets arrive in.
static func art_for(part: Dictionary) -> ModuleData:
	return DB.modules.get(StringName(part.get("id", &"")))
