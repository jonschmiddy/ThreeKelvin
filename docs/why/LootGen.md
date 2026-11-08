The reasoning behind `tkg/scripts/systems/LootGen.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Shallow loot

Inside `roll_module()`, above `if danger >= NO_COMMON_TIER:`:

```text
AND SHALLOW LOOT STAYS SHALLOW (Jon, Oct 22: a hard game, where going deep
is worth it). From halfway in -- tier 3, danger 5 -- no COMMON is rolled,
by any source: wreck, bag, derelict, event, relic analysis, shelf, the
custodian. Taken out of the pool built above rather than skipped inside
the loop, so a pool this would empty (a Territory forcing a manufacturer
with nothing above Common here) keeps its commons instead of collapsing to
the one hard-coded part below.
```

## Manufacturer gate

Above `static func can_appear(manufacturer: StringName) -> bool:`:

```text
True when a manufacturer's parts and hulls may appear in this run: it is
switched on (`DB.ACTIVE_MANUFACTURERS`) AND this run has it unlocked
(`Run.unlocked_manufacturers`, read off the flight record at run start --
see `Unlocks.open_now`). Unbranded (manufacturer &"") always passes, so a
fresh profile's pool is Korvan plus unbranded and is never empty.

THE ONE GATE. Every drop, shelf, yard hull, derelict hull, reward and the
custodian's body is rolled through `roll_module` or `roll_hull`, and both ask
this; a new way to hand the player a part should too.
```

## Affix counts

Above `static func _affix_count(r: ModuleData.Rarity) -> int:`:

```text
EIGHT ENTRIES FOR AN EIGHT-VALUE ENUM. This was seven long against a Rarity
that ends at CONTRABAND, so `_affix_count(CONTRABAND)` indexed past the end.
Nothing in the module tables is authored contraband today and the rarity
upgrade roll caps at LEGENDARY, so it was unreachable rather than broken —
which is the kind of thing that stays unreachable right up until somebody
authors the first contraband part.
```

## Hull pool

Above `static func hull_pool() -> Array[HullData]:`:

```text
The frames a derelict or a yard can offer in this run: the three unbranded
salvage frames always, and every manufacturer's three that `can_appear`.
It drew from all of `DB.hull_frames` -- every manufacturer's, whatever was
switched on or unlocked -- so a fresh profile met Solari, Probate and Calyx
chassis on the blocks before it could fly any of them. Never empty: the
salvage frames carry no manufacturer.
```

## Hull grades

Above `const GRADES_AT := {`:

```text
A hull off a wreck. Draws from `hull_pool()`, so a derelict can offer either
an unbranded salvage frame or somebody's chassis — and a found chassis moves
your set count, which is what makes "should I take it" a question with more
than one number in it.

The perk is REROLLED even on a manufacturer hull, unlike the one you start
with, which keeps the perk its manufacturer authored. A ship you were handed at the
yard is to spec; a ship you cut out of a wreck is whatever it ended up as.
WHAT GRADE A YARD AT EACH TIER CAN OFFER, authored rather than derived.

It was `int(danger / 1.6) + randi() % 2`, which put C on tier 1 alone -- the
first ring or two of a fifteen-layer galaxy, and half of those rolls came out
B anyway. So the bottom grade barely existed, and "bad ships on the outskirts"
was a thing the arithmetic technically allowed rather than a thing you saw.

Weighted by repetition, which is the same trick `TIER_DELTA` uses: a grade
listed twice is twice as likely. Read down the columns and the ladder is
legible -- C through the outer half, S only in the inner.

  tier 1  C C B        outskirts: scrap, and the occasional decent frame
  tier 2  C B B
  tier 3  C B B A      the middle: a C is still possible and still cheap
  tier 4  B A A S      S becomes reachable
  tier 5  A S S        the core, where a bad ship would be a story
```

## C-tier oddity

Inside `roll_hull()`, above `if t == 0:`:

```text
A C-TIER CARRIES SOMETHING ODD, and this is the only reason to buy one.

`DB.tier_perks_for` starts at B, so a C has exactly one perk -- the
manufacturer's -- which is also all a STARTER hull has. Against the ship you
launched in, a C on the blocks was smaller, weaker, had fewer mounts and
offered nothing the starter did not: a purchase with no argument for it at
any price. One extra perk is the argument. It is a cheap frame somebody
else fitted out, and what they left in it is the point.

ON THE HULL, NOT THE LADDER. Putting it in `TIER_PERKS` would grant it to
every C in the game including the one the player starts in, which is a
different change and not this one.
```
