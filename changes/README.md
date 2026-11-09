One file per change, folded into `CHANGELOG.md` when a build is cut
(`tools/dev/cut_changelog.py VERSION`), so two branches never conflict over
the one file. Name it `YYYY-MM-DD-what-changed.md`, by the day: the files are
read in name order. The content is the CHANGELOG line itself:

```
- **Fixed** — in the Shipyard, clicking your ship no longer freezes the game
  for seconds. (#34)
```

`**Fixed**`, `**Changed**` or `**Added**`, then what a player would notice, in
plain words. The gate reads this folder (`unit_changes`).
