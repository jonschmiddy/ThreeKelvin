The reasoning behind `tkg/scripts/systems/SaveGame.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Suspend save

Above `const PATH := "user://run.save"`:

```text
The run in progress, on disk. One slot, rewritten at every safe point.

This is a SUSPEND SAVE, not a checkpoint. Loading deletes the file, and the
file is rewritten from live state at the very next safe point — so there is
never an older state on disk to go back to. Quitting is a bookmark. It is not
a way to retry a fight you are losing or a jump you regret.

That restraint is not fussiness. "Lateral map travel is always available and
cheap, so every death is self-authored" is a design ruling, and it only means
anything while a death is final. A reloadable save repeals the greed clock
without appearing to change a single number.

COMBAT IS DELIBERATELY OUTSIDE THE SAVE. A safe point is a moment when the
only live state is RunState's, so restoring one cannot strand a half-resolved
fight. The autosave lands immediately BEFORE a fight begins rather than after
the jump that led to it, so force-quitting mid-fight costs you the fight, not
the jump — you resume on the sector with the contact still there and ENGAGE
still offered. It does refund the hull the fight had already taken, which is
the one hole in this; closing it would mean serialising deck order, enemy
intent loops, drones and charge timers for a case reached only by force-quit.
```

## Save path

Above `static var path: String = TestRun.scratch("run", "save") if TestRun.active() else PATH`:

```text
WHERE THE SAVE GOES: the player's file, or, when the game was started by a
harness or test (anything after `--` that a player would not type), a scratch
file beside it. Tests used to overwrite Jon's run.save on every gate run and
every render (2026-10-05: a chart render replaced his run). Tests that need
the real path set this themselves. One scratch file PER PROCESS
(`TestRun.scratch`): a single shared one let harnesses running side by side
load each other's runs.
```

## Version history

Above `const VERSION := 43`:

```text
Bumped whenever the shape below changes. An old file is discarded rather than
guessed at — a half-understood save produces a run that is subtly wrong,
which is worse than no save at all.
2: the economy. `exotic` became the first row of a materials ledger, station
stock stopped storing a price and started deriving one, and a node learned
whether it has ever been stocked and how much has been sold into it.
3: heat reached the map. A node now carries whether it rolled for an ambush
and what that roll produced, so a hostile attracted by your own heat cannot
be refused by quitting and coming back cold.
6: a node carries the BAG a shared kill left in it, and whether one has been
rolled. Stored by value like the shelf rather than re-derived: the roll is
deterministic from the node, but its SIZE came from how many ships were in the
fight, and nothing on a resumed map remembers that.
7: the contract ledger and manufacturer standing. A version 6 save has neither, so
it resumes with an empty board and no accounts — which is survivable but
silently loses work the player had already flown for.
8: the hold became a GRID. A part carries the cell it sits in, so a hold you
arranged comes back arranged rather than re-packed from scratch.
9: the hellbender — where the galaxy's other harvester is, what hull it has
left, and how many moves it has made (the counter is a seed source, so
losing it would re-derive a different walk). A node also carries `eaten`:
a save that forgot it would resume a derelict the rival stripped as one
somebody in the party did.
10: a hull carries the perks its GRADE grants, on top of its manufacturer's one.
They are granted by `at_tier` and the loader does not call it, so they are
written and read back explicitly. A version 9 save has none of them, and
an S-tier ship restored from one is three perks short with every number
still right — unreadable rather than wrong, which is what the rule at the
top is for.
11: the vocabulary pass. A node's manufacturers-with-berths moved from
`makers` to `berths`, and a contract's manufacturer from `house` to
`manufacturer`. A version 10 file has neither key, so it would resume
with every node stripped of its berths and every contract unbranded — a
galaxy that looks intact, posts no work anywhere, and tints nothing on
the chart. Discarded instead.

THE RENAME DID NOT TOUCH THIS NUMBER, and that is the whole reason this
entry exists. The keys moved and the gate above went on saying 10, so an
old save PASSED the check and was read with keys that are not in it —
the exact failure the rule at the top of this file forbids, arrived at by
renaming rather than by shipping a new shape. See the note below: the
number is not the defence, it is only how the defence notices.

8 rather than either side's number, and the reason is worth writing down: two
branches both shipped a "6" — the shared-kill bag on one and the hold grid on
the other — so a file stamped 6 could be either shape and there is no way to
tell which from the number. This format has BOTH, so it is readable by
neither, and taking a fresh number is the only answer that keeps the rule
above true. Anything stamped 6 or 7 is now discarded, which is the correct
outcome and the whole reason the field exists.

AND THEN IT HAPPENED AGAIN AT 8. The hold grid and the hellbender were written
on separate branches and both stamped 8, so an 8 can be either shape by
exactly the argument above. 9 has both.

Which says something the paragraph before it did not: the number is not the
defence. It collides whenever two branches are open at once, and it will
collide again. What actually keeps a wrong save from being loaded is the
rule at the top -- an unreadable file is DISCARDED rather than guessed at --
and the number is only how that rule recognises one. 8 is discarded now for
the same reason 6 and 7 were.
12: THRUST BECAME A FIELD. It was read off fuel_factor -- the gauge and the
price of a jump were one number -- so every fuel-efficiency part quietly
lowered the pilot's thrust and made them worse at thrust checks for fitting
a thriftier engine. HULL_FIELDS gained 'thrust', so a version 11 hull has
no such key and would restore with a thrust of whatever the default is
rather than what its weight class says. Discarded instead.

Caught by .github/scripts/version_guard.py, which is the first time that
has happened in anger -- and it needed fixing first: a field LIST declares
its keys as bare quoted strings, and the guard could not read one. It said
PASS on this very change until it was taught to.
13: THE AFFIX VOCABULARY CHANGED, and this is a break the version guard
cannot see. An affix is stored as its NAME — a string VALUE in the save, not
a key — and the guard watches keys. Seven of the ten names are gone
(Overbored, Autoloader, Salvaged, Mass-Fed, Efficient, Grafted, Heat-Sinked),
and `_module_from` resolves a name by walking DB.affixes and simply skipping
what it cannot match. So a version 12 save would load, and every rolled part
on it would come back stripped of its rolls: no crash, no warning, a quietly
weaker ship. Discarded instead.

Worth writing down because it is the shape of break the guard is blind to by
construction: renaming the VALUES a save stores is exactly as destructive as
renaming its keys, and nothing automated is watching for it.
17: THREE NODE TYPES DELETED. FIGHT, EVENT and DERELICT are gone and SYSTEM
replaces them, because what is at a place is `options` now and those three
were only labels for what got rolled there.

THE ENUM RENUMBERED, and that is the whole reason this line exists. `type` is
serialised as an INT, so a version 16 save loaded against this build would
come back with every node pointing at a different kind of place -- stations
reading as cores, cores as pulsars. It would not crash and it would not warn;
it would simply be a different galaxy wearing the old one's name.

Discarded, and that discard IS the migration: there is no forward-read worth
writing when the mapping is meaningless. This bump is what arms it.

16: THE AMBUSH IS A FLAG. `MapNode.ambush` held the pack itself; it is now
`ambush_pending`, with the pack derived positionally at fight time. A version
15 save carries the old array and it is read forward as "pending if it was not
empty" -- so a run suspended mid-approach still gets jumped, by the SAME pack,
because `_roll_foes` answers the same way it did when the array was written.

15: A SYSTEM HOLDS A LIST. `MapNode.options` carries the ids of what was
rolled at each node, so the shape of a saved system changed. A version 14
save has no such key and every node comes back with an empty list, which
re-rolls once on the next arrival -- the same contract `foes` has, and not a
corruption. KEPT rather than discarded for that reason: the worst case is one
system offering a different set than it did before the quit, against losing
the run entirely.

14: SENSORS CAN SEE. Every map node carries a `sensed` mark now -- set when
the ship is close enough and never cleared -- so the shape of a saved system
changed. A version 13 save has no such key, and every node would come back
unsensed: not a corruption, but a chart quietly narrower than the one the
player left, which is the same class of lie as a stripped module. Discarded.
18: THE HOLD CARRIES TWO KINDS OF THING. Cargo rows gained a `kind`, and a
material row stores an id and a cell instead of a rolled part.

Backward compatibility actually holds -- `kind` is absent on every module row
ever written, so a version 17 save reads back through exactly the old path.
The bump is about the OTHER direction: a version 17 build handed a material
row would run it through `_module_from` and produce a nameless part with no
affixes sitting in your hold. That is the stripped-module lie again, so the
number moves and the save is discarded rather than half-understood.
19: MONEY IS A THING IN A CONTAINER. A bag row can now be `kind = credits`,
which a version 18 build would push through `_module_from` and land in your
hold as a nameless part worth nothing. Same argument as 18 and the same
direction: old saves read back fine, new ones must not be handed backwards.
20: A SYSTEM HOLDS CONTAINERS. One per hull you killed plus one of its own,
each with its own items and its own claims -- and they persist, which is the
point: a wreck you left half stripped is somewhere you can go back to.

A version 19 save has no `jetsam` key and reads back with none, which is
correct for it: nothing was ever put in one. The bump is for the other
direction, as 18 and 19 were -- a 19 build handed this save would show you a
sector with the loot missing and no wrecks in it.
21: `hoards` became `jetsam`. A RENAME AND NOTHING ELSE -- same shape, same
contents, same claims -- but the key a save is written under is the key a
save is read from, so a version 20 file would come back with no containers in
it and a version 20 build handed this one would do the same. `SaveGame.load`
refuses a mismatch, which is what makes the discard the migration.
22: and `flotsam` became `jetsam`, for the reason 21 should have used --
`jettison` is the verb and jetsam is its noun. Same rename, same argument:
the key a save is written under is the key it is read from.
23: A SPENT OPTION REMEMBERS WHAT IT CAME TO. `taken` said an option was
done and nothing said what happened, which was enough while a spent option
vanished off the list and is not now that the card stays and wears its band.
`results` is written as two parallel arrays because JSON has no integer
keys -- a dictionary keyed by option index comes back keyed by "0" and "3".

A version 22 save has no `results` and reads back with none, which draws
every already-spent option as RESOLVED rather than as the band it actually
got. That is a downgrade rather than a lie, and it is the direction the
version guard does not care about; the bump is for the other one, as 18
through 22 were.
24: THE MATERIAL LEDGER IS GONE. `materials` was a dictionary of id to count
saved beside `cargo`, which already stored the same materials as objects with
shapes and positions -- and the objects are what the game reads now, so the
dictionary is not written and not read. A version 23 save carries one and a
version 24 build would ignore it, which is the quiet half; the loud half is
that a 23 build handed this save would find no ledger and show you nothing
for a hold full of crates.
25: A SYSTEM HAS A SKY. `star`, `gas_giant` and `near_pulsar` decide whether
four options may appear at all -- the pulsar sweep, the two flare-star
encounters and the gas giant -- and all three are rolled at generation off
`Rng.world`. They are saved rather than recomputed because a save carries the
MAP, not the seed that made it: a 24 save read by this build would come back
with an ordinary sky everywhere, and the systems that had been offering those
options would quietly stop.
26: THE GALAXY TABLE LOST TWO KINDS AND GAINED FOUR. `galaxy_kind` is an
INDEX into `GalaxyGen.KINDS`, so removing Barred Ring Spiral and Collisional
Ring renumbered everything after them. The rolled parameters are saved
alongside the index and would still restore correctly -- the map would be
intact -- but the run would name itself after a different galaxy than the one
it is, on the one screen that exists to tell you where you are.
27: `pad` joins the file. Overflow from a hull swap is state now rather than
a deletion, so a save taken mid-move has to carry it or the move eats it --
which is the bug the pad exists to fix.
28: `fight`, the fight a run was saved out of (see mark_fight). A save from
27 has no way to say whether it was written mid-fight, so it is not read.
29: A SYSTEM REMEMBERS WHAT ITS CARDS SAY. The sector map lists every event
as a card, and a card you walked away from reads LEFT ALONE, STILL OPEN (Jon:
"left alone should survive a reload"); a card you took reads its band and a
line of what came of it, "FUEL -16 · You put sixteen units across." Neither
is in `taken` or `results` -- walking away spends nothing, and `results` is
only the band -- so each node carries two more maps, `left` (option index to
the first line of leaving) and `said` (option index to what moved and the
first line of the outcome). Written as parallel arrays for the reason 23
gives: JSON keys are strings. A 28 save would load with every walk-away
forgotten and every card's line gone, quietly; a 28 build handed this save
would drop them the same way. Refusing the mismatch is the migration.
30: WHERE THE SHIP WAS LEFT, by system (`parked`: `ParkedShips.spots`,
the orbit or the open-space spot the map last had you at). It lived only in
memory, so a reload dropped you at the system's edge and LOCAL drew the
warp-in instead of the world you were orbiting. Written as a list of rows
with the system's index in each, for the reason 23 gives.

THE FIRST BUMP THAT STILL READS THE ONE BEFORE IT (`OLDEST_READ`). A 29 save
differs from this shape only by not having `parked`, and missing, it means
exactly what a 29 build did with it: every system's ship at its edge. So
there is nothing to half-understand, and refusing it would cost a player a
run for a field whose absence is a correct answer. A 29 build handed a 30
save still refuses it, which is the direction the number exists for.
31: WHICH PICTURE A WRECK IS (`Jetsam.look`). The enemies wear Jon's kept
ships now, three to an ordinary kind and one per fight (`Combat.look_for`),
and a wreck has to be the hull the fight showed. Read the way 30 reads 29: a
30 save has no `look`, and missing it means the kind's first picture -- a 30
build drew none of these pictures at all, so there is nothing to disagree
with. OLDEST_READ stays at 29.
32: THE CORE WON, ITS BODY NOT YET SALVAGED (`core_won`). The one save a won
run may have: written at the custodian's kill so a game quit before the body
is clicked comes back to the body (`SaveGame.save_core_won`). Read the way 31
reads 30: a 31 save has no `core_won`, and missing means not won -- the only
state a 31 build ever wrote. OLDEST_READ stays at 29.
33: A WRECK HAS A PLACE (`Jetsam.site`, Jon Oct 14: "each planet or POI you
can visit should contain its own wrecks/fights"). Read the way 32 reads 31: a
32 save's wrecks have no `site`, and missing means `MapGen.SITE_ANY`, shown
at every place in the system -- what a 32 build drew. And `opened` (a wreck
you have looked in, whose leftovers SECTOR LOOT shows too); missing means
the wreck's `scanned`, the nearest thing a 32 save kept. OLDEST_READ stays at 29.
34: WHAT THIS RUN'S WORLD MAY HOLD (`unlocked`, `Run.unlocked_manufacturers`;
Jon, Oct 20: "Solari things should NOT show up in the game until Solari is
unlocked"). Read off the flight record once at run start and kept, so a
CONTINUE rolls the shelves and wrecks it has not opened yet from the same
pool as the ones it has, whatever the record says now. Read the way 33 reads
32: a 33 save has no `unlocked`, and missing means every manufacturer -- a 33
build gated drops on `DB.ACTIVE_MANUFACTURERS` alone, so that is the world it
was already rolling. OLDEST_READ stays at 29.
35: THE QUESTS AN EVENT GAVE YOU, AND WHAT EVERY QUEST PAID (`event_quests`,
`quests_done`; Jon, Oct 22: an event that plants a follow-up "is essentially
a quest", and finished quests go under COMPLETED, not away). Read the way 34
reads 33: a 34 save has neither, and missing loses only what the map cannot
say. Its open event quests still list, read off the map (the placed option
on its system, not taken), with the giver the option itself names
(`quest.from`); one taken lists under COMPLETED without its pay; and its
delivered contracts list there too, after any finished since, with the pay
each one carries. OLDEST_READ stays at 29.
36: THE FRAME YOU ARE MOVING OUT OF (`old_hull`), written while anything is
still on the pad. A 35 save quit mid-move came back with its parts on the pad
and no ship to draw the fitted ones on, and nothing showed the pad at all: the
station would not let you go and would not say what was holding it (Jon, Oct
23, 0.4.1-alpha.1). Read the way 35 reads 34: a 35 save has no `old_hull`, and
missing means none -- the pad's parts forget the old hardpoints and are laid
out in the old hold (`RunState.mend_loadout`, which every load runs, and which
also puts a fitted part on a hardpoint it can have). Also in 36, both
optional: A.S.H.'s COMMS log for the run (`ash_comms`; a 35 save starts it
empty), and the manufacturer the run launched as (`launched_as`; a 35 save
has none, and its win falls back to the hull it ends in, see Unlocks).
OLDEST_READ stays at 29.
37: WHAT THE HULL ON OFFER CUTS UP FOR (`found_scrap`, `{credits,
material}`). The derelict hauler's frame carries the pay of the strip you
gave up for it, so a frame you do not fly has SCRAP in place of LEAVE IT
(Jeremy, friends' alpha). Read the way 36 reads 35: a 36 save has no
`found_scrap`, and missing means none -- its found hull offers LEAVE IT, as
a 36 build did. OLDEST_READ stays at 29.
38: A SYSTEM CAN HAVE TWO SUNS (`twin`, ruling 20). Rolled at generation off
its own stream and saved with the node for 25's reason: a save carries the
MAP, not the seed. It also decides the whole layout -- which world goes round
which star, and every body's index -- so a system that changed its mind
across a load would move the ship's parked place and its wrecks' sites
(`parked.at`, `Jetsam.site`, both body indices) onto other bodies. Read the
way 37 reads 36: a 37 save has no `twin`, and missing means one sun, so its
systems lay out as they did. OLDEST_READ stays at 29.
39: EACH SYSTEM'S MAP CLOCK (`clocks`: `Run.map_clock`, ruling 23). A
binary's two suns turn on map time, and the worlds round one of them with
them, so where everything in a system is depends on its clock; a parked free
ship's spot is an absolute plane point that only means where it was at the
clock it was left at. Rows of {index, t}, for the reason 23 gives. Read the
way 38 reads 37: a 38 save has no `clocks`, and missing means t 0 -- the
picture a 38 build showed on every visit, its suns where they were laid out
-- so every parked spot loads where it was made. OLDEST_READ stays at 29.
40: THE LEAD SHIP'S JUMPS (`party_jumps`: `Run.party_jumps`, Jon, Nov 4). In
co-op the Custodian grows on the most jumps any ship in the dive has made
(`RunState.custodian_jumps`), so a pilot behind the lead who quit and pressed
CONTINUE would otherwise meet a weaker boss than the badge showed. Read the
way 39 reads 38: a 39 save has no `party_jumps`, and missing means 0, so its
count is its own jumps, as a 39 build grew it. OLDEST_READ stays at 29.
41: THE RUN'S ASCENSION LEVEL (`ascension`: `Run.ascension`, Jon, Nov 8).
The Hellbender flies only at `RunState.HELLBENDER_ASCENSION` and up, and a
run is spawned at its level once, so CONTINUE has to bring the level back or
the ladder could not say what a loaded run is. Read the way 40 reads 39: a
40 save has no `ascension`, and missing means 0, the game a 40 build played.
A 40 save that already has a live Hellbender KEEPS it (its five fields load
as before): pulling a rival out mid-chase, or mid-fight, is worse than
letting one old run finish with it (`SaveGame.OLD_SAVE_KEEPS_HELLBENDER`).
OLDEST_READ stays at 29.
42: SCIENCE (Phase 12, Jon's picks Nov 4). `data` (`Run.data`), the dealt
`board` (as routine ids), `board_owned` (steps bought per branch),
`black_box_spent`, and a module's `augmented`. The board is saved as ids and
never dealt again at a load: a retuned pool would otherwise move a live run's
board under steps already bought. It was 41 on its own branch; the
Hellbender took 41 by landing first, so science is 42 (Nov 8). Read the way
41 reads 40: a 41 save (the Hellbender's build, or a 40 one) has none of
these keys and loads with 0 DATA, nothing owned, nothing augmented, and its
board dealt from its seed and seat (`_board_from`), the board a 42 build
would have dealt it. Nothing in science reads `ascension`, so a 41 save's
key is the Hellbender's to read. OLDEST_READ stays at 29.
43: `moored_right`, the station node your ship is moored right of after an
undock (`SectorScreen.mirrored_at`, docs/why/SectorScreen.md#mirrored), or -1.
A 42 save has none and loads moored on the left, as any arrival is.
OLDEST_READ stays at 29.
```

## Saving

Above `static func save() -> void:`:

```text
Called from Router at every safe point. Cheap enough to be unconditional:
the map is the bulk of it and a hundred and fifty nodes stringify in a
millisecond or two, which is nothing beside the screen swap that triggered it.

The map guard is doubled here and in Router._autosave() on purpose. This is
the one function that writes, and _snapshot() indexes `Run.map[Run.at]` with
nothing in front of it — a half-populated run reaching this call takes the
process down rather than declining to write.
```

## Core won save

Above `static func save_core_won() -> void:`:

```text
THE CORE WON, ITS BODY NOT YET SALVAGED (Jon: "I would want to have to click
the dead custodian"). The run is recorded as won at the kill and the ordinary
save goes then, as ever; this writes the one save a won run may have: the
core, cleared, with the body on it, marked `core_won`, so a game quit before
the body is opened comes back to the body -- and to nothing else (the doors
stay shut, `Router.final_loot`). DONE on the body clears it.
```

## JSON precision

Inside `_write()`, above `f.store_string(JSON.stringify(_snapshot(), "", true, true))`:

```text
full_precision, not the default. Without it JSON rounds floats hard enough
to move systems on the chart by a visible fraction of a pixel.

It is still not bit-exact, and it is worth writing down what was measured
rather than leaving the next person to wonder: over 20,000 random floats,
63% round-trip exactly and the worst relative error is 9.3e-14. That is
three orders of magnitude below single precision and it cannot reach any
observable in this game — fuel is int(round(distance * 10)), so flipping
one would need a distance sitting within 1e-13 of a .5 boundary.

JSON is kept over FileAccess.store_var, which WOULD be bit-exact, because
a save you can read in a text editor is worth more during development than
fourteen digits nothing consults.
```

## Loading

Above `static func load_into_run() -> bool:`:

```text
Restores the run and consumes the file. True when a run is now live.

The delete is the whole point of the model, but it also opens a window: a
crash between here and the next safe point would lose the run. Router saves
on the very next screen swap, which is the one this call is about to cause,
so that window is a few milliseconds wide.
```

## Load resets

Inside `load_into_run()`, above `Run.hauls = 0`:

```text
ZEROED, not restored — these two are deliberately outside the save, so a
load has to clear them the way `start_new_run()` does. Without it, SAVE &
QUIT to the launcher and CONTINUE inside the same process carries the
previous run's haul count and its dismissed salvage rail into the loaded
one: the rail stays shut in-session and opens after a cold start, which is
the same save behaving two different ways.
```

## Module rows

Above `static func _item_to(m: HoldItem) -> Dictionary:`:

```text
A module is a template id plus what LootGen rolled onto it. Affixes are
stored by name and resolved back to the shared DB instances, which is how
they are held during a run too — LootGen picks out of a shallow duplicate.

There used to be a "price" meta in here as well, because a station stamped one
on its stock and a shelf that came back without it silently held a sale.
Market removed the whole class of problem: a price is a function of the place
and the part, computed when it is asked for, so there is no longer a price
anywhere to lose. A derived number that is saved is a second copy of the
truth, and it only ever goes one way.
Cargo is two kinds of thing now, so the hold's rows say which they are.

A material stores ONLY its id and where it sits. Everything else -- name,
tier, value, shape, text -- is rebuilt from `MaterialTable`, which is the
right way round: a catalogue row that changed between versions should change
what you are carrying, rather than leaving a save that contradicts the table
it was authored against. A module cannot do this, because a module is rolled
rather than looked up: its affixes and its wear are the instance.

`kind` is absent on every module row, old and new, so a save written before
materials existed reads back exactly as it did -- there is nothing to migrate
and the version did not need to move for this.
```

## Hull rows

Above `static func _hull_to(h: HullData) -> Dictionary:`:

```text
`manufacturer` is written alongside perk_id rather than added to HULL_FIELDS,
and that is not a style choice: the restore loop below coerces every listed
field to int or float, so a StringName in that list would come back as 0.

It is written at all — rather than inherited from the frame matched by name —
because who built your hull decides a set bonus. The name lookup happens to
resolve it today, but its fallback is hull_frames[1], an UNBRANDED frame, so
any save whose hull name stopped matching would silently cost you a set piece
and nothing would report it.
```

## Hull restore

Inside `_hull_from()`, above `var manufacturer := StringName(str(d.get("manufacturer", "")))`:

```text
MANUFACTURER AND WEIGHT FIRST, name only as a fallback.

The warning above came true: hulls gained a name per CLASS, so a save
holding a Halberd Cutter found nothing in `hull_frames` — those carry
the tier-0 name — and silently restored an unbranded Medium Frame with
somebody else's perk. Manufacturer and weight are both written into the save
and neither is renameable, so they identify the frame outright.
```

Inside `_hull_from()`, above `var tp: Array = d.get("tier_perks", []) as Array`:

```text
RESTORED, NEVER RE-DERIVED. `_hull_from` does not go through `at_tier`
-- it copies a tier-0 frame and puts the saved scalars back on it -- so
nothing here would grant the grade's perks a second time. An S-tier ship
would come back carrying only its manufacturer perk, three short, with every
number on the screen still correct. That is the same shape of fault as
the Halberd that came back a Picket, and it is why the version below
moved: a save written before this cannot be told from one written after.
```

## Parked ship rows

Above `static func _parked_to() -> Array:`:

```text
WHERE THE SHIP WAS LEFT (`ParkedShips.spots`), one row per system.
Rows, not a dictionary keyed by system: JSON keys are strings (see 23).
`at` is the place the ship orbits (a body, -1 the star (star A of two suns),
SystemLayout.STAR_B (-4) star B, -9 none), and `p`, `head` and `mode` say
where it was flying in open space when it orbits nothing. Settled on a wide
orbit there, `cen`, `r` and `sense` say round what (-1 star A, the star; -4
star B; -9 both suns), how wide and which way, so it is put back on it
(`ShipFlight.restore_free`). They are only there for such a row, and a row
without them -- an older save's -- settles again where it is: no VERSION.
```

## Node containers

Inside `_node_to()`, above `var res_at: Array = []`:

```text
EVERY CONTAINER IN THE SYSTEM. They persist across a jump by being node
state, and across a session by being here -- a wreck you left half
stripped is somewhere you can go back to, which is most of the point.
TWO ARRAYS, NOT A DICTIONARY. See VERSION 23: JSON keys are strings, so a
map from option index to outcome comes back with "0" where 0 went in and
every lookup misses silently.
```

## Node options

Inside `_node_from()`, above `var opts: Array[StringName] = []`:

```text
Absent on a save written before a system held a LIST of things to do. Left
empty, which makes the node roll once on the next arrival and keep it from
then on -- the same contract `foes` and `ambush` state above.

Ids rather than definitions, so a save can be rebuilt after the table has
changed underneath it. Resolution is lazy -- `OptionTable.by_id` answers
empty for an id this build does not have; a missing option must never
refuse a save.
```

## The runs board

Above `static func _board_from(raw: Variant) -> Array[StringName]:`:

```text
THE RUN'S BOARD, as saved (VERSION 42): nine routine ids, three a branch,
FRAME then CORE then DRIVE, each branch weakest first. An id this build does
not know is dropped, and anything short of a whole board in that shape (a 41
save has none, a hand-edited one may have anything) is dealt again from the
restored seed and seat (`RunState.deal_board`), the board the run would have
been dealt. Its bought steps stay as saved; the deal is the one it had unless
the pool changed under it.
```
