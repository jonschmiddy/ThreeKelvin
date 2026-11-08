The reasoning behind `tkg/scripts/ui/SettingsMenu.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Title screen settings

Above `signal closed`:

```text
Settings in a drawer of its own, for the title screen.

In a run, Settings is not this: it swaps into the escape drawer in place of
the menu (PauseMenu.show_settings). The title screen has no escape drawer to
borrow, so this is the same drawer -- same width, same edge, same backdrop,
same motion -- holding the same SettingsPanel.
```
