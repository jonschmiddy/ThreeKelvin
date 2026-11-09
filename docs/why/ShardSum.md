The reasoning behind `tkg/scripts/sim/ShardSum.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Shard totals

Above `var h := Harness.new()`:

```text
A SPLIT HARNESS'S TOTALS, judged across its shards' logs:
  godot --headless --path . -- sheet=ShardSum label=<name> logs=<log>,<log>,...
A slow harness run as N shards (`-- shard=K/N`, `Harness.shard`) judges each
case in the shard that ran it, but an assertion over every case (found and
clean in at least 99% of a sweep, at most so many left) needs them all: each
shard prints its numbers for it (`Harness.total`, a SHARD_TOTAL line) and
this adds them up and judges the expression on the sums, as the harness
unsplit would have. It also holds the split itself: every shard's log ended
(its SHARD_DONE line), K from 1 to N each once with N the logs given, and the
cases the shards ran add up to every case, once, and every total came from
every shard (each prints all of them, nought for a sweep it has no case of).
PASS: `<label>_total: PASS`. Each shard's own verdict (`<label>: PASS`) is
read by whoever ran it.
```
