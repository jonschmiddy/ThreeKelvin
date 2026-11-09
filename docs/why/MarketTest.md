The reasoning behind `tkg/scripts/sim/MarketTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Market sweep

Above `var fails: int = 0`:

```text
The market, as one table, and the check that it cannot be gamed.

  godot --headless --path . -- market

RUN THIS AFTER TOUCHING Market.gd. Two jobs, and the second is the reason the
file exists.

FIRST, it proves the invariant by exhaustion. Every combination of the axes a
price is derived from — five development levels, five security levels, the
three manufacturer relationships, five danger tiers, both hull perks, every rarity,
clean and contraband — is priced, and every one is checked for:

    melt < ask       you cannot buy a part and melt it for a profit
    bid  < ask       you cannot sell a part back where you bought it

That is the whole exploit this economy replaced, and it was not a tuning
error: the buy price lived in StationScreen and the melt price lived in
RunState, and neither file had heard of the other. A constant nudged by three
points in the wrong direction reopens it in a way nothing in the game reports
— you simply become rich. Two thousand price comparisons in four seconds is a
cheap way never to wonder again.

SECOND, it prints the table. Prices only mean anything against each other, the
same way the six attributes do, and the same argument applies: reading them
one station at a time in the running game is how you convince yourself a
spread exists that does not.
```

## One price

Above `func _one_price() -> void:`:

```text
THE COUNTER QUOTES THE MARKET, AND THERE IS NO SECOND PRICE.

The Exchange used to have two places to carry a part to: a counter paying the
local bid, and a chute paying `Market.melt` -- a flat rate that is deliberately
NOT a function of where you are. Two prices for one object in one room is a
second currency however it settles up, so the chute is gone and this is the
guard that keeps it gone.

THE TEST IS THAT THE QUOTE MOVES WITH THE PLACE. Asserting the number equals
`Market.bid` would pass just as happily if someone wired the flat rate in and
the two happened to coincide for the part being checked. Saturating the market
separates them by construction: a bid falls as a station takes more, and a
melt price cannot move at all -- so a counter whose quote does not drop is
quoting something other than what this place will bear.

`offer()` reads `Run.node_at()` rather than taking a node, which is why this
runs against the live run instead of the synthetic places above.
```

## Till side

Inside `_one_price()`, above `var till := TradeCounter.offer(part, TradeCounter.Side.CHARGES)`:

```text
--- AND THE OTHER SIDE OF THE SAME DESK.

The Promenade's till charges rather than pays. It is the same class with
`Side.CHARGES` set, and the thing that makes that safe rather than a second
currency is the spread: what the shop asks is always more than what it
bids, which the exhaustive sweep above proves for every place in the game
and this re-checks at the counter the player actually touches.
```

## Desk sides

Inside `_one_price()`, above `var till_desk := TradeCounter.new()`:

```text
--- AND EACH DESK TAKES ONLY FROM ITS OWN SIDE OF THE SHOP.

THIS ONE IS A MONEY BUG IF IT SLIPS, and a silent one. The two counters are
told apart by where the thing was picked up -- `origin` on the drag payload
-- so a till that accepted a part out of your hold would charge you for
something you already own, and an Exchange counter that accepted one off
the shelf would pay you for the shop's own stock.
```
