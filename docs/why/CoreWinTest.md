The reasoning behind `tkg/scripts/sim/CoreWinTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Core win

Above `var _tree: SceneTree`:

```text
THE CORE'S BOSS, BEATEN, THROUGH THE REAL DOORS:
  godot --headless --path . -- sheet=CoreWinTest

Jon, Oct 12: "when defeating the final boss at the core, let's have the body
of the boss lootable, but let it end the alpha with a winning game popup.
same music as the death screen."

A run with things in its hold flies to the core, presses ENGAGE
(`Router.engage_here`), and plays the custodian to a kill: its hull is cut to
one and its block to none first, so the fight is short, and the cards are
played through `Combat.play` as the hand plays them. Then, from the screen
the router leaves:
  - the custodian's body lying on LOCAL, NOT opened by itself (Jon: "I would
    want to have to click the dead custodian"): SALVAGE THE CUSTODIAN said,
    every door shut; clicking it (the wreck's own click) opens the popup with
    the boss's own loot in it, and the win screen is NOT up yet;
  - the run already in the record as a win, and the one save a won run may
    have written: the core with the body on it (`core_won`). Quit there and
    CONTINUE comes back to the body, still to click, recorded once;
  - Tab doing nothing while the body is open, a part taken into the hold;
  - DONE bringing up the win screen: YOU WON, Jon's note whole and unscrolled
    at the game's size, the stats, TITLE, and the death screen's music
    (`Audio.music_asked` &"gameover", which plays `Audio.DEATH_CUE`);
  - a second kill closed with Escape, and a third left by a door that should
    not be there (`Router.show_system`), both ending on the win screen;
  - an ordinary fight won, which leaves you on LOCAL by its wreck with no
    win screen, no loot step and no win in the record;
  - and the death screen asking for the same music the win does.

THE CUSTODIAN GROWS WITH THE RUN (Jon, Nov 3, rule G3 with cap B): 200
through jump 15, then x1.04 a jump, capped at 400 from jump 33. Checked first
(`_custodian_growth`): the template's `hull_at`, the hull a fight fields
through `Combat.plan` at each count, the template left at 200 across fights,
only the Custodian growing, and a co-op joiner adding 0.6 of the grown hull.
ONE CUSTODIAN FOR THE GALAXY (Jon, Nov 4): in co-op it grows on the lead
ship's jumps (`Run.custodian_jumps()`), so a ship at jump 5 behind a lead at
33 fields 400, and a fight opened at 20 grows to 33 mid-fight with its damage
kept and the log saying so (`_custodian_party`), a count asleep or past the
cap rising with no hull moving and nothing said, a ship joining a fight
already grown past its count saying nothing; and `Router.start_combat` on a
host in a dive opens the party's fight at that count (`_party_router_fight`).
Every core run below flies in at jump 41, so ENGAGE must open at 400.
```

## Custodian growth

Above `func _custodian_party() -> void:`:

```text
THE LEAD SHIP'S JUMPS (Jon, Nov 4: "The custodian strength and icon should be
the same for everyone in the galaxy, even if they join late."), without a
wire: the count a fight is built at, and the growth the host makes mid-fight.
```

## Party fight count

Above `func _party_router_fight() -> void:`:

```text
THE FIGHT CARRIES ITS COUNT TO THE HOST (PROTOCOL 16), through the real
door: `Router.start_combat` on a host in a dive with a partner on its
roster hands `Combat.grown` to `Net.open_fight`, and the party's fight is
grown at the lead ship's count. The partner is a roster row only (nobody on
the wire), as NetTest's stale guest is; the fight's push goes to nobody.
And the tooltip's party words follow the dive's galaxy (`CustodianBadge.party`).
```
