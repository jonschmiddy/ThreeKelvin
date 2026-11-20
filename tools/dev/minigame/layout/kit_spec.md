# Science mini games: the UI kit

One chrome for all 17 games. `kit.js` draws it; picture: `games_in/kit_spec.png`; worked references:
`kit_swaps_ref.py` (Coolant, Pulsar) and `games_in/kit_ref_2x.png`; status A: `a_swaps.py` (Coolant first).
Play areas, rules and puzzle sizes stay each game's own.

Load `kit.js` after `tk_helpers.js` / `tk_font.js` (it registers `TK.KIT`). For the fit scripts: `page(KIT_JS + "\n" + game_js)`.

## Status A (Jon, Nov 20)

"I like A. You can just get rid of the bottom bar with GIVE UP. You can just press ESC to give up."

- **No strip.** No GIVE UP, no haul line, no LEAVE under the game: the whole 150 x 140 glass is the game
  (152 x 140 for the torch, the leak, the dock). Esc gives up.
- **No status line.** Its words go three ways (`games_in/fit/status_inventory.md` lists every game's):
  END words are the **result card**, LIVE words are **toasts**, a STANDING readout gets its own spot or goes.
- **The result card** (`KIT.resultCard`; in the game the shell draws it): over the play area 0.6 s after the
  end, the END word in its kind's colour, a rule, NAME [TIER] (the name in its tier's ink, [TIER] quiet), an
  amber LEAVE. **A click anywhere on the glass, or Esc, leaves.** This overrides Jon's Nov 19 "only LEAVE
  leaves" for the result card only: the card covers the game, so every click is a click on it. Everywhere
  else the rule stands (only pressable things look pressable).
- **Toasts** (`KIT.toast`): rows 12-22, centred, full for 0.9 s, two dithered steps, gone at 1.2 s; never take
  a click, never look pressable. One at a time; a new one replaces the old.
- **ESC on the tell** (Jon, Nov 20: "Maybe. CONTROL [GAME INSTRUCTIONS] / [ESC] TO GIVE UP"): the tell card
  has two lines, the game's controls and words, then the ESC key cap and TO GIVE UP in quiet ink.
- **Play areas grow** into every freed row (the status line's and the strip's). Pulsar and Sling keep their
  dials (r 14, r 13). Anomaly's lens goes back to r 55 with its rule in the bottom corners. Same rules and
  puzzle sizes; whole pixels; nothing overlapping or cut at any depth's worst case.

## Rows (the game area is always 150 x 140; whole pixels; 3x5 font, 4 px advance)

| rows | what | notes |
|---|---|---|
| 0-8 | HEADER band, border colour `#111823` | text rows 2-6 |
| 9 | header rule, `line` | |
| 10 - | PLAY area | the game's own; to row 139 without controls, to row 115 with |
| 116 | DECK rule, `line` (only with on-screen controls) | `KIT.deckY(true)`; `KIT.deckY(false)` is 140 (no deck) |
| 117-139 | CONTROL row (only with on-screen controls) | every control centred on row 128 |
| 33-73 | the RESULT CARD (the shell's), over the play area | `KIT.CARD` |
| 12-22 | TOASTS, over the play area | `KIT.TOAST` |

Gutters: 3 px left and right (text, meters, buttons). Gap between controls: 4 px.

## Header: `KIT.header(g, left, right, {padR})`
- Left: the game's main state, e.g. `HEAT` + meter, `ROTOR 10`, `TRY 1/2`, `SIG` + meter + `1/2`.
- Right: its counter(s), right-aligned at x 147: `TURNS 3  PAR 16`, `MOVES 7`, `TIME 38`. Pairs 8 px apart.
- Label `cold` (dim), value `ice` (bright). A label may take a kind (bad when the state is critical).
- Nothing else in the header except a game's own lamp or blocks drawn in the span it returns (`{lx, rx}`) or in `padR` (Pulsar's LOCK lamp).
- The game sizes its meter so left and right never meet (check the widest value).

## Result card: `KIT.resultCard(g, status, kind, haul, tier, t)` / `KIT.cardRect(status, haul, tier)`
- The tell card's box (bevelLo edge, border-colour face, bevelHi top line), centred on x 75, rows 33-73 (41 tall).
- END word at y+5 in its kind's colour, line rule at y+13 (6 in each side), NAME [TIER] at y+17, LEAVE
  (33 x 13, `active`) at y+25, centred on x 75.
- Width = widest line + 16, at least 79, at most 144 (x 3-146); a name too long for both drops [TIER].
- `t` is seconds since the end: nothing before `KIT.CARD.delay` (0.6 s), so the game's own end moment plays first.
- In the game the game says the word (`MiniGame.say_end`; on a page `pop.finish`) and the shell draws the card
  once the haul is paid (a give-up: `GAVE UP`, neutral). The shell sweeps NAME [TIER] in on the reward sound.

## Toast: `KIT.toast(g, text, kind, age, {cx, y})`
- A LIVE word (NO LOCK, LEAK, TOO FAST, ZAP! LIVE LINE ...): the same box, 11 tall, at rows 12-22, centred on
  x 75; text at y+3 in its kind's colour; width = text + 10.
- `age` 0-0.9 s full, then 3 of 4 pixels (the kit's 2x2 ordered dither), then 1 of 4, gone at 1.2 s.
- Draw it last in the frame (over everything); it takes no click.

## Popups helper (pages): `KIT.popups(ctx)`
`pop.say(text, kind, now)` (a toast), `pop.finish(text, kind, now)` (the END word), `pop.draw(g, now)` last in
the frame, `if (pop.click(now)) return;` first in the pointer handler. The card needs `ctx.haul` or
`window.__HAUL` (`{name, tier}`) to show, so a page in `diff.py` never draws it. In the game: `MiniGame.say`,
`MiniGame.say_end`, `MiniGame.draw_toast()` (last in the frame), `MiniGame.toasting()` (redraw while it fades).

## Tell card: `KIT.tell(g, text, icons, t, {y})`
Jon, Nov 20: "Maybe. CONTROL [GAME INSTRUCTIONS] / [ESC] TO GIVE UP".
- Line 1: the game's icons (y+2), then its words (y+6, ending in a full stop) in `hot`.
- Line 2, always: the `KIT.ESC` key cap (`key:ESC`, 17 wide, at rest: it never blinks) at y+15, then
  `TO GIVE UP` at y+20 in `cold` (the label ink), each line centred in the card (Jon, Nov 20: "can we center the text?").
  A game's icons never list ESC (MiniGameTest checks it).
- Box: `bevelLo` edge, border-colour face, `bevelHi` top line; 29 tall, centred on x 75; width = the wider
  line + 12 (line 2 is 59). Rows 45-73 (`ROW.TELL.y`). Icons are `TK.icon` kinds (`click`, `hold`, `drag`,
  `drag-h`, `drag-v`, `dial`) and key caps (`key:SPACE`, `keys:WAD`).
- Where the middle hides what a player needs to start, the game passes `{y}`: `ROW.TELL.top` (rows 12-40:
  Sample Tray, the sample's row; Four Kelvin, the ship on row 60) or `ROW.TELL.high` (rows 33-61, the result
  card's top: Tumble Dock, the spin arc's arrowheads). Godot: `MiniKit.tell(px, text, icons, t, MiniKit.TELL_TOP)`.
- Shown until the first input, then gone. Max width 144 px: 26 characters with one drag icon.

## Buttons: `KIT.button(g, x, y, w, h, label, state, icon)`
- Heights: 13 (label, or 9x9 icon + label in a line) at y 122; 19 (icon over label) at y 119.
- Widths: 25 / 33 / 45 (`KIT.btnW(label, icon)` picks the smallest that fits).
- States: `normal` (line face, bevelHi top/left, ice label) · `pressed` (shadow on top, face and label 1 px down) ·
  `active` (amber face, dark label: the one to press now, or the chosen mode) · `active-pressed` · `disabled` (outline only, dim label).
- Icons: 9x9 one-colour masks in the label colour (`KIT.ICONS`: ccw, cw, thrust, undo, spin, check, clear, lock, smoke, patch, grow; scan, dig, left, right in `kit_swaps_c`). Add new ones in the same 9x9 style.
- Hold-to-use buttons (thrusters, THRUST) show `pressed` while held.

## Dial: `KIT.dial(g, cx, cy, angle, {state, ring, label, value})`
- 19 across (R 9) at cy 128: knurled rim that turns with it, shaded face, amber pointer with a 2x2 tip.
- States: normal, active (held: brighter pointer), disabled. `ring: 'good'` = a dotted collar when it is set right.
- Label (`cold`, row 122) and value (`ice`, row 129) sit right of it. `KIT.dialAngle(v)` maps 0..1 to the 270 degree sweep.

## Meter: `KIT.meter(g, x, y, w, frac, kind, {mark})`
- 7 tall, `bevelLo` frame, 3x5 segments on a 4 px pitch (top row lighter), off segments `#18212d`.
- In the header at y 1; in the control row with a label on row 122 and the meter at y 128.
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
Tier ink (the card's NAME): `t0`-`t4`, common to legendary. `warn` (`#b8923f`) is not a kit colour: amber means
yours, so a warning is neutral until it is bad.

## Moving a game to A (`a_swaps.py`, one list per game, applied after the kit swaps)
1. The canvas is 150 x 140 (152 x 140): `H=140`; grow the play area into rows to 139 (no controls) or 115 (controls).
2. Every `KIT.status` call goes: END words to `pop.finish` (`say_end` in Godot, before `done`), LIVE words to
   `pop.say` (`say`), STANDING readouts per `status_inventory.md`. `KIT.status` and `ROW.STATUS_TY` are no-ops
   kept only while games move; a moved game never calls them.
3. The tell lists the game's own icons only (its second line is ESC); `pop.draw(g, now)` last in the frame;
   `pop.click(now)` first on a press.
4. Check 150 x 140 at every depth's worst case, nothing overlapping or cut, and 0 px in `diff.py` at start and end.
