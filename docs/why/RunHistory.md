The reasoning behind `tkg/scripts/systems/RunHistory.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Run history

Above `const PATH := "user://history.json"`:

```text
Every run that has ended, oldest first, in user://history.json.

Deliberately a separate file from the save. The save is the present tense and
gets deleted the moment it is read; the history is the past tense and is only
ever appended to. Putting them in one file would mean one bad write could
take both.

This is a record, not meta-progression. Nothing here feeds back into a run —
no unlocks, no carried-over currency. The design ruling is that identity is
assembled mid-run from what you find, and a history that handed you a
starting bonus would be the first crack in that.
```

Inside `record()`, above `chassis_manufacturer = String(Run.launched_as if Run.launched_as != &"" else Run.hull.manufacturer),`:

```text
WHO YOU LAUNCHED AS, by id. `hull` is a display string and `manufacturers` is a
tally of the parts you ended up carrying; neither answers "which manufacturer
did this player fly", which is the question the unlock chain asks. See
Unlocks.
The manufacturer LAUNCHED AS (`Run.launched_as`), not the hull flown at
the end, which a swap can make another manufacturer's or none (Geno,
Oct 23). No new key for the end hull: a new key here needs
RunHistory.VERSION, and moving it discards the whole record.
```

Inside `record()`, above `seed = Run.galaxy_seed,`:

```text
THE RUN, AS ONE NUMBER. Everything a run is — the galaxy, the map, the
loot, who was waiting at every node — derives from this, so recording
it turns the flight record from a list of things that happened into a
list of things that can happen AGAIN. It is what makes "that was a
great run" actionable rather than nostalgic.

Run.galaxy_seed rather than Rng.master: the master is reseeded per
seat in co-op, and what identifies a run is the galaxy everyone shares.
```
