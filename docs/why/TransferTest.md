The reasoning behind `tkg/scripts/sim/TransferTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Transfer test

Above `var _tree: SceneTree`:

```text
The container, checked on what is DRAWN rather than on what is true.

THIS IS THE TEST THAT SHOULD HAVE EXISTED FOUR ROUNDS AGO. The same bug was
reported three times with three different triggers -- a drop into the
container, a right-click, and a drag that appeared to be refused -- and every
time the report was some version of "it will not move, then it appears out
there when I do something else". Every time, the model was already correct:
the item had left the hold, entered the bag, and the SCREEN had not been told.
The something else was only ever the first redraw.

Every probe written to chase it asserted on `Run.cargo` and `n.bag`, which is
exactly the half that was never broken. So this one refuses to look at them.
It counts ICONS, because an icon is what a player can see, and a view that
agrees with the model is the only claim worth making here.

Headless, on purpose. `-- sectorshot transfer` photographs this screen and
needs a window; this needs no pixels, only the tree, so it can sit in the
merge gate where a regression gets caught by a machine rather than by
somebody playing.
```

## Right-click

Inside `run()`, above `var back: HoldItem = wreck.items[0]`:

```text

It used to jettison, which made it the only destructive gesture in the
game with no confirmation and no travel. The assertion is INVERTED rather
than deleted: a binding that was removed and quietly comes back is exactly
the kind of thing that reaches a player before it reaches a test.
`n.bag` is untyped, so the element needs saying out loud.
```

## Blink count

Inside `run()`, above `var dips := 0`:

```text

"Too much flashing... it is like strobing instead of glitching" -- which
is a countable claim, so this counts it. The alpha used to swing the full
way either side of where it was heading on every one of fourteen cuts;
the crate vanished and came back fourteen times and read as a fault in the
screen rather than as interference.

The rule now: it is plainly visible for most of the sequence, and it dims
a small, fixed number of times.
```

## Popup shape

Inside `run()`, above `var frame := _view._loose.get_parent() as Control`:

```text

It used to size itself to its contents, so filling the container grew it,
emptying it shrank it, and a scrollbar appearing made it wider -- a window
that moves while you are working in it. Three states, one size: as it
stands, stuffed past scrolling, and stripped bare.

THE SIX-ROW FLOOR IS GONE AND THE RULING IS NOT. The popup used to be six
rows tall whatever was in it, which is how it never moved; Jon asked for
the dead space back and the skin he picked fits the grid to the pile
instead. So the measurement now happens ONCE, when the container arrives,
and the two checks below are what actually matters -- they caught this
exactly when the first version measured on every refresh.
```
