The reasoning behind `tkg/scripts/sim/DerelictTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Derelict test

Above `const ID := &"derelict_hauler"`:

```text
THE DERELICT HAULER SAYS WHAT YOU ARE CLAIMING, AND CLAIMING IT NEVER COSTS
YOU THE STRIP:
  godot --headless --fixed-fps 60 --path . -- sheet=DerelictTest [seed N]

Jeremy, friends' alpha: he flew a heavy ship, took "Claim the hull", got a
light frame he did not want, and had given up "Strip it for scrap" for it.
The frame was rolled off the loot stream after the choice, so nothing could
name it first, and LEAVE IT was the only way to say no.

Everything here is read off what is drawn and what the run holds, never off
the new helpers, so the same sheet runs against the old code and fails there:
 1. On the real LOCAL, the derelict's page at three systems whose frame is
    light, medium and heavy, in all three layouts: the claim's card names the
    frame's weight and no other, and the page passes the box test at 960x540
    (the band on screen and off the HUD, every card inside it and off the
    others and the text, its words inside it). YOU CHOSE names it too, and the
    hull found is that weight.
 2. The same frame on every visit, and for a partner: claimed again with the
    loot stream moved and another seat, it is the same hull, number for number.
 3. Declining it pays the strip. The strip's credits and crate measured, then
    the claim's frame cut up with the rail's SCRAP (where LEAVE IT was, inside
    the rail, off TRANSFER, no wider than LEAVE IT left it) for the same credits
    and the same crate, once. SCRAP survives a backed-out TRANSFER and a save
    and load, and the system map's hull row has it too. A wreck's hull, which
    cost you nothing, keeps LEAVE IT.
 4. A frame still on offer is paid, never lost. Claiming a second derelict
    put the new frame over it, and buying a yard hull threw it away, its pay
    with it both times. Now each pays the strip's credits and crate first,
    and the log names the crate and says it is in SECTOR LOOT (Jon: a crate
    landing there with nothing on screen was "super NOT intuitive"). Backing
    out of the yard hull does not bring the paid frame back to pay twice.
 5. SCRAP at three digits (danger 5 or 6 pays 105): the box test on the rail
    and on the system map's row, its words inside the button.
 6. A 0.4.2-alpha.1 save (VERSION 36) holding a found hull loads it with
    LEAVE IT and no SCRAP, as that build had it.
```
