The reasoning behind `tkg/scripts/data/CreditChit.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Credit chit

Above `const WHAT_MONEY_IS := "Credits are the only currency.\nRepairs, upgrades and purchases all come out of the same balance."`:

```text
Money, as a thing you pick up.

Credits are the money everything is priced in, and `MATERIALS_NOTE` §1 says
materials sell but never price. DATA (science, Jon's pick 1A, Nov 4) is the
one other pool, and it is not money: it comes only from readings, only a lab
takes it, and it never trades with credits, so it has no chit and never sits
in a hold. None of that changes what this is. What changes is that a
payout of credits stops being a number that arrives and becomes an object in
the container with everything else -- because a wreck that hands you a gun by
making you reach for it and hands you money by incrementing a counter is
telling you those are two different kinds of event, and they are not.

IT NEVER OCCUPIES A CELL. That is the whole trick and it is why this is a
`HoldItem` that lies slightly: it has a footprint so the container can draw
it in a cell, and `RunState.stow` cashes it instead of placing it, so it
goes in whatever your hold looks like. A full hold cannot refuse money.

Which means the usual rule -- take the most valuable thing that FITS -- has an
exception, and the exception is the interesting part: this is the one item in
the game where "do I have room" is never the question.
```

## What money is

Above `const WHAT_MONEY_IS := "Credits are the only currency.\nRepairs, upgrades and purchases all come out of the same balance."`:

```text
WHAT MONEY IS, said once.

`HudBar` says this over the balance in the top bar and the chit says it over
the object -- and they were two sentences about one thing, which is how two
sentences about one thing start disagreeing. The chit adds what it is worth
and how much room it takes; the rule underneath is shared. Credits only, now
that DATA exists: the chit's and a material's card (`ChitIcon`,
`MaterialIcon`) are about money, and only the top bar's CREDITS adds
`WHAT_DATA_IS` beside it.
```
