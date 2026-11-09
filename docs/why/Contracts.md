The reasoning behind `tkg/scripts/systems/Contracts.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Board

Above `const OFFERS := 2`:

```text
What a station's manufacturer wants doing, and what it pays.

POSITIONAL, like the shelf and the wreck. What is on a station's board is
drawn from `Rng.derive(&"work", node.index)`, so it is a property of the place
rather than of who walked in — four ships docking in four different orders see
one board, and it is the same board on the second visit as on the first.

NOT CONTESTED, unlike the shelf. Two ships can both take the same contract and
both deliver it. A shelf holds one Legendary and a job holds as many hands as
want it; the thing being paid for is the flying, and both of them flew. See
`netcode.md` "One kill, one bag" for the shape it is deliberately NOT.

Nothing here expires. See ContractData's header for why that is a rule rather
than an omission.
```

Above `static func board(n: MapGen.MapNode) -> Array:`:

```text
What this station is offering. Every station posts work (Jon, Nov 3: all five
decks at every station); one with no berth posts it for its dock desk (`dock_desk`).
Empty off a station, and rarely at one: an offer with nowhere to send you is
not posted, so a board with no ordinary system within reach can be bare.

Idempotent and derived — nothing is stored on the node. A board that was
generated once and saved would be a board that could drift from the seed, and
there is nothing here a seed cannot say.
```

## Heat asks

Above `const HEAT_MIN := 4`:

```text
How much heat a berth will ask for. Small, because `RunState.cool_in_transit()`
sheds half a jump's worth every time you move: arriving anywhere with heat on
the hull means having chosen not to cool down, and that choice is the whole
mechanic. Anything larger than this is not a contract, it is a demand that you
fly hot for six jumps, which is the ambush layer being weaponised against the
player rather than offered to them.
```

## Dock desk

Above `static func dock_desk(n: MapGen.MapNode) -> StringName:`:

```text
WHO POSTS WORK AT A STATION WITH NO BERTH (Jon, Nov 3: every station has all
five decks, the HIRING BOARD among them). One manufacturer, drawn off the
station's own position, so it is the same desk on every visit, for every ship
in a party and on a save from before this existed: it is derived, never
stored. That desk also takes delivery here (`ContractData.berth_of`).

A DESK, NOT A BERTH. It hangs no banner, sets no shelf, holds no territory
and gives no standing price; all of those read `berths` or `manufacturer`,
and this is neither. Any manufacturer can be drawn, as a berth can: a locked
one's fetch is already a crate with no markings (`_item`).

Empty for anything but a station, and for a station that has a berth.
Ported from the station study's `-- sim alldecks` (Nov 3), so its numbers stand.
```

Above `static func dock_desk_from(index: int, table: Dictionary) -> StringName:`:

```text
The desk for station `index` out of `table`'s ids. Split from `dock_desk` so
StationDeckTest can hand it a table whose StringNames were made out of text
order. By their TEXT (`NetSession.sorted_ids`), never `keys().sort()`: an
Array of StringNames sorts by address, so the same seed's desk moved with how
the process started, and a saved job lost its desk (or two co-op copies
disagreed). The desk is derived, never saved, so this order is the save.
```

## Job targets

Above `static func _target(n: MapGen.MapNode, r: RandomNumberGenerator,`:

```text
Somewhere to send them. Never this system, never the core, and never a place
the map cannot name.

Biased OUTWARD-ish rather than always deeper: a board that only ever points
coreward is a board that is spending the player's fuel on the manufacturer's behalf,
which is the "somebody else's schedule" §6 was worried about. About a third of
the work sits shallower than the station posting it.

ONLY AN ORDINARY SYSTEM, because the work is put there as an event on its
map (`post_goal`) and only an ordinary system holds events: a station IS its
shelf, a pulsar's one thing is its beam, the start is quiet on purpose and
the core is a boss. A fetch used to land on a station a quarter of the time,
where there was nothing to see, and a hunt needed a fight already rolled
there -- which was gone if you had won it before you signed.
```

## Posting the goal

Above `static func post_goal(job: ContractData) -> void:`:

```text
PUT THE WORK WHERE THE NOTE SAYS IT IS. A signed fetch or hunt is an event
on the named system's map -- a pod in orbit of a world, or a contact past the
last orbit -- so the system map, LOCAL and the panel all show it, and doing
it is what readies the contract. Before this nothing was ever put there: a
fetch closed itself on arrival with one log line, and a hunt waited for any
fight you happened to win, so a player who flew to the place found nothing
that said the job was there.

IDEMPOTENT, and called from both doors: signing (`RunState.take_contract`)
and arriving (`Router.settle_arrival`). One untaken event per kind per
system serves every open job of that kind there. A hunt whose event was spent
without the kill -- you fled the fight -- gets a new one on the next arrival.

PER SHIP. The event is written onto this machine's node only, because the
contract is this ship's alone (see the header: not contested); the claim
that would race a partner for it is skipped (`OptionTable.is_job`).
```

## Fetch items

Above `static func _item(manufacturer: StringName, r: RandomNumberGenerator) -> String:`:

```text
What got left out there. A NAME AND NOTHING ELSE — see recover().

Only a part this run can find (`LootGen.can_appear`): a Solari station on a
profile that has not unlocked Solari still posts its work, but the crate it
asks for is unmarked rather than named after a part the player has never
seen and cannot meet.
```

## Heat contracts

Above `static func heat_deliverable_at(n: MapGen.MapNode) -> Array:`:

```text
Heat contracts you could close RIGHT NOW, standing where you are.

Separate from deliverable_at() because a heat contract is never READY out in
the dark — it becomes closable at the moment you dock still carrying the heat,
and it stops being closable the moment you vent. It is the one job whose
completion is a fact about this second.
```

## Fetch contracts

Above `static func reach_target(index: int) -> void:`:

```text
Taking the pickup finishes any FETCH pointed at this system.

Called by the pickup's own event (`OptionTable` `job_pickup`), which
`Contracts.post_goal` puts on the named system's map; and on arrival
(`Router.settle_arrival`) only for a fetch naming a place that cannot hold
an event, which nothing signed now does. A recovered item is
NAMED AND NOT CARRIED: it does not take a hold slot, cannot be scrapped by
accident and cannot be lost to a full hold. A contract that soft-locks on
inventory is a bug wearing a decision's clothes, and there is no version of
"you sold the thing you were paid to fetch" that is worth what it costs.
```

## Delivery markers

Above `static func delivery_manufacturers() -> Array:`:

```text
Manufacturers with something waiting to be handed over: a heat contract you are
carrying the heat for, or any job you have already finished out there.

THE THIRD THING THE CHART HAS TO MARK. A fetch and a hunt point at a place
before you go; this points at a place afterwards, and a heat contract points
at one and never had a target at all. Without it the chart answers "where is
the work" and goes silent on "where do I take it", which is the half of the
trip that actually costs fuel.
```
