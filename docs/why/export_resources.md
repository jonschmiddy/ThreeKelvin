The reasoning behind `tkg/tools/export_resources.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Resource export

Above `func _run() -> void:`:

```text
Dumps the seeded Database content to .tres files so modules, hulls and
enemies become inspector-editable assets instead of code.

Run from the Godot editor: File > Run (with this script open).
After exporting, point Database at the folders with ResourceLoader if you
prefer .tres as the source of truth.
```
