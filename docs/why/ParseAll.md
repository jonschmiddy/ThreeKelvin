The reasoning behind `tkg/scripts/sim/ParseAll.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Parse all

Above `func run() -> void:`:

```text
Every .gd in the project, loaded:
  godot --headless --path . -- parseall

`--check-only` DOES NOT SEE EVERY FILE, and that is the whole reason this
exists. It reaches the scripts the scene tree pulls in; it does not reach the
ones loaded by hand at the moment somebody runs them. Every out-of-band
harness in scripts/sim is exactly that shape — `load(...)` inside a branch of
Main that only fires when you pass its flag.

So CoFightTest.gd sat un-parseable for five days. `--check-only` reported zero
errors, `validate.sh` stayed green, and the only way to find out was to run
the co-op harness by hand, which nothing in CI does. Three lines had gone in
at column zero in the middle of an `if` body — the shape a heredoc leaves when
it eats the indentation on the way in.

Loading a GDScript compiles it, so a file that will not parse fails here.
```

## Touch and read

Inside `run()`, above `@warning_ignore("unused_variable")`:

```text
TOUCH IT AND LET GODOT SPEAK. Three cleverer answers were tried here
and all three were wrong, which is most of what this file is for:

  load(f) == null     waves a broken file through. A script that
                      will not parse still comes back AS a GDScript,
                      which is exactly why the failure this exists
                      for read "Nonexistent function 'new' in base
                      'GDScript'" instead of a null reference.
  can_instantiate()   answers a different question, and said no to
                      BotPilot, a file that parses perfectly.
  compile the source  every file carrying a `class_name` then
                      collides with its own registered global class.

Godot itself prints "Parse Error" and "Failed to load script" when a
load fails. So the reliable check is simply to make sure every file
IS loaded and then to read what it said -- which validate.sh does by
grepping this run's log. All this loop owes it is the touching.
```
