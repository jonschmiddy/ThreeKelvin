# Science mini games: the UI kit

One chrome for all 17 games. `kit.js` draws it; picture: `games_in/kit_spec.png`; worked references:
`kit_swaps_ref.py` (Coolant, Pulsar) and `games_in/kit_ref_2x.png`. Play areas, rules and puzzle sizes stay each game's own.

Load `kit.js` after `tk_helpers.js` / `tk_font.js` (it registers `TK.KIT`). For the fit scripts: `page(KIT_JS + "\n" + game_js)`.

## Rows (the game area is always 150 x 130; whole pixels; 3x5 font, 4 px advance)

| rows | what | notes |
|---|---|---|
| 0-8 | HEADER band, border colour `#111823` | text rows 2-6 |
| 9 | header rule, `line` | |
| 10 - | PLAY area | the game's own |
| deck top | DECK rule, `line` | 98 with controls, 121 without (`KIT.deckY(controls)`) |
| deck +2 | STATUS line text | 100 or 123, centred on x 75; the haul line sits at row 132, so 4 rows stay clear between them (Jon: "ROUTED is a bit too close to FLARE GLASS") |
| 107-129 | CONTROL row (only with on-screen controls) | every control centred on row 118 |
| 130-139 | the shell's strip | GIVE UP / haul line + LEAVE; never the game's |

Gutters: 3 px left and right (text, meters, buttons; LEAVE / GIVE UP sit 3 in too). Gap between controls: 4 px.
The rightmost button (33 wide at x 114) lines up with GIVE UP under it.

## Header: `KIT.header(g, left, right, {padR})`
- Left: the game's main state, e.g. `HEAT` + meter, `ROTOR 10`, `TRY 1/2`, `SIG` + meter + `1/2`.
- Right: its counter(s), right-aligned at x 147: `TURNS 3  PAR 16`, `MOVES 7`, `TIME 38`. Pairs 8 px apart.
- Label `cold` (dim), value `ice` (bright). A label may take a kind (bad when the state is critical).
- Nothing else in the header except a game's own lamp or blocks drawn in the span it returns (`{lx, rx}`) or in `padR` (Pulsar's LOCK lamp).
- The game sizes its meter so left and right never meet (check the widest value).

## Status line: `KIT.status(g, parts, kind, controls)`
- The ONLY place for status words: ROUTED, BALANCED, LOCKED, ALL DUG, MATCH!, CUT FREE, SEALED, DOCKED, IMPACT, OVERHEAT, NO LOCK...
- Also the running readout (`COLD 1/2  VALVE DRY`): parts two spaces apart, each its own kind.
- No 2x stamps or boxes over the play area for status. Big outcome moments are animation in the play area, words on this line.

## Tell card: `KIT.tell(g, text, icons, t)`
- One line: icons, then the words (ending in a full stop), in `hot`. Box rows 45-61, centred on x 75, in every game.
- Box: `bevelLo` edge, border-colour face, `bevelHi` top line. Icons are `TK.icon` kinds (`click`, `hold`, `drag`, `drag-h`, `drag-v`, `dial`) and key caps (`key:SPACE`, `keys:WAD`).
- Shown until the first input, then gone. Max width ~140 px: about 28 characters with one icon.

## Buttons: `KIT.button(g, x, y, w, h, label, state, icon)`
- Heights: 13 (label, or 9x9 icon + label in a line) at y 112; 19 (icon over label) at y 109.
- Widths: 25 / 33 / 45 (`KIT.btnW(label, icon)` picks the smallest that fits).
- States: `normal` (line face, bevelHi top/left, ice label) · `pressed` (shadow on top, face and label 1 px down) ·
  `active` (amber face, dark label: the one to press now, or the chosen mode) · `active-pressed` · `disabled` (outline only, dim label).
- Icons: 9x9 one-colour masks in the label colour (`KIT.ICONS`: ccw, cw, thrust, undo, spin, check, clear, lock, smoke, patch, grow). Add new ones in the same 9x9 style.
- Hold-to-use buttons (thrusters, THRUST) show `pressed` while held.

## Dial: `KIT.dial(g, cx, cy, angle, {state, ring, label, value})`
- 19 across (R 9) at cy 118: knurled rim that turns with it, shaded face, amber pointer with a 2x2 tip.
- States: normal, active (held: brighter pointer), disabled. `ring: 'good'` = a dotted collar when it is set right.
- Label (`cold`, row 112) and value (`ice`, row 119) sit right of it. `KIT.dialAngle(v)` maps 0..1 to the 270 degree sweep.

## Meter: `KIT.meter(g, x, y, w, frac, kind, {mark})`
- 7 tall, `bevelLo` frame, 3x5 segments on a 4 px pitch (top row lighter), off segments `#18212d`.
- In the header at y 1; in the control row with a label on row 112 and the meter at y 118.
- `mark` = a goal tick (blue).

## Colours: one meaning each
| kind | colours | means |
|---|---|---|
| neutral | cold / chill | plain readings, running state |
| yours | ember / flare / hot (amber) | the player's own: pointer, needle, cursor, active button, your trace |
| goal | t2 blue (+ ice) | the target to match or reach |
| good | good / mark green | right, done, safe |
| bad | bad red | wrong, failed, danger, a bar near its end |

Labels `cold`, values `ice`, tell text `hot`, frames `bevelLo` / `bevelHi` / `line`, bands `#111823`.
`warn` (`#b8923f`) is not a kit colour: amber means yours, so a warning is neutral until it is bad.

## Applying it to a game
1. Draw the header and the deck every frame (or the deck on a static plate, then controls over it).
2. Fit the play area into rows 10 to the deck's top (88 rows with controls, 111 without). Keep the status line clear.
3. Move every status word to `KIT.status`, every start card to `KIT.tell`, every button / knob / bar to the kit pieces.
4. Hit areas follow the new rects; the control row starts at row 107.
5. Check the frame is still 150x130 and drive the game start to result (as `kit_ref_sheets.py` does).

## Clearance above the reward line (Jon, Nov 20: "the dials come right up to the reward line")

The haul line is row 132. Nothing lit sits in rows 128-131: every control, dial, knob, meter and status
word ends by row 127 (a dimming veil over the deck is darker, not lit). `kit_boxtest.py` checks every
game's start, mid and result frames (`kit_frames/`, `kit_frames_mid/`).

