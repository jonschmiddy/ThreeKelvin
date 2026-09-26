# Art pool

Generated art that was judged but never assigned to anything in the game. It is
kept here, outside `tkg/`, so Godot does not import it and nothing ships until
someone picks a sprite for a slot.

- `ships/`: the ship pool (Sept 2026), 126 sprites at 1x, facing right. Jon's
  plan: generate for variety, then assign ships to enemies afterwards. `flip: true` in `picks.json` means
  he judged it mirrored.
- `megafauna/`: the seven kept creatures for the Voidwhale Calf and the Void
  Leviathan slots.
- `places/`: the kept sector places: stations, derelicts, core, pulsars.

`picks.json` records each verdict: keep, cut, or unjudged. The last ship round
was never marked. To use one, copy it to `tkg/art/sprites/enemies/<enemy id>.png`,
where `DB.enemy_sprite` looks for it.
