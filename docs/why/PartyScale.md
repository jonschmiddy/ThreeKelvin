The reasoning behind `tkg/scripts/net/PartyScale.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Party scale

At the top of the file, under `extends RefCounted`:

```text
THE PARTY'S SIZE SETS THE ENEMY AND THE PAY (Jon, Nov 5: "increase the
difficulty of enemy ships globally depending on how many players are in the
multiplayer game ... ship strength and loot pools are increased as the
playercount increases.").

GLOBAL, NOT PER FIGHT. Every fight in an n-player game is built for n: a
ship fighting alone while its partners are elsewhere meets the same hull as
the whole party would. It replaced the per-join growth (0.6 of one ship's
worth for each ship that walked into a fight), which made the enemy depend
on who happened to be in the room and grow again on every drop and rejoin.

THE COUNT IS THE HOST'S: the players in the session now (`NetSession.
party_count`, the host's roster, pushed whole to everyone). A fight already
open keeps the count it opened at (`SharedFight.party`, on the wire), so a
drop or a join mid-fight changes nothing in it; the next fight takes the new
count. Solo, and a party that has dropped, is 1, and every number here is
then exactly what it was before.

Hull only, never damage: "no second combat resource ... more enemy health,
longer fights, that's all" (Jon, Nov 3).

The numbers were measured with `-- sheet=PartySize` (see there and
`docs/tests.md`), the sim's N-ship harness: one enemy list, N real
`Combat`s, each ship's hull and heat swapped into `Run` as it acts.
```
