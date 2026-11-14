The reasoning behind `tkg/scripts/systems/PlaytestLogs.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Save my logs

Above `static var dest_override := ""`:

```text
SAVE MY LOGS: one zip a friend can drag into the chat.

Without it, sending what went wrong means finding a hidden AppData folder.
So one button (Settings' PLAYTEST row, and the game-over panel) writes ONE
zip to the Desktop -- or into the game's own folder if the Desktop cannot be
written -- and opens the folder with it selected.

WHAT IS IN IT, BY NAME, AND NOTHING ELSE: this session's `godot.log` and the
one before it, `settings.cfg`, `run.save` if a run is suspended, the flight
record (`history.json`), and `build.txt` -- which build this is, the OS and
the graphics card. Every one of them is read from the game's own user folder;
nothing outside it is ever opened, and a developer's folder full of harness
pictures stays out because nothing is gathered by listing a folder except
the logs, and only `.log` files from there.

BUILD.TXT CARRIES WHAT A SLOW MACHINE'S REPORT NEEDS (Oct 27). "The game
chugs on my Mac" could not be read from it: it named the graphics card and
the screen, and none of what decides how much the game draws there -- the
LOOK (the tube is a pass over every window pixel), the window's mode and
size and how many screen pixels each game pixel became, how far the screen
scales (a Retina Mac opened the game at 3x until the 2X cap of Oct 27), the
frame cap and vsync (a frame a hair over 16.7 ms is SHOWN for 33.3 with vsync
on), the renderer, and whether the machine was on battery. Each is one line, asked of the engine
the moment the zip is written.

IN THE LOG COPIES the home folder's path becomes `~` and the account name
goes too: logs can carry absolute paths (an engine warning about a file names
it), and a friend's user name is nobody else's business.

NOTHING IS SENT ANYWHERE. It is a file on their own disk.
```

## Window line

Above `static func window_line() -> String:`:

```text
The window as the game is drawn into it: the mode and WINDOW SIZE the
settings ask for, the window's real size, how many screen pixels each game
pixel became (the shell's whole-number fit, `GameShell._fit`: BORDERLESS and
FULLSCREEN choose it too), and the screen's own scale (2 on a Retina Mac,
where the window's pixels are the backing store's, not the points a player
sees) beside the largest of any screen.
```

## Scrubbing the files

Above `scrub_with`:

```text
The bundle's text files (`settings.cfg`, `run.save`, `history.json`) go through the
same scrub as the logs. They carry a free-text ship name and whatever a future
setting stores, and a person who sends the zip should not be sending their home
folder or account name by accident.

They are text, so the scrub cannot corrupt them for the reader: a path replaced
inside a JSON string or a config value leaves `~`, which is valid there, and the
quote or bracket around it is untouched. A backslash is written doubled in both
formats (`C:\\Users\\Jon`), so that form is replaced too; the single form is not a
substring of it, so neither pass touches the other's matches. A home folder of one
character (or "/") is skipped: replacing it would turn every slash in the text into `~`.

The account name (three letters or more, as before) is taken out of `/Users/<name>`,
`\Users\<name>` and the doubled form, now also out of `/home/<name>` outside `$HOME`,
and out of the short form Windows gives a long name, `C:\Users\NAME~1`: its first six
letters in capitals, `~` and a digit, matched without regard to case.
`scrub_with(text, home, name)` is the same scrub for a given home and name, so a test
can feed it both without touching the environment.
```
