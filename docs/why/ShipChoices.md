The reasoning behind `tkg/scripts/ui/ShipChoices.gd`; each heading is referenced from the code by a `Why:` line.

## On your ship

Jon, Nov 15: LOCAL's bottom shelf goes (the event band, the quiet drawer, the OPEN IT bar). He picked
C of three mockups (https://claude.ai/artifact/UFYW9E4C4sWWfyBjvawSVw, "your own ship, in two
steps") and BEAT over CLICK for when the choices come.

1. The event shows up: an event tag pinned to whoever talks (the event's subject as drawn, else the world
   you orbit), a mint frame with a tick down to them. The title in gold with its tag word, a source
   line, then the body, printed as the band printed it (`SignalText`). Nothing on your ship yet, so
   you read first.
2. One second after the text is in (BEAT), the choices settle onto the parts of your ship that
   would do the work (`ShipParts`): corner brackets in the maps' R1 style, 0.95 under the mouse and
   0.5 for the rest, settling 2 px inward; a leader to a label "PART: VERB" with the price or odds
   under it. The odds keep their colour and the prices stay legible on a dim label, so the danger
   is read at a glance. NOT NOW is the bow. Clicking the part or its label chooses, through the same
   `LocalEventDrawer.choose`, so `OptionResolve.take` (and the party's claim) is unchanged.
3. The event tag turns to their answer. Over your ship, the reward stack: the check's odds, what moved
   ("+60 CREDITS", already yours, so no brackets: only pressable things look pressable) and, when
   anything landed on the pile, a bracketed "+1 PART" that opens the pile (`TransferView`, SECTOR
   LOOT) as the band's button did. The bow flies on (CONTINUE), or says THEY ARE FIRING.

Jon's notes on the first stills (Nov 15): the event tag sits right by the thing the event is about,
UNDER it first, else beside it, never over it (round 2), with a short tick, never parked in a corner with a long leader. A
tall text widens the box (to 320) before the event tag goes further off. It may cover empty sky, never a
ship, a label or the HUD; where nothing near is clear, the labels give way to it (`_free`). It stays
where it stood from step 1 through step 3 (`_spot`: it keeps its top edge). How the check went goes
in the reward stack.

NO VOICE (Jon, Nov 15): a quote pinned to the subject read as the subject talking ("looks like the
spacewhale is talking to us"). So the pinned box is the EVENT TAG, a plain description of the thing:
the title, its tag word and the body, no source line and no hail. (The code's names followed:
`EventTag`, `event_tag`.) The band's WILL MAKE … UNAVAILABLE shows on the label you point at.

This stage adds the layout beside the band, behind `LocalEventDrawer.layout`. It is on in an editor
run with no harness flags (F5), and off in exports and every harness unless `-- shipchoices` asks.

## Quiet tag

With no shelf, the shelf's quiet one-liners need a home too (the mockup's "with no shelf at all"):
a system's or station's line pins to the place as a name tag (the station's mouth, the world you
orbit, the event's subject, else the star), with its doors as bracketed words (OPEN IT, JOIN FIGHT,
SECTOR LOOT, a pulsar's FLY THE BEAM, the Hellbender's ENGAGE). The way to the sector map is the
HUD's SECTOR tab, so the shelf's own button is not repeated. "The ship is lost" is a card in the
middle with SUMMARY; SALVAGE THE CUSTODIAN is a bracket on its body with the word under it. The tag
has no frame (Jon, Nov 15): it is not pressable, only its bracketed words are. At a station it pins
to the station. Rebuilt only when what it says changes, so its words can be clicked.

Jon, Nov 15, playing it: the quiet one-liners with nothing to do ("Open space, with the reactor
running...") are unnecessary. A tag shows only when it carries something to do: OPEN IT, JOIN
FIGHT, SECTOR LOOT, a pulsar's FLY THE BEAM, ENGAGE, the docking hint until the first dock, the
death card's SUMMARY and the Custodian's salvage. Everything else says nothing.

## Scan sector

Jon, Nov 15, playing it: "when an encounter ends the player is just awkwardly sitting in LOCAL",
then "what about instead we go from the bridge (SCAN SECTOR)". After a result, and whenever LOCAL
has nothing up, a bracket on your ship's bridge (the raised command deck, top front) says BRIDGE:
SCAN SECTOR; clicking it zooms LOCAL out to the sector map, as the shelf's SCAN SECTOR did. FLY ON
is gone. Walk-away choices and NOT NOW stay on the bow and only close the event. Never while the
choices are up, in a fight, or while an event is about to open on its own.

## Nothing on a moving ship

Jon, Nov 15, playing it: entering the first sector, BRIDGE: SCAN SECTOR stood at the screen's left
edge, then rode in with the ship. What is on your ship (the part brackets and labels, SCAN SECTOR,
the reward stack) shows only once the ship has stopped: LOCAL settled (`SectorScreen.settled_local`,
no fly-in), the ship not arriving, and its box still for `STILL_S`; then it fades in over `FADE_S`.
It goes at once when the ship moves (an arrival, a GO, the zoom ladder, a dock flight). The event
tag is on the subject, not the ship, and is not held. Jon then: "can the reticle move with the
ship? The text can stay still": the brackets are drawn on their parts where the ship is as each
frame is drawn, arriving or zooming, and cannot be clicked until the words show.

The words in a boxed label are centred on their ink (cap tops to the last line's foot, read off the
font's own glyphs), not on the font's box, whose ascent and descent differ (Jon, Nov 16).

THE FLASH AS AN EVENT OPENED (Jon, Nov 16, on main too): `LocalEventDrawer.open_held` laid a black
screen over LOCAL and faded it out, a leftover from LOCAL coming up from the map's zoom. By then LOCAL
had been on screen through its own arrival, so the event's start blacked the whole screen for a
frame. It no longer does; the cut from the map with no zoom ladder still fades in from black. `ShipChoicesTest` watches a first arrival and a
GO frame by frame.

