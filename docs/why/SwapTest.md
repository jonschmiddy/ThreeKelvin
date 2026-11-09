The reasoning behind `tkg/scripts/sim/SwapTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Hull swap softlock

Above `const FIXTURE := "res://tools/fixtures/swap_softlock_0.4.1.save"`:

```text
A HULL SWAP NEVER STRANDS YOUR PARTS, AND NEVER SHUTS THE STATION DOOR:
  godot --headless --path . -- sheet=SwapTest

Jon, Oct 23, on 0.4.1-alpha.1 with friends playing: "after swapping/upgrading
my ship all the parts no longer appear for me to transfer and now i can no
longer undock from a station". His save is `tools/fixtures/` and this loads
it as it is.

A swap puts everything you own on the PAD (`RunState.transfer_to_hull`), and
UNDOCK is refused while anything is on it (`ready_to_fly`). The one screen
that showed the pad was the moving-day page (`TransferScreen`), and three
doors left it behind for good:
 - a FOUND hull (a derelict's TRANSFER, in space) never opened it at all, and
   nothing stopped the ship flying on with its whole kit on a pad nobody
   could see -- Jon's (no yard in his galaxy sold a hull, and his frame is an
   unbranded salvage one);
 - Tab (or any other screen change) over the yard's page freed it with the
   station, and docking again never brought it back;
 - SAVE AND EXIT mid-move came back without the old frame (`old_hull` was not
   saved), so the parts still bolted to it had no ship to be drawn on.

Three runs, each checked on what is DRAWN as well as what is true:
 1. Jon's own save: loads with nothing lost and every mount valid, docking
    opens the move with every pad item visible, and after moving the parts the
    ship undocks.
 2. The yard: TAKE IT, then Tab, then another screen and back, then SAVE AND
    EXIT and CONTINUE in the same process -- the move is there each time,
    drawn with the old ship, and BACK OUT is not offered on a stale undo.
 3. A found hull in space: TRANSFER opens the move, Tab and the jump are
    refused while the pad is loaded, BACK OUT puts the found hull back on the
    rail, and CAST OFF returns to LOCAL, not to a station.
```
