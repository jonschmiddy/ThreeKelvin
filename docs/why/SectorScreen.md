The reasoning behind `tkg/scripts/ui/SectorScreen.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Screen shape

Above `var combat: Combat`:

```text
Where you are — one screen, whether or not something is shooting at you.

There is no separate combat screen. A fight is this sector with an enemy in
it: the same frame, the same ship in the same place, with the hand and intent
strip appearing underneath. Two classes drawing the same place gave the player
two versions of one page and made the ship jump between contexts.

`combat` is null when the sector is quiet. Combat-only controls hide rather
than being built conditionally, so there is one layout to reason about.
```

## Salvage rail

Above `var _salvage_scroll: ScrollContainer`:

```text
The window onto the list. THE RAIL HAS A CEILING NOW, and the bug it fixes is
not a scrolling bug — it is a layout one.

A `PanelContainer` takes its minimum size from its child, and the child was a
`VBoxContainer` holding one panel per part in the hold. Six parts out of a
lawless run came to well over a screen, the rail's minimum grew past the
viewport, and because it sits in the arena — which is the expanding row of the
root column — the whole page grew with it. The hand strip and the quiet strip
were pushed off the bottom, and the sector was unplayable until the hold was
emptied from another screen.

A ScrollContainer's minimum height does NOT track its content, so the rail now
asks for a fixed, small amount of room and gives the overflow a scrollbar.
```

Above `var _taking: bool = false`:

```text
True while a TAKE is out at the host and has not been answered.

One click at a time. `take_from_bag()` awaits a round trip, and a second click
landing inside that window would put two requests in the air for a hold with
one slot left in it — the answer to the first is what decides whether the
second is even legal.
```

Above `func _build_salvage_rail() -> PanelContainer:`:

```text
Three bands: a heading, a scrolling list, and the two buttons that dismiss it.

Only the middle one scrolls, and only the middle one is rebuilt. The heading
used to be a child of the list with a `name` on it so the refresh could tell
it apart from a module row — that check is gone with the structure that needed
it, which is the small win hidden inside the layout fix.
```

Inside `_build_salvage_rail()`, above `var stow := Widgets.button("DECIDE LATER",`:

```text
IT HIDES THE PANEL. It does not move anything, and it never did -- what it
sets is a hush, and the old label got away with "STOW" only because
everything it listed was already in the hold.

A bag is not. Loose salvage sits in the SYSTEM until you take it, so
pressing this on a bag put the panel away and left the parts on the floor,
which read exactly like the game had eaten them. Same word, two states,
and only one of them was true.
```

Inside `_build_salvage_rail()`, above `col.add_child(_salvage_actions)`:

```text
THE JETTISON BUTTON IS GONE, and it was wrong twice over.

It called `Run.cargo.clear()` -- it emptied your whole hold, everything,
in one press. Its own tooltip said "Destroys everything in the hold. There
is no reason to do this", which is an accurate description of a control
that should not exist. MATERIALS_NOTE 3.4 now rules it out outright:
nothing of yours is ever destroyed for you.

And the word had been taken. Jettison means one thing now -- overboard,
into this system's own pile, where it stays -- and it is done
by right-clicking the thing you want rid of, one at a time, wherever the
hold is shown. A second button spelled the same way and meaning "burn
everything" is not a button, it is a trap.
```

Inside `_refresh_salvage()`, above `var mine := Run.found_hull != null`:

```text
NOT `Run.cargo`. This rail listed everything in your hold, which made
sense when loot ARRIVED there -- something turned up and the rail was how
you heard about it. Nothing arrives any more: 3.6 made every physical
grant a container you reach into, so by the time a part is in your hold
you have already picked it up on purpose and decided to keep it. Printing
it again in the sector is the game telling you something you just did.

A found hull is different and stays: it is not in your hold, it is an
offer, and the rail is where the offer lives.
ONLY A HULL OPENS THIS NOW.

The rail has been shedding jobs for a while: it stopped listing your cargo
when every payout became a container, and the bag it summarised is now
several containers reached through the hulls they came out of. What was
left was a panel occupying the top right of every system to hold one
button and a sentence.

A found hull is a real reason to keep it: an OFFER rather than a
possession, not a hold item so it cannot go in a container, and rare
enough that a panel appearing for it reads as something having happened.
```

Inside `_refresh_salvage()`, above `var hushed := Run.salvage_hushed(bag_here)`:

```text
STAYS DISMISSED ACROSS A JUMP. The state lives on `Run` because this screen
does not survive one — see RunState.salvage_hushed_hauls.

It stops being dismissed when there is something NEW to decide about: a
fresh haul, or a bag at a system you have not stood over yet. Watching
`cargo.size()` instead of `hauls` was right until the refit screen learned
to drag a part off a hardpoint into the hold — that grows the hold too, so
unbolting your own coolant line made this panel offer it back as salvage.
```

Inside `_refresh_salvage()`, above `func _refresh_self_plate() -> void:`:

```text
MODULES ONLY. This rail asks "stow it or fit it", and a crate of ore
answers neither: it cannot be bolted to anything and there is nothing to
decide about it here.

It listed everything in `Run.cargo`, which was every part you owned and
was survivable while a hold held four of them. With materials in there it
became your whole inventory, printed down the side of the sector, every
time you arrived anywhere. The hold is where you look at what you are
carrying; this is where you look at what just arrived and is fittable.
```

Inside `_on_salvage()`, above `Router.show_transfer()`:

```text
STRAIGHT TO THE MOVE, as the yard's TAKE IT goes. Everything you own
is on the pad now and this is the one screen that shows it; without
it the ship flew on bare, its kit on a pad nobody could see, until a
station's UNDOCK refused for good (Jon, Oct 23).
```

## Card gestures

Above `const GRAB_SIDE := 14.0`:

```text
How far sideways before a press is a REORDER, and how far up before it is a
SHOT. Both in design pixels, both deliberately small -- the gesture should
commit early enough that the card is following your hand rather than lagging
a decision behind it.

Sideways is the larger of the two because it is the recoverable one: reorder
the wrong way and you drag back, fire the wrong card and it is spent. The
bias belongs on the side that costs something.
```

Above `func _on_card_grabbed(view: CardView, at: Vector2) -> void:`:

```text
A card was pressed in the hand. Arm it: it lifts and stays, and from here the
LINE does the aiming.

The whole point of section 3a. `set_drag_preview` pinned a full-size card to
the cursor, so at the exact moment the damage figure appeared the enemy it
applied to was behind a 112x160 card. Live numbers made that worse rather
than better: the biggest number on the screen was hidden under the thing that
produced it.
A card was pressed. NOTHING HAPPENS YET.

Sideways inside the hand is a reorder; up and out of it is a shot. Which one
was meant is not knowable at the press -- only once the pointer moves -- so
this records the grab and `_grab_decide` commits to a mode on the first
motion that clears a threshold.

LIVE_CARD_NUMBERS section 3a rules hand reorder DROPPED, on the grounds that
it collides with the targeting line. It does not collide if the two are told
apart by DIRECTION, and both are worth having: the fan is the only place hand
order can be arranged, and order is the whole of what a hand is.
```

Above `func _grab_decide(at: Vector2) -> void:`:

```text
Which gesture this is, decided on the first motion that clears a threshold.

HELD IN ONE DIRECTION ONLY. A shot must never quietly become a reorder --
your hand drifting back down over the fan would eat the click, which is the
fault this hold was written for and it still stands. A reorder BECOMING a
shot is the opposite case and is safe, because the only way to trigger it is
to carry the card clean out of the drawer: a deliberate, large gesture that
cannot happen by drift. See `_promote_to_aim`.

Without that promotion a sideways nudge trapped the card: the only way back
to aiming was to drop it and start the drag again.
```

Inside `_grab_decide()`, above `var above_drawer := at.y < _hand.get_global_rect().position.y`:

```text
ABOVE THE DRAWER, and nothing else. This used to arm on leaving the hand's
rect in ANY direction, or on any upward travel past GRAB_UP -- so a card
dragged off the side of the fan, or nudged up while still inside it, threw
a targeting line across the board before the player had aimed at anything.
The line now exists only once the cursor is out of the drawer vertically,
which is also the only direction anything can be aimed at.
```

Above `func _promote_to_aim(at: Vector2) -> bool:`:

```text
A reorder carried out of the drawer becomes a shot. Returns whether it did.

THE REORDER IS COMMITTED, not undone. It was written the other way first, on
the reasoning that dragging a card up through the fan is not a request to
move it -- and that is wrong about what the player sees: the card has spent
the whole gesture sitting in its new place, and reverting on the way out
yanks it back to where it was grabbed from at the exact moment attention
moves to the board. Where you left it is where it stays.
```

Above `func _input(e: InputEvent) -> void:`:

```text
Motion and release while a card is armed.

`_input` rather than `_unhandled_input`: the release has to be seen wherever
it happens, including over a Control that would otherwise swallow it, because
a gesture you cannot get out of is worse than one that occasionally misfires.
Cancel comes free from this -- releasing over nothing is releasing over
AIM_NONE, which resolves nothing and puts the card back.
```

## Keyword readout

Above `var _readout_host: Control = null`:

```text
Every keyword panel is parented HERE and nowhere else, and opening one empties
it first.

"At most one readout on screen" used to be an invariant three suspended
coroutines had to maintain between them — the rest timer, the layout frame and
whichever hover event arrived while those were waiting — each holding the same
`_readout` member and each able to run while the others slept. One interleaving
that lost track of the reference left a panel on screen that nothing owned and
nothing would ever close, so a second one opened on top of it. A single parent
that is swept before every open makes it a fact about the node tree instead,
which no interleaving can break.
```

Above `var _readout_gen: int = 0`:

```text
Bumped every time the panel is torn down. A coroutine that wakes holding a
stale generation has been overtaken while it slept and must not touch the
screen — not to position a panel, not to fade one in, not to leave one behind.

Deliberately bumped in _clear_readout() rather than on every hover event: an
exit for a card that does not own the panel is not an interruption, and
cancelling on those would mean the panel never opens while the cursor is
sliding along a fan.
```

Above `func _readout_layer() -> Control:`:

```text
The keyword panel, in a fight.

Same builder the gallery uses. The glossary was only reachable from a
development screen, which meant every rules word on a card was something the
player had to already know — and Brace, Salvo and Feedback are precisely the
words a new player does not.

Floated in a layer above everything rather than placed in the hand row: the
hand is a fixed-height panel at the bottom of the screen, so a panel parented
into it would either resize the row or be clipped by it.
Created on first use rather than in _build(), so the layer does not exist at
all in a run that never rests on a card. Full-rect and click-through: it is a
place to put panels, not a thing on the screen.
```

Inside `_show_readout()`, above `_readout_pending = view`:

```text
And not immediately. In a fight the cursor crosses the hand constantly
on its way to an enemy, and a panel that appears the instant it touches a
card turns reading the board into a slideshow. The delay is what makes it
a thing you ASK for by resting on a card, rather than a thing that happens
to you. The gallery keeps its instant panel: browsing is the whole point
there, and nothing is behind it to look at.
```

Inside `_show_readout()`, above `panel.modulate.a = 0.0`:

```text
Invisible until it knows where it goes.

The panel's height depends on how much of its text wrapped, which is not
settled until the layout pass — so its final position cannot be computed
on the frame it is created. It used to be parked at the top of the screen
for that one frame and then moved, which is exactly the flash: a panel
appearing in the wrong place and jumping. Held at zero alpha, that frame
is simply not seen.
```

Inside `_clear_readout()`, above `_readout_host.remove_child(c)`:

```text
Removed as well as freed. queue_free() takes effect at the END of the
frame, so a panel that is only queued is still on screen for the frame
in which its replacement is built — one frame of exactly the doubled
panel this is here to prevent. The sweep is over every child rather
than over the one the member points at, which is the whole point: a
panel nothing is tracking any more is still a panel on the screen.
```

## Exit panel size

Above `const EXIT_ASK := Vector2(244, 144)`:

```text
ONE SIZE FOR ALL FOUR OF THEM.

There are two exits and each has a question and an answer, and every one of
the four was a different height: the hail question is five wrapped lines and
its answer is two, so the box shrank under the cursor at the moment of the
press and CONTINUE landed somewhere KEEP FIGHTING had not been. A panel that
resizes between asking and answering is two panels wearing the same border.

MEASURED, not guessed -- `-- sectorshot combat askhail resolve` prints the
box either side of the press. The tallest of the four is the hail question at
137 -- its badge and its two sentences wrap to one line more than anything
else -- and this is that plus a line of slack, because the badge is the part
that varies: SENSORS 4 - YOU HAVE 0 - 5% - NEAR-CERTAIN FAILURE is a good
deal longer than THRUST 3 - CERTAIN SUCCESS, and a floor that only just fits
the case I happened to photograph would be a wish rather than a size.

The body expands into whatever is left, so the buttons sit on the same line
in all four.
```

## Discard tooltip

Above `const DISCARD_TIP := "DISCARD\n\nCards you played or discarded, and the rest of your hand at END TURN.\nClick to look."`:

```text
WHAT THE DISCARD HOLDS, as `Combat` fills it: every card played or picked to
discard, and at END TURN the rest of the hand (`Combat.end_turn`). It said
"What you have played so far", and half the pile is cards never played (the
tutorial audit, Oct 22).
```

## Drawer height

Above `const DRAWER_H := 190`:

```text
How tall the drawer is, and therefore how tall the viewport is not.

190 of 540, so the system keeps a little over two thirds. FIXED rather than
sized to content on purpose: the drawer holds three different things -- the
list, one option, one result -- and if it resized between them the viewport
would jump on every click. A view that moves while you are reading it is the
thing this layout exists to stop.

THE HAND USES IT TOO, so a fight is a clean swap: the system does not resize
when something starts shooting. 170 rather than a cleaner quarter because a
card is 160 tall and the hand reserves 164 -- below that the cards have to
hang out of the band.

THE CARDS NO LONGER CARE WHAT THIS IS. `HandView` holds itself at a card plus
sixteen and centres, so its eight pixels of air are fixed whatever the band
does -- which is what lets this number belong to the RAILS again.

It has been 135, 170, 190, 182 and now 196, and every move before this one was
the cards and the piles taking room off each other through it. They are
decoupled now: this grows when the rails need it, and nothing else moves.
```

## Dock arrival

Above `static var dock_hidden := false`:

```text
THE MAP'S DOCK (`Router.show_station`, `ZoomLadder`'s fade): the LOCAL it
builds keeps your ship off itself until the dock's arrival brings it in, so
its first sight on LOCAL is that arrival's first frame (Jon, Oct 20).
```

## Hand refresh

Inside `setup()`, above `Sig.player_combat_state_changed.connect(func() -> void:`:

```text
THE HAND TOO, not just the ship panel. Every modifier the card faces show --
lock-on, salvo, adapt, heat -- is written in `CardResolver` when a card
resolves, and this is the signal that fires for it. Hooked here as ONE
refresh rather than four separate hooks, which is what the brief's section
5 recommends: the alternative is subscribing the hand to heat, lock-on,
adapt and the turn's first attack independently and hoping nobody adds a
fifth modifier without remembering the fifth hook.
```

## Local event

Inside `setup()`, above `_events = LocalEventDrawer.attach(self, fighting(), c == null and not _dock_hidden and not Router.docked, flyin)`:

```text
THE EVENT THE MAP SENT YOU TO, lifting from the bottom of the view (before
the first refresh, so the bar can offer OPEN IT) -- or, by LOCAL's own
doors, the event at the place the ship is, as GO opens it (Jon, Oct 21:
"Clicking GO or clicking LOCAL should have the same result")
```

## Arrival

Inside `setup()`, above `var flew_in: bool = bool(handoff[0]) and not fighting()`:

```text
Fly in. Arriving somewhere should look like arriving somewhere — the ship
comes in under power from the left, cuts its engines short of station and
coasts to a halt, then sits there breathing.

Not during a fight. A combat sector is one you are already in the middle
of, and Router rebuilds this screen when the fight starts, so playing the
approach there would fly the ship back in mid-battle.
ONCE PER ARRIVAL, not once per screen. This is rebuilt every time you come
back from SHIP or STARCHART, so the approach played again each time -- the
ship flying in to a system it has been parked in for five minutes.

Static because the screen is not: the flag has to outlive the thing that
sets it, in the same way the chart's view memory does.

AND SOMETIMES IT IS A WHOLE JOURNEY. `Router.begin_jump` spends nothing;
it hands this screen a departure to play on the system you are LEAVING,
and the jump is committed at the flare's peak, when the ship is gone. So
the two halves of a jump are two screens, and the seam between them is a
frame with nothing on it.
An ambush builds its own copy of this screen, so the arrival message has
to be CONSUMED AND DISCARDED there rather than left for the next screen to
find and play over a fight that has already started.
```

Inside `setup()`, above `art.park()`:

```text
CLICKED THROUGH, SO ALREADY THERE. A skip carried across the commit
means the player wants to BE at the next system -- not to watch the
half of the sequence that survived the screen swap. This used to
fall into the call below and fly the ship in with its thruster at
full level, which is a jump animation being skipped into a jump
animation. `-- jumpcine hush` is what says so.
```

Above `const DRAWER_AT := 0.78`:

```text
When the boards light up, as a fraction of the approach.

A SECOND BEFORE THE SHIP STOPS, which is not the same as the beats bleeding
into each other. The approach's last second and a half is unpowered drift --
nothing is happening in it, it is the ship losing its speed -- so the boards
coming up through it reads as the system answering while you coast in, not as
two animations talking over each other. 0.78 of 4.5 s is one second early.
NOW ONLY A FIGHT'S HAND (an ambush met on arrival): the thin bar waits for the
ship to settle, and an event's band rises then (Jon, Oct 22: "You should
enter the sector with NO bottom drawer shown", `_arrived_drawer`).
```

Inside `_begin_arrive()`, above `var clip := _ship_arrives(art, CARD_TOTAL)`:

```text
THE DELAY IS WHAT KEEPS THE SHIP OFF SCREEN. `_tick_arrival` measures its
span and puts the hull at -span on its FIRST tick, and only then honours
the delay — "held off screen rather than parked at rest". Calling arrive()
later instead would leave the ship sitting at its mooring through the card.
And the drive's lead-in on top: the ship moves ARRIVE_LEAD_S after its sound
starts. See ShipView.ARRIVE_LEAD_S.
```

Inside `_begin_arrive()`, above `var warp_lead := clampf(WARP_IN_S + ARRIVAL_GAP_S - CARD_OUT, 0.0, CARD_HOLD)`:

```text
HOLD, THEN FADE, AND THEY ARE NOT THE SAME STEP. `parallel()` joins the
tweener BEFORE it, so writing the fade as `tween_interval(HOLD)` followed
by `parallel().tween_property(out)` ran the fade during the hold -- the
card was gone in 0.8 s of a beat that was supposed to last 1.4. Chained,
it is read for as long as it says it is.
The reversed warp has to END ARRIVAL_GAP_S before the drive starts, so it
starts inside the hold. The hold is split around it rather than a timer left
running, so a skip that kills this tween silences it too.
```

Inside `_arrival_drawer()`, above `func _build() -> void:`:

```text
NOTHING AT THE BOTTOM WHILE YOU ARRIVE (Jon, Oct 22: "You should enter the
sector with NO bottom drawer shown"): the thin bar rose here, a second
before the ship stopped, and an event's band then rose out of it. It comes
once the ship has settled now, and only if no event's band is coming
(`_arrived_drawer`).
```

## Arrival sound

Inside `setup()`, above `Audio.play(_ship_arrives(art, 0.0), 0.0)`:

```text
THE DRIVE, ONCE, HERE. This is the only place in the game that
means "you have just entered a system": the guard above fires once
per node and never during a fight, which is exactly the condition
the sound wants. Beside `arrive()` rather than inside it, because
ShipView.arrive() also flies in convoy hulls and enemies, and four
ships arriving must not be four thrusters.

THE CLIP IS THE ONE FOR THE PATTERN THE FLAME DREW, at the
weight of the hull drawing it. arrive() picks how the engines
give out this time and hands back the clip cut from that row, so
its coughs are the ones on screen and its size is your ship's.
Picking the sound here instead -- or letting Audio's round-robin
pick it -- would be fifteen ways to be wrong.

No pitch variance either, for the same reason: a pitch shift is a
time shift, and it would slide them apart. The three weights are
pitch-shifted, but in the render, before the flame was cut in.
The ship waits out the drive's lead-in here too, or the clip's coughs
would land ARRIVE_LEAD_S after the flame's.
```

## Local arrival

Above `static var _flyin_seen := -1`:

```text
AT A PLACE FLOWN TO (Jon, Oct 21, "station:BC": "In a sector with a dock, if I
click LOCAL the ship is just near the dock already, no animation happens"):
the first LOCAL at a world, the star or the station the map's ship flew to
plays a system's arrival -- the very call, `_ship_arrives`: off the left
edge on its drive, the flameout, the drift to its mooring, its bob, its clip,
the sky held still -- without the system's name (you are already in it).
Once a flight (`SystemMapScreen.flown_to`): LOCAL again there shows it
parked. Not after a jump (the map plays that), at a run's first system (it
has its own), at an undock or a dock (`arrived_here`), for an event GO opens
(the zoom down was the arrival), in a fight, or with reduced motion. LOCAL
pressed as the ship still burns onto the orbit plays it too: the ship was
arriving, and that is what LOCAL shows. A key or a click parks it at once.
```

## Station wake

Above `const WAKE_BEAT_S := ZoomLadder.DOCK_BEAT_S`:

```text
THE STATION WAKES ON LOCAL as the dock wakes it: an idle beat, then its
lights on over the dock's own POWER step and curve (`WAKE_POWER_BY`), the
warning lights flashing and then green (`WARN_CLEAR`); held green a moment,
then gone. After your ship has settled at its mooring, as the dock's
ARRIVE, BEAT, POWER run: the station answering the ship that came alongside,
and the flameout and the breakers never over each other.
```

## Jump sounds

Above `const WARP_IN_S := 1.48`:

```text
The jump's warp in reverse, ending on the frame the drive starts and the ship
comes in, so leaving and arriving are one event heard both ways. Jon: "let's
have the warp sound in reverse when the transition to the new sector happens.
right before the thruster sound cuts on". `audio/hyperjump.py` reads this and
cuts the clip to exactly this long, so its end is the drive's start. It is the
whole length of the warp, doppler over basswarp: 1.48 s.
```

Above `const ARRIVAL_GAP_S := 0.50`:

```text
And a breath between it and the ship: the warp ends this long before the drive
starts. Jon: "little more delay between the warp and the ship coming into
frame", then "i like the .5!!!".
```

Inside `_begin_arrive()`, above `_cine.tween_callback(func() -> void:`:

```text
NOT IN THE FIRST SECTOR. The run starts there, so nothing warped in to be
heard arriving. Jon: "No reverse warp sound in first sector." The hold is
split the same way either way, so the card keeps its timing.
```

## Jump commit

Inside `_commit()`, above `if _phase != Phase.DEPART or not is_visible_in_tree():`:

```text
THE SCREEN HAS TO STILL BE THE SCREEN. `_swap` hides the outgoing screen on
the frame it frees it, and queue_free leaves it in the tree for the rest of
that frame — so a flare peaking after QUIT has cleared the hull would run a
jump against a run that has ended. That is the quittest bug, in a new place.
```

Inside `_refresh()`, above `if _phase == Phase.COMMITTING:`:

```text
`Run.jump_to` emits `resources_changed` BEFORE `jumped`, so there is one
synchronous refresh on the DEPARTING screen already holding the new
`Run.at` -- it would repaint the backdrop to the system it is leaving for,
for one frame, on the frame the flare is brightest. Harmless until now
because that refresh used to land on the starchart.
```

## Name card

Above `func _build_name_card(n: MapGen.MapNode) -> Control:`:

```text
The system announcing itself, once, over empty space.

THE DETAIL LINE LIVES HERE AND NOWHERE ELSE, and this does not reverse THE
NAME, AND NOTHING ELSE above. That ruling is about the corner you stand in
for as long as you are here, and the corner still carries the name alone.
This is the arrival, and it is gone before you can act on anything.

ICE and COLD. A heading in this game is cold; EMBER, FLARE and HOT are heat,
and a system name in them would read as a warning about the system.
```

## Header corner

Inside `_build()`, above `_title = UITheme.body("", UITheme.ICE, UITheme.FS_PLACE)`:

```text
THE NAME, AND NOT EVEN THAT, WHICH FINISHES AN ARGUMENT THIS CORNER HAS
BEEN LOSING BY DEGREES.

It carried an eyebrow reading SECTOR, the name, a class line, and a
paragraph of description. Three went because the screen already answered
them: SECTOR is which tab is lit, and the class line and the blurb
describe a place whose contents are the drawer along the bottom and
whatever is floating in the middle. The name survived as "the one fact
nothing else on screen carries".

It is not that fact any more. ARRIVING SAYS IT NOW -- the system announces
itself across the middle of an empty frame as you fly in, which is a
better place to be told where you are than a label you stopped reading
after the first system. See `_build_name_card`. What is left in the corner
is nothing, and an empty corner is the point: melancholy comes from
composition, and the frame is doing that work.

`_title`, `_sub` and `_blurb` are all BUILT AND NOT ADDED now, following
the note below about `_hull`: the refresh writes to them every
frame and would have to grow a null check for each one otherwise.
```

Inside `_build()`, above `_hull = UITheme.body("", UITheme.CHILL, UITheme.FS_SMALL)`:

```text
Hull, heat, danger, layer and "engaged - 1 hostile" all lived here, and
every one of them is already on screen: hull and heat in the HUD along the
top, the sector's name and class in the header above this, and the count
of hostiles is the number of ships you can see. Built but not added, so
the refresh code that writes to them keeps working. (The danger and layer
line, `_facts`, was cut outright on Oct 22: nothing read it, and danger and
layer are on the sector map, the chart and the escape menu's ladder.)
```

## Removed side rail

Above `func _build_orphans() -> void:`:

```text
The side rail is gone. Its contents, in order of what happened to them:

The log went because every line was a transcript of an animation you had just
watched, competing with the board for the same glance. (It came back hidden,
behind a LOG button, for whoever wants the transcript: `FightLog`.) The enemy's name,
health bar, hull count and class went because all four already sit under its
sprite, where the enemy actually is. The two chip rows moved to the intent
strip, which was already the line answering "what is happening this turn".

And _preview went because the targets now say it themselves: a valid drop
lights up and paints the number it would do. These four stay alive as
orphans so the refresh code that writes to them does not have to change.
```

## Self plate

Above `const PLATE_W := 120`:

```text
Your hull and your status, under your own ship.

THE ENEMY HAS HAD ONE SINCE THE START and you have not: their name, their bar
and their number sit under their hull where you are already looking, while
yours were a strip in the corner of the card rail and a pair of digits in the
top bar. Two pools read from two different parts of the screen.

Mirrors `EnemySlot` deliberately -- same bar width, same six pixels of height,
same centred number under it -- so the two sides of the fight are one
vocabulary rather than two.

`HULL_BIAS` is `ShipSlot`'s: the hull is centred in the left 68% of its half,
so the plate is centred on the same fraction rather than on the middle of the
panel, which would put it off the ship's nose.
```

Above `const PLATE_AIR := 26.0`:

```text
How far under the hull the plate sits.
How much air between the hull's last row and the top of the bar.

AIR UNDER THE SHIP, not distance from its middle, which is what `PLATE_DROP`
measured and why it read as neither centred nor clear: the hull is about a
third of its canvas, so 56 from the middle lands wherever that particular
hull happens to end. The enemy's own readout sits about this far under its
art, and the two sides of the fight should agree.
```

Inside `_build_self_plate()`, above `col.alignment = BoxContainer.ALIGNMENT_BEGIN`:

```text
BEGIN, NOT CENTER. A Control's size does not shrink back when its minimum
does, so with no statuses showing the box stayed as tall as it had been
with them -- and centring the contents in that leftover height put the
hull bar eight pixels lower than it sat a moment before. The bar moved
every time an effect came or went.

Top-aligned, the bar is at the top of the plate whatever else is in it,
and the statuses print underneath. The bar is the thing you look for; it
does not get to move.
```

Inside `_build_self_plate()`, above `_self_name = UITheme.body("", UITheme.ICE, UITheme.FS_SMALL)`:

```text
YOUR NAME, ABOVE YOUR BAR, in the same order the enemy's readout uses:
name, bar, number, statuses. Two ships in a fight should be described the
same way -- theirs has always said who it is, and yours said nothing.

ICE against their THEM. The colour is the only part of the readout that is
NOT mirrored, and it is the part carrying whose ship it is.
```

Inside `_build_self_plate()`, above `_self_plate = col`:

```text
Centred under the hull rather than under the half: see `HULL_BIAS`.
A CHILD OF THE SHIP, so it goes where the ship goes.

Two wrong answers came first and both were about the same thing. Anchoring
it to a fraction of the panel assumed the ship's slot was the whole width;
it is one of several children of a row, so the plate sat a long way to
starboard. Positioning it from `self_anchor()` on refresh got the place
right and the TIME wrong -- `ShipView.arrive()` animates, so the plate was
aimed at where the hull had been when the last refresh happened and stayed
there.

Parenting settles both: the offset is measured once, against the art, and
the arrival carries the plate in with the ship.
```

Inside `_build_self_plate()`, above `_view.ship_view().resized.connect(_place_self_plate)`:

```text
ON RESIZE, NOT JUST ON REFRESH. The first version placed the plate only
from `_refresh_self_plate`, which runs before the slot has been laid out
-- `ship_bottom_y` had no canvas to measure yet and the ship's control was
still half its eventual height, so the plate landed eighty pixels above
the hull and stayed there.

Both signals matter and for different reasons: the ship resizing moves the
hull, and the plate resizing changes what "centred" means, because a
status row wider than the bar widens the box the bar sits in.
```

Above `func _place_self_plate() -> void:`:

```text
Under the hull, centred on the hull.

MEASURED FROM THE SPRITE, not from the box around it. `PLATE_X` was 0.26 of
the slot's width, arrived at by looking at a screenshot, and it was wrong the
moment anything about the layout moved -- which is how it came to sit off to
port of the ship it belongs to. `ship_offset_x` is the same question answered
by the image itself, and `ship_bottom_y` is the vertical half of it.

The canvas is drawn `STRETCH_KEEP_CENTERED`, so the control's middle IS the
canvas's middle and both offsets are corrections from there.
```

## Quiet strip

Above `func _build_quiet_strip() -> Control:`:

```text
What there is to do here, when nothing is shooting. Occupies the same band as
the enemy intent strip does in a fight, so the screen keeps one shape whether
the sector is quiet or not.
A PLAIN CONTROL BETWEEN THE PANEL AND THE COLUMN, so the drawer has a
position of its own to slide in on. A container child's position belongs to
the container — it is rewritten on the next sort — and this panel is a direct
child of the root VBox, so tweening its `position.y` would hold until the
next layout pass and then snap back. `EnemySlot` records the same trap and
reaches for the same answer; `ShipView` needs none of it because its slot is
not a container.

SIZED, NOT ANCHORED. A full-rect preset would tie the panel's position to the
holder's edges, and Godot recomputes an anchored control's position whenever
its parent resizes — which the holder does on its first layout pass, a frame
after the reveal has already put the drawer below the floor.
```

Above `func _sync_drawer_box() -> void:`:

```text
Keep the holder the size of the drawer and the drawer the width of the
holder. GUARDED AGAINST ITS OWN ECHO: writing the holder's minimum resizes
the holder, which calls this again.

`position.y` is deliberately not touched here. It belongs to the reveal, and
a layout pass that quietly put it back to zero would be the reveal never
happening for a reason nobody could see.
```

Above `func _sync_bleed() -> void:`:

```text
Carry the sky down to the bottom of the screen.

The arena stops at the drawer band and the band was a flat dark strip with a
hard seam across it -- fine while the drawer was always up, and the first
thing you see during an arrival, when it is parked below the floor. The view
paints past itself now; see `EncounterView.set_bleed`.
```

## Local drawer

Inside `_rebuild_drawer()`, above `if n.type == MapGen.NodeType.SYSTEM or n.type == MapGen.NodeType.STATION:`:

```text
A SYSTEM OR A STATION: ONE LINE, AND THE WAY TO THE MAP. What is here, its
pages and its choices, the floor's loot and the berth are all on the sector
map (`SystemPanel`), and every one of them is taken where it stands -- you
fly there first. LOCAL said all of it again in a drawer of its own, and a
choice taken from here was one taken without going (Jon's LOCAL ruling).
```

Above `static func things_here(n: MapGen.MapNode) -> Array:`:

```text
WHAT IS HERE (Jon, Oct 21, "bar:here"): the events not yet taken at the place
the ship is (`SystemLayout.place_of`, `Run.site_here`), not the whole
system's -- "3 THINGS HERE" stood beside a giant with nothing at it. At the
edge and in open space, none.
```

Inside `_drawer_here()`, above `if _join_shown:`:

```text
THIS SYSTEM'S OWN PILE, beside the way to the map (Jon: "button on the
bottom right next to SCAN SECTOR that opens the popup for the sector
loot"), only while there is something on it, as the map's SECTOR LOOT is:
a popup in the cutaway, the two-grid screen with your hold beside it
anywhere else
```

Inside `_drawer_here()`, above `if n.type == MapGen.NodeType.STATION and ZoomLadder.chosen() and Router.at_station(n):`:

```text
DOCK, ONE DISTANCE IN (`ZoomLadder`): the station is right there, so the way
into it is here as well as on the map -- ONLY THERE (Jon, Oct 18, "dock:A"):
at a world, the star or open space in a station's system there is no
station beside you to dock with (`Router.at_station`), and no button that
looks like one; the line says where to go
```

## Drawer sizing

Above `func _size_drawer(n: MapGen.MapNode) -> void:`:

```text
How tall the drawer is for this place.

THE BOOKENDS ARE NARROW. A system gets the fixed `DRAWER_H`, because its
drawer swaps between a list, an option and a result and a band that resized
between those would make the viewport jump on every click. The start and the
core swap between nothing: each says one line, offers one button, and that is
the whole of it. A hundred and seventy pixels of panel holding forty of
content is a hole under the ship, and these two are the first and last things
anybody sees.

Costs one resize on the first jump of a run and one on the last. Stations and
pulsars are the same shape and could have the same treatment; they are left
alone because each one would add a resize to a transition that has none, and
unlike these two you dock at them repeatedly.
```

Inside `_size_drawer()`, above `var bookend := n != null and not Run.dead`:

```text
EVERY PLACE WITH ONE THING TO DO. It was the two bookends of a run; a
station and a pulsar say exactly as little -- a line and a button -- and
were being given a drawer sized for a list of four options, so most of the
panel was air.

AND A SYSTEM NEVER IS ONE, WHICH REVERSES A RULING FROM AN HOUR AGO. A
finished system did collapse to this height and should have: it said one
line over a hundred and ninety pixels of air. It does not say one line any
more -- every option it ever had is still on the row wearing SUCCESS or
BOTCHED or UNAVAILABLE, so there is no air to collapse and the record of
what you did there is the thing that would be hidden. The collapse was a
fix for emptiness, and the emptiness is gone.
(and since LOCAL's drawer became one line, a system is one too: every
place says a line and offers a button, and the sky gets the rest)
```

## Drawer actions

Inside `_drawer_simple()`, above `if label != EncounterDrawer.TO_SECTOR:`:

```text
AND THE WAY OUT -- UNLESS LEAVING IS ALREADY THE ONE THING. A cleared
system and a spent pulsar have nothing left to do but go, so their own
button IS the jump, and adding a second one printed PLOT NEXT JUMP twice
side by side.

Compared against the label rather than the node type on purpose: what the
button SAYS is the thing that would be duplicated, and `_on_action` decides
that from four different branches.
AND THE WAY OUT, WHICH IS NOT `_on_action`. That function is "the one
thing this place offers" and it is DIFFERENT per node -- dock at a
station, harvest a pulsar -- and only happens to be the chart at a system
because a system's options are the rows above it. Wiring the jump to it
would make PLOT NEXT JUMP dock you.
```

## Plot jump sound

Above `func _plot_next_jump() -> void:`:

```text
ONE SOUND FOR IT, AND IT IS THE PAGE TURNING.

This started as the opposite ruling -- "Clicking plot next jump should not
activate the tab_click sound effect" -- which silenced the page and left the
click. Hearing it, Jon corrected it the other way: "let's not have the
ui_click sound, just the page tab sound." That is the better half to keep.
The click is the sound of a BUTTON, and there are a dozen of them on this
screen; the page turn is the sound of the thing that actually happened.

So the button is built with its click off (`Widgets.button`'s third
argument) and `ui_tab` is left alone to play from `_swap`, where every
screen change plays it.
```

## Pile view

Above `const CHIP_ROW_H := 18`:

```text
A stack of card backs with a count on it.

The strips either side of the hand were dead space with a line of text in
them — "deck 12 · discard 3" — which is a pile's information without a pile.
Drawn as actual backs the number stops being a stat and becomes a THING: you
can see the draw pile getting thin, and the discard growing to meet it,
without reading either.

The back borrows the card's own vocabulary — a banner down the left, a
punched square where an emblem would go — so a face-down card is obviously
one of these cards rather than a generic rectangle.
The height the player's status chip row holds whether or not it has chips in
it. See where it is built for what happens without it.

18, MEASURED. A chip is a PanelContainer around 10px text with 2px of padding
and a border, and it renders 18 rows tall — not the 16 the arithmetic
suggested. Reserving 16 changed nothing at all, because the chip was still
the taller of the two and the row sized to it: the hand sat at y=690 with no
chips and y=654 with one, either way.
```

Inside `_dead_strip_note()`, above `func _card_x(shown: int) -> float:`:

```text
Where the BACK card starts, so the whole leaning stack is centred.

Centring one card and then leaning the others off it pushed the pile right
as it filled, which is a pile that moves while you play. The lean is known
-- two pixels per card behind the front one -- so it is subtracted here and
the group stays put.
```

Inside `_dead_strip_note()`, above `var o := Vector2(_card_x(shown) + float(i) * 2.0, float(shown - 1 - i) * 2.0)`:

```text
INSIDE ITS OWN BOX. This was `-i * 2`, which drew the cards behind
the front one ABOVE y=0 -- outside the control, over whatever sits
above it. On the right rail that is FLEE, so a discard pile with
anything in it painted across the button.

The stack still leans up and to the right; the whole thing is just
offset down by as far as it leans, so the deepest card starts at
zero instead of the front one.
```

## Rail sizing

Inside `_dead_strip_note()`, above `const W := 68`:

```text
Big enough to read as a card rather than as an icon of one.

WAS 86, WHICH THE BAND CAN NO LONGER HOLD. The old note read "the hand row
is 160 tall to fit a card, so there was height going spare either side" --
and the spare is gone now the band is a fixed 170 shared with the drawer.
At 86 the left rail came to about 179 and pushed the whole panel past the
drawer it is supposed to swap with.
68, NOT 60, and the reason is a word. Every button on both rails is cut to
this width, and "END TURN" on one line does not fit 60 -- it wrapped, came
out at 24 against its neighbours' 16, and no amount of stylebox padding was
ever going to explain that. The eight pixels come off the card area, which
has them.
THE FLOOR, NOT A CHOICE. `END TURN` measures 58 at FS_SMALL and the flat
button boxes add six each side, so no rail can be narrower than this
whatever else is written on one. `-- fitwords` prints the table.

It went to 100 to hold "NOT NEGOTIATING" and that was the wrong way round:
the rail sets what a word may be, because the PILE is cut to the rail too
and a wide rail makes a landscape pile. At 68 a full stack is 64 across
against 66 tall; at 100 it was 96 against 66.
```

Inside `_dead_strip_note()`, above `const H := 88`:

```text
52 IS THE CEILING, swept rather than guessed: the band is a fixed 170 shared
with the drawer, and `-- sectorshot` reports 171 at 53 and 175 at 57. Every
pixel this gains comes straight off the panel it has to fit inside.

It has come down from 86 in three steps, each paying for something the rail
gained -- the fixed band, then the stack's lean, then the air under the
label. If it needs to be bigger the room has to come from somewhere else in
the column, because there is none here.
66, which is where it was always trying to get to. It has been 86, 66, 62,
58, 52, 60 and 52 again across one night of the rail and the cards trading
pixels; the hand holding its own height is what ended the argument.
```

Inside `_dead_strip_note()`, above `const CARD_W := W - 4`:

```text
The card inside the column, which is NARROWER than the column.

`W` is the rail's width and every button on both sides is cut to it, so
narrowing that narrows the whole panel. The card is drawn at `CARD_W`
instead, centred, at 60 against 68 -- four pixels of margin each side and
the rest of the column filled. It was 44, which left twenty-four pixels of
nothing beside a pile that had already been squeezed three times.

HEIGHT IS MAXED, not chosen: the control is `H + 16 + RAIL_DROP` and every
one of those is spoken for -- the lean, the label, and the air under it --
inside a band that is a fixed 170. Width was the only slack left.
The card, sized so a FULL stack is exactly as wide as a button.

Three cards each lean two right of the last, so the widest the pile ever
draws is this plus four -- and tying it to `W` here is what stops the two
drifting apart. They did: the rail went to 100 for a long word and the
card stayed at 64, which put the pile back in the dead space it had just
been given to fill.
```

Above `const RAIL_TOP := 4`:

```text
Where the rails begin, which is where a HOVERED card begins.

A card rests at 8 inside a hand bottom-aligned at 14, and hovering lifts it by
8 -- so the top edge of the card you are looking at is at 14, and that is the
line the rails should start on. Rested cards sit 8 below it, which is right:
the lifted one is the one you are considering, so it is the one the panel
squares up to.

Separate from `RAIL_DROP` because they stopped being the same number the
moment this had to match something. That one is still the gap BETWEEN things
and the air under the pile label; this is only the gap above the first box.
4, plus the 4 gap that lands after it, puts the first box on 8.

EIGHT IS ALSO WHERE A HOVERED CARD STARTS, and that is not a coincidence
surviving by luck -- the hand is bottom-aligned, so shortening the band moves
it up by exactly what the band lost, and the lift is a constant. Both were 14
at a band of 196 and both are 8 at 190. They travel together.

The spacer is a CHILD of the rail, so the separation lands after it too, which
is why this is 4 and not 8. Setting it to the target directly overshoots by
exactly one gap.
```

Above `const RAIL_DROP := 6`:

```text
How far the rails sit below the top of the band.

A card's frame starts at the very top of the panel and its CONTENT starts a
few pixels in, so rails flush with the frame read as sitting higher than the
cards they flank. Six is the difference, and it is paid for out of the pile
rather than added to the band -- 170 is shared with the drawer and there is no
slack in it.
```

## Hand layout

Inside `_build_hand()`, above `var left := VBoxContainer.new()`:

```text
Everything you spend on the left, everything you end with on the right,
and the cards in between. Energy sits at the top of the left column
because it is the number you check before choosing a card, not after.
TOP-ALIGNED, BOTH OF THEM. Centred, each column centres against its OWN
height -- and the left carries a chip row the right does not -- so the
pairs that are meant to read across the panel drifted apart by more the
further down you looked. ENERGY/END TURN, TURN/FLEE and the two piles are
the same three rows on both sides, and now they start at the same y.
```

Inside `_build_hand()`, above `var draw_push := Control.new()`:

```text
PUSHES THE PILE TO THE BOTTOM, and this is what `RIGHT_GAP` was doing by
hand. That gap was a measured constant chosen to make the two rails come
out the same length -- which held exactly until any other number in either
column moved, and then the piles were four pixels apart again and the fix
was another measurement.

An expanding spacer needs no measuring: both piles sit on the rail's bottom
edge, so they are level with each other by construction and their labels
land on the card edge because the band is what it is.
```

Inside `_build_hand()`, above `_end_button = Widgets.button("END TURN", _on_end_turn)`:

```text
Two lines and a box. It is the button you press every single turn, so it
should be the biggest target on the panel — and stacked it reads as a
button rather than as a word in a row of words.
THREE BUTTONS SPANNING ONE BLOCK. Together they come to the same 54 as
ENERGY and TURN opposite -- 22 + 3 + 14 + 3 + 14 -- so the piles below stay
level with the draw pile and the two rails read as columns rather than as
two lists that happen to be the same length.

END TURN keeps the weight because it is the one you press every turn. It was
two lines and 38 tall, which made it a different size from the ENERGY box it
is supposed to mirror; one line at 22 mirrors it as part of the block.
```

Inside `_build_hand()`, above `_end_button.custom_minimum_size = Vector2(PileView.W, 16)`:

```text
16, not 22. A bevel button floors at about 17 whatever it is asked for, so
three of them plus a 22 came to 62 against the 54 the left rail spends on
ENERGY and TURN. Levelling them is what makes the block fit at all.
```

Inside `_build_hand()`, above `_end_button.add_theme_stylebox_override("disabled",`:

```text
AND `disabled`, WHICH IS THE ONE EVERY CUSTOM BUTTON FORGETS. The theme's
is `bevel_in(PANEL, 3, 5)` -- three above and below against these boxes'
zero -- so a button that greys GROWS, and the rail and everything under it
shifts a couple of pixels. Reported as the drawer moving when FLEE turns to
NO ESCAPE, which is exactly when a button greys.
```

Inside `_build_hand()`, above `_hand_wrap.add_theme_stylebox_override("panel",`:

```text
THE SAME HEIGHT AS THE DRAWER, so a fight is a clean swap. The two panels
are mutually exclusive and occupy the same band; matching them means the
system above does not resize the moment something starts shooting, which is
the one frame where a viewport jumping would be most obvious.

AND THE PADDING HAD TO GIVE. `custom_minimum_size` is a floor, not a
ceiling: the hand reserves a card's height plus four, and `panel_with`'s
default 12 above and below took that to 188 against the drawer's 170. The
measurement is why this is 3 rather than a guess -- 164 + 6 is exactly the
band, and any more padding puts the cards back through the ceiling.
```

Inside `_refresh_hand()`, above `_end_button.text = "END TURN"`:

```text
ONE LINE, and it is set here as well as at construction because this
runs on every refresh and used to put the newline back. That is why
the button measured 24 against its neighbours' 16 whatever its
minimum size or its stylebox said: it was two lines tall again by
the time anything looked at it.
```

## Hand lowering

Inside `_build_hand()`, above `_hand_holder = Control.new()`:

```text
IN A HOLDER, SO IT CAN BE LOWERED. Jon: "the card drawer should slowly
lower after a fight is won... instead of totally disappearing and the ships
jerking down to the center of the screen." The holder is what the root
column measures; shrinking it slides the panel down behind the bottom edge
while the arena grows in step, so the ships ease to where LOCAL will have
them instead of snapping there. Same shape as the quiet strip's holder.
```

Above `const LOWER_S := 0.65`:

```text
How long the hand takes to lower when a fight is over. Jon asked for about
half a second to 0.8 s: slow enough to read as the drawer going down, short
enough that nobody is waiting for it.
```

Above `func _lower_band(then: Callable) -> void:`:

```text
THE HAND GOES DOWN (Jon, Oct 13): "the card drawer should slowly lower after
a fight is won... instead of totally disappearing and the ships jerking down
to the center of the screen."

LOCAL's band is one line tall and the fight's is a hand of cards, so the
arena grew by the difference on the frame the screen was swapped and every
ship dropped to its new centre at once. Now the band shrinks to exactly the
height LOCAL will give it -- measured off this screen's own quiet drawer,
filled the way LOCAL fills it -- over `LOWER_S`, two pixels a step, and the
ships ease down with the arena. Then the quiet strip fades in where the hand
was, and `then` runs on a layout identical to the one coming.
```

Inside `_lower_band()`, above `target = minf(target, from)`:

```text
DOWN, NEVER UP. At the core LOCAL's band says a paragraph and asked for
more than the hand had, so the "lowering" grew the band and pulled every
ship to the top of the screen. The body's popup covers that swap anyway.
```

Above `func _one_line_height() -> float:`:

```text
How tall LOCAL's band will be. Its words wrap, and a wrapping label hidden
in a fight has no width to wrap to: asked as it stands, the core's line
measured a column of single words, most of the screen high. LOCAL gives it
the whole width, where one line fits, so a measure taller than the hand is
replaced by one line: the button's height or the text's, whichever is more,
inside the panel's own padding.
```

## Pile listing

Above `const PILE_COLS := 7`:

```text
How many cards fit across the panel before it wraps.

Seven at `CARD_W` plus the flow's four is 808, which leaves the 960 a margin
either side. Past that the panel would be wider than the screen it is
centred in, so the flow wraps and the scroll takes the overflow -- a starting
deck is ten cards but nothing stops a run ending with forty.
```

Above `func _show_pile(title: String, cards: Array[CardData], sorted_by_name: bool) -> void:`:

```text
What is in a pile.

Both piles are public information -- the discard always was, and a draw pile
you cannot count is just an unfair surprise -- but they are public in
DIFFERENT ways, which is why the draw pile is sorted and the discard is not.
The ORDER of the draw pile is the one thing that is genuinely hidden, so
showing it in sequence would hand over the next five turns; sorting by name
answers "what is left" without answering "what is next". The discard has no
such secret, so it reads newest-first, the way you put it there.
```

Inside `_show_pile()`, above `v.setup(c, true, 1)`:

```text
PLAYABLE, WHICH IS A LIE THAT READS TRUE. `set_playable(false)` drops
a card to a third alpha, and `CardView` already records why that is
wrong in bulk: "a hand greyed out end to end reads as unplayable".
A pile listing greyed end to end reads the same way -- as if the
cards had been taken off you rather than merely put down.

Nothing can be played from here regardless: the flow is not a
`HandView`, which is the parent `CardView` checks before it will
start a drag, and the card ignores the mouse anyway.
```

## Wrecks

Inside `_refresh()`, above `var wrecks: Array = Run.wrecks_here(n)`:

```text
EVERY HULL THAT DIED HERE, and they stay whether or not anything is
left in them. A wreck does not stop existing because you emptied it,
and one that vanished when picked clean would say the sector had
forgotten a fight happened in it.
...AT THIS PLACE: the world you orbit keeps the hulls of the fights
over it, and the next world along has none of them.
```

## Status chips

Inside `_refresh_player()`, above `Widgets.clear(_player_chips)`:

```text
EVERY EFFECT ON YOUR HULL, AS A PICTURE. See `StatusChip` for why these
stopped being words: five words under a sprite is a paragraph, five icons
is a glance, and the word survives in the tooltip.

The colours are the ones the words already carried, because colour is what
says whose an effect is -- the two blues are yours, ember is a timer, and
the drones share one steel.
```

Inside `_refresh_player()`, above `if combat.feedback > 0:`:

```text
NO SALVO CHIP, AND LIVE_CARD_NUMBERS SECTION 3 IS WHY IT IS GONE.

It never was a status. Its own note said so -- "SALVO IS NOT A STATUS, BUT
ITS CONDITION IS" -- and it sat in this row regardless, between BRACE and
FEEDBACK, which are things ON THE SHIP that got there because you played a
card. This one appeared and vanished according to what was in your HAND,
which nothing else in the row does, and it was never the result of an
action you took. A light in the status row answering a different kind of
question from every light beside it reads as broken even when it is right.

What it was FOR was the arithmetic: "whether every salvo card in your hand
is currently worth more was invisible -- you had to remember whether you
had swung yet." That is exactly the tax section 3 removed. A salvo card in
hand now prints its raised number, in the modified colour, under the same
`salvo_live` test this chip was asking. The fact moved onto the card it is
a fact about, which is where it had been trying to get to.
```

Inside `_refresh_enemy()`, above `if e.block > 0:`:

```text
THE SAME CHIP AS YOURS (Jon: "why is it BLOCK 6 instead of the
icon?"). The enemy's row was still the words-in-a-box chip the player
row dropped.

NO BRACE CHIP. An enemy's brace is already the pips on its hull bar
(`EnemySlot.BracePips`) and the plating on its picture; a chip would
say it a third time. It also cost room: the lancer, hulk, sentinel
and custodian start every fight with brace, so the row was never
empty, and the slot's centred column lifted each of them 9 px into
its neighbours (PopPlaceTest: a pop on the cutter in cutter, lancer,
hulk hit both their readouts).
```

## Gate buttons

Above `func _refresh_gate(b: Button, label: String, why: String, cause: StringName,`:

```text
RULING 8's shape: a disabled thing says what it wants.

A greyed HAIL with no explanation reads as a bug. "NO REPLY" on a creature
and "NO TERMS" on the thing guarding the core both say the rule out loud,
once, at the moment it applies -- and both fit the button, which the first
pair did not.
One shape for the two shut-door buttons. RULING 8: a disabled thing states
what it wants -- the LABEL carries the reason, the TOOLTIP the cause, and
the ink cools while the door is shut. The button has room for two words of
why not; the tooltip has room for a short sentence, and that is all it
should be. Only the cause-to-sentence table differs between the two.
```

Inside `_refresh_gate()`, above `if combat.finished or _hold or _opening:`:

```text
A FIGHT THAT IS OVER, OR PLAYING OUT, OFFERS NO WAY OUT OF IT. After a
successful flee HAIL stayed bright and pressable -- `hail_cause` has no
reason to give once the fight is finished, so the button read as open --
and FLEE said NO ESCAPE, which is a reason for something else (audit item
12). Greyed under its own name, no reason: there is nothing to explain.
```

## Containers

Above `func _open_jetsam(h: MapGen.Jetsam, title: String = "", direct: bool = false) -> void:`:

```text
Reaching into the bag, which is the one control on this screen that has to
ask somebody else's machine before it can answer.

`Widgets` binds the module rather than the index, so the index is recovered by
identity — `n.bag` holds the very objects the rows were built from, and the
array never shrinks, so `find()` is exact rather than a lookup by name.
Open the two-grid view over this system's loose salvage.

Built per open and torn down on close, the same as the pile listing, because
what it shows changes every time something is taken out of it.
Open one container: a hull you killed, or the system's own pile.

ONE FUNCTION FOR BOTH, because they are the same thing with different
contents -- `MATERIALS_NOTE` 3.6 -- and the only difference is which door you
came through. The container names the popup, so a Rustjaw Cutter says so and
the floor says SECTOR LOOT.
```

## Drag preview

Above `func _drag_preview(c: CardData, index: int) -> String:`:

```text
Hovering a card prices it against every enemy at once, so choosing a target
is a comparison rather than a guess.
What a held card would do to the thing under it. Drawn ON the target by the
slot itself; this only decides the words.

It replaces a small label under each enemy's health bar, which read as part
of the enemy's own stat block — a number that belonged to them and happened
to move. Shown only while a card is actually over a target, it reads as the
answer to a question you are asking.
```

## Ship hover

Above `var _still_pointer := Vector2.INF`:

```text
WHERE THE POINTER WAS WHEN THE SHIP ARRIVED UNDER IT, or INF. A ship coming
to rest under a pointer nobody moved is not being pointed at: the outline
lit there the instant the arrival ended (Jon, Oct 13: "the ship is
highlighted... No highlight"). Held until the pointer moves off this spot
or clicks; then the hover works as it always did.
```

Inside `_on_own_ship_input()`, above `_ship_outline.visible = false`:

```text
NOT PRESSABLE NOW -- a fight, an arrival, a screen up over LOCAL -- so it
does not look it (no outline, no hand), and a click on it is the thud a
button that cannot be pressed makes (Jon: "the same thud sound when you
try and click on a button that doesn't work"). Not while a card is being
aimed: then your hull is a target, and the click is the card's.
```

## Zoom ladder

Above `var _lad := {}`:

```text
LOCAL AS ONE DISTANCE OF FOUR (`ZoomLadder`). Its camera is the cutaway's: the
scene itself scaled round a point (the ships, the subject, the dust and the
shots) and the sky by depth (`LocalSky.set_zoom`), so a move in or out has
real parallax -- the far stars hold, the world you orbit moves most. k is 0 at
rest and 1 at the distance toward the other screen: pulled back to a speck of
your ship for the map and the chart, pushed in on the station's ring for the
station.
```

Inside `ladder_cam_end()`, above `_view.reapply_bleed()`:

```text
THE ROW ON THE BAND AS IT IS NOW, not as it was when the camera was taken:
its bottom offset is the band's height, and a band that moved under the
camera left your ship low and its plate under the hand
```

Inside `open_cutaway()`, above `var near: Array[Control] = []`:

```text
THE SCENE ITSELF ZOOMS (Jon: "LOCAL should zoom the real scene too"): the
ships (yours, the wrecks, a partner's), the dust and the shots with your
ship, 2x; the sky layer by layer by its own depth
```

## Docking

Inside `_attach_station_face()`, above `var art := _view.ship_view()`:

```text
(and when your ship's own place moves with the screen's layout -- its slot
taller or shorter as the bar along the bottom settles, the view itself the
same size -- the hallway stays level with it: LOCAL built ahead at UNDOCK
was placed for a slot 8 px taller than the one it stood in, the station 4
px low)
```

Inside `ladder_cam_begin()`, above `var skyc: LocalSky = _view.backdrop`:

```text
THE SKY AND THE DUST HOLD STILL WHILE IT DOCKS (Jon, Oct 20: "The dust
move too much"): LOCAL's sky camera follows your ship's own travel
(`LocalSky.cam_follow`, `CAM_FOLLOW` of it), and the dust slides with
it at its depth (`LocalDust._rest_at`) -- 209 px in one frame as the
arrival takes the hull off the left edge, then back over its approach,
and up to 515 px on with it as it goes in. Docking, the station stands
still and so does all of it: held where it is (`cam_hold`), the dust
left its own slow drift. Given back at the end (`ladder_cam_end`).
UNDOCKING TOO (Jon, Oct 21: "Undocking holds still too"): the ship flies
out of the bay to its mooring and the dust, the sun and the world stay
put. Held at the camera of the ship at its mooring (`ship.pos`, where
`ladder_cam_end` puts it back), so it is the camera the move hands back
and nothing steps when the hold is let go. (With the ladder's own camera
still too: `ladder_cam`.)
```

Inside `ladder_cam_begin()`, above `if inward and (_wake_t >= 0.0 or _wake_owed):`:

```text
(and the station's lights as the move found them: after an undock a
dock's CUT goes down to black over them lit; undocking, which of the
arrival's flameouts its engines will sputter out on, picked as an
arrival picks one)
(a wake on LOCAL still under way is finished, lit: the dock finds the
station awake and does not put it out again)
```

Inside `ladder_cam()`, above `var t := hk * ZoomLadder.dock_approach_s()`:

```text
DOCKING, IN FIVE STEPS (`ZoomLadder.dock_steps`; Jon, Oct 20: "I want
the ship to enter the screen like it does for the first sector"): k is
the whole approach's clock, linear. The camera holds still through the
whole dock -- the cut, the arrival, the beat, the power-on and the way
in -- with nothing but your ship moving; its arrival is stepped on
this clock (below).
```

Inside `ladder_cam()`, above `beat = &"enter"`:

```text
5. THEN IN, ONE MOVE: from its mooring, slowly at first, gathering
speed down the hallway and on into the hull, still at speed as it
goes in. THE CAMERA STAYS WHERE IT IS (Jon, Oct 20: "Why is there so
much parallax? The dust shouldn't move as the ship comes in. The
station is stationary."): only your ship moves
```

Above `func _dock_arrival(art: ShipView, hall: Dictionary, p0: Vector2) -> void:`:

```text
THE DOCK'S ENTRANCE IS A NEW SYSTEM'S ARRIVAL, EXACTLY (Jon, Oct 20: "Why
doesn't the ship enter like the first local?"). Under the CUT's black your
ship stays at its mooring; on the ARRIVE's first frame it is handed to
`_ship_arrives` -- the one call every arrival on LOCAL makes, the first
system's and every jump's alike -- and its clip played with it, as
`_begin_arrive` plays it when the name card goes. The only difference is the
clock: the arrival is stepped on the ladder's (`arrive_step`, the very same
tick), so the dock's steps and its approach cannot drift apart. Its mooring,
its size, its path, its flameout and drift, its bob are the arrival's; nothing
here moves or sizes it until the ENTER.
```

## Undocking

Inside `ladder_cam()`, above `kc = 0.0`:

```text
UNDOCKING IS THE DOCK PLAYED BACKWARDS (Jon, Oct 21: "the background
stays put as your ship flies out, matching docking"). k runs from 1 to
0 over the dock's own ENTER (`ZoomLadder.DOCK_ENTER_S`), and on every
frame your ship is where the ENTER had it as far from its end: in the
hull at its berth while LOCAL comes up from the yard's black (the dock's
dip backwards, `ladder_up_s`), then out through the mouth, growing back
to its own size, fastest first and slowing all the way to rest at its
mooring (fly = k squared, the ENTER's ue squared run back). Its engines
burn as the ENTER's did and sputter out as it settles
(`_undock_engines`). THE CAMERA DOES NOT MOVE -- no pan, no zoom out of
the mouth: the station, its layers, the wrecks, the dust, the sky and
its worlds stand where they are, as they do docking (4e6d1fcc) -- and
the station stays lit, a working station (Jon).
```

Above `func _undock_engines(art: ShipView, hall: Dictionary) -> void:`:

```text
UNDOCKING'S ENGINES, the ENTER's backwards: lit at the cruise burn (the
dock's entry burn, `_dock_burn`, seen and heard) from the moment any of your
ship can be seen coming out -- `dip_s` after LOCAL comes up, where the dock's
burn went out -- until the arrival's own flameout takes over
(`ShipView.sputter`), timed so that its last cough comes `UNDOCK_COAST_S`
before your ship comes to rest at its mooring -- the last of the way coasted
at the idle, as an arrival's is -- then the idle it keeps. The flameout's clip from its
first cough, at the burn's level so the two are one engine, from where the
coughs are -- and never on a press that ended the move at once
(`ZoomLadder.finish_now`): your ship is parked then, and nothing is heard.
```

## Calm move

Above `func calm_begin() -> void:`:

```text
THE CALM MOVE (`ZoomLadder`, Jon's pick A, Oct 17: "one motion everywhere").
LOCAL's camera is placed by two numbers: where your ship is on screen and how
big the scene is drawn against rest. The ladder walks your ship along one
straight line between where it rests here and where it rests on the next
view; nothing else on LOCAL moves on its own account.
```

## Aim cursor

Above `var _cursor_off: bool = false`:

```text
Take the line down. `played` says whether the card resolved, which decides
only whether the armed card is put back the way it was -- a played card is
about to be rebuilt out of the hand anyway.
Take the system pointer away, or give it back.

`MOUSE_MODE_HIDDEN` rather than a blank cursor image: the game already drives
an animated custom cursor from `Main`, and swapping that out from here would
fight it for the same slot. Held as a flag so the mode is only pushed when it
actually changes -- this is called on every mouse motion during an aim.
```

## Jump skip

Inside `_input()`, above `if _phase == Phase.DEPART or _phase == Phase.ARRIVE:`:

```text
THE SKIP, AND IT HAS TO BE FIRST. `_unhandled_input` would be too late --
the drawer's own buttons and the HUD tabs get the click before it. ESCAPE
is deliberately let through so the pause menu is always reachable, and TAB
is deliberately eaten: Main owns it and swaps screens with it, and a
mid-departure Tab would walk off with an uncommitted jump.
THE SKIP IS OFF BY DEFAULT NOW, and it is a setting: MOTION > SKIP THE
JUMP. A player mid-jump is holding the mouse -- they just clicked JUMP --
so a click-anywhere skip is something you do by accident the first time
and then never see the animation again. Whoever has seen it enough says
so once.

THE EVENT IS STILL EATEN EITHER WAY. Everything behind this is a drawer
button or a HUD tab belonging to a system the ship is leaving or has not
arrived at, and clicking one mid-jump is how an uncommitted jump walks
off. ESCAPE is let through so the pause menu is always reachable.
```

## Aim line

Above `class AimLine extends Control:`:

```text
Hand order is presentation, not state — the deck, discard and draw rules do
not care — so reordering is free and worth allowing.
Hand order is presentation, not state — the deck, discard and draw rules do
not care — so reordering is free. The view hands over the order it is already
showing, which is why nothing can land a slot off.
The aiming line: from the armed card to wherever you are pointing.

Its own Control because it must draw OVER the board and under nothing, and
because a `_draw` on the screen itself would be behind every child panel.
Ignores the mouse entirely -- it is a picture of a gesture, not a part of one.
```

Inside `_on_card_dropped()`, above `const AMP := 5.0`:

```text
TWO WAVES BEATING ALONG A STRAIGHT RUN, under an envelope that is widest
at the middle. Chosen off a bench of forty-odd treatments; the numbers are
the bench's, kept rather than re-guessed.

Each entry is a frequency in cycles across the run, a travel speed in
radians a second (sign is direction), and its share of the swing. The two
are deliberately not harmonics -- 12 against 17 never repeats over a run,
so the crossings wander instead of standing in a row.
```

Inside `_on_card_dropped()`, above `const BOW := 0.24`:

```text
How far the run bows off the straight line, as a share of its length and
capped. Generous on purpose: a shallow bow reads as a UI rule, a deep one
reads as something thrown.

MIRRORED ON THE HORIZONTAL. The bow is perpendicular to the run, so left
to itself it turns WITH the aim -- leaning out when you aim up-left and the
other way up-right, and swinging through the change as the cursor crosses.
Flipping its sign with the run's x makes it always belly away from the
card. That swing is what "acts weirdly" was.
```

Inside `_on_card_dropped()`, above `func _draw_shaft(a: Vector2, b: Vector2, t: float) -> void:`:

```text
The run, walked a pixel at a time with the waves placed off the axis.

STRAIGHT, and that is a fix rather than a simplification. This was a bowed
arc whose control point was perpendicular to the run, so the curve leaned
one way aiming left and the other aiming right and swung through the change
as the cursor crossed. Waves on a straight run have no such handedness.
```

## Turn playback

Inside `_on_end_turn()`, above `if combat.is_shared():`:

```text
THE TURN PLAYS OUT ON SCREEN (audit item 1). `end_turn` resolves the whole
enemy turn and deals the next hand in one call, and the screen used to
show all of it on the frame of the click. Held, it is caught as it
happens and then shown in order: what you burned, each enemy's move one
after another, the hull dropping as each shot lands, and only then the
new hand. In a shared fight the enemy's turn arrives later, over the
wire, and is drawn as it comes.
```

Above `static var shown_hull: int = -1`:

```text

COMBAT RESOLVES INSTANTLY AND ALWAYS WILL; THE SCREEN TAKES ITS TIME (combat
polish, Oct 13). The audit filmed END TURN doing everything on one frame --
the hand gone, every enemy acting, the hull down, new intents, a new hand --
with the shots landing half a second after the numbers had moved, and a kill
swapping the screen on the frame the card was let go. Nothing here changes a
number. It holds what the SCREEN shows back until the eye has been shown why:

  * a shot's numbers move when it LANDS (`_on_volley_landed`), with the
    damage, BLOCKED or MISS popped where it hit, and the impact sound and the
    view's kick on that frame (`Sig.hit_landed`);
  * END TURN is held (`_hold`): what it caught is replayed in order -- what you
    burned, then each enemy's move one after another -- and the new hand is
    dealt when the last shot is in (`_play_turn`);
  * a kill is a breakup of the ship's own picture when the killing shot lands
    (`_start_death`, `ShipBreakup`), and the fight ends when every death has
    finished (`_check_ending`), lowering the hand into LOCAL's band.
```

## Exit buttons

Above `func _ask_exit(title: String, ink: Color, edge: Color, said: String,`:

```text
Talk instead of shoot. `Combat.hail` owns the ruling and the roll.

No confirm panel, unlike FLEE. Fleeing throws a run's salvage away and deserves
the second question; hailing costs nothing you can see, and RULING 3 says a
number on the button IS the commitment.
BOTH WAYS OUT ASK FIRST.

Each is a single press that spends a run's progress, and each sits one row
from END TURN, which you press every single turn. Making them thin and
coloured narrowed the target; it did not make the click reversible.

They are also both CHECKS now, and that is the other half of it: RULING 3
says the odds go on the thing you press, so a button that rolls something
behind you is the one shape the rest of this game does not use. The panel is
where the number lives.

Nothing else in combat costs a run in one press, so nothing else gets this.
```

Inside `_ask_exit()`, above `var go := Widgets.button(go_label, func() -> void:`:

```text
IT DOES NOT CLOSE. The panel asked the question and it is the thing the
player is looking at, so it is where the answer belongs -- a panel that
vanishes and hands off to a full-screen overlay somewhere else makes you
find the result of your own press. `_on_combat_ended` rewrites it when the
exit works; the branch below rewrites it when the exit fails and the fight
simply goes on, which nothing was telling you at all.
```

Inside `_ask_exit()`, above `_refresh()`:

```text
AND THE SCREEN CATCHES UP, for both of them. Hailing did this in its
own closure and fleeing did not, so a successful hail left the hand
greyed behind the panel and a successful burn left five playable cards
sitting under a fight that was already over. The refresh belongs to
"an exit was taken", not to one of the two exits.
```

Inside `_ask_exit()`, above `if _exit_ask != null and not combat.finished:`:

```text
`finished`, NOT `fighting()`. That helper asks whether there is a fight
on this screen and stays true after one ends -- `_finish` sets a flag,
it does not clear the enemy -- so testing it here ran the failure
branch over a hail that had just WORKED, and `_on_combat_ended` had
already written STOOD DOWN into the panel a microsecond earlier. The
only way to see it was the empty body: a success carries its summary
on the signal, so `exit_note` was still the empty string.
```

## Hail

Above `func _on_hail() -> void:`:

```text
Hailing: the same exit bought with words rather than fuel.

It used to fire on the press. That was defensible while it was the cheap way
out -- nothing spent, nothing lost -- and it stopped being true once failing
it broadcast your position: fourteen heat and the turn handed back is a worse
afternoon than the six fuel FLEE asks you to confirm, and FLEE was the one
with the panel.

Heat rather than fuel, and the number is the botched one, because that is the
outcome the panel exists to warn about. A partial costs six and they still
leave; nobody presses a button because of what a partial costs.
```

## Death breakup

Above `func _on_enemy_destroyed(who: int) -> void:`:

```text
A hull coming apart. Not drawn here any more: the kill is shown when the
killing shot LANDS, as a breakup of the ship's own picture (`_start_death`).
Spawning debris on this signal put the explosion on screen eight frames
before the shot that caused it arrived (audit F4).
```

Above `var _prebuilt: Dictionary = {}`:

```text
Breakups being cut on a worker thread, by enemy: started on the frame the
kill resolved, picked up when its shot lands ten-odd frames later. Cutting a
hull is 40 to 90 ms of GDScript; on the landing frame it was a visible
freeze at the moment of impact (measured 105-128 ms frames).
```

Inside `_start_death()`, above `if not e.template.fauna:`:

```text
SOUND ON EACH VISIBLE BREAK, never on the resolution (Jon's rule). The
death styles' own sounds are not made yet: `moment` names every event a
sound will follow and is left unheard for now; a ship's explosive breaks
play today's explosion, and a creature's death plays nothing.
```

## Fight end

Inside `_on_combat_ended()`, above `_ending = {result = result, text = text}`:

```text
NOTHING ENDS ON THE FRAME IT RESOLVED. The kill, the death, the escape:
each waits for what the eye is still being shown -- the shots in the air,
the turn playing out, a hull coming apart -- and then ends, by
`_check_ending`. A won fight then lowers the hand (Jon) before LOCAL.
The endings a player ASKED for (flee, hail) still answer in the panel
they pressed.
```

Above `func _check_ending() -> void:`:

```text
THE END OF A FIGHT, once the screen has caught up with it: nothing in the
air, no turn playing out, no hull still coming apart.

THE HAND-OFF for the core's guard is the `won` branch: The Custodian's
breakup has finished and its body is on screen as the wreck it left
(`EnemyArt` draws a dead ship as its breakup's wreck). From there the band is
lowered and `_leave_combat` hands over to `Router.after_combat`.
```

## Hand raising

Inside `_on_fight_opened()`, above `if combat != null:`:

```text
THE FIRST HAND IS DEALT ONCE THE CONTACTS ARE IN (audit F6). It used to be
on screen whole on the first frame of the fight, the drawer and the cards
popping in together while the enemy was still flying in.
Every contact's wreck is cut now, off the main thread, so a kill costs its
frame nothing (see EnemyArt.warm_wreck).
```

Above `func _hold_for_arrival() -> void:`:

```text
AN AMBUSH ON ARRIVAL WAITS FOR YOU TO ARRIVE. The fight is begun as the jump
lands, and its screen plays the arrival (the system's name, your ship coming
in under power); the contacts used to fly in under the name and the hand was
up before your ship was there, which then flew in to a fight already laid
out. Now it is an arrival like any other until the approach's last second,
where LOCAL's drawer would have come up: there the contacts fly in and the
hand comes up instead (`_arrival_drawer`). The band and its buttons are held
as `_raise_band` holds them.
```

Above `func _raise_band() -> void:`:

```text
THE HAND COMES UP (Jon, Oct 13): "When the enemy ship enters.... the ships
pop up and the drawer pops into view.... can we have the opposite of the
fight ending screen where the drawer and ships would move up gently instead
of a pop?"

`_lower_band` played backwards, on the same clock and the same curve. The
fight's screen is built looking exactly like the LOCAL it replaces (it is
swapped in without a fade: `Router.start_combat`), so its first frame is
LOCAL's band, one line tall. Then LOCAL's line fades out (`BAND_FADE_S`, the
ending's fade in), the hand's band grows from that height to the hand's over
`LOWER_S` on the same sine, two pixels a step, while the arena shrinks with
it so your ship and the contacts ease up to their places; the hand's panel
fades up as it starts to rise and your plate fades in over the second half
(the ending fades it out over the first). The contacts fly in through it
(`EnemySlot.enter`, started as the fight opened).

NOTHING ON THE BAND TAKES A CLICK WHILE IT MOVES: LOCAL's buttons are behind
a shield from the first frame, END TURN, FLEE and HAIL are greyed as they are
while the hand lowers, and the first hand is dealt once the band is up.
Picture only: the fight it opens was begun before any of this, and nothing
here is sent to, or waited on by, anybody else's game.
```

Inside `_raise_band()`, above `var waited := 0`:

```text
AND NOT UNDER A CAMERA MOVE. ENGAGE pressed on the system map (the core's
guard) brings this screen in on the map-to-LOCAL zoom, which holds the row
at the size it had when the move began; a band grown under it left your
ship half the band low with its plate under the hand once the move landed
(Jon, Oct 22: "Glitch on boss fight?"). The hand comes up once it has.
```

Above `func _open_row_eased() -> void:`:

```text
The contacts take their half of the row. Where LOCAL gave your ship more of
it (an event's subject stood in the place's stead; a pack wider than the
place), your ship is carried across to the fight's place over the band's
rise, on its curve, in whole pixels, its plate with it, rather than standing
there on the next frame.

PINNED, NOT MEASURED ONCE: the row settles over a frame or two (the slots
learn their ships' widths, a pack closes up), so the ship is held where LOCAL
had it through every layout pass (`_pin_ship`, on its own rect changing) and
eased from there to wherever the row has put it by then.
```

## Pop numbers

Above `func _pop_at(to_player: bool, who: int, lines: int = 1) -> Vector2:`:

```text
Where a number about a hull goes, in the fx layer's space: centred across on
the hull's ink, just above your ship; above an enemy's INTENT WORDS, clear of
them (Jon, Oct 13, "C": just above the hull it sat on STRAFE and read
"ST-8E"). `lines` is how many will stack upward from here: the whole stack,
and the rise, is kept on screen under the top of the fight (`_pop_room`).
```

Above `func _pop_limit(who: int = -1, ink: Rect2 = Rect2()) -> float:`:

```text
The top of the fight in the fx layer: under the HUD.
How high a number may rise: under the HUD, and -- for a ship in a pack's
front rank -- under whatever ship stands behind and above it in the
formation (its words, hull and plate, wherever they come over the
numbers' width: the ship behind is set into the front ships' shoulders,
`EncounterView._pack_shoulders`), so a landed number never runs into the
rank behind. `ink` is the hull's ink in the fight layer's coordinates.
```

Above `func _hull_ink(to_player: bool, who: int) -> Rect2:`:

```text
A hull's INK in the fight layer's coordinates (`_view.fx`): the painted
pixels, not the canvas or the slot. Your canvas carries the exhaust's
clearance on one side, and centring on it put BLOCKED 5 right of the hull's
middle (Jon's still).
```

## Hit layers

Above `func _wreck_id_of(who: int) -> int:`:

```text

Jon's picks (Oct 13): hits B, block as the bubble, brace as the plated overlay,
on every ship in a fight (`HitLayers`). Each lands on the frame its pop and
sound do: `_on_volley_landed` hands it the volley; the refreshes catch block
and brace up when the screen does (a card's, a turn's start); the enemy's turn
fizzles each one's block as it acts and shimmers up the block it gains.
```

Inside `_on_fx_moment()`, above `if from != null and is_instance_valid(from) and not from.is_visible_in_tree():`:

```text
NOTHING SEEN, NOTHING HEARD: a ship's layers go with it while it breaks up
and stay hidden on its wreck, but its open vents keep their clock -- and
sputtered, heard, over a Hellbender coming apart and after it was a wreck.
```

## Ship loss

Above `const WRECK_HOLD_S := 1.0`:

```text

Jon, Oct 13: "When you die... let's have your ship crack and explode... pause
for a beat... then the run ended popup shows up." The killing volley lands as
it always did; then your hull comes apart (`ShipLoss`, the boss-length cut of
a ship style), the wreck holds for WRECK_HOLD_S, and RUN ENDED follows by the
same door as before (`_leave_combat`). Nothing about the run changes: it was
over in the maths on the frame the fight resolved.
```

## Shot landed

Above `func _on_shot_landed(who: int, to_player: bool, _kind: int) -> void:`:

```text
The shot arrived. Now the target moves.

ABOUT ITS PLACE AT REST, a second hit too. Two shots landing a frame apart
took the place mid-shake, a part of a pixel off, and left the hull there
for good: 0.8 px off the grid and the pack laid out round it (found sliding
the convoy column out, `-- sheet=ConvoySlideTest`).
```
