The reasoning behind `tkg/scripts/net/SharedFight.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Shared fight overview

Above `const CREW_SHARE: float = 0.6`:

```text

`to_wire` and `from_wire` below are a wire format: a key renamed or added
there is a protocol change (`grown` was PROTOCOL 16). Read by
.github/scripts/version_guard.py.

One fight that more than one ship is in.

This is the enemy, and only the enemy. Everything on YOUR side of a shared
fight — deck, hand, energy, block, brace, heat, hull — stays in `Run` and
`Combat` on your own machine and never crosses the wire, because it never
has to: no other player targets it, spends it or reads it. That asymmetry is
the whole reason joint combat is a small feature rather than a rewrite. The
contested object in a fight is the thing being shot at, so the contested
object is the only thing the host owns.

Host-authoritative and pushed whole, for the same reason `NetSession.claims`
is: a fight is tens of numbers, not thousands, and a list rebuilt from
scratch cannot drift the way an append-only stream of deltas can the first
time one arrives twice.

Nothing here touches `Run`, `Combat`, `Rng` or a screen. It is rules and a
wire format, which is what makes it testable without four machines.
```

## Crew share

Above `const CREW_SHARE: float = 0.6`:

```text
What each extra ship adds to the enemy, as a fraction of what it was worth
alone.

Not 1.0. Three ships on one frigate is three hands of cards against one
intent, so a frigate scaled linearly would be easier than the solo fight, not
harder — the party's action economy grows faster than its exposure. 0.6 is
the same number `Combat.start()` already uses to split a pack's health, which
is the same problem seen from the other side: more hulls in a fight are worth
less than the sum of them.
```

## Intent pick

Above `enum Pick { LOOP, POOL, ESCAPE }`:

```text
Where the intent came from. `Combat._spawn` scales a private copy of both
lists, identically on every machine, so an index into them is a name the
whole party already agrees on and no intent has to be sent by value.
ESCAPE is the miniboss spooling its way out of the fight — an intent that
exists in no template list, so it travels as a kind rather than an index.
Every machine builds the same card from it: Combat.escape_intent().
```

## Last hit

Above `var last_hit: PackedInt32Array = PackedInt32Array()`:

```text
The last hit anybody landed: `[peer, foe index, total, serial]`, or empty.

Carried so a partner's shot can be DRAWN. Your own hits you already saw —
you played the card — so this exists to give the other three machines the
damage number and the hull flash they would otherwise have no way to know
about. Read once, on arrival, and never used as state.

The serial is what makes "once" mean once. Every push carries the last hit,
including the pushes that are about something else entirely — somebody
joining, the turn advancing — so a reader comparing the VALUE would redraw an
old shot every time the fight moved, and two identical hits in a row would
draw as one. A counter has neither problem.
```

## Paid count

Above `var paid: int = 0`:

```text
How many ships were still in it when the last hull came apart.

The size of the bag, and it is a FROZEN NUMBER rather than `crew.size()` read
at the moment of payment. Winning makes every ship call `Combat._finish()`,
which calls `leave()`, so the crew list starts emptying on the same frame the
fight ends — and each machine would read it at whatever point its own copy had
reached. Two ships would then disagree about how many parts are floating out
there, which is worse than either answer: the bag is a shared object, so its
SIZE has to be a fact the host states once.

Zero until something dies, so a fight that ends any other way pays no bag.
```

## Grown count

Above `var grown: int = -1`:

```text
THE COUNT ITS HULL WAS GROWN AT (`RunState.custodian_jumps`, PROTOCOL 16), or
-1 for a fight with nothing in it that grows. The opener's count goes in;
the host raises it to the galaxy's (`NetSession.galaxy_jumps`) as the fight
opens and whenever that rises while it is on (`regrow`), so the boss in the
fight is the boss the badge shows (Jon, Nov 4).
```

## Opening

Above `static func open(node_index: int, ids: PackedStringArray, hp: PackedInt32Array,`:

```text
The first ship engages. `hp` and `brace` are what its own `Combat._spawn`
produced, so the danger scaling and the pack split stay in one place.
`cur` is current hull — below `hp` only when the enemy arrives already hurt,
the hellbender carrying a previous engagement's damage. `base` stays what one
ship's worth of the FULL enemy is, so a joiner's share does not shrink just
because somebody softened it up first.
`grown` is the count the opener's hull was grown at (`Combat.grown`).
```

## Joining

Above `func join(peer: int) -> bool:`:

```text
Another ship arrives at a system somebody is already fighting in.

The enemy grows to meet them, hp AND max_hp together, so the bar stays
honest and a fight that is half over does not suddenly read as full. Growing
a wounded enemy is deliberate: joining a fight late is help, and help that
arrives at 10% health should not be worth the same share of the loot as help
that was there from the first turn. It is, and this is the price.

The share is of one ship's worth of the hull (`base`), which for the
Custodian is the grown hull: it grows with the lead ship's jumps
(`EnemyTemplate.hull_at`, `grown`), so a joiner at jump 33 adds 0.6 of 400,
not of 200, and after a `regrow` 0.6 of the new hull. The joiner's own count
does not count; the host's galaxy count already holds it.
```

## Leaving

Above `func leave(peer: int) -> void:`:

```text
Somebody died, fled, disconnected, or won and walked away.

The enemy does NOT shrink back. A ship that breaks contact leaves the rest of
the party holding a frigate scaled for four, which is the honest consequence
of the thing it just did — and `Combat.flee()` already charges six fuel for
it, so the game has never pretended disengaging was free.

What must happen is the barrier releasing. A crew list that still holds
somebody who is never pressing END TURN again is a fight that never takes
another turn, so leaving is the one part of this that is not optional.
```

## Turn barrier

Above `func end_turn(peer: int) -> bool:`:

```text
One ship is done for the turn. True when that was the last one and the enemy
may now act.

THE BARRIER IS ONLY HERE. Nothing gates the start of a turn — everybody draws
and plays at their own pace, immediately, exactly as they do alone. What
cannot happen concurrently is the enemy swinging, because that is the one
moment a shared object acts on several private ones at once. So the fight is
free-running everywhere except the seam where it cannot be, which is
`docs/coop-design.md` §5's "do not gate the tick" applied one level down.
```

## Regrow

Above `func regrow(to: int, ratio: PackedFloat32Array) -> bool:`:

```text
THE LEAD SHIP JUMPED PAST THIS FIGHT'S COUNT (decision 2, Jon, Nov 4): every
live foe that grows (`ratio` holds its `hull_at(to) / hull_at(grown)`, 0 for
one that does not) is scaled by it, the damage already done staying done:
max_hp by the ratio, hp by what max_hp gained, and `base` by the ratio, so a
later joiner adds 0.6 of the new hull. Scaling max_hp keeps every join share
already added in proportion, even after a pilot has left (join growth never
shrinks back, so counting the crew would undercount). A lone Custodian lands
exactly on `hull_at(to)`. True only when a hull moved: a count still asleep
(to jump 15) or past the cap (33) grows nothing, and the fight is not pushed
for it, so nobody's log says it grew. `grown` rises either way, and the next
push carries it.
```
