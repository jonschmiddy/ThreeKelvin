The reasoning behind `tkg/scripts/net/BotBoard.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Bot board

Above `const SCHEMA := 1`:

```text
What the bot can see, in words rather than in pointers.

This is the whole API surface of the ninth seat. Everything on the far end of
the mailbox — a model, a script, a person with a text editor — knows the game
only through what this file chooses to say, so the shape here is the shape of
what a remote brain is able to think about.

Two rules held it to this size:

LEGAL MOVES ARE LISTED, NOT INFERRED. Every board carries a `moves` array of
strings that are actually playable right now — the cards with the energy for
them, the systems in fuel range, the shelf slots nobody has bought. A brain
that has to work out legality from raw state gets it wrong, and gets it wrong
in the direction of trying illegal moves, which is a stall. Handing it the
list makes the wrong answer impossible to spell.

IT DESCRIBES, IT DOES NOT ADVISE. There is no "recommended" field and no
score. `Policy` already holds an opinion and it is one keystroke away when
the brain wants it (`pass` takes it); mixing the two would produce a bot that
is really the autopilot with a model rubber-stamping it, which is not the
thing that sounded fun.

Everything here is JSON-safe: dictionaries, arrays, ints, floats, strings,
bools. No StringName, no objects. `JSON.stringify` silently renders an object
as a pointer, so a leaked EnemyState reaches the far end as `<Object#-92233>`
and reads as data right up until somebody tries to use it.
```
