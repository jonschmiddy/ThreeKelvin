The reasoning behind `tools/code_check.py`, the gate's maintainability ratchet.

## The limits

Measured on 63a09f26, game code only (`tkg/scripts`, not `sim`): 95 functions over 100 lines,
the longest 4317 (`OptionTable._authored`, one data table), the next 876 (`Main._ready`); eight files over 3000 lines, the
largest 5498; and 499 functions returning a bare `Dictionary`, `Array` or `Variant`. A
bare return hides what is inside, so every caller guesses the keys. `Array[Foo]` and
`Dictionary[K, V]` say it, and cost nothing. Fixing all of it at once is not worth the
risk to a seeded replay, so the rule only blocks more.

## How a line is counted

A function runs from its `func` line to the last code line before the next declaration at
its indent or less. Blank lines and comments inside it count; a trailing blank line does
not. "Over 100" fails, so a function of exactly 100 passes. `-> Array[Foo]` is not bare.
Sim code is left out on purpose: its harnesses are long straight scripts, not game rules.

## The baseline

Keys are the file and the function name, never a line number, so an unrelated edit above
a function does not churn the file. A second function of one name in one file is `name#2`.
A length entry records its size, and a function that grows past it fails. A bare return
records only its key. Renaming or moving a baselined function reads as new debt: fix the
type while you are there, or record it with `--update` and say why in the PR.

A fixed entry is reported (`FIXED`, `SHRANK`) and does not fail the gate, so two branches
never fight over the one file. `--update` rewrites the baseline from the tree and prints
every entry it ADDED or grew, so that shows in the diff.
