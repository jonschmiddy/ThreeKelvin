The reasoning behind `tkg/scripts/ui/PauseMenu.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Pause menu

Above `signal resume_requested`:

```text
Escape menu. Overlays the game rather than replacing it, so the run behind it
stays intact and visible — the ship never disappears, which is the same rule
the encounter layout follows.

A DRAWER DOWN THE LEFT EDGE, built from Jon's picks across four rounds of
mockups: the drawer itself (over a centred box of full-width buttons that
read as a different game), the CHART INSET version of it ("clean"), and
chamfered plates with a second line under each label and a doubled-pixel
icon. It says where you are before it asks what next.

Built in code against UITheme like every other screen. Nothing here pauses
the tree: the game is turn-based and advances only on input, and this
control swallows every click. It lives on Main's overlay layer -- see
`Main._overlay` for why.
```

## Reduced motion close

Inside `setup()`, above `mat.set_shader_parameter(&"amount", 1.0)`:

```text
THE BACKDROP'S AMOUNT IS ALWAYS SET, animated or not. It used to be set
only on the animated way in, so a menu opened under REDUCED MOTION had
none -- and `close` reads it. Turn reduced motion back off with the menu
open and the close animated: it read null, the cast to float threw, and
`close` stopped halfway with the menu still up and swallowing every click
while Main thought it was gone (Jon: "makes the escape menu lock up").
```

## Exits

Above `func _show_exits() -> void:`:

```text
THE TWO WAYS OUT, and the difference between them is the whole save model.
SAVE & EXIT writes a bookmark you resume from once; the other throws the run
away. The autosave means the first is what happens anyway if the process
dies — this button exists so the player knows that. (There were three.
ABANDON RUN — START OVER went: it was ABANDON with one screen skipped, and
the title is one click from a new run anyway.)

Both land on the TITLE SCREEN rather than closing the game. Leaving a run and
leaving the program are different intentions, and the title screen is where
the answer to "what now" lives — including CONTINUE, which is the thing
SAVE & EXIT just created.

Mid-fight, the fight starts over when you come back: combat is outside the
save, so the run on disk is the one from before it, and SaveGame.mark_fight
notes which fight to restart.
```
