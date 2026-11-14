# validate.sh: what each unit's comment used to say

The reasoning behind `.github/scripts/validate.sh`'s units, moved out of its comments verbatim, by unit. The script keeps one line of why and a pointer here. Dates and names are as written then.


## unit_stowtest

Driven through the REAL screen, because the rule has been wrong three times
and the first of those was not about the rule at all — the flag lived on
`SectorScreen`, which Router rebuilds on every jump. No assertion on the
predicate can see that. This one presses the button, jumps, and checks the
rail on the screen Router built afterwards.
The two exit-time reports Godot emits when a headless run has had a Control
tree in it: the process ends holding the theme's font. A statement about
teardown, printed after the test's own verdict — and scoped to this line, so
no other step stops failing on a real leak.


## unit_dockflytest

DOCK only at the station itself (Jon, Oct 18, "dock:A"): at the system's edge
and at a world, no DOCK on LOCAL or the map, no station side, and the door
refuses; flown to the station, DOCK is offered and docks.
Docked (Jon, Oct 27): LOCAL greyed on the HUD with "Docked. Press UNDOCK to
leave."; Tab never lands on LOCAL; the map's FLY HERE, WASD and GO and the
chart's JUMP refused and reading DOCKED; STATION, the map's DOCK and PARTY's
LEAVE go straight back in, never by LOCAL. Each old way off the berth is
refused, and made after UNDOCK leaves nothing of the berth behind.


## unit_derelicttest

Jeremy, friends' alpha: a heavy pilot claimed the hull blind, got a light frame,
and had given up "Strip it for scrap" for it. On the real LOCAL at a light, a
medium and a heavy frame, in all three layouts: the claim's card names the
weight, the page passes the box test, YOU CHOSE names it, and the hull found is
that one, the same with the loot stream moved and another seat. Then the
frame's SCRAP on the rail (where LEAVE IT was) pays the strip's credits and
crate, once, after a backed-out TRANSFER and a save and load; and on the map.
A frame still on offer is paid, not lost, when a second claim or the yard's
TAKE IT replaces it, and the log says its crate is in SECTOR LOOT. SCRAP +105
fits the rail and the map; a VERSION 36 save's found hull keeps LEAVE IT.


## unit_orbitworldtest

Jon, Oct 21: "I want the planet you are orbiting to be large in the
background (you are close to it)." Four seeds through the real doors with the
ladder on: launch, every world of the start system, a jump on and a station's
system flown to for the first time (FLY HERE, GO), LOCAL by the HUD's tab, by
Tab and by GO, and CONTINUE: the sky's world on LOCAL's first frame is the one
the ship orbits, at least the look's size, under your ship and clear of the
HUD and the goal line; LOCAL pressed mid-arrival draws that world too.
600 s: its tour flies every leg on map time since ruling 20 (about 24 s a
flight, where they took 4 to 12): 310 s alone on the Mac (Oct 31), past the
300 it had (137 s on Oct 30).


## unit_content

NEITHER OF THESE WAS IN THE GATE AT ALL, which is how the export and the page
drifted apart in silence. PASSIVE_AXIS values became arrays while the exporter
still called String() on one; a gauge came out as the four characters
["hull"], the JSON stayed valid, the page kept rendering, and every gauge chip
vanished. Nothing errored at either end — it was found by looking at a table
that had gone blank.

Both ends check now and both run here. The exporter vets its own rows against
the vocabulary the GAME defines, and the page throws on a gauge it does not
recognise rather than rendering an empty cell.


## unit_ashtest

The ship's AI (Jon and Ashlee, Oct 17; docs/ash.md). Her thirty approved
lines, character for character against docs/ash_lines.json; each moment fires
its own (launch, a new hull, the hull failing, over the heat cap, a big haul,
one more wreck, doubt); the quiet after a line, one line a fight, never during
a drag or the enemy's turn; nothing after the ship is lost; hints win; her face
8 to 12 changes a second while she talks; and the box test on 65 screens, LOCAL
and fights of one to three ships in every weight, against the HUD, the goal
line, the hand, both ships and their words, plates, ovals and numbers.


## unit_twinsitetest

Ruling 20 (Oct 30), two suns on the real map: star B hit where its sun is
drawn, named, its FLY HERE flown and its close orbit ridden; the map leaves
the ship there and puts it back; a partner there drawn where it said, and on
an orbit at the orbit's drawn size. Oct 31: a ship settled round star B, both
suns or one star comes back on that orbit, by LOCAL and by the save's rows;
the map left on a flight's coast puts the ship where it was going; no words
across the other sun; a capture at star B drawn as it is flown; LEAVING while
held alongside to go; it quits with a flight plan still on a worker (that
crashed the quit, signal 11); and the map drawn again round a flight (a style
or GRAPHICS change) carries its errand on: a GO's event once, the map open
again (a GO cut short kept the map shut until it was left). Nov 1: each
star's facts as it is drawn (star B the K5 orange dwarf, masses as the
pulls), AROUND (never ROUND), no event card wider than the column, and a GO
that leaves the view open (hover, wheel, drag) and still runs its event once.
Nov 2 (ruling 23, the pair turning): about 140 s alone with its lap sweeps;
289 s on the CI runner, which killed it at 180 and nearly at 300.


## unit_hulldamagetest

James, a playtester (Oct 17): ships get big holes in them, and ships can't
have holes. Jon picked D (A+B+C mixed per hit, `HullHitFx`), the game's; A, B
and C are its parts. Each on a light, a dark and a white hull at both sheet
sizes: no near-black blob, every mark on the hull's own pixels in its own
colours (or burnt metal), every glow the heat ramp's and changing shape 8-12
times a second, the same seed the same marks, more marks as the hull goes, D
quieter than the older marks; then the real fight, D the default on every
ship but the Custodian (the older marks).


## unit_fightopentest

Jon, Oct 13: "When the enemy ship enters.... the ships pop up and the drawer
pops into view.... can we have the opposite of the fight ending screen".
Animated headless at 60 fps, through the real screens: the core's ENGAGE, an
event's THEY ARE FIRING, a pack of three started on LOCAL, and an ambush met
on arrival. Every frame: nothing (your ship, plate, bands, rails, each
contact's box, readout and intent) jumps over 10 px or pops in or out, no
frame is faded dark, nothing overlaps the rising band, no card / END TURN /
FLEE / HAIL / pile takes a click before the band settles (and they do after);
an ambush keeps its contacts and hand until your ship has arrived.


## unit_midjointest

Nov 5, the same-second mismatch and the review's holes: a ship that asked for
its own enemy and was seated in a partner's fights the partner's (hulls,
intents, what SAVE & EXIT restarts, "VELA got here first."), on the host and
as a guest of a host in this process; SAVE & EXIT and ABANDON leave the
party's crew (nothing here runs a turn with no hull), CONTINUE joins again,
grown once; a join answered on the kill goes to the win; an ambush at a
partner's fight says so; a slow host is waited for, not fought around, and
an answer that lands after SAVE & EXIT is left again.


## unit_wrecksitetest

Jon, Oct 14: "each planet or POI you can visit should contain its own
wrecks/fights." A wreck lies where your ship was when it died (Jetsam.site);
LOCAL draws that place's wrecks and no other's, each with its own death and
marks; a save keeps the place, and an older save's wrecks show everywhere.
Jon, Oct 15: what is left in a wreck you have opened is under SECTOR LOOT too,
from anywhere in the system, claimed as the wreck's own.
Jon, Oct 17: "fix destroyed ships from going on top of you when you edit your
ship after a fight" -- every door off LOCAL and back (the cutaway with a part
moved in it was the one) leaves the wrecks where they lay, off your hull; and
"destroyed ships still show up in other systems" -- a real jump draws none.
Fit means nothing overlaps: no wreck's words on the world you orbit, and no
wreck's picture on it while the pile is a fight's worth.


## unit_outcometest

OutcomeRow's six looks (today, A big, B a ledger, C flown to the HUD, D a
table over the buttons, E that table and the things you got drawn big) on the
real LOCAL with the HUD: the real outcomes OutcomeCheck finds (Jon's lifepod,
credits and a part, credits and fuel, a part alone, nothing, credits alone,
the most changes), the numbers the run moved said in every look and layout, every
entry box-tested against the band, the buttons and the text, CONTINUE where
today's look has it; then C animated and under reduced motion: the HUD holds
its old number until the flight lands, flickers, and nothing pressable moves.


## unit_soundmomenttest

The free half of the Oct 17 sound plan (`Audio.FX`, one switchable row a
moment). Audio is off headless, but while it tapes it makes every decision
(limits, suppression, the pick, the caps) and writes it down: through the real
fights, deaths, your ship's loss and the ladder, each picture's own `moment`
against what was heard -- the band, plates on and off, a hit partly taken,
vents and their sputters, deaths G, N, O, P, the Hellbender's furnace and pops,
C1c's split, power_off and no page click into RUN ENDED, the chrome sliding
and the side bar's decode.


## unit_packlayouttest

Jon, on three enemies piled on each other: no ship, wreck, name, hull bar,
chips or intent may overlap another enemy's, or yours. Every pair and triple
of the pictures a fight can bring, every triple with a wreck in it, and
LOCAL's rows of up to twelve wrecks, in the formation (B, the game's) and the
column (C): three or more blocks drawn from their half sheets, every box
apart, inside the view, your ship where it stood; each fighting ship's shield
oval clear of its words, name, bars and chips and of every other block (Jon,
"shield:A"); in B the gaps across a rank even (within 4 px at 1080p), the
gaps between ranks even, every gap at least 24 px.


## unit_chartaheadtest

A new run builds its chart's star field on a worker while the hull is
picked (`MapChart.build_ahead`): the first STARCHART or Tab used to stand
still for the build (350-420 ms on the PC, 300-560 ms on Jon's Mac).
Headless, three galaxies, the real doors: the chart stands at the size the
field is built for, opening it builds nothing, and the field is the one the
chart builds itself, list for list; built while other galaxies are written
over Run, it is still the run's. And the title's shader warm (`ShaderWarm`)
draws the shaders the map draws with.


## unit_artcheck

THE SIZE MISTAKE IS THE INVISIBLE ONE. Everything else about a sprite is
visible the moment you look at it; a module eight pixels too wide, or a card
illustration that is 92x61, is not — it draws, it reads, and it is quietly
wrong on one screen nobody opened. This check has existed since the module
batch and was never in the gate, which meant 119 assets were vouched for by a
command somebody had to remember to type.

IT PASSES WITH ART MISSING, on purpose. Enemies and sector places are still
drawn procedurally and that is the designed fallback, so what is counted is
coverage and what FAILS is a file that exists and does not fit.


## unit_fittest

THE GATE'S BLIND SPOT, CLOSED. This has existed for a long time and never ran
here, so it went eight failures deep without anybody hearing -- six of them a
real break: a module could not be picked up off the hull at all, because an
overlay had been added to a PanelContainer, which lays out every child it has
and ignores their anchors, so an invisible box the size of the panel sat in
front of the ship eating the drag. Nothing looked wrong.

It was left out for a while as "flaky, about one run in six". It was not
flaky. It picked the first EMPTY cell in the hold to drop onto without asking
whether the part fit there, and a Widowmaker is four cells wide in a five-wide
hold -- so when the mount order happened to put the big gun first, the hold
correctly refused the drop and the assertion failed. Calling that flakiness
and reaching for a timing fix is why it took two tries: a bounded wait cannot
make a fact true that was never going to be.

Six seconds, and fourteen consecutive passes.


## unit_parseall

`--check-only` DOES NOT SEE EVERY FILE. CoFightTest.gd sat un-parseable for
five days while it reported zero errors, because it only reaches scripts the
scene tree pulls in -- and the out-of-band harnesses are loaded by hand, at
the moment somebody runs them, which is never in CI. This loads every .gd in
the project and reports the ones that will not.


## unit_rngtest

Neither of these was in the gate, and both guard a rule the codebase leans on
hard. `-- rngtest` is what enforces the named-stream rule: draw from the
global generator for anything that decides something and a run stops replaying
from its seed, which in co-op means four machines quietly disagreeing about
the galaxy. `-- nettest` stands four — now eight — peers up in one process.

The cost of their absence was not hypothetical. MAX_PLAYERS went from four to
eight and NetTest went on asserting four in nine places; it had been failing
ever since and nothing said so, because nothing ran it. That is the whole
argument for these two steps being here.


## unit_sim

The repo's actual regression test. It has already caught an infinite draw
loop and a structural map flaw; a balance change that crashes a run shows up
here and nowhere else.

READ `errors`, NOT `wins`. This is a smoke test, not a measurement. The run is
unseeded and 40 runs is far too few to say anything about balance: three
consecutive runs at one unchanged commit gave 23%, 30% and 35%, and across one
day of pure UI work the same gate printed 45%, 40%, 25% and 8%. Nothing in
those numbers was a change to the game.

So a win rate here is worth roughly +/-15 points and cannot detect a real
economy shift. `ROADMAP.md` records the honest figures: 200 runs is +/-4, and
500 is what a conclusion costs. Quoting this line as a result -- which is easy
to do, because it is the number the gate prints -- says something the gate did
not measure.


## unit_pysyntax

Syntax only. Rendering needs numpy, scipy and soundfile and writes ~850 MB,
which is not what a pull request check is for.

The interpreter is found by RUNNING it, not by `command -v`. On Windows,
`python3` is a Microsoft Store alias stub that exists on PATH, satisfies
`command -v`, and then refuses to run — so the absent-and-skipped branch never
fired and this step failed on every laptop in the project for a reason that
had nothing to do with the code. Windows installs the real one as `python`.


Since then a missing interpreter fails this step like the other python steps, via `gate_no_python`; the "absent-and-skipped" branch described above is gone.


## unit_musiclab

THE LAB IS THE SOURCE OF THE MUSIC, so it gets checked like source.

`music/lab/tk_music_lab.html` is the one file every cue lives in -- the notes,
the instruments, the effects, the arrangement. The oggs under
`assets/audio/music/` are RENDERED from it and the JSON under `music/songs/`
is DUMPED from it, so neither is worth checking: they cannot be wrong on their
own, only stale.

`check_cue.mjs` fails on exactly two things, a held note grinding against its
chord and a cue playing a pitch it has sworn off, and prints everything else
as a note -- off-chord strong beats and repeated notes are usually deliberate.
`check_lab.mjs` drives the page headless: tabs, transport, scrubbing,
settings lines, and no errors on the console.

SKIPPED RATHER THAN FAILED when node or the dependencies are absent, the same
bargain the Python check above makes. The tools need `npm install` in
`music/tools` once per machine, and a fresh clone has not done it.


The "bargain the Python check above makes" no longer holds for python: a missing interpreter now fails. Missing node or its dependencies is still a skip.


## unit_versionguard

THE GUARD THE VOCABULARY PASS NEEDED AND DID NOT HAVE. That pass renamed keys
in three persistence surfaces and raised none of the numbers guarding them.
Nothing failed: a save stamped with the current version was read with keys
that were not in it and came back as a galaxy with no contracts, two co-op
builds shook hands and drew every partner unbranded, and every run ever flown
stopped unlocking its manufacturer.

The vocabulary check below could not have caught it and neither could any word
grep, because BOTH SPELLINGS ARE LEGAL. What changed was the shape.

Run against this branch's diff from main, or against the last commit when
there is none. It found all four surfaces of the August break when pointed at
it after the fact, and a fifth nobody knew about -- five save keys renamed
stoker_* to hellbender_* at a version that did not move.
FOUND BY RUNNING IT, for the reason the audio step below already gives: on
Windows `python3` is a Store alias stub that satisfies `command -v` and then
refuses to run. This step was written with `command -v` first and failed on
this machine immediately, which is the comment down there doing its job.


## unit_enclint

WHY THIS IS A GATE AND NOT A HABIT. Every fault it finds was found by hand
first, one encounter at a time, by a person reading prose -- a dominated
choice, a walk-away that spent the encounter, credits paid to an empty sky, an
encounter reaching into the hold. All of them are patterns. Only "this reads
weird" needs eyes, and eyes are wasted on the rest.

BASELINED, so it could be switched on the day it was written. The table had 35
findings the moment the linter existed; a gate that failed on all of them
could only ever be turned on after a cleanup nobody had time for, and eighty
new encounters were about to arrive. `--strict` fails on what is NOT in
`tools/encounter_lint_baseline.txt`, so old debt stays visible and stops
blocking new work.


## unit_prose

Two tools, one question each. `prose_grade.py` holds the encounters to the
reading level: grade 7 or under, 17 words a sentence on average, no sentence
over 22 words (re-ruled 2026-10-13 for all player-facing text; it was grade 5
from 2026-09-12). Every encounter meets it, so it needs no baseline. The rest
of the text is reported by `prose_grade.py --all`, not gated. The grade is a
ceiling, not a goal: prose_tells' "fragments" flag is the floor.
`prose_tells.py` reads EVERY player-facing string for the tells the
encounter-prose skill lists -- "It is not X. It is Y." past one an encounter,
"which is the point", a summing-up closer, a dash, "round", hands in an
encounter -- and is BASELINED like the linter above: what predates it is a
ruling for Jon, not a lint failure. Its REVIEW list never fails the gate.


## unit_vocab

A VOCABULARY RULING WITH NOTHING CHECKING IT DECAYS BACK. This project spent
months with four words for one concept -- house, maker, man, manufacturer --
spread across 42 code files, a save key, a network wire key and eleven
documents. Ruled 2026-08-24: the word is `manufacturer`. They manufacture
parts for spaceships; they are corporations, not families, and `house`
imported a dynastic register the setting does not have.

THE MATCH IS CASE-INSENSITIVE. It was not, at first, and `GROUPED BY HOUSE`,
`THE HOUSE PERK IS REROLLED` and eleven more upper-case comments walked
straight past a guard whose whole job was to catch them. A vocabulary check
that only sees one casing is a vocabulary check that lies.

Three exemptions, all deliberate, all narrow:

  1. The LAN idiom -- "friends in the house", "outside the house" -- is
     English about people under your roof, describing local-network play.
     Renaming it produces nonsense.
  2. "maker's mark" -- the stamp a craftsman leaves on the work. A real
     English term, used in an art prompt and in an insurance document.
  3. "Widowmaker" (a gun) and "gatehouse" (a building) are words that merely
     contain the string.

  4. A retired word in BACKTICKS or as a QUOTED KEY is being NAMED, not used.
     `"chassis_maker"` and `"makers"` are keys sitting in files on players'
     disks. The readers that still honour them are the fix for a rename that
     shipped without raising the numbers guarding it, and a version ladder
     saying a key moved from `makers` to `berths` is doing the same job.
     Banning the old spelling from the code that has to READ the old spelling
     would force a choice between a green gate and a working load.

     Deliberately narrow: the quotes or the backticks have to be there.
     `var maker := ...` is still caught, which is the vocabulary this rule was
     written for -- checked by dropping such a file in and watching it fail.

BRAND AND MARQUE were added after they were used to route AROUND this check:
a rename hit the guard on `maker`, and a synonym went in instead -- first as a
local called `brand`, then as `marque` in a comment. Neither was on the list,
so neither failed, and the vocabulary the list exists to protect drifted
anyway. A guard that only knows two of a word's synonyms teaches people the
third.

BRANDED AND UNBRANDED ARE DELIBERATELY NOT HERE, and this is the line: the
banned usage is the NOUN standing in for `manufacturer`. `unbranded` means
"carries no manufacturer", which is a real state a part can be in -- it is on
screen as UNBRANDED SALVAGE and there is no one-word replacement -- and
retiring `branded` while keeping its antonym would leave the pair incoherent.
`-w` treats both as their own words, so they pass by construction.

NOT `-w`, AND THAT IS THE POINT. To grep, an underscore is a word character,
so `-w house` does not match inside `delivery_houses` -- and every compound
identifier in the codebase was invisible to this check. It was found the
expensive way: `RunState.delivery_houses()` was renamed, `StarchartScreen`
was not, and opening the chart printed "Nonexistent function" while the
guard stayed green. The boundary below treats an underscore as a separator
and still ignores `widowmaker` and `gatehouse`, where the preceding letter
is alphanumeric and there is no boundary to match.

If you are adding a sixth, the bar is: would a person say this out loud?
Two passes once, while the archive's prose needed a skip for the short
word. That prose went with the ARCHIVE (Oct 22), and both passes now run
everywhere.


### unit_vocab, second note

The same check for prose. docs/archive/ is out of scope on purpose -- those
files describe a moment and are kept stale deliberately.

Two exemptions here that the code does not need: "house style", the
publishing idiom for a publication's own conventions, and the line in
docs/README.md that states the rule, which has to name the words it bans.

## unit_cometflighttest

The comet's three spots as flights (CometFlightTest): a comet forced into up to
25 systems a seed over four seeds, every world's orbit to every spot planned
and one in four flown. Found and clean in 99%, settled and held within 0.5 px,
the comet met there, never inside a sun's keep-out, and click to settled at
each spot within Jon's limits (Nov 9, "M1"): median 4.5 s, 90th 7.5 s, worst
8 s. It measured 4.30/6.92/7.42, 3.42/5.92/7.44 and 2.55/4.89/7.49 s for the
far, near and star spots when the limits were set; about 90 s.

## unit_arrivesidetest

The side and way round a flight arrives (ArriveSideTest; Jon, Nov 10, "S3", the
choice dropped Nov 11): on the real map a click on either half of the selected
world, Shift up or held, arrives on the lit side going with its spin, the tag
says nothing of sides and the line drawn is the one flown; then
the solver alone over real systems, every sided or sensed flight landing as
asked. About 60 s.

## unit_cometcatchtest

The catch on the real map (CometCatchTest): the race planned for all three
spots, the comet's page offering them, a spot flown to and waited at, the pass
down to LOCAL with the reading open, the ship back on its spot after, and TOO
LATE twice, neither flown to. About 34 s.

## unit_jumpshadertest

Every jump shader compiled by a real renderer, and every landed film's stage built and
drawn through the real Router (JumpShaderTest). Headless runs use a renderer that compiles
nothing, so at the jump films' merge (Nov 11) a shader with a `return` in `vertex()`
passed JumpSeqTest and would have shipped a film that draws nothing. The sheet draws each
`shaders/jump/*.gdshader` on a rect, then plays every film to its commit, with an engine
logger that fails on any error; a shader that does not compile prints `SHADER ERROR` and
`Shader compilation failed`, which it counts. Checked by adding two broken shaders: both
failed it.

It is the gate's one windowed unit. On Windows it opens on the hidden desktop (TK_HIDDESK,
which gate_land.sh's env.sh finds) with the real binary, never on Jon's screen; on Linux CI
under `xvfb-run` with Mesa's software OpenGL (the workflow installs both); with no display
and no xvfb-run it fails, since a check that cannot run has not passed. Nothing in it is
timed: it counts errors, so a busy machine only makes it slower. Exit-time leak reports of a
windowed run are allowed; an error while the films play fails in the sheet itself.
About 40 s on the PC.

On CI it timed out from its first run (Nov 11, 600 s killed, 6 or 7 of the 11 films played,
about 80 s a film against a few seconds on the PC): Mesa's llvmpipe draws every frame on the
CPU, the films are 529 frames each at the harness's 1920x1080 window
(`DisplaySettings.leave_launch_window`), and four Godots share a 4-core runner. Nothing hangs;
it is slow. The Linux xvfb branch now passes `--resolution 960x540`, the project's own size,
which `leave_launch_window` leaves alone: a quarter of the pixels, every shader still compiled
and every film still played to its commit. The Windows and `DISPLAY` branches keep the full
window. Not yet measured on CI: read the unit's time off the next run and set the limit to
twice it.
