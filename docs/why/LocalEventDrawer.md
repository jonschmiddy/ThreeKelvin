The reasoning behind `tkg/scripts/ui/LocalEventDrawer.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Event drawer

Above `signal changed`:

```text
EVENTS RESOLVE ON LOCAL (Jon picked drawer A, the low full-width band: "THIS
IS NIIIICE. I like A low band."; scratchpad `local_role/notes.md` section 5).

The sector map lists a system's events as cards and says one sentence of
each; GO flies the ship there and the view zooms down into LOCAL, composed
for that body (`ParkedShips.spots` -> `LocalSky`'s situation). Then
this comes up with the event's whole text and its choices -- the same choice
cards, odds, costs and readings the map's panel showed
(`EncounterDrawer.choice_card`). Choosing resolves through `OptionResolve`,
the one rule; the result comes up in the same place: the band word, YOU
CHOSE, what happened, what you end up with (`OutcomeRow`, in the look Jon
picks), REWARD (the system's pile in
`TransferView`) and CONTINUE. A fight it starts is THEY ARE FIRING, and then
the fight itself, whose hand takes the band's place. NOT NOW drops it and the
bar under the view says OPEN IT.

THE ONLY PLACE A CHOICE IS TAKEN: the map's panel no longer resolves events.
Co-op is unchanged -- `OptionResolve.take` asks the party first, as it did.

THREE LAYOUTS, ONE SWITCH (`layout`), so Jon can pick from stills:
  row     the low band, as tall as what it says (Jon: "almost too much empty
          space in the drawer"), capped at the fight hand's height; the
          choices a row of compact cards under the text
  column  the same band, the choices a narrow column on the right
  card    a small card that pops up in the middle of the play area (Jon: "What
          about a small card pop in the middle?"), nudged off your ship and
          the encounter's subject so the scene is still what you look at
Everything else -- the flow, the rule, the words -- is the same in all three.

THE TEXT ARRIVES LIKE A SIGNAL (`SignalText`), a word at a time; any click or key finishes it
(and is spent doing so), and the choices fade in only once it has.

The bar's half lives here too (`bar_line`, `can_reopen`), so `SectorScreen`
only asks what to print and whether to offer OPEN IT.
```

## Attach and auto open

Above `static func attach(on: Control, fighting: bool, auto: bool = false, held: bool = false) -> LocalEventDrawer:`:

```text
Put a drawer on LOCAL's screen, and open the event the map asked for. Not
during a fight (the hand has the band), and not for another system.

LOCAL IS GO (Jon, Oct 21: "I want to see the actual event of that
planet/POI... Clicking GO or clicking LOCAL should have the same result"):
with nothing asked for, `auto` (LOCAL's own doors: the HUD's tab, Tab, the
fly-in's landing) opens the event at the place the ship is as GO would
(`auto_open`). `held`: LOCAL's own arrival is under way, and the band waits
for it to settle (`open_held`), as GO's waits for the move down to land.
```

## Drop easing

Above `const DROP_MAX_PX := 10.0`:

```text
THE DROP NEVER JUMPS. It was a cubic ease-in, which ends at three times its
average speed: up to 29 px a frame on a middle-length band. It slides down
eased at both ends instead, over as long as its height needs to stay under
DROP_MAX_PX a frame at 60 fps (Jon, Oct 14: "Slide, eased"; a dissolve and a
shutter were the other two, and git has them). `-- sheet=BandDropTest`.
```

## Outcome looks

Inside `_result()`, above `var look := OutcomeRow.look`:

```text
WHAT YOU END UP WITH, in the look Jon picks (`OutcomeRow.look`): today's
four fixed pairs, A only what changed and big, B a GAINED | LOST receipt
beside the text, C only what changed flying to the HUD, D a little table
over the buttons, E that table and the things that came aboard drawn big
```

Inside `_result()`, above `var right: VBoxContainer = null`:

```text
D: a table on the right, the text wrapping clear of it; the buttons go
in that column, at its top (below). E: D as it was, the table over the
buttons on the band's floor, and what came aboard drawn big beside that
column, to its left (the table then leaves out what the plates say)
```

Inside `_result()`, above `var d_top := look == &"D"`:

```text
D's BUTTONS AT THE TOP RIGHT, level with the title (Jon, Oct 19: "can we
also have the buttons at the top right?"), its table -- the four stats
that moved, none when none did -- centred in the right column under
them (`OutcomeRow`'s D)
```

## Fight start

Above `func _fight() -> void:`:

```text
The fight the event started: the existing one, whose hand takes the band.

ONCE THE BAND IS DOWN. It used to start on the press, which threw the band
away in the middle of its drop and swapped the fight in over it; now LOCAL
is whole again when the fight's screen takes its picture, and the hand comes
up from there (`SectorScreen._raise_band`). Once: a second press on the
button sliding away is nothing.
```
