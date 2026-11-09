The reasoning behind `tkg/scripts/systems/SafeFile.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Write then rename

Above `class_name SafeFile`:

```text
SaveGame and RunHistory used to open their file with FileAccess.WRITE, which
truncates it at once, and then store the text. A crash or a full disk between
the two left an empty or half-written file. RunHistory.load_all reads that as
no history, so the next record() wrote a one-run file and the flight record,
and with it every unlocked manufacturer, was gone; SaveGame._read reads it as
no save and load_into_run deletes it.

The text goes to a sibling `.tmp` and DirAccess.rename_absolute moves it over
the real file. The paths are globalized first, as SaveGame.clear() does for
remove_absolute, so a user:// path works the same on the Mac and on Windows.
The rename is atomic on the Mac, and on Windows Godot replaces the old file
as it moves the new one in; either way a crash before the move leaves the old
file whole.
```
