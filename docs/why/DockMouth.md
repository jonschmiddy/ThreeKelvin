The reasoning behind `tkg/scripts/ui/DockMouth.gd`; each heading is referenced from the code by a `Why:` line.

## The mouth is the button

Above `class_name DockMouth`, and in `SectorScreen._attach_station_face`:

```text
DOCK BY THE STATION'S MOUTH (Jon, Nov 15). On LOCAL at a station the bar
offered DOCK beside SCAN SECTOR while the station's open bay stood right there.
Integrated means no controls (Nov 9 yard): click the thing itself. So the
bay's opening is the button: the pointer on it lights the bay (look A,
`StationFace` Dock by the mouth), the cursor is the pointing hand, a click
docks exactly as the bar's DOCK did (`Router.show_station`, with its click
and hover sounds), and the bar's DOCK is gone (every control earns its place).

Only pressable things look pressable: `_has_point` answers only while docking
is offered, so the hand and the light come only then. Offered is where the
bar's DOCK was (a station beside you, `Router.at_station`, the ladder on) and
LOCAL at rest: no fight, no jump or arrival playing (`settled_local`), no move
under way, not dead, not the Custodian's body, not while the Hellbender holds
the system. The hit area is a child of the back face, under your ship's row,
so your hull keeps its own clicks where the two meet; it is the opening,
`StationFace.mouth()`, placed each frame by the face.

Mirrored (moored on the station's right, `Moored`) the same mouth is there,
flipped with the view, and docks by the fade (`ZoomLadder.dock_fade_only`).
Its pointing hand is set once, before the flip: a cursor changed under the
mirror reads an upside-down rect (`Moored.cursor`).

There was no key for DOCK (`Keys` has none, and Tab is NEXT SCREEN), so none
was added. The map's DOCK is unchanged.
```

## The hint line

Above `const HINT := true`:

```text
A FIRST-TIMER'S HINT (proposed Nov 15; Jon has not ruled): until the first
dock by the mouth on this profile the bar reads "A STATION HERE · CLICK ITS
BAY TO DOCK" instead of "A STATION HERE". Kept in the hints file
(`Hints.store_path`, key HINT_KEY) as a hint's seen flag is. HINT false turns
it off in one line.
```

Nov 17 (Jon: "If I click Dock from the sector... the tooltip shows up for the
CLICK ITS BAY TO DOCK"): the map's DOCK brings LOCAL up on its way into the
hangar, and the bar offered the bay's click while the dock was already under
way. The hint now stays off while a dock is under way or done
(`DockMouth.docking`: docked, the map's DOCK chain or LOCAL with your ship kept
off, the ladder's move in), and a dock by the map's DOCK marks it seen
(`DockMouth.learned`): a player who docked knows how to dock.
