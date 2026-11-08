The reasoning behind `tkg/scripts/ui/EventScreen.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Option rewards

Inside `_choose()`, above `OptionTable.pay(outcome, Run.node_at(), StringName(_event.get("id", &"")))`:

```text
THE REWARD AN OPTION PAYS, which this screen never had to handle before.

`module = true` in the returned dictionary means "one rolled at this
system's danger", and both other resolution paths honour it -- `Policy` for
the sim and `SectorScreen` for a row that resolves in place. This screen
predates the option model and only read `fight`, so when RULING 2 made it
the detail view it became the one path that silently dropped the pay: it is
reached by exactly the options with prose AND a check, and those are the
ones that pay in parts. `salvage_rights` pays a module in two of its bands
and paid nothing through here.

No EventTable event grants one, which is why nothing caught it earlier.
```

## Prize door

Inside `_choose()`, above `var row := HBoxContainer.new()`:

```text
THE DOOR, WHICH THIS SCREEN NEVER HAD.

`pay` has always put a module on the system's floor from here, and this
screen has always said nothing about it -- the prose named the thing and
then the thing was somewhere else, two screens away, behind a button in a
sector you had to walk back to. `salvage_rights` pays a module in two of
its bands and is reached by exactly this path.

Same word and same pile as the drawer's: see `SectorScreen._open_prize`.
```
