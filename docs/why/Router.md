The reasoning behind `tkg/scripts/autoload/Router.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Docked state

Above `var docked: bool = false:`:

```text
Whether the ship is tied up at a station rather than flying the system.

Not on Run and not a Sig signal: it is a fact about which side of the airlock
you are on, and the two functions below are the only ways through it in
either direction -- every arrival, every UNDOCK and every resume goes through
show_sector(). The HUD reads it to decide what its first tab says: LOCAL
greyed at the berth (UNDOCK is the only way out, Jon, Oct 27), STATION on a
page looked at from it (the map, the chart), so that looking round and coming
back does not make you re-dock to return.

Leaving the berth ends the docking, and with it every deck's power-on.
```

Above `var powered := {}`:

```text
THE DECKS THAT HAVE POWERED ON THIS DOCKING, by deck id. Jon: once a station's
or a lab's power-on has played, it should not play again because you went to
the star chart and came back. Coming back builds a new StationScreen, so the
scenes cannot remember it themselves; undocking clears it, and the next
docking powers them on again.
```

## Breadcrumbs

Above `var _crumbs := not "sim" in OS.get_cmdline_user_args()`:

```text
BREADCRUMBS IN godot.log, one short line each: every screen change, a
resume, a jump, a fight's start and end. A friend's log used to hold the
build, the run's seed and A.S.H.'s lines and nothing else, so a report
could not say where they were when it went wrong (release check, Oct 18).
Not under the balance sim, which plays hundreds of runs.
```

## Closing the window

Above `func _notification(what: int) -> void:`:

```text
CLOSING THE WINDOW SAVES, as SAVE & EXIT does (release check, Oct 18). The
autosave only writes on a screen change, so a wreck looted, a part fitted or
a trade made since then was lost to the window's X. Mid-fight it does what
SAVE & EXIT does there: the save from before the fight stands and the fight
is noted so it starts again. The title, the hull pick and a finished run
save nothing (`_autosave`'s own rules). A harness's `quit()` never comes here.

A FLIGHT PLAN STILL BEING MADE ON A WORKER is waited for before the engine
shuts down (`ShipFlight.drain`): here as the window closes, and as this
autoload goes, after every screen (a harness's `quit()` comes that way). Left
out, a plan the map asked for crashed the quit (signal 11), Oct 31.
```

## Pair handover

Above `func pair_handed(at: int) -> bool:`:

```text
WHETHER A MAP OR LOCAL OPENING SYSTEM `at` IS HANDED ITS PAIR by the picture
before it (ruling 23, PROTOCOL 14): that system's map is the screen up (LOCAL
built ahead of a move, `ZoomLadder.preroll`), or the screen swapped out this
very frame showed it (its map or LOCAL). Then it opens on the kept clock, the
angle that picture had (`Run.map_t`), and never takes the party's: taken at
the handover, a partner's clock ahead jumped the pair forward map to LOCAL
and back LOCAL to map (the map put away wrote its own clock again, review 1).
The map catches up with the party while it is up (`SystemMapScreen._catch_up`),
and takes it at once out of LOCAL when it is too far on to
(`NetSession.handed_clock`).
Opened after anything else -- a fight, the dock, the chart, a jump -- it takes
the party's clock at once (`NetSession.adopt_clock`): nothing shown before
had the pair in it.
```

## Screen swap

Above `func _swap(screen: Control, chrome: bool = true) -> void:`:

```text
`chrome` is whether the HUD belongs above this screen. The launcher and the
record reached from it run before any run exists, and the HUD reads ship
state — it bails on a null hull, but an empty bar above a title screen is a
bug that looks like a decision.

THE SCREEN BEING LEFT IS HIDDEN, not just queued. `queue_free` leaves it in
the tree for the rest of the frame, and whatever redraws it there -- hiding
the HUD for the title screen grows the content area and resizes it -- draws
it against state that has already moved on. QUIT and SAVE & QUIT clear the
hull before this runs, so the starchart drew once more with no ship and
logged hundreds of errors for a frame no one ever saw. A hidden control is
never drawn. `-- quittest` guards it.
```

## Page sound

Inside `_swap()`, above `if current == null or is_front_door(current) or is_front_door(screen):`:

```text
THE PAGE SOUND IS FOR MOVING BETWEEN PAGES, not for arriving in the game.
Jon: no click "when starting the game", nor "when launching the ship for
the first time". So booting, and every swap to or from the title or the
lobby, is silent; `screen_changed` below still fires for everything else
that listens to it.
```

## Screen fade

Above `var seamless_next := false`:

```text
The incoming screen arrives; it does not appear.

THE OUTGOING SCREEN IS NOT CROSSFADED, and that is deliberate rather than
lazy. It is hidden and freed on the same frame it always was, because the
reason it is hidden is that drawing it again draws a run that has already
moved on -- QUIT clears the hull before this runs, and the starchart drew
once more with no ship and logged hundreds of errors for a frame nobody saw.
Holding it on screen to fade it out would put those frames back. `-- quittest`
is the test that found that and it still has to pass.

So only the arriving half animates, and it works because of what is now
BEHIND it: the sky belongs to the Router, so it does not blink between
screens. The content fades up over a world that was already there, which is
the whole reason this reads as continuity rather than as a dissolve.

Modulate rather than a colour rect over the top: a rect would need to be
above the HUD to cover it and below the cursor to not, and the ordering
problem is not worth a fade.
The next screen arrives without the fade, once: set when the screen leaving
has already made itself look exactly like the one coming (a won fight lowers
its hand into LOCAL's band first), so fading the new one in over the sky
would blink every ship for a few frames to show nothing new.
```

## Animation gating

Above `func animating() -> bool:`:

```text
Whether anything should animate at all.

Three cases, and the third is the one that is easy to miss. The SIM boots the
whole project and swaps hundreds of screens with nobody watching, so a tween
per swap is pure cost. HEADLESS has no frames to show it in.

And every `-- ...shot` TOOL runs windowed, on purpose -- the dummy display
server never emits `frame_post_draw` -- so without this line the fade caught
all of them: they wait a fixed handful of frames and then photograph, which
after this change means photographing a screen at whatever opacity it had got
to. Every picture the project judges its own layout from would have come out
dim, and the tools predate the fade so none of them knows to wait.

Matched by suffix rather than by a list, because the list is nine long today
and the next one would be added without anybody thinking about this.
```

## Sky exclusions

Above `static func nav_screen(s: Control) -> bool:`:

```text
Which screens the sky belongs behind.

Every exclusion here is for its own reason, so this is a list and not a rule.

The STATION is an interior and its cutaway says so: a starfield on a deck
would contradict the one conceit that screen is built on.

The LAUNCHER and the STARCHART are not excluded for being wrong — they
already draw a galaxy of their own, and two skies is one more than anywhere
has.

THE SECTOR is the interesting one, because it is the screen this layer was
lifted out of. `EncounterView` paints a region-tinted wash in its own `_draw`
and its backdrop draws ON TOP of that wash, so the two are one composition
rather than two layers that happen to be stacked. Moving half of it up here
would put the wash over the sky and lose the thing it was built to do. It
keeps its own pair, this one stands down behind it, and nothing bakes twice.
Unifying them means moving the wash as well, which is a change to the best
screen in the game and does not belong in the same step as giving nine bare
screens a sky for the first time.

Everything else is somewhere in space, which is the entire point of the layer.
LOCAL, the sector map or the star chart: the screens built on `field`.
```

## Autosave

Above `func _autosave() -> void:`:

```text
The one place the run is written to disk.

Every safe point is a screen swap and every screen swap comes through here,
so this is a chokepoint rather than a list of call sites that someone has to
remember to extend. Combat is excluded by in_combat() — `combat` is assigned
before start_combat() swaps its screen, so the fight's own swap saves nothing
and the state on disk stays the one from just before the shooting started.
Choosing a chassis is excluded for the same reason combat is: the state is
not one you should be able to come back to. start_new_run() has already
rolled a world and a random hull by the time the select screen opens, so
without this, quitting at the select and pressing CONTINUE would resume into
the sector flying a ship you never picked — the one choice the screen exists
to ask, answered silently by a dice roll.

The empty map is not a paranoid check either. `_snapshot()` reads
`Run.node_at()`, which is `map[at]` with nothing in front of it, so a run that
has a hull but no map takes this chokepoint down with an index error — and
that is exactly the state a save file with a valid version and a truncated map
used to leave behind on its way to the launcher.
```

## Room you are in

Above `func _room_for(screen: Control) -> Variant:`:

```text
The party, before a dive. Runs with no run loaded, like the launcher, so it
takes no HUD — the bar reads ship state and there is no ship yet.
THE ROOM YOU ARE IN, decided here because this is the one place every
screen change passes. It used to be the station's own business -- on in
`setup`, off in `_exit_tree` -- and that could not survive a second room:
`_exit_tree` runs at the end of the frame, AFTER the next screen has
started, so leaving a station for the sector would have switched open space
on and then straight back off.

null means NO CHANGE, and it is what the panels return. The ship, the
cards, the chart and the rest are opened from wherever you are, so they
keep that place's room -- the same rule `music_state` applies to the score.
```

## Star room

Above `func _star_room() -> StringName:`:

```text
OPEN SPACE, OR THE STAR OUTSIDE. Pulsars, red and blue hypergiants each have
a room of their own -- Jon's picks from the sound pass, layered -- and every
other system is plain open space. Read off the same fields `star_kind` reads,
so what you hear and what the chart calls the star cannot disagree.
AND PLAIN SPACE IS THE REACTOR. Its first room was space tone -- the noise
outside the hull -- and Jon cut it for being distracting. What replaced it
points the other way: "just like a reactor hum", the ship's own plant, which
is the one sound that should be there in a system with nothing in it.

THIS LINE HAS BEEN LOST ONCE ALREADY. I reverted this whole file to strip
some timing prints out of it and took the room with them, and the symptom
was Jon asking why open space had gone quiet again. Revert a hunk, never a
file, when the file has other work in it.
```

## Boot splash handover

Inside `show_launcher()`, above `var boot := current == null`:

```text
THE FIRST TITLE OF THE PROCESS COMES OUT OF THE BOOT SPLASH, and the
splash is this screen's own first frame: the wordmark where the title draws
it (`assets/splash/`, project.godot's boot_splash). The usual screen fade
would take the wordmark down to nothing and back up in the first eighth of
a second, a blink right at the handover. So the screen arrives as it is and
everything the splash did not hold fades up around the wordmark
(`LauncherScreen.fade_up_around_title`). Later visits fade as before.
```

## Run start reset

Above `func _on_run_started() -> void:`:

```text
A run beginning — started fresh or restored from the suspend save — cannot
inherit the last one's fight. Nothing in RunState touches `combat`, so
ABANDON RUN from the pause menu mid-fight used to leave in_combat() true
forever: the new run's sector wired itself to the dead run's enemy, the
autosave bailed on every screen swap so the run was never written, and the
HUD kept SHIP and STARCHART greyed for the rest of it.

Hung on the signal rather than written into new_run(), because the other
boundary — load_into_run() — needs exactly the same reset and emits exactly
the same signal. Two call sites, one chokepoint, same reason _swap() is the
only place that saves.
```

## Dropping a fight

Above `func drop_combat() -> void:`:

```text
THE FIGHT ON SCREEN, DROPPED: out of the party's crew if it was shared and
still on, off the signal bus, and gone (`Combat.abandon`). SAVE & EXIT,
ABANDON and a run starting all leave a fight this way (review, Nov 5): they
used to drop it with no leave, and the partners sat on "WAIT <name>".
```

## New run

Above `func new_run(seed_value: int = 0) -> void:`:

```text
A run starts by choosing a chassis, then opens on the sector rather than the
chart: your ship in open space, not a graph of places you have not been yet.

start_new_run() still runs FIRST and rolls the world plus a random chassis,
so every screen has a valid hull to draw before anything is chosen. The
select screen then refits that ship as you browse and hands control on.

A run that was live when this is called was abandoned, not finished, and goes
into the record as such — restarting a bad opening is a real outcome and
pretending otherwise would quietly inflate the win rate.
`seed_value` is the host's, and zero means roll one. A party dive is an
ordinary run that happens to have been handed its seed — which is why it
comes through here and lands on the chassis select like any other. Each
player picks their own ship on the same galaxy, and that IS the party
composition rule in `docs/coop-design.md` §6.

The previous forced seed is put back rather than cleared, so `-- seed N` on
the command line survives a run started from the lobby.
```

## New run opening

Inside `show_chassis_select()`, above `s.launched.connect(func() -> void: show_local())`:

```text
A NEW RUN OPENS ON LOCAL, your ship side on (Jon: "when you start the game,
you start in the local view"); the sector map is a tab away.
NO TOUR (tutorial direction B, Oct 17): the controls are yours the moment
the ship stops. What to do next is the goal line under the HUD (`GoalLine`),
and each thing is taught by a hint the first time it matters (`Hints`).
```

## Resuming a run

Above `func resume_here() -> void:`:

```text
Where a restored run picks up. Always the sector — every arrival lands there
anyway, and it is the one screen that reads correctly for every node type.

The fight at an uncleared combat node is NOT restarted here. It is offered:
the sector's action button says ENGAGE and starts it when pressed. Restarting
it automatically would drop a returning player straight into a turn they did
not ask for, and the node stays uncleared either way, so nothing is skipped
for free — flying on forfeits the loot.
```

## Saved fight over

Above `func _saved_fight_over(saved: Dictionary) -> bool:`:

```text
A FIGHT SAVED OUT OF THAT THE PARTY HAS SINCE FINISHED (review, Nov 5).
SAVE & EXIT leaves a shared fight now, so the partners can end it while
this ship is away; restarted, it was a second fight against an enemy the
party had killed (a second Custodian, or a dead Hellbender's reward again).
Finished means the party's fight here, with the saved ids, killed or broken
off; a fight saved at the core with the core cleared since; or a Hellbender
no longer here. A fight everyone simply left (`paid` 0) starts again, as a
solo one always has.
```

## Starchart rescan

Above `func show_starchart() -> void:`:

```text
Re-scan before drawing, because SIGHT IS A SNAPSHOT AND REACH IS LIVE.

`chart_from` runs on arrival and `sensed` keeps that answer until the next
one. `reachable` is computed from the ship's CURRENT thrust every time it is
asked. Fit a thruster at a station and reach grows while the sight marks do
not -- so a system becomes reachable, is drawn, prices its fuel, and cannot be
jumped to, because `can_jump_to` wants `sensed` as well.

Reported as a system inside both rings whose button read NOT ENOUGH FUEL, on a
ship carrying 279 fuel against a 6-unit cap. The message was the screen's
if-chain treating anything left over as an affordability problem; the cause
was two answers to "how far can I see" taken at different times.

Cheap enough to just do: one pass over the map, once per opening, against a
draw that walks every node anyway.
```

## Show sector

Above `func show_sector() -> void:`:

```text
WHERE YOU ARE: the system map (Jon: "a system map like Starfield's"), or the
side-on view while a fight is on or a jump is leaving. The callers that mean
"back to the place" come through here -- UNDOCK, the galleries' and PARTY's
BACK or LEAVE, the end of a fight -- and land where the place is: the map;
LOCAL in a fight, or as UNDOCK's one distance out on the ladder; and the
station from a page looked at from the berth (`over_berth`). The HUD's first
tab does not come through here: it goes to `show_station` or `show_local`
itself (`HudBar._go_here`).
```

Inside `show_sector()`, above `if over_berth():`:

```text
A HELLBENDER AT ANCHOR DOES NOT SHUT THE MAP. It did (Oct 2: "the map would
let you walk round it"), from when it was fought from anywhere in the
system. Since it has a place of its own on the map (Jon, Oct 15: one place,
one fight) the map is the only way TO it -- LOCAL elsewhere says "Fly out
to it" and its button is this door -- so with the old hold kept, SECTOR,
that button, Tab and the end of a fight it was still here after (fled, or
its escape burn hopping back) all came back to LOCAL, and only STARCHART
left (Jon, Oct 22: "Fighting the Hellbender totally breaks the sector and
local buttons. You are able to click starchart.").
DOCKED, "BACK TO THE PLACE" IS THE BERTH (Jon, Oct 27: UNDOCK is the only
way out). From a page looked at from it -- the map, the chart, PARTY's or a
catalogue's LEAVE -- this went to the map and undocked on the way, so
leaving a co-op party page walked you out of the station unasked.
```

## System map arrival

Inside `show_system()`, above `if arrived:`:

```text
A JUMP'S ARRIVAL IS NOT A MOVE BETWEEN DISTANCES: the departure's LOCAL is
another system. Taken as one, the zoom out of it carried the old system's
planet and station into the new system's map for half a second as its name
decoded beside them (nav audit, Oct 17). The map plays its own arrival.
```

## Undock only way out

Above `func cast_off() -> bool:`:

```text
UNDOCK IS THE ONLY WAY OUT (Jon, Oct 27, on Jeremy's "LOCAL lets you leave a
station too easily"). The map and the chart are a VIEW from the berth
(`show_system`), so you can look round the system and plan the next jump while
tied up -- but flying the map's ship, GO on an event, or the chart's JUMP is a
move, and a move from the berth is refused and says how to leave. It used to
cast off on the spot (the clamps, the decks' power-ons spent, no undock seen),
which is how a player left a station without meaning to.

The words are the HUD's: LOCAL greyed at the berth says the same
(`DOCKED_LINE`), and so do the map's FLY HERE and GO and the chart's JUMP.
True when the ship is free to go (it is not docked, and nothing is on the pad).

THE PAD HOLDS THE SHIP IN SPACE TOO. A derelict's frame (TRANSFER on the rail)
moves you aboard where it was found, with no berth to refuse the jump -- and
0.4.1 let the ship fly on with its whole kit on a pad no screen showed, to be
refused by the next station's UNDOCK for good (Jon, Oct 23). The move is up
while the pad is loaded (`show_transfer`), so this is the backstop.
```

## Docking place

Above `func at_station(n: MapGen.MapNode = null) -> bool:`:

```text
WHETHER THE SHIP IS AT THE STATION ITSELF, the one place DOCK is offered
(Jon, Oct 18, "dock:A": "only at the station", not anywhere in a system that
has one). The other half of `cast_off`: a move off the berth undocks, and a
dock only happens where the berth is. It was offered from anywhere in the
system -- LOCAL's bar at a world drew the station's side beside it and DOCK
played the whole dock into a station that was not there -- the same picture
that undocking without leaving made (8d653b27).

At the station's own body as the map left the ship (`Run.site_here`), or
where the map's ship is right now while the map is up on that system, or
docked. Every DOCK asks this: LOCAL's bar and the station's side on it
(`SectorScreen`), the map's DOCK card (`SystemPanel`) and its beacon
(`SystemMapScreen.take_action`), the fuel hint's "Refuel here", and
`show_station` itself.
```

## Show local

Above `func show_local() -> void:`:

```text
LOCAL: the side-on view of the system, where the jump leaves from and every
fight is fought.
Where you are. Always available, including after the run ends.
No combat guard here. after_combat() routes here from inside the fight, so a
"are we in combat" check would swallow the very transition that ends it — the
HUD disables the SECTOR tab during a fight, which is where that belongs.
(after_combat clears `combat` first, so `fight_up` never swallows it: it
stops only a rebuild of the fight's own screen while that is the one up.)
DOCKED, ONLY UNDOCK COMES HERE (`show_sector` from the berth; Jon, Oct 27).
The player's other doors stop short of it: the HUD's tab is greyed at the
berth and goes back to it from the map or the chart, Tab goes round by the
berth, and the map's GO refuses. A harness may still call it to leave by hand.
```

Inside `show_local()`, above `SectorScreen._approached_at = Run.at`:

```text
AND YOU DO NOT FLY IN TO A SYSTEM YOU ARE ALREADY IN.

The approach plays once per node, latched on `_approached_at`, and a
station node never sets that latch: arriving at one docks you straight
away, so the sector screen is not built until you leave. Undocking was
therefore its FIRST sight of the node and flew the ship in from off
screen -- Jon: "You are already in the sector." Setting the latch here
says what is true, that this system has been arrived at.
```

Inside `show_local()`, above `s.setup(combat if in_combat() else null)`:

```text
Hand the live fight back if there is one. A SectorScreen built with no
Combat shows no fight, and the tabs that stay lit during one — CARDS, and
now HISTORY — swap this screen out and back. Without this, looking at the
card catalog mid-fight and pressing SECTOR returned you to an empty sector
with `combat` still running behind it, which is unwinnable and unloseable.
```

## Back from galleries

Above `func back_to(here: Control) -> Callable:`:

```text
Where LEAVE goes from a page you opened OVER the run.

The catalogues sit on the HUD, so they can be opened from any screen and
"back" cannot be a constant -- this is the same question PartyScreen answers
inline, asked once so the two galleries do not each answer it differently.

A GALLERY IS NOT A PLACE TO BE SENT BACK TO. Opening MODULES from CARDS and
pressing LEAVE should put you back in the game, not bounce you between two
catalogues; anything not named here falls to the sector, which is the one
screen that always exists mid-run.
```

## Moving day

Above `func show_transfer() -> void:`:

```text
Moving day, after a hull swap that left something on the dock.

NO HUD, and that is deliberate: the bar's SECTOR and STARCHART tabs are ways
off this screen, and there is no off it -- the ship cannot leave with crates
on the ground, so offering the exits and then refusing them is worse than not
offering them. `chrome = false` is the same argument the chassis select makes.

OVER THE STATION, NOT INSTEAD OF IT. The dock swapped the station out, and
with the station gone the sky came back: you moved aboard in open space, the
system's moon behind you, as if you had undocked. It opens over the Shipyard
now, dimmed behind it, and closing it leaves you standing in the same yard
(Jon: yes). Anything else that opens it -- a tool, a screen that is not the
station -- still gets the page of its own.
```

Above `func _reopen_move() -> void:`:

```text
AT THE BERTH WITH THE PAD LOADED, the move is what you see. The pad is what
holds UNDOCK shut, and the move is the one screen that shows it -- so a berth
with a loaded pad and no move open was a station that refused to let you go
and could not say why (Jon, Oct 23: a hull found in space flew its kit here on
the pad; and Tab, or any door off the station, freed the yard's move with the
station, and docking again never brought it back). Deferred, so the station is
in the tree and set up first.
```

## Jump mailbox

Above `var _post_depart: int = -1`:

```text
A MAILBOX, NOT A MODE, and the distinction is the whole safety of this.

A jump used to be one frame: press the button, the fuel is gone and you are
there. It is a sequence now — the ship revs and leaves the OLD system, and
only then does anything get spent — so something has to carry "you committed
to a jump" across a screen swap.

These are written once and READ ONCE. The screen that takes a message owns
it from then on, and if that screen dies before it commits, the jump is
simply cancelled with nothing spent. A persistent flag would be a mode, and a
mode is a thing that can be left switched on.

NOT ON `Run`, for the same reason `docked` is not: it is a fact about which
side of a transition you are on, it must not be saved, and a departure that
has not committed is indistinguishable from being parked where you already
were. That is what makes a quit mid-departure safe without a save version.
```

## Jump arrival

Inside `_on_jumped()`, above `SystemMapScreen._parked.erase(_index)`:

```text
IN AT THE EDGE. A jump arrives where every arrival does, whatever orbit
the ship was left in on the last visit, so an arrival's ambush is at the
edge and leaves its wrecks there -- not on a world whose own fight's hulls
are already lying round it (Jon, Oct 15: one place, one fight).
```

Inside `_on_jumped()`, above `park_at_station(Run.node_at())`:

```text
...BUT AT A STATION, AT THE STATION (Jon, Oct 18, "arrive:B"): a jump into
a system with a station brings the ship in alongside it, so DOCK is there
on arrival and LOCAL has the station's side; a jump anywhere else arrives
at the edge as above. (No fight is ever rolled at a station, so nothing
arrives there to leave its wrecks.)
```

Nov 10 (the jump films): the arrival at the edge of the map is the whole arrival for a quiet
jump (Jon: "I just want the arrival at the edge of the map"); LOCAL's name card and reversed
warp no longer play after a jump at all (`docs/why/SectorScreen.md#arrival`). The flow here is
unchanged: `commit_jump` at the film's commit time, `_on_jumped`, `resolve_current_node`, the
autosave at the safe point, `show_sector` to the map.

## Arrival save

Inside `resolve_current_node()`, above `_autosave()`:

```text
The save the SaveGame header promises: on the sector, at the node you flew
to, with the contact still there. Until this line the last write predated
the JUMP — start_combat() assigns `combat` before it swaps, so the fight's
own swap saved nothing and the star chart's was the newest state on disk.
Force-quitting a fight therefore refunded the fuel, put you back at the
system you left, and let you pick a different route entirely.
```

## Arrival

Inside `resolve_current_node()`, above `if n.ambush_pending and no_fights_at(n):`:

```text
Every arrival lands on the sector. You should see the place before you are
asked to do anything with it — a station is a lit hab ring turning in the
dark, not a menu that appears. Fights are the exception only in that they
start immediately, and combat happens on the sector screen anyway.
Something followed you in. This is a fight on the way to the door rather
than instead of it: the system still holds whatever it held, so the node
is NOT consumed by winning here — see start_combat's `clears_node`.
(never at a station: a save from before the rule may still carry the flag)
```

## Hellbender arrival

Inside `resolve_current_node()`, above `if Run.hellbender_alive() and Run.hellbender_at == n.index:`:

```text
The hellbender holds this system. Nothing here is reachable past it — not the
dock, not anything the system was offering — so arrival lands on the sector
and the one button says what there is to do. NOT auto-engaged, for the
same reason the core stopped being: two people never arrive at a system on
the same second, and a set piece a party cannot gather at is fought alone
by design. See the CORE note below.
```

## Core arrival

Inside `resolve_current_node()`, above `MapGen.NodeType.CORE:`:

```text
THE CORE DOES NOT OPEN ON ARRIVAL, and it used to.

Dropping straight into the custodian is right for one ship and wrong
for a party, because two people never arrive at a system on the same
second. Whoever landed first was in the boss fight before the other had
finished their jump — so the run's one set piece was fought alone by
design, and the party had no way to be at it together. A latecomer
joining mid-fight works and always did; there was simply nothing to
join by the time they got there.

It also fixes a second core: winning consumed the node, and this branch
never checked `cleared`, so the next ship to arrive rolled a fresh
custodian and killed the galaxy's boss again. FIGHT has checked that
since it was written; CORE never did.

So the core is a place you arrive at now. The sector says what is out
there and the button says ENGAGE, which is the wiring a resumed run has
always used — `_on_action` and `_quiet_lines` both already had the
case, and this makes it the ordinary path instead of the restored one.
```

## Rolling a system

Above `func _roll_here(n: MapGen.MapNode) -> void:`:

```text
Decide what is waiting at a system, once, and leave it on the node so the
save carries it. Cleared nodes are left alone — whatever was here is resolved
and re-rolling it would put it back.

Both of these used to be rolled at the moment the screen opened, which meant
quitting and resuming rolled them again: a bad enemy draw or a hail with two
bad options cost nothing to refuse. That is save-scumming through the front
door, and it defeats "every death is self-authored" without touching a
number. Idempotent by design — it is also the lazy path for saves written
before the node carried these.
```

Inside `_roll_here()`, above `OptionTable.ensure(n)`:

```text
WHAT THERE IS TO DO HERE, decided once and written onto the node.

Same contract as `foes` and `event_key` above and for the same reason: this
runs before the autosave, so quitting and coming back cannot re-roll it.
Save-scumming through the front door is what that rule exists to stop.

Stations are excluded because a station IS its option list -- the shelf,
the hull on the rack, repair and fuel -- and it is the one node the chart
telegraphs. The core is excluded because it is a hand-authored boss.
```

## Ambush roll

Above `func _roll_ambush(n: MapGen.MapNode) -> void:`:

```text
Whether anything followed your heat trail in.

Rolled here with the rest of what a system holds, and for the same reason:
arriving is the safe point, so a hostile your own throttle attracted cannot
be refused by quitting and coming back cold.

NO NODE INHERENTLY HOLDS A FIGHT ANY MORE, so the old exclusion went with the
types: "being ambushed on the way to a fight is the fight" was true of a FIGHT
node and is false of a system that merely OFFERS one. The ambush is a separate
interrupt and the option is still sitting there when it is over. Only the core
is excluded, because it is a hand-authored boss.
```

## Foes

Above `func _roll_foes(n: MapGen.MapNode) -> Array[StringName]:`:

```text
The contact and its pack. Packs appear deeper in, and more often in lawless
space where nobody is flying alone. They split health rather than doubling it
— see Combat.start.
Positional. What is flying at a system is a property of the system, and
`n.foes` is already saved per node — so this was ALREADY meant to be decided
once and stay decided. It just had no way to say so across two machines.
```

## Station docking

Inside `show_station()`, above `var here: MapGen.MapNode = Run.node_at()`:

```text
ONLY AT THE STATION (dock:A): every DOCK is offered only there, and this is
the door they all go through, so a dock from anywhere else in a station's
system is refused here too, whoever asks. A run or a harness that starts
docked parks the ship at the station first (`park_at_station`). (A system
with no station never offers one; the harnesses that dock there anyway,
to see the berth, still can.)
```

Inside `show_station()`, above `if not docked and current is SystemMapScreen and ZoomLadder.enabled() and ZoomLadder.design_for(3) in ["B", "D"] \`:

```text
ARRIVING, OR JUST COMING BACK TO THE DESK? Docking is a thing the ship
does once; walking back to the station from the chart or the ship screen
is a page change. Only the first plays the clamps, and only the first
swallows the page sound -- the rest are ordinary tabs (Jon).
THE MAP'S DOCK, ON THE LADDER (3B, 3D): down to LOCAL first, beside the
station's side, and on into its hangar from there (`ZoomLadder.chain`).
NOT FROM THE MAP LOOKED AT FROM THE BERTH: there the ship never left, and
going by LOCAL undocked it, played the dock again and powered every deck on
again (Jon, Oct 27: UNDOCK is the only way out). The HUD's STATION and the
map's DOCK go straight back in, as Tab from the chart does.
```

Inside `show_station()`, above `if animating() and ZoomLadder.busy() and not ZoomLadder.active._cut 				and ZoomLadder.active.r_new == ZoomLadder.STATION and ZoomLadder.active.seam == 3 				and ZoomLadder.active.design in ["B", "D"]:`:

```text
THE CLAMPS AS IT LANDS (Jon, Oct 21: the roar, "then putter out to
nothing before it lands"): a dock that flies your ship into the yard
(3B, 3D) owes them until it is on its stands
(`StationScreen.ladder_yard_t`, or the move's end); any other plays
them now, as the berth opens
```

## Opening a hail

Above `var _open_option := -1`:

```text
Open the hail. The node is NOT consumed here — event_resolved() does that
when the outcome actually lands. Marking it on open meant the swap below
autosaved a cleared node while the picked event existed only inside
EventScreen, so a force-quit at the hail resumed onto a system whose signal
had stopped and which gave nothing.

The pick lives on the node, decided on arrival by _roll_here(). Two reasons,
and only the first is about quitting. HudBar.refresh() only greys tabs while
in_combat(), which an event is not, so all five stay lit and the screen can be
swapped out from under a live hail; rolling a fresh event on the way back
would make leaving and returning a re-roll until the options pay. Holding it
in Router covered that but not a force-quit, because Router is not saved and
the node is.
Which option of the current system is open, or -1.

Held here rather than on the node because it is a screen's business, not a
place's -- the node records which options are SPENT, in `taken`, and that is
the part a save has to carry.
```

## Option detail

Above `func show_option_at(index: int) -> void:`:

```text
Open one named option as the detail view.

RULING 2. The sector renders the list; this is the screen an option gets when
it has earned one -- both a `body` and a check, so there is prose worth reading
and a number worth weighing. Everything simpler resolves in its own row and
never comes here, because two to four options across twenty-five systems is a
great deal of reading and prose that is unavoidable stops being read.

`EventScreen` is reused rather than replaced: an option is
`{title, body, choices}` and it renders `{title, body, options}`. One key.
```

## Option bookkeeping

Above `func option_resolved(index: int, result: StringName = &"done") -> void:`:

```text
Mark one option spent without opening anything.

What the sector calls when a row resolved IN PLACE. The bookkeeping is the
same as `event_resolved`'s and lives in one function so the two paths cannot
drift: an option spends itself, and the system is finished only when nothing
is left in it.
```

## Claiming options

Above `func claim_open_option() -> bool:`:

```text
Ask the party for the option this event screen is standing in, BEFORE the
screen rolls or pays anything. The other half of the seam `event_resolved`
records: consumption is arbitrated here through `Run.take_option`, because
an option two ships can race for must be asked for, not assumed -- roll
first and apologise afterwards, and the loser has already pocketed the
payout. See `_resolve_derelict` for the shape.
```

## One only

Inside `event_resolved()`, above `OptionTable.foreclose(n, _open_option)`:

```text
ONE ONLY, ENFORCED. The list has promised this since exclusive sets
existed -- first as a bracket captioned ONE ONLY, now as the rival
greying under the cursor -- and nothing has ever made it true: taking
the auction left the queue sitting there, takeable. The SIMULATOR has
been playing the rule correctly all along (`Policy.take_options`
counts what it forwent), so the model the balance numbers come from
and the game you actually play have disagreed about it.
```

## Pulsar harvest

Above `func harvest_pulsar() -> void:`:

```text
Fly the beam.

The one node type that is a deliberate trade rather than a fight or a shop:
a neutron star's wind is the densest fuel source in the galaxy and its
radiation is the most reliable way to lose a hull. You come away with a full
tank and exotic matter worth studying, and you pay for it in the only
currency the ship cannot buy back cheaply.
```

## Derelict race

Above `func _resolve_derelict(n: MapGen.MapNode) -> void:`:

```text
A wreck is the one thing in the game today that two ships can genuinely race
for, so this is the one place that ASKS the party rather than assuming.

Everything else that finishes a system — the fight you won, the hail you were
inside — cannot be taken out from under you, and `Run.take_whole()` tells the
party without waiting. Here the answer decides whether any loot is rolled at
all, and rolling it first and apologising afterwards does not take the module
back out of the loser's hold.
```

## Fight sharing

Above `static func at_hellbender(n: MapGen.MapNode) -> bool:`:

```text
`extras` is what the node already rolled. It is a parameter rather than
something rolled in here so that the fight a node offers is decided once, at
arrival, and survives a save — see _roll_here().
`share` is whether the party can be in this one.

True for the fight a SYSTEM holds — that is a fact about a place, so every
machine derived the same enemies from the same node index and a second ship
arriving is arriving at the same frigate.

FALSE for an ambush, and the reason is in `_roll_ambush`: whether something
noticed you is rolled off `Rng.foe`, a stream, precisely so that four ships
at one system do not all get jumped. Two players' ambushes at the same node
are two different events that happen to share an address, and joining one to
the other would be joining a fight that is not there.
NO FIGHTS AT A STATION (Jon: "Why would there be a fight at a station? There
should never be fights at stations."). A station is a harbour: nothing is
rolled to jump you there (`_roll_ambush`), the Hellbender never stops at one
(`RunState._spawn_hellbender`, `_hellbender_step`), it holds no options to
take a fight from (`OptionTable.ensure`), and `start_combat` refuses one there
whoever asks -- an event's bait, a partner's shared fight, a save left
mid-fight, a debug key -- so no wreck is ever left at one either.
WHETHER YOU ARE AT THE HELLBENDER, or at the core's Custodian: each has a
place of its own on the map (`SystemLayout`), and it is fought there and
nowhere else (Jon, Oct 15), so its wrecks are its own place's.
ONLY A BODY IS EITHER PLACE: each returns -2 for "none", which no ship is ever
at, but the two were compared unguarded, so any site that came to equal -2
would have read as at a Hellbender that is not there. Two suns made the site
values a set to be careful with (star B is -4, `SystemLayout.STAR_B`).
```

## Joining fights

Inside `start_combat()`, above `var blind := forced_race`:

```text
SOMEBODY IS ALREADY SHOOTING HERE: you are in THEIR fight, whatever brought
you to it -- the JOIN button, an option's hostiles, an ambush on arrival.
The party keeps one fight per system (`NetSession.fights`, keyed by the
node) and the host joins whoever asks into the one that is open, so a ship
that planned a different enemy here would hold the party's numbers on the
wrong hulls. Built from the fight's own ids instead, the same on every
machine (Oct 22 playtest: "couldn't join his fight").
```

Above `func join_fight() -> void:`:

```text
JOIN: into the fight a partner opened at this system.

The set pieces go through their own doors, which already join an open fight
(the core clears its node on a win, the hellbender writes its hull back);
anything else is a contact that does not consume the system, as every fight
opened by an option or an arrival is.
```

## Host answer

Above `func _take_answer(f: SharedFight, folded: bool, told: bool) -> void:`:

```text
THE HOST'S ANSWER, TAKEN WHOLE (the same-second race, Nov 5).

One fight per system, owned by the host, and a second start never opens a
second fight: it is seated in the first. A ship that asked to OPEN (no
partner's fight was here when it looked) and is seated in a partner's was
beaten to it by a push still on the wire. Its own contact is spent, as an
option fight folded into a partner's always was, and it fights theirs:
`Combat.begin` builds the enemy from the fight's ids, and this says so and
writes down the fight that SAVE & EXIT restarts (`fight_door`). Every other
shared answer is the fight it asked for.

A JOIN CAN BE ANSWERED WITH ANOTHER FIGHT too (review, Nov 5): the fight it
meant to join ended and a partner opened a new one here before the ask
arrived. `begin` builds that one, so it is the one written down as well, or
SAVE & EXIT would restart the fight that had ended.
```

## Engaging

Above `func engage_here() -> void:`:

```text
Start the fight waiting at this system.

Only reachable after a resume: arriving at a combat node normally begins the
fight inside resolve_current_node(), so the sector never draws with an
unfought contact in it. A restored run does exactly that, and the action
button that says ENGAGE has to mean it.
```

## Option fights

Above `func start_ambush(foe: StringName = &"") -> void:`:

```text
Events can drop you straight into a fight (distress-beacon bait).

Not shared, and not because of the enemy: the fight is drawn from `Rng.foe`
rather than from the node, so two players who took the same bait are not
looking at the same ship. The event that produced it was a private
conversation and so is what came out of it.
A fight an option's outcome opened.

WINNING DOES NOT CONSUME THE SYSTEM, and that changed with the type collapse.
An EVENT node held one event, so consuming on victory was harmless -- by the
time this ran, `event_resolved` had already consumed it. A SYSTEM holds about
three options, and clearing it here would delete the two the player had not
reached yet: engage the hostile, win, and the wreck and the beacon that shared
the system quietly stop existing.

The option consumes ITSELF, through `taken`. The system is finished when
nothing is left in it, which is `event_resolved`'s rule.

`foe` is the event's tag (`OptionTable.fight_foe`): the creature its text set
up, or `&""` for a ship.

SHARED SINCE OCT 22. It was private ("the event that produced it was a
private conversation"), which was harmless while a system HELD its fight and
arriving at it was the shared door. The type collapse moved every ordinary
fight behind an option, so every ordinary fight became private and nobody in
a party could ever join anybody's: Jon flew into Kevin's system and could
only watch. Which enemy the opener fields is still theirs (`Rng.foe`); a
partner joining is handed the opener's ids (`join_fight`), so the two
machines agree without the roll being positional.
```

## Option foes

Above `func option_foe(n: MapGen.MapNode, foe: StringName = &"") -> EnemyTemplate:`:

```text
What an option's fight brings at `n`. With no `foe`, a ship: one, off
`Rng.foe`, from the ordinary pool -- never fauna, even in a fauna region,
because the event's text set up a ship. With `foe` (the event's tag,
`OptionTable.fight_foe`), that creature and nothing else: the text named it
(Jon, Oct 17: the text leading up to the fight "should mention the megafauna
or whales"). A tag naming anything that is not a creature is refused loudly
and fields a ship, so a typo cannot put a pirate behind a whale's text.
One function so the headless sim (`HeadlessSim._option_fight`) fields what
this does.
```

## Fight holds camera

Above `func fight_up() -> bool:`:

```text
THE FIGHT HOLDS THE CAMERA: its own screen is up. While it is, every way
between distances does nothing -- Tab or whatever key NEXT SCREEN is bound
to, the HUD's tabs, anything else that calls a door -- the same as the
SECTOR and STARCHART tabs the HUD greys for `in_combat`. The doors to the map
and the chart lead back to the fight, and `show_local` stops there. It did not: Tab in a fight went `show_system` -> `show_local` and
built the fight's screen again over itself, so the picture dimmed and came
back, the hand was dealt again and the enemy flew in a second time (nav
audit, Oct 17). From a page opened OVER the fight (CARDS) the
same doors are still the way back to it.

AND UNTIL THE FIGHT HAS HANDED OVER. From the last kill to `after_combat` --
the breakup played out, the hand lowered -- the fight is `finished`, so
`in_combat` is false, but its screen is still the one up and `combat` still
set: Tab, a rebound key or a HUD tab there started a ladder move that raced
the hand-off to LOCAL (Oct 17). `after_combat` clears `combat` before it
swaps, so this never stops the hand-off itself.
```

## Final loot

Above `var final_loot: bool = false`:

```text
THE LAST LOOT OF THE RUN IS OPEN: the custodian's body, over LOCAL, with the
win screen behind its DONE. While this is true the only way on is the win
screen -- the HUD is hidden, Tab does nothing (`Main._input`), Escape is DONE
(`Main._unhandled_key_input`) and any screen swapped in anyway is followed by
the win screen (`_swap`). The run is already recorded as won by then, so
this guards the moment, not the record.
```

Above `func await_core_body() -> void:`:

```text
THE BODY WAITS TO BE CLICKED (Jon: "Does the custodian death immediately open
the salvage box or do you have to click the dead custodian? I would want to
have to click the dead custodian."). LOCAL, with the body lying there as a
wreck and SALVAGE THE CUSTODIAN said under it; clicking it opens the popup
(`SectorScreen._open_jetsam`), and DONE brings the win screen. Every door is
shut meanwhile (`final_loot`: no HUD, no Tab, and any screen swapped in is
followed by the win screen), and the one save a won run may have is written
(`SaveGame.save_core_won`), so quitting here comes back to the body.
```
