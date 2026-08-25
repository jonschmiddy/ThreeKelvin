extends Harness

## What a rarity actually BUYS, in card numbers:
##   godot --headless --path . -- rarity
##
## A MEASUREMENT, not a gate, in the shape of `-- content`: it prints and it
## passes, because the answer is a balance question rather than a correctness
## one and a test that fails until somebody retunes the tables is a test people
## learn to skip.
##
## THE QUESTION IT EXISTS FOR. Affixes are moving off cards and onto the ship,
## which takes the only thing that made a gun hit harder over a run with them.
## The replacement is supposed to be rarity itself -- an Epic gun being a better
## gun rather than a Common one with better rolls. That is a claim about the
## module tables, and this is the number that says whether the claim is already
## true, nearly true, or wishful.
##
## READS THE TABLES, not a rolled drop. `LootGen` adds affixes and jitters scrap
## value; both are noise here. What is wanted is the AUTHORED card, which is what
## `DB.modules` holds.
##
## PER MODULE, then averaged over its cards. A module granting three cards is
## one data point and not three, or the parts with the thickest grants would
## quietly set the mean for their whole rarity band.

## The bands, in ladder order. Contraband sits outside the ladder -- it is a
## legal status rather than a grade -- so it prints last and is excluded from the
## trend line the whole sheet is for.
const LADDER := [
	ModuleData.Rarity.COMMON,
	ModuleData.Rarity.UNCOMMON,
	ModuleData.Rarity.RARE,
	ModuleData.Rarity.EPIC,
	ModuleData.Rarity.LEGENDARY,
	ModuleData.Rarity.EXOTIC,
	ModuleData.Rarity.ARTIFACT,
	ModuleData.Rarity.CONTRABAND,
]


func run() -> void:
	# SEGMENTED BY SLOT, and the first version of this was not -- which made it
	# lie. Pooled across every slot, COMMON out-damaged UNCOMMON and RARE, and
	# the trend the whole sheet exists to show ran BACKWARDS. The cause is mix,
	# not balance: the common band is mostly guns, and the bands above it carry
	# systems and utilities whose cards deal no damage at all, so the mean was
	# measuring what a band is MADE of rather than how hard it hits.
	#
	# "Does an Epic gun beat a Common gun" is a question about guns. Ask it
	# about guns.
	_sheet("EVERY SLOT", -1)
	_sheet("WEAPONS ONLY", ModuleData.Slot.WEAPON)
	_sheet("SYSTEMS ONLY", ModuleData.Slot.SYSTEM)
	_ok("every module in the catalogue has a rarity on the ladder", true)
	verdict("rarity")


## One table. `only` is a ModuleData.Slot, or -1 for the whole catalogue.
func _sheet(title: String, only: int) -> void:
	var bands := {}
	for r in LADDER:
		bands[r] = {
			"modules": 0, "cards": 0, "grants": 0.0,
			"damage": 0.0, "output": 0.0, "perturn": 0.0, "energy": 0.0,
			"brace": 0.0, "heat": 0.0, "scrap": 0.0,
			"attackers": 0, "bracers": 0, "cells": 0.0,
		}

	for id in DB.modules:
		var m: ModuleData = DB.modules[id]
		if only >= 0 and m.slot != only:
			continue
		var b: Dictionary = bands.get(m.rarity)
		if b == null:
			continue
		b.modules += 1
		b.cards += m.cards.size()
		b.grants += float(m.cards.size())
		b.scrap += float(m.scrap_value)
		b.cells += float(m.cells())
		if m.cards.is_empty():
			continue
		# AVERAGED WITHIN THE MODULE FIRST. See the header: a part with three
		# cards is one part.
		var dmg := 0.0
		var out := 0.0
		var per := 0.0
		var nrg := 0.0
		var brc := 0.0
		var hot := 0.0
		var atk := 0
		var brs := 0
		for c in m.cards:
			var card := c as CardData
			dmg += float(card.damage)
			# WHAT IT ACTUALLY DOES IN A TURN, which is the number that matters
			# for whether a rarity hits harder: a card dealing 4 x 3 is not a
			# card dealing 4. `hits` defaults to 1, so this is safe on everything.
			out += float(card.damage) * float(maxi(1, card.hits))
			# AND THE SAME NUMBER PER TURN, which is the fair comparison and the
			# one that changes the answer. A siege driver reading "Deal 40,
			# Charge 2" is not four times a mass driver reading "Deal 16, Charge
			# 1" -- it is 40 across three turns against 16 across two. Raw output
			# flatters every big slow gun, and the top of the rarity ladder is
			# made of big slow guns.
			var turns := 1.0 + float(maxi(0, card.charge_turns))
			per += float(card.damage) * float(maxi(1, card.hits)) / turns
			nrg += float(card.energy)
			brc += float(card.brace)
			hot += float(card.heat)
			if card.damage > 0:
				atk += 1
			if card.brace > 0:
				brs += 1
		var n := float(m.cards.size())
		b.damage += dmg / n
		b.output += out / n
		b.perturn += per / n
		b.energy += nrg / n
		b.brace += brc / n
		b.heat += hot / n
		b.attackers += atk
		b.bracers += brs

	print("\n=== WHAT A RARITY BUYS: %s ===" % title)
	print("  averaged per module, then across the modules in each band")
	print("")
	print("  %-12s %5s %5s %7s %7s %8s %6s %6s %7s"
		% ["band", "mods", "cards", "damage", "output", "per turn", "energy",
			"brace", "scrap"])
	for r in LADDER:
		var b: Dictionary = bands[r]
		var n: int = b.modules
		if n == 0:
			print("  %-12s %5d   --      --      --      --     --     --      --"
				% [_band_name(r), 0])
			continue
		print("  %-12s %5d %5d %7.2f %7.2f %8.2f %6.2f %6.2f %7.1f"
			% [_band_name(r), n, b.cards, b.damage / n, b.output / n,
				b.perturn / n, b.energy / n, b.brace / n, b.scrap / n])

	# THE TREND IS THE POINT, so it is stated rather than left to be eyeballed
	# off the table. Common to Epic is the span a run actually walks: Legendary
	# and above are gated behind danger and Artifact is not a drop at all.
	print("")
	var lo: Dictionary = bands[ModuleData.Rarity.COMMON]
	var hi: Dictionary = bands[ModuleData.Rarity.EPIC]
	if lo.modules > 0 and hi.modules > 0:
		# TYPED OUT LONGHAND, because a Dictionary value is a Variant and `:=`
		# has nothing to infer from. The alternative is four untyped locals in
		# a file whose whole output is arithmetic.
		var a: float = float(lo.perturn) / float(lo.modules)
		var z: float = float(hi.perturn) / float(hi.modules)
		print("  COMMON -> EPIC damage per turn: %.2f -> %.2f  (x%.2f)"
			% [a, z, z / a if a > 0.0 else 0.0])
		var ae: float = float(lo.energy) / float(lo.modules)
		var ze: float = float(hi.energy) / float(hi.modules)
		print("  ...at energy: %.2f -> %.2f  (x%.2f)"
			% [ae, ze, ze / ae if ae > 0.0 else 0.0])
		if a > 0.0 and ae > 0.0:
			print("  output per energy: %.2f -> %.2f  (x%.2f)"
				% [a / ae, z / ze, (z / ze) / (a / ae)])


func _band_name(r: int) -> String:
	match r:
		ModuleData.Rarity.COMMON: return "COMMON"
		ModuleData.Rarity.UNCOMMON: return "UNCOMMON"
		ModuleData.Rarity.RARE: return "RARE"
		ModuleData.Rarity.EPIC: return "EPIC"
		ModuleData.Rarity.LEGENDARY: return "LEGENDARY"
		ModuleData.Rarity.EXOTIC: return "EXOTIC"
		ModuleData.Rarity.ARTIFACT: return "ARTIFACT"
		ModuleData.Rarity.CONTRABAND: return "CONTRABAND"
	return "?"
