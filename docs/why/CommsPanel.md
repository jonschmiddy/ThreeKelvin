The reasoning behind `tkg/scripts/ui/CommsPanel.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Comms panel

Above `static var _open: CommsPanel = null`:

```text
COMMS, opened by the HUD's COMMS tab (Jeremy, a playtester, Oct 23: "The AI
is amazing, but it doesn't need to repeat everything when I jump out of a
menu after it has already said it. Give me an option to revisit all
communications."). Everything A.S.H. has said aloud this run (`Ash.comms`):
her quips, her teaching lines and the goal steps, newest first, a row each
with the jump it was said on and her words. A row with her voice has PLAY,
which says it again; a line said as text alone has none.

THE HUD, NOT THE ESCAPE MENU: the bar had the room. Measured on LOCAL at the
960 picture, its row wants 655 px of 932 with developer mode off and 785 with
it on; COMMS is 42 more (702 and 832), and a party's PARTY tab about as much
again, still under. `-- sheet=AshTutorTest` holds the row to fitting.

LAID OUT AS THE QUESTS TABLE IS (`QuestPanel`): over whatever is up, in the
HUD's column after the screens, right of the goal line and of A.S.H.'s first
place and under the HUD (`QuestPanel.frame_rect`), so it covers neither. One
of the two is open at a time. Closed by its tab, by CLOSE, by any change of
screen and by the escape menu opening over it. No count on the tab, ever, so
it never changes size.
```
