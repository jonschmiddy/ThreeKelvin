The reasoning behind `tkg/scripts/systems/NebulaField.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Cloud placement

Above `const R_MIN := 0.22`:

```text
Where the galaxy's gas clouds are.

Placement only — how a cloud is DRAWN stays in the chart, which has a great
deal of machinery for it. This exists because two different parts of the game
need to agree about where the gas is: the chart draws it, and the sector
screen has to know whether the system you are standing in is sitting inside
one. Deriving that twice from the same seed would work right up until someone
adjusted one copy.

Everything here is in NORMALISED galaxy units — the same space MapGen.gal
uses, where 1.0 is the disc radius — so a cloud and a system can be compared
without either knowing how big the chart happens to be drawn.
```

## Cloud extent

Above `const EXTENT := 0.62`:

```text
How much of a lobe counts as the cloud.

ONE number, used by everything: whether a system is in the gas, whether the
cursor is over it, and where the boundary is drawn. They were separate — the
outline took the whole lobe while membership took the dense middle — so the
chart drew a ring around systems that the panel then said were not in a
nebula. Any answer is defensible; three different answers are not.

Set where the gas actually stops: the falloff kills most of a cloud past
about six tenths of each lobe, so a boundary drawn further out circles empty
sky.
```

## Planetary shapes

Above `enum Shape {`:

```text
What a planetary nebula actually looks like.

They are the prettiest objects in the sky and almost none of them are the
plain ring the textbook picture suggests. What shapes one is what the dying
star was doing on the way out: a companion or a fast rotation leaves a dense
torus round the equator, the wind escapes through the poles instead, and you
get an hourglass. A jet that stalls in the surrounding gas leaves a bright
knot on either side. Only the quiet ones come out round.
```

## Planetary colour

Above `func _planetary_hue() -> Color:`:

```text
Planetaries come in every colour there is, and one palette entry made
every one of them the same object.

The green is doubly-ionised oxygen and it IS the classic — the Ring, the
Dumbbell — so it keeps the largest share. But which lines dominate
depends on the temperature of the star that shed the envelope and how
far the shell has expanded since, and those vary hugely from one to the
next: hydrogen and nitrogen give the reds, helium the hard blues, and a
thin old shell around a very hot core comes out violet. Unlike an
emission cloud, whose colour is just "what hydrogen does", this is a
property of the individual star.
```

## Arm fit placement

Above `enum Placement { RIDGE, FIT }`:

```text
WHERE ON A SPIRAL A CLOUD GOES.

RIDGE is how it always was: the centre on an arm's ridge at a rolled radius,
nudged along it, and the cloud as big as it was rolled whatever the arm is
doing there. FIT keeps the roll for everything but the centre, then looks at
`FIT_TRIES` places on the arms and takes the one where the most of the cloud
-- its lobes as drawn, a shell's ring and not its empty middle -- lies inside
the arm band (`arm_share`).

FIT, because RIDGE hung clouds off the arms (Jon, 2026-10-04: "Nebula hanging
off the edge of a galaxy spiral is weird... right?"). A ridge point is the
middle of the arm only at that one radius; the arm winds past it, so a shell
two tenths of the disc across centred on it lies half in the dark gap.
Gas sits in the arms: that is where the density wave piles it up, and where
the massive stars that become remnants are born. Ellipticals, lenticulars
and anything without arms keep the old placement; so does the cloud put in
over the core, which sits in the bulge on purpose.

Measured by `-- sheet=GalaxyDump nebulae`, 120 pinned seeds a kind, share of
each cloud inside its arm, RIDGE then FIT: Grand-Design 46% to 87% (212 of
368 clouds more out than in, to none), Barred 32% to 79%, Starburst 46% to
87%, Interacting Pair 68% to 96%, Anemic 14% to 64% (its one cloud is a
forced remnant and its arms are the thinnest). Pulsars per galaxy did not
move on any kind: a remnant's pulsar is the nearest system within 0.14-0.20
of its centre, and on an arm there is always one. Flyable everywhere either
way, maptest's 120 at 4.87 jumps both.
```

Above `static func _fit(c: Cloud, k: int, arms: int) -> void:`:

```text
FIT: the best of `FIT_TRIES` places on the arms for `c`, its shape already
rolled. The first try is where RIDGE would have put it, so a cloud that
already sat in its arm stays there.

A CLOUD WIDER THAN THE ARM IS MADE SMALLER. A tight two-armed spiral's arm is
about a tenth of the disc across and a landmark shell is up to six tenths,
so no place keeps it in; measured over 10 seeds the best place still left a
third of the Grand-Design's clouds half out. So when the best place keeps
under `FIT_INSIDE` of it in, the cloud shrinks a step (`FIT_SHRINK`, down to
`FIT_SMALLEST` of what it rolled) and looks again: a big cloud still gets to
be the biggest one the arm can hold.
```

## Core cloud

Inside `_build()`, above `if k == 1:`:

```text
One cloud is put in close, where the black hole can get at it. Every
cloud used to be placed outside 0.22 of the disc while the turning core
reaches 0.21 — so gas and hole had never once overlapped, and the code
that hands gas over to orbit had never had anything to hand. Real
galactic centres are thick with molecular gas; this is the one place
the game had none.
```

## Landmark size

Inside `_build()`, above `if not spiral and k == 0:`:

```text
THE SAME SIZE IN EVERY KIND. A spiral's landmark is shrunk to fit its
arm (FIT, below: measured mean 0.13, p90 0.19 over 12 seeds), and a
galaxy with no arms skipped that step, so its landmark kept the full
0.16-0.24 roll -- and a gas-poor ball rolls ONE cloud, the landmark, often
a remnant at x1.25: a shell a quarter of the Merger Remnant and the Dwarf
Spheroidal across (mean 0.24, p90 0.28). Shrunk here by FIT's typical
step instead, before the lobes are built round it.
```

## Kind weights

Inside `_build()`, above `var roll := a5`:

```text
Weighted toward the quiet kinds. This is a game about a cold universe
with one warm thing in it, so the loud clouds stay in the minority.
Rebalanced toward the two kinds a star DIED in. They are not just
scenery any more — a pulsar can only exist where one of these is, so
a 12% planetary meant most galaxies rolled none at all and the rarest
object in the game had nowhere it was allowed to be.
```

## Forced shell

Inside `_build()`, above `if c.kind == Kind.REMNANT:`:

```text
Every galaxy still forming stars gets at least one shell in it. Left
purely to the dice, 85 galaxies in 200 rolled neither a remnant nor a
planetary — and since a pulsar can now only exist inside one of those,
that was 40% of runs in which the rarest thing in the game was not
merely rare but structurally impossible.

Forced on the LAST cloud, and only when nothing earlier obliged, so a
galaxy that already has shells is untouched. A galaxy with no gas at
all still gets nothing, which is right: no star formation means no
massive stars, and no massive stars means nothing left to explode.
REMNANT only. A planetary used to count here, back when a pulsar
could sit in one — now that only a core-collapse supernova leaves a
neutron star, a galaxy whose one shell was a planetary was being
recorded as satisfied and then producing no pulsar at all.
```

## Planetary size

Inside `_build()`, above `c.radius *= 0.72`:

```text
Small and sharply hollow. A planetary is the envelope of one
star, not a star-forming region — at nebula scale it is tiny,
and drawing it the size of the others loses the distinction.
Still the smallest by a distance, but no longer a third of
the others: at 0.34 it was small enough that a system rarely
fell inside one, and now that a pulsar needs to fall inside
one, "rarely" was doing real damage.
```

## Core kept clear

Above `static func core_keep(g: Dictionary) -> float:`:

```text
THE CORE IS KEPT CLEAR. A cloud on the bulge ran into the black hole's disc
and its glow, and with the billows round it nothing read as itself (Jon,
Oct 5, of a remnant over the core: "Nebulas collide into the black hole...
it's hard to tell what is what.... it's just messy right now"). Every cloud's
drawn extent (`EXTENT` of each lobe) is kept outside the bulge's visible
reach plus a margin (`core_keep`): one that would cross it is moved straight
out from the centre until it clears, and made smaller if that would put it
past the disc. The cloud placed in close on purpose (k == 1) now sits just
outside the bulge instead of on it.
```

## Cloud membership

Inside `at()`, above `if cl.holds(p, reach) and d < closest:`:

```text
Well inside, not merely touching the outermost wisp: the falloff kills
most of a cloud past about six tenths of its nominal radius, so
anything beyond that is clear sky with a few pixels in it.
Against the lobes, not against a radius: the cloud is not a disc, and
testing it as one meant the tooltip fired over empty sky on one side
and refused inside plain gas on the other.

`reach` scales them: the dense middle for whether a SYSTEM sits in the
gas, since the falloff kills most of a cloud past about six tenths of
each lobe, and the full extent for whether the CURSOR is over it.
```
