class_name CreditChit
extends HoldItem

## It never occupies a cell: `stow` cashes it, so a full hold cannot refuse money.
## Credits become an object in the container, so money and parts are not two kinds of event.
## DATA is not money: no chit, never in a hold.
## Why: docs/why/CreditChit.md#credit-chit

## Said once: `HudBar` and the chit share one rule, as two sentences would disagree.
## Credits only: the top bar's CREDITS adds `WHAT_DATA_IS` beside it.
## Why: docs/why/CreditChit.md#what-money-is
const WHAT_MONEY_IS := "Credits pay for repairs, fuel, parts and upgrades."

## WHAT DATA IS, said once: the top bar's DATA readout, and the second line of
## its CREDITS one. Where it comes from, where it goes, and that it is not money.
const WHAT_DATA_IS := "DATA comes from readings out in the systems. You can't buy or sell it. Only a lab takes it."

## What it is worth. Set when the chit is minted; nothing rolls it afterwards.
@export var amount: int = 0


static func of(credits: int) -> CreditChit:
	var c := CreditChit.new()
	c.amount = maxi(0, credits)
	c.name = "%d CREDITS" % c.amount
	# One cell, because it has to be drawn somewhere and a note is small. The
	# size is never consulted for whether it fits -- see the class note.
	c.size = Vector2i.ONE
	return c


func hold_line() -> String:
	return name
