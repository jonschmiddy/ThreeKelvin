class_name CreditChit
extends HoldItem

## Money, as a thing you pick up.
##
## `RunState` says credits are the only currency and `MATERIALS_NOTE` §1 says
## materials sell but never price. None of that changes. What changes is that a
## payout of credits stops being a number that arrives and becomes an object in
## the container with everything else -- because a wreck that hands you a gun by
## making you reach for it and hands you money by incrementing a counter is
## telling you those are two different kinds of event, and they are not.
##
## IT NEVER OCCUPIES A CELL. That is the whole trick and it is why this is a
## `HoldItem` that lies slightly: it has a footprint so the container can draw
## it in a cell, and `RunState.stow` cashes it instead of placing it, so it
## goes in whatever your hold looks like. A full hold cannot refuse money.
##
## Which means the usual rule -- take the most valuable thing that FITS -- has an
## exception, and the exception is the interesting part: this is the one item in
## the game where "do I have room" is never the question.

## WHAT MONEY IS, said once.
##
## `HudBar` says this over the balance in the top bar and the chit says it over
## the object -- and they were two sentences about one thing, which is how two
## sentences about one thing start disagreeing. The chit adds what it is worth
## and how much room it takes; the rule underneath is shared.
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
