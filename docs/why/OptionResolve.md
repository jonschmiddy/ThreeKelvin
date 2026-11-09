The reasoning behind `tkg/scripts/systems/OptionResolve.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Taking a choice

Above `static func pays_anything(res: Dictionary) -> bool:`:

```text
TAKING ONE CHOICE OF ONE OPTION, the same way from every screen that offers
it -- the sector's drawer and the system map's panel -- so the rules cannot
drift apart. Moved whole out of `SectorScreen._take`; its reasoning comes with
it. `Policy` resolves options its own way for the simulator and is not
touched, so the simulator still measures the same game.

`take(n, i, j)` runs choice j of option i at node n and returns what
happened, for the screen to show:
  ok         false if nothing was done (see `why`)
  why        "bounds", "credits", "material", "fuel" or "too_late"
  who        on "too_late", the partner who got there first ("" if unknown)
  stay       walking away: nothing rolled, paid or spent
  checked    whether a skill check was rolled
  band       SkillCheck.Band
  odds       the odds line the choice showed
  res        the outcome's own dictionary (its `text`, its payload)
  bill       `EncounterDrawer.bill_rows` from before the choice to after `pay`
  got        the THINGS it moved, which the bill's five numbers cannot say:
             a part or a material put on the system's pile (REWARD), a hull
             frame found, a place marked, an item taken out of your hold
             (`_things_after`)
  loot       how many things it put on the system's pile: what REWARD opens
             (`shows_reward`)
  dead       the ship died of it: show the game over
  fight_now  a fight the player chose with nothing to read: start it, no panel
  foe        what that fight brings: the event's creature tag, or &"" for a
             ship (`OptionTable.fight_foe`); hand it to `Router.start_ambush`
```

## Reward detection

Above `static func shows_reward(out: Dictionary) -> bool:`:

```text
WHETHER THE RESULT SHOWS REWARD: the choice put something on the system's
pile, read off the pile (`loot`, counted by `_things_after`) and not off the
outcome's keys.

THE KEYS WERE THE BUG. REWARD was `OptionTable.pays_item`, which is
`res.module` and nothing else, while three other ways onto the same pile
went unseen: `material`, `material_id`, and an effect calling
`Run.add_material` itself. Each of those said CONTINUE and dropped, the crate
sitting under SECTOR LOOT with nothing on the result to say it was there
(Jon, Oct 22). Counting what arrived cannot miss a payload form written
next month. Credits are not here: an event pays them straight to the wallet
and the result's table says so; there is nothing to take.
```

## Party claim

Inside `take()`, above `if not out.stay and not OptionTable.is_mine(n.options[i]):`:

```text
ASK THE PARTY FIRST -- the same door the wreck path uses. An option two
ships can race for is arbitrated through `Run.take_option` before
anything is rolled or paid: assume you won and both players pocket the
payout, and the flag agreeing afterwards does not take it back. Walking
away (`stay`) consumes nothing, so it does not ask.
A SIGNED JOB'S EVENT IS NOT RACED FOR: it is on this ship's map for this
ship's contract and nobody else's (`Contracts.post_goal`), so it is not
put to the party -- a claim on its slot would land on whatever a
partner's map holds at that index. AN EVENT QUEST IS THE SAME
(`OptionTable.is_mine`): on this ship's map for what this ship did.
```

## Ledger

Inside `take()`, above `var was := Run.ledger()`:

```text
THE LEDGER OPENS BEFORE THE CHOICE RUNS. A gate you pay to attempt is part
of what the option cost you, and a bill that started counting after the
toll was taken would show a botched sixty-credit gamble as costing nothing.

AND THE SCREEN DOES NOT TAKE THE MONEY. `cost_credits` is the price the
choice DISPLAYS and the affordability gate above refuses on; every priced
choice in the table already spends it inside its own effect. Deducting it
here as well charged the player twice -- the deep dock's thirty-credit
tank cost sixty, and at exactly thirty credits the gate let the click
through and `add_credits` floored the second charge at zero, so the price
was everything you had. `Policy` never applied this deduction, so the
simulator has always priced these options at one charge and the win rate
in the gate was measured against that.
```

## Spent option

Inside `take()`, above `if not out.stay:`:

```text
SPENT NOW, NOT ON CONTINUE. The result is already applied -- credits moved,
hull taken, a module in the hold -- so a player who closed the game on the
result screen must not come back to an option they have already been paid
for.

UNLESS NOTHING HAPPENED. A `stay` choice is walking away -- no roll, no
cost, no payout -- and marking it RESOLVED would spend an encounter on the
act of declining it. Declining leaves the thing exactly as found.
```

## Chosen fights

Inside `take()`, above `out.fight_now = not out.dead and not out.checked and bool((res as Dictionary).get("fight", false)) \`:

```text
A FIGHT YOU CHOSE DOES NOT NEED A PANEL IN FRONT OF IT. The result panel
earns its click when there is something to read: which way a roll went,
and what the branch cost. A choice with no check that starts a fight and
moves nothing has neither. ONLY THE UNCHECKED ONES: a botched check is
exactly the case where the panel is the point. The line is logged either
way, so nothing written for the moment is lost.
```
