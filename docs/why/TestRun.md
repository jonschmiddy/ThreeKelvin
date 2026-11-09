The reasoning behind `tkg/scripts/systems/TestRun.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Harness scratch files

Above `const STALE_S := 86400`:

```text
A HARNESS'S OWN SCRATCH FILE, one per process:
`user://harness/<stem>_<pid>.<ext>`.

It was one file for every harness (`user://harness_run.save`), and the gate
runs its harnesses side by side -- and other agents run theirs at the same
time. So `subjecttest` saved its run, went to the title and pressed
CONTINUE, and loaded whatever `savetest` or a render had just written there:
another galaxy, another system, the ship "in orbit" of a world that system
does not have (Oct 12: 4 failures in a gate, none run alone; reproduced 1 in
4 with `savetest` looping beside it). The "Parse JSON failed" that came and
went in the gate was the same thing, a read half way through another
process's write.

Files not written for a day are deleted the first time any is asked for, so
the folder holds only recent harnesses' files. BY AGE, NOT BY PID: Godot's
`OS.is_process_running` only knows processes this one started, so on Windows
it calls every other live harness gone -- the first version of this deleted
a running `subjecttest`'s save under it (3 failures in 8 runs).
```
