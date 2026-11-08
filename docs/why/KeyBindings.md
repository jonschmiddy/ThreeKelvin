The reasoning behind `tkg/scripts/ui/KeyBindings.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Key bindings page

Above `const CHIP_W := 46.0`:

```text
CONTROLS, the last section of Settings: every key a player can move, by the
screen it works on (`Keys`).

A ROW IS AN ACTION: what the key does on the left, then two chips -- its
key, and a second key if it has one -- and RESET, shown only on a row that
has been changed, so a page of defaults is a quiet page and a moved key is
easy to find again.

CLICK A CHIP AND PRESS A KEY. Escape backs out without changing anything,
and Backspace or Delete empties the slot. A key another action on the same
screen already uses is not taken silently: the row says which action has it
and offers SWAP (the two trade keys) or CANCEL.

Built for the drawer's width, like the rest of Settings, and rebuilt only
itself when a key changes -- the rest of the page and its scroll stay put.
```
