class_name CreditChit
extends HoldItem

## It never occupies a cell: `stow` cashes it, so a full hold cannot refuse money.
## Credits become an object in the container, so money and parts are not two kinds of event.
## Why: docs/why/CreditChit.md#credit-chit

## Said once: `HudBar` and the chit share one rule, as two sentences would disagree.
## Why: docs/why/CreditChit.md#what-money-is
const WHAT_MONEY_IS := "Credits are the only currency.\nRepairs, upgrades and purchases all come out of the same balance."

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
