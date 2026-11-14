The reasoning behind `tkg/scripts/systems/Hellbender.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line. Its prose still names the `Run.hellbender_*` forwarders, which are the same functions.

## The hellbender

Above `const STRIDE := 3`:

```text
THE GALAXY'S OTHER HARVESTER. One rival crew per dive, flying a furnace of a
ship, doing exactly what you are doing — and it is the one enemy with a
POSITION instead of an address. It rides the same link lattice the player
does, one hop at a time, eating the derelicts it lands on.

WHO DECIDES WHERE IT IS. The map's other shared facts are positional — a
seed puts the same wreck on four machines — but a thing that MOVES needs a
clock, and this game deliberately has no shared one: four ships jump at
their own pace. So the hellbender is host-authoritative, like a claim. The host
counts every ship's jumps (its own directly, a client's when the presence
message lands), moves the hellbender every `hellbender_stride()` of them —
a threshold that scales with the crew, so a bigger party does not shake it
off the chart — and pushes the whole state — position, hull, move counter —
through `Net.push_hellbender()`.
Solo, this machine IS the host of nothing and runs the same code without a
wire. WHERE it goes is `Rng.derive(&"hellbender", move counter)` — positional in
time rather than in space, so a replayed seed replays the pursuit and a
client handed the counter could re-derive the walk.

WHY IT EATS. §0 of `docs/coop-design.md` measured that attaching more
fights to a mechanic adds texture, not pressure, because fights pay. The
hellbender is pressure because AVOIDING it costs: every derelict it reaches
first is salvage the party does not get. Kill it or route around it, and
both of those are decisions with prices.

WHY IT HEALS IN TRANSIT. It breaks off at 35% hull (see
Combat.escape_intent()) carrying its damage, and mends HELLBENDER_MEND per move
after. That is the chase: the hull you took off it is a debt it pays back
slowly, so catching it two jumps later finishes a fight you already started,
and letting it go quiet for twenty is starting over.
```

Above `const STRIDE_CREW := 2`:

```text
Jumps between moves in a crew, PER SHIP. The clock counts the whole party's
jumps, so a flat threshold means the more of you there are the faster it
runs: at three, two ships moved it every jump and a half each, and it was
always gone by the time anybody landed on it. Nobody ever met it. Scaled by
the crew, the cadence is a thing each pilot can feel — two of YOUR jumps per
port, however many of you are flying — and the second jump is the window
somebody catches it in. A shade quicker per ship than the solo three,
because four ships strip a galaxy four times as fast and a rival that cannot
keep up is not a rival.
```

Above `func stride() -> int:`:

```text
Party jumps per move, for the crew currently flying. See the constants: the
count is the whole party's, so the threshold has to be the whole party's too
or the rival outruns a bigger crew. The call site tests the counter against
this with `<` rather than an equality, so a crew that SHRINKS mid-run — the
threshold dropping under a counter already past it — moves the rival on the
next jump instead of stranding it forever.
```

Above `func step(feeding: bool, away_from: int = -1) -> void:`:

```text
One hop. `feeding` is false on a flee hop — a ship running for its life is
not stopping to cut salvage, and the client applying the pushed position
must agree about which kind of landing it was. See `Hellbender.land()`.
`away_from` is a system a flee hop never lands in: the one it ran from. Two
hops out could be A to B and straight back to A, so its escape burn put it
at anchor where you had just watched it go (`hellbender_breaks_off`).
```
