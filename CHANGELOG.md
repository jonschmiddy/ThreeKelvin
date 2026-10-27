# Changelog

All notable changes to **Three Kelvin** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html). Alpha builds carry a pre-release tag (`-alpha.N`).

## [Unreleased]

- **Changed** — the chassis select shows each frame's real hull after its HULL pips, so a light
  Korvan reads "4 29 hull". Geno read 4, 6 and 8 pips against 29, 40 and 57 hull as a mismatch.
  The HULL tooltip no longer says a pip is exactly 7 hull. It says about 7, rounded, and works
  the sum on your own ship ("29 hull is 4 pips"), on the refit screen and in the cutaway too.

### Roadmap

The next build follows the friends' playtest of 0.4.2-alpha.1 (Oct 23). See
[`docs/DEVELOPMENT_PLAN.md`](docs/DEVELOPMENT_PLAN.md) for the build order and the balance spine.

## 2026-10-23

### [0.4.2-alpha.1]

Fixes from the friends' first night on 0.4.1-alpha.1, chiefly a hull swap that could strand
your parts and keep you docked. Saves from 0.4.1-alpha.1 load, and a stranded one comes back
playable. The Windows and Mac builds come from the same commit.

- **Added** — COMMS on the top bar, beside QUESTS. It lists everything A.S.H. has said this run,
  her quips and her tutorial lines, newest first, with the jump each was said on. PLAY on a line
  says it again in her voice. The list is kept with the run's save, and older saves load with an
  empty list. Jeremy asked for it: "Give me an option to revisit all communications."
- **Changed** — your ship shows only its weapons on LOCAL, in a fight, in the station hall and
  in the yard. Systems and utilities stay fitted but are no longer drawn on the hull, so the ship
  looks less cluttered. Every part still shows in the cutaway, on the refit screen and when
  moving to a new ship.
- **Changed** — fitting a part with hull on it brings its hull with it. A full ship stays full
  (40/40 fits a +7 plate and reads 47/47), so the HULL bar moves at once for the "+1 HUL" the
  part shows. A damaged ship keeps the same damage across a fit, and taking a part off and
  putting it back lands you where you started. Before, fitting raised only the maximum, so a
  full ship read 40/47 and the bar did not move until you repaired.
- **Changed** — lock on stacks. Playing a second lock on card adds to the first instead of
  replacing it, and your next attack spends all of it, on every hit.
- **Fixed** — a part found a grade higher than usual now gives the stats its readout shows. A
  Ranging Optics that rolled Rare read SENSORS +1 but added nothing, and the same was true of
  every part with a stat bonus that rolled a grade up. Parts in saved runs are mended when the
  run loads.
- **Fixed** — after a hull swap you can always see your parts and leave. Taking a hull found in
  space never opened the screen for moving your parts across, so the ship flew on with all of
  them on the pad, out of sight, and the next station would not let you undock. Tab on that
  screen at a shipyard closed it for good, and SAVE AND EXIT in the middle of a move lost the old
  ship's picture. Now the move opens for a found hull, stays open until the pad is empty, opens
  again whenever you dock with anything on the pad, and comes back after CONTINUE. BACK OUT on a
  found hull puts the hull back where you found it. A stuck save opens on the move when it loads,
  with every part shown, and nothing is lost.
- **Fixed** — A.S.H. no longer says a tutorial line aloud twice. A line she has said to its end
  comes back, while you still have not done what it teaches, as words in her box with no voice
  and no chirp. A line cut off because you left the screen is said aloud once more on a later
  visit, never on the same screen or in the same fight, and after that only as words. Lines
  that only tell you something, like the fuel line after your first jump, are said once and
  never again. Her lines still stay up until you do what they teach. Jon's 0.4.1-alpha.1 log had
  the hull line five times and the heat line four times in one fight.
- **Fixed** — the heat lesson stays up until END TURN when a card like Bleed Heat cools the ship
  to nothing. It used to go and come back at the start of every turn.
- **Fixed** — pressing SAVE & EXIT counts as doing what the SAVE AND EXIT lesson teaches. Its
  question hid the lesson, so A.S.H. said it again the next time you opened the menu.
- **Fixed** — winning a run unlocks the next manufacturer even if you finished in another ship.
  A win counted for the manufacturer of the hull you ended in, so a Korvan run that swapped onto
  an unbranded frame from a derelict unlocked nothing. A win now counts for the manufacturer you
  launched with, and wins already recorded that way count too: on a profile with no other wins,
  they unlock Solari.

## 2026-10-22

### [0.4.1-alpha.1]

For the friends' alpha (Oct 23): 0.4.0-alpha.1 plus event quests and finished quests in the
QUESTS table, and R turning materials. Saves from 0.4.0-alpha.1 load as they are. The Windows and
Mac builds come from the same commit.

- **Added** — event quests in the QUESTS table. When an event plants a follow-up further in, like the
  runner's parcel, the QUESTS table lists it with the jobs you signed: MARKED, what to do, where
  it is and how many jumps away, ON ARRIVAL for the pay, and the event that gave it. Its note is
  the event's own words, and SHOW ON STARCHART and PLOT ROUTE work as they do for a job. A run
  saved before this still lists the ones it has open.
- **Added** — finished quests stay in the QUESTS table. Jobs you have handed in and event quests you have
  finished go under a COMPLETED heading below the open ones, newest first and greyed a little,
  with what each paid: a job's credits and standing, and an event quest's credits and the things
  it gave you. A finished row still opens its note and SHOW ON STARCHART.
- **Fixed** — R turns materials in the hold, as it turns modules. Point at a long crate in the
  hold on the refit screen, in LOCAL's cutaway or on the hull swap screen and R stands it on end,
  if it fits that way. Before, R only turned a material you were carrying.
- **Fixed** — in co-op, a partner taking an event can no longer close your quest or your job's
  pickup. An event quest and a contract's work are yours alone, and a partner's claim on the same
  spot in the same system now leaves them open.
- **Removed** — a hidden line on LOCAL that spelled out the system's danger and layer. It was
  built every frame but never shown; danger and layer are on the sector map, the chart and the
  escape menu. Nothing on screen changes.

### [0.4.0-alpha.1]

The fixes from the first outside playtest (Kevin, Oct 22): a much deeper tutorial that A.S.H.
speaks and nobody can click away, a QUESTS tab, co-op that works, REWARD on every result that
gives loot, and a harder game. The Windows and Mac builds come from the same commit.

- **Added** — A.S.H. speaks the deep tutorial's new and rewritten lines: Jon picked one of three takes for each (Oct 22).

- **Added** — a QUESTS tab on the bar at the top, after STARCHART. It opens a table of every
  quest you have signed, over LOCAL, the sector map, the chart or a station: what to do, its
  state (SIGNED, READY, or how much of its heat you carry), where it is (the system and its
  layer, or any yard of the one who posted it and the nearest), how many jumps away, the pay,
  and who posted it. Click a row to read the note and use SHOW ON STARCHART, which opens the
  chart on that place with the quest's tag, or PLOT ROUTE, which also draws the route there
  from YOU. With none signed, the table says where to get one.

- **Added** — a much deeper tutorial. A.S.H. now teaches 23 more things, each the first time it
  matters and each until you have done it. In a fight: the ENERGY box after your first card, a
  card's heat corner, underlined words and how to read them, picking a card to discard,
  malfunctions, FLEE and HAIL when the hull is at half, and the draw and discard piles. In an
  event: a choice that tests your ship and its odds, and the result with its REWARD. Elsewhere:
  fuel on your first arrival, the hull, flying by hand on the sector map, the starchart's layer
  strip, a signed job's ring, a marked system, a JUMP that cannot go, the slots that take the
  part in your hand, the cards each part brings, your ship's stats, the yard's FAULTS drone, a
  ship for sale, UNDOCK, and SAVE & EXIT in the escape menu. The chassis select has a card too.
- **Changed** — The Hellbender's posters just say WANTED. The bounty they promised (2500 CR on the
  WANTED sheet and the screen's FEATURED listing, 500 CR on a whiteboard note) was never paid, so the
  sums are gone, and so are the screen's "bounty raised" and "bounty desk" lines about it. Once it is
  dead the two posters are stamped DESTROYED, not CLAIMED. What its wreck pays is the same.
- **Changed** — from danger 5 in, there are no common parts or materials. Wrecks, kill bags,
  derelicts, event finds, relic analysis and station shelves no longer offer COMMON parts there,
  and wrecks, events and mining no longer give common materials. The grades above take their
  place, so a deep wreck is worth more than a rim one. Nearer the rim, commons drop as before.
- **Changed** — a jump now goes at most one ring deeper than the ring you are in. Jumps outward or
  along your ring reach as far as before. The quickest way to the core is now 14 jumps, one for each
  ring, where it was as few as 4. A star inside your reach ring that is two rings deeper or more
  says TOO DEEP when you point at it. Its fuel row reads ONE RING AT A TIME, and the JUMP button
  reads TOO DEEP. Every galaxy still has a way into each ring, and the core is reached from the
  last ring. The HEADING row now says OUTWARD for a star further out, where it said COREWARD.
- **Changed** — the Custodian has 200 hull, up from 120.
- **Changed** — the tutorial is paced by the game. In a fight a new line only starts with your
  hand settled and no card held, and most wait for the start of a turn: your first turn teaches
  the hand, energy and END TURN, and the rest come one turn at a time after that. Outside a fight
  there is a 3 second gap between lines, and one new line per screen. The line about what an
  enemy will do now comes at the start of turn 2, and the brace and heat lines stay until you
  press END TURN.
- **Changed** — A.S.H.'s lines about the hand, heat, brace, wrecks, salvage, SECTOR LOOT and the
  event band say more: support cards go on your own ship, what a wreck keeps if you leave, and
  that NOT NOW saves an event for later. The ship editor's line no longer mentions flipping a
  part, which only changes how it looks. Her voice for the new and rewritten lines comes later;
  until then they show as text.

- **Changed** — A.S.H. can no longer be clicked away. A tutorial line stays until you do what it
  teaches: pick a star on the chart, open an event, play a card, press END TURN, move a module, use a
  deck. Lines that only tell you something (enemy intent, brace, heat, low fuel) stay for their
  reading time after she stops talking, then go by themselves. If you leave the screen, the line goes
  and comes back next time, except the ship view's and each deck's, which count as said once you have
  heard them through. If another line is waiting, a line that has been up 20 seconds gives way
  and comes back later. Her quips play to the end: clicking her, picking up or dragging a card, or
  opening a wreck no longer cuts her off. END TURN still does. A tutorial line that comes due while
  she is talking waits for her to finish.
- **Changed** — while you drag a module in the ship view, every fitted module it can swap with gets a
  teal frame, next to the teal rings on the empty mounts it fits. A fitted module with no frame cannot
  swap with it, usually because the hold has no room for the module coming off. A module dragged out
  of SECTOR LOOT goes into the hold first, so with no room for it there nothing lights. The frames
  come up when you pick the module up and go when you drop it or let go anywhere else. Moving a fitted
  module onto another fitted one now works with a full hold too, since the two just trade places.
- **Changed** — the Custodian is harder. It dropped its block move (Plated Up), so Annihilate
  now comes every third turn, and Annihilate deals 40 instead of 22. Its hull is 200. In the sim
  a well-built ship now wins about half its fights with it, and a starter ship never does.
- **Fixed** — in co-op you can now join a friend's fight. When a partner is fighting in the system
  you are in, LOCAL's bottom bar says who and has a JOIN FIGHT button, and so does the sector
  map's panel. Before, there was no way in: every ordinary fight comes from a system's event or
  from something jumping you on arrival, and those fights were private, so you could only watch.
  The enemy grows for the second ship and the turn waits for both of you, as at the core.
- **Fixed** — in co-op the sector map now draws your partners' ships, in green with their names,
  and you can watch them fly between worlds. Before, a partner in your system was not on the
  map at all. Two ships in the same spot, like two that just jumped in together, sit side by
  side instead of one on top of the other.
- **Fixed** — on the star chart, a partner in the same system as you is now marked beside your
  YOU marker instead of exactly on top of it.
- **Fixed** — in co-op, a partner's ship on LOCAL and in a fight shows its pilot's name, hull bar
  and heat bar again. Before, the ship flew in with nothing over it.
- **Fixed** — in co-op, if two players' games build different galaxies from the same dive (which
  could happen between a Windows PC and a Mac), both screens now say so in a line at the top
  and ask you to send godot.log. Before, the party played on with every place in the wrong spot
  and nothing said why. Both galaxies and the seed are written to godot.log either way.
- **Fixed** — in co-op a friend who joins after the host has started the dive, or who rejoins
  with the code after their game closed, now lands in the same galaxy. Before, they got into the
  party and then sat on "The host starts the dive." for good. Both of you need this build.
- **Fixed** — an event that gives you something to take now always shows REWARD on its result.
  Before, only an event that gave a part did. One that gave only materials showed CONTINUE,
  the drawer dropped, and the materials sat under SECTOR LOOT with nothing to say they were
  there. This hit 82 events, 24 of them job events such as the dropped load, the long claim
  and the auction. CONTINUE still leaves anything you did not take under SECTOR LOOT. Credits
  are still paid straight to you and shown in the result's table.
- **Fixed** — pointing at a material or a credit chit in the ship view on LOCAL now shows its
  tooltip, in the hold and in a wreck's or the sector's loot. Before, only modules showed one
  there, so a material you were about to drag aboard said nothing.
- **Fixed** — the ship view on LOCAL and the SHIP screen no longer let you fit a part the reactor
  cannot run. The mount does not light up for it, and the log says the reactor cannot carry it.
  Moving parts across to a new ship at the yard already refused it.
- **Fixed** — the DISCARD pile's tooltip now says what goes there: the cards you played or
  discarded, and the rest of your hand at END TURN. It used to say only the cards you played.
- **Fixed** — the status icons in a fight now use the card's own word. NEGATE was called SLIP, and
  GROWS was called ADAPT.
- **Fixed** — RUN ENDED has a TITLE button. Before, the only way back to the title was Esc and
  then ABANDON.
- **Fixed** — Esc on CHOOSE A CHASSIS goes back to the title, after closing the opening deck if it
  is open. It used to open the pause menu, whose ABANDON put a run you never launched on your
  record.
- **Fixed** — the line at the bottom of LOCAL no longer has a dash in it. It reads NOTHING ELSE
  HERE · SEE SECTOR, like the event's own line.
- **Fixed** — epic, legendary and artifact materials now turn up at the same depth as epic and
  legendary parts: epic from danger 5, legendary and artifact from danger 7. Before, they turned
  up from danger 3 and 4, so the best materials were found about twice as close to the rim as
  the parts of the same grade.

- **Fixed** — arriving on LOCAL no longer shows the thin bar at the bottom while your ship flies
  in. Before, the bar was already up as you arrived, and then the event's text and choices rose
  out of it. Now the bottom of the screen stays empty until your ship settles. Then the event
  rises from below the screen, or the thin bar slides in if there is no event.
- **Fixed** — engaging the Custodian from the system map no longer leaves your ship sitting low in
  the fight for the whole battle, half hidden behind your hand with its name, hull bar and status
  icons out of sight. Your hand now comes up after the camera has finished moving in from the map.
- **Fixed** — in a system where the Hellbender is anchored, the SECTOR tab, Tab and LOCAL's
  button to the map now open the system map. Before, they all sent you back to LOCAL, so the
  only way off LOCAL was the STARCHART. This was worst after a fight with it: if you broke
  contact, or it ran on its escape burn and came straight back into your system, SECTOR and
  LOCAL stopped working for as long as you stayed. The map is also the way to the Hellbender's
  own place, where you fight it. Its escape burn now always takes it out of the system it ran from.
- **Fixed** — after you win an event's fight, LOCAL no longer shows a whole enemy ship beside the
  wreck of the one you shot. The event's own picture of what you were fighting came back once the
  fight ended, so a second ship seemed to appear out of nowhere. Now only what you fought is gone:
  the rest of the scene stays, such as the fuel depot, the seized hull or the hunting ship on the
  harpoon line. An event you flew past without fighting still shows its ship.
- **Fixed** — signing a job on the Hiring Board no longer reshuffles the board. Before, the job
  you signed came down and every other note slid along a place, and everything else on the
  board jumped to a new spot: the WANTED poster, the other notices and paper on a cork board or
  whiteboard, and the other listings on a city's screen. Now the job stays where it was, stamped
  SIGNED, and nothing else moves. The picked tab, the ads, the ticker and any open popup stay as
  they were. If you already carry the heat a heat job asks for, its note shows OFFLOAD where SIGN
  was, so you can hand the heat in from the same note.
- **Fixed** — a signed contract's work is now in the system its note names. A fetch puts a
  CONTRACT PICKUP event on a world in that system, and a hunt puts a CONTRACT TARGET contact
  there. Both show on the system map with the quest mark and in its event list, and open on
  LOCAL like any event. Taking the pickup or winning the fight readies the job to DELIVER at
  any of the poster's yards. Before, nothing was ever put there: a fetch finished on arrival
  with one log line, and a hunt waited for any fight you happened to win, which was gone if
  you had cleared the system before signing. A system you had already emptied opens again
  for the job, and a hunt you flee is there again the next time you arrive. Contracts now
  name ordinary systems only, never a station or a pulsar.
- **Fixed** — no two systems share a name. About a third of every galaxy had a name another
  system also had, so a contract naming one could send you to the wrong place. The later
  system of each pair now takes the next free name, and every other name is unchanged.
- **Fixed** — a contract's layer now matches the chart's. It printed one less (LAYER 6 for a
  system the chart calls LAYER 7).
- **Removed** — the ARCHIVE. Its tab on the HUD and THE ARCHIVE on the title screen are gone,
  and so are the 41 documents it held. Wrecks, fights, pulsars and contract cargo no longer turn
  up a document. Four event choices gave you a document and nothing else; they now pay a few
  credits, or give a used tow line, instead. Documents you found in earlier builds are no longer
  shown anywhere, and your saved runs load as before.

## 2026-10-21

### [0.3.2-alpha.1]

Fixes and changes on top of 0.3.1-alpha.1, from Jon's play that night. The Windows and Mac builds
come from the same commit.

- **Changed** — opening LOCAL at a world or station with an open event now opens that event,
  the same as pressing GO on it: you see the event's own ship or object, and the event's text
  and choices come up once your ship has settled. If you close it with NOT NOW, it stays closed
  until you fly away and come back. LOCAL no longer shows the generic signal beacon, wreck or
  battlefield picture anywhere. A place with no event shows nothing.
- **Changed** — when you dock, your ship's engines are heard as it flies into the shipyard. They
  roar as it comes in over the floor, then sputter out, and the flame you see sputters with them.
  The engines are quiet before the ship settles on its stands, and the docking clamps now sound
  as it touches down. Before, the clamps sounded while the screen was still dark and the ship
  came in without a sound. Pressing a key stops it all at once, and with reduced motion on you
  hear only the clamps.
- **Changed** — the first time you open LOCAL at a world or station you flew to on the sector map,
  your ship flies in from the left and settles into orbit, the same way it arrives in a new
  system but without the system's name. Opening LOCAL there again shows it already parked. A key
  or click skips straight to parked.
- **Changed** — a station now powers on when you arrive beside it on LOCAL, without docking. Once
  your ship settles, its lamps flicker on bank by bank and its warning lights flash, then turn
  green. It stays lit while you are there, and docking then keeps it lit instead of powering it
  on again.
- **Changed** — a station powering on now makes sound, both on LOCAL and when you dock. Each bank
  of lamps clunks and buzzes as it lights, and a short tone plays when the warning lights turn
  green. There is no sound for a station that is already lit, when you skip, or with reduced
  motion on.
- **Changed** — LOCAL's bottom bar counts only the things at the world or star you are at, such as
  "1 THING HERE". Before, it counted every event in the system, so it could say "3 THINGS HERE"
  beside a planet with nothing at it.
- **Fixed** — LOCAL no longer shows a stand-in beacon, wreck or battlefield picture. Before, a
  system with an event anywhere showed one beside your ship at every world, at the star and at
  the system's edge.
- **Fixed** — LOCAL no longer shows an old event's ship or object at the edge of a system. After a
  new run, or after jumping back into a system, the last event you opened could appear there.
- **Fixed** — if you open LOCAL while your ship is still moving into orbit beside a station, LOCAL
  now shows the station, the DOCK button and "A STATION HERE". Before, it showed a small
  stand-in ring and told you to fly to the station you were already reaching.

### [0.3.1-alpha.1]

Two fixes and one change on top of 0.3.0-alpha.1. The Windows and Mac builds come from the same
commit.

- **Fixed** — LOCAL now shows the world you just flew to even if you open it while your ship is
  still burning into orbit. Before, LOCAL showed empty space for that second or so, and the sector
  map then dropped your ship out of its orbit. The same happened if you opened LOCAL just after
  sending the ship somewhere else, before it had left.
- **Fixed** — after you dock, pointing at your own ship in the shipyard shows its stats box at
  the right size. Before, the box was 9 pixels too tall, with an empty strip along its bottom, and
  sat 9 pixels too high. It was only right when the station opened without the docking animation.
- **Changed** — on LOCAL, the world you orbit is now drawn large behind your ship, as if you were
  close to it. Planets and gas giants are about twice as wide as before, and their lower edge runs
  off the bottom of the view.

### [0.3.0-alpha.1]

Jon's own polish on top of 0.2.0-alpha.1, made the same day. The Windows and Mac builds come from
the same commit.

- **Changed** — when A.S.H. explains your ship's cutaway, her box now also shows the keys under
  her words: "R turns a part. F flips it." It shows the keys as you have them bound in Settings.
  She does not say them; her spoken line is the same as before.
- **Changed** — when your ship flies into a system on LOCAL, the dust and the sky now stay still
  and only the ship moves, as they already do when you dock. Before, the dust jumped sideways as the
  ship appeared and then slid back while it flew in.
- **Changed** — LOCAL REGION (L) on an elliptical or dwarf galaxy now zooms in on the systems near
  you, as it does on a spiral. Before, it framed the whole galaxy and barely zoomed at all.
- **Changed** — undocking is the dock played backwards. After the shipyard goes dark, LOCAL comes
  up with the view held still and the station's lights on. Your ship flies back out of the station's
  mouth the way it went in, engines burning, and slows to its mooring as they sputter down to idle.
  The dust, the sun and the worlds stay put, and the station stays lit. A key or click during it
  puts your ship at its mooring at once.
- **Added** — A.S.H. now says her five station deck tips out loud, in her warm voice, like her other
  tutorial lines.

### [0.2.0-alpha.1]

The first build sent to playtesters: 0.1.0-alpha.1 with the fixes from Jon's own playthrough of
it. The Windows and Mac builds come from the same commit.

- **Fixed** — the game froze while A.S.H. taught the star chart's list on a first run. Each
  check that her box covers no system asked the whole galaxy at every few pixels: about a
  second a frame. It asks only the systems near her box now.
- **Fixed** — LOCAL REGION (L, or the key it is bound to) pressed while the chart was still
  coming on was lost. It is kept and given to the chart when it lands.
- **Fixed** — two copies of the same build could refuse to party ("Your content does not match
  the host's"), depending on how each one started. The check that both players have the same game
  now reads the same way in every copy.
- **Fixed** — the welcome note's dark backdrop missed the edges of the screen, so the title showed
  through as a lit frame around the corners and sides. It covers the whole picture now, and so do the
  title's other popups and the Settings drawer.
- **Fixed** — text on the sector map's side panel ran up against its scroll bar. Every scroll bar
  in the game keeps a 4 px gap now.
- **Changed** — a manufacturer you have not unlocked appears nowhere. On a new profile, wrecks,
  shelves, the yard, derelicts, rewards, contracts and the Custodian hold Korvan and unbranded
  parts and hulls only. Win with Korvan and Solari's join them from the next run. In co-op, the
  host's unlocks decide what the galaxy holds.
- **Changed** — docking opens with a new system's arrival, exactly: LOCAL cuts to black, then your ship
  flies in from off screen to its mooring as it does in the first system, on the same path, with the
  same burn sputtering down to idle. Then a beat, the station's lights come on, and the ship lights
  its engines and flies in. The camera, the sky and the dust stay still throughout: only the ship moves. Docking from the
  sector map now fades to black and opens on LOCAL with the ship still off screen, so it is never seen
  at its mooring first. A key or click during it still docks at once.
- **Changed** — the station's left column of decks slides in like the other panels once your ship is on
  its stands, with its dark ground under it. It used to slide in see-through over the hangar and
  then pop to its dark column when it landed.
- **Added** — a launch screen in place of Godot's logo. The game opens in a small window in the
  middle of your main screen, showing the galaxy icon and LOADING, then switches to your own window
  when it is ready.
- **Added** — a first-visit tip for each station deck: the Shipyard, the Promenade, the Exchange, the
  Hiring Board and the Laboratory. Each shows the first time you open that deck, after the
  station's own tip, and outlines the deck's main thing: the drones, the shelf, the sell
  counter, the job notes, the fabricator. It counts as seen as soon as it shows. A.S.H. says
  it, or it shows as a card with her off. Her lines are text alone for now, with no recording.
- **Added** — README-ALPHA.txt explains FLY TOGETHER: HOST PARTY and a code, the same build for
  everyone, and the firewall prompt for HOST DIRECT.

## 2026-10-20

### [0.1.0-alpha.1]

The first alpha, for playtesters. The Windows and Mac builds come from the same commit.

- **Added** — a run to the core of a galaxy. The galaxy has 15 layers and about 287 star systems,
  and you can jump to any system within your drive's range. Danger rises from 1 at the rim to 10 at the core. A run ends
  when the hull reaches 0, the tank runs dry, or you abandon it. You win by destroying The
  Custodian at the core.
- **Added** — four views, all one camera at different distances, and the archive:
  - **LOCAL:** your ship side-on, the world you orbit, its wrecks and its events.
  - **SECTOR:** the system map. You fly the ship to events and the station.
  - **STARCHART:** the galaxy, with your jump range and the danger and fuel cost of each system.
  - **The station:** you dock and the camera goes in.
  - **ARCHIVE:** its own screen, with 41 documents recovered from wrecks and events.
- **Added** — card fights:
  - The reactor sets your energy, and the hull's weight sets your hand size. Press END TURN to
    end your turn.
  - Cards make heat. Past the heat cap, each point over costs 1 hull at the end of the turn.
  - Keywords: Brace, Charge, Salvo, Lock on, Vent and drones, plus 16 malfunctions that enemies
    can put in your deck.
  - FLEE and HAIL are checks.
- **Added** — nine enemy kinds:
  - five ship types;
  - two creatures, the Voidwhale Calf and the Void Leviathan;
  - The Hellbender, a rival harvester that roams the chart and runs at 35% hull;
  - The Custodian.

  Every kill leaves a wreck where the fight happened, and you can loot it.
- **Added** — 135 encounters, with checks against the ship's six attributes: HULL, THRUST,
  MANEUVER, THERMAL, SENSORS and STEALTH. A choice that is a check shows its odds, and a check you
  meet always passes. After an encounter, a small table shows only what changed among credits, fuel, hull and
  heat.
- **Added** — weather. There are eight kinds of sky and about 43 weather events. They play on the
  SECTOR map and, more rarely, on LOCAL.
- **Added** — 24 hulls: seven manufacturers at three weights, plus three unbranded salvage frames.
  Each comes in four grades, C to S. A new profile flies Korvan. Winning with a manufacturer
  unlocks the next one.
- **Added** — 95 modules, with seven rarities and 10 affixes, and 68 trade materials. The hold is a
  grid. Press R to turn a part and F to flip it.
- **Added** — the ship editor. Click your ship to open it. Drag a module onto an empty slot to
  install it, or off the ship into the hold to remove it. You can rename the ship here.
- **Added** — stations, with five decks:
  - **PROMENADE:** buy parts.
  - **SHIPYARD:** patch, repair, refuel, clear a fault, or buy a new hull with yours in part
    exchange.
  - **EXCHANGE:** sell parts and materials.
  - **HIRING BOARD:** fetch, hunt and heat contracts.
  - **LABORATORY:** relic analysis, in cities only.

  Outposts have fewer decks.
- **Added** — A.S.H., the ship's AI. She is a holographic face with 30 voiced lines for the
  moments that matter.
  - She introduces herself at the start of every new run, then gives the tutorial in 21 more voiced
    lines.
  - Settings can switch her off. The hints then show as cards.
- **Added** — a light tutorial:
  - The goal line (GOAL: REACH THE CORE) shows your first two steps.
  - 15 one-time hints each wait for a click.
  - Settings > HINTS has TUTORIAL ON/OFF and REPLAY TUTORIAL.
- **Added** — co-op. FLY TOGETHER on the title screen lets you host or join a party of up to 8
  ships, by code over a relay or by direct address. Fights are shared. A party has no hints or tutorial.
  A.S.H. still speaks, but does not teach.
- **Added** — the look:
  - pixel art drawn at 960×540 and shown at 2x;
  - four render styles, with SIMPLIFIED the default;
  - five screen looks, with CRT the default;
  - star fields that drift in layers when you pan;
  - a breakup for every ship you destroy, your own included.
- **Added** — a low-hull warning, from 30% hull down. The screen edges glow red, every piece of
  text decodes badly (letters flip to noise and back), and A.S.H.'s voice stutters and crackles.
  It gets worse as the hull falls and clears when you repair. The escape menu and Settings stay
  clean, and nothing on screen moves. Under reduced motion it is only a faint red edge.
- **Added** — sound: 27 music cues by danger tier, for fights and for death, about 150 sound
  effects, and station ambience with PA announcements.
- **Added** — settings:
  - window mode, monitor and window size;
  - render style, graphics level, screen look, colorblind modes, contrast and brightness;
  - reduced motion, screen shake and a frame cap;
  - four volume sliders;
  - 21 rebindable keys.
- **Added** — saving. The run saves at safe points and when you close the window. SAVE & EXIT TO
  TITLE, then CONTINUE, picks up where you left off. A fight is not saved: if you quit
  mid-fight, it starts again. The flight record and the archive carry over between runs.
- **Added** — Settings > PLAYTEST > SAVE MY LOGS. It puts one zip on the Desktop to send with a
  report. The same button is on the RUN ENDED screen. The game never sends anything by itself.
- **Added** — builds:
  - **Windows:** one exe, plus a console exe that shows errors.
  - **Mac:** one universal app, for Apple Silicon and Intel.

  Neither build is signed. `README-ALPHA.txt` explains the first launch. The version shows on
  the title screen and in the pause menu.
- **Known issue** — only Korvan, Solari and unbranded parts drop. The other five manufacturers can
  be unlocked and flown, but they have only 4 to 7 parts each and use Korvan's hull art. Their set
  bonuses can't be completed.
- **Known issue** — three set bonuses don't do what their text says:
  - **Cygnet 5:** drones persisting between encounters is not built.
  - **Korvan 3:** does nothing for cards that already charge in one turn.
  - **Solari 3:** applies to Solari cards that scale with heat, not to plasma weapons.
