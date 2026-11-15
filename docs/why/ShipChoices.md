The reasoning behind `tkg/scripts/ui/ShipChoices.gd`; each heading is referenced from the code by a `Why:` line.

## On your ship

Jon, Nov 15: LOCAL's bottom shelf goes (the event band, the quiet drawer, the OPEN IT bar). He picked
C of three mockups (https://claude.ai/artifact/UFYW9E4C4sWWfyBjvawSVw, "your own ship, in two
steps") and BEAT over CLICK for when the choices come.

1. The event shows up: a hail pinned to whoever talks (the event's subject as drawn, else the world
   you orbit), a mint frame with a tick down to them. The title in gold with its tag word, a source
   line, then the body, printed as the band printed it (`SignalText`). Nothing on your ship yet, so
   you read first.
2. One second after the text is in (BEAT), the choices settle onto the parts of your ship that
   would do the work (`ShipParts`): corner brackets in the maps' R1 style, 0.95 under the mouse and
   0.5 for the rest, settling 2 px inward; a leader to a label "PART: VERB" with the price or odds
   under it. The odds keep their colour and the prices stay legible on a dim label, so the danger
   is read at a glance. NOT NOW is the bow. Clicking the part or its label chooses, through the same
   `LocalEventDrawer.choose`, so `OptionResolve.take` (and the party's claim) is unchanged.
3. The hail turns to their answer. Over your ship, the reward stack: the check's odds, what moved
   ("+60 CREDITS", already yours, so no brackets: only pressable things look pressable) and, when
   anything landed on the pile, a bracketed "+1 PART" that opens the pile (`TransferView`, SECTOR
   LOOT) as the band's button did. The bow flies on (CONTINUE), or says THEY ARE FIRING.

Jon's notes on the first stills (Nov 15): the hail sits right beside whoever talks, as in the mockup,
over them, else under, else beside, with a short tick, never parked in a corner with a long leader. A
tall text widens the box (to 320) before the hail goes further off. It may cover empty sky, never a
ship, a label or the HUD; where nothing near is clear, the labels give way to it (`_free`). It stays
where it stood from step 1 through step 3 (`_spot`: over the speaker it keeps its foot, under or
beside them its head). The answer keeps the hail's source line; how the check went goes in the
reward stack. The band's WILL MAKE … UNAVAILABLE shows on the label you point at.

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
