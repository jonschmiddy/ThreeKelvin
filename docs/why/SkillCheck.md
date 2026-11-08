The reasoning behind `tkg/scripts/systems/SkillCheck.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Shortfall ladder

Above `const ODDS: Array[float] = [1.0, 0.65, 0.40, 0.20, 0.05]`:

```text
An event option gated on one of the six attributes.

A check is a dictionary on the option: `{attr = &"hull", need = 5}`. The
screen asks this class what it costs, what the odds are, and — once pressed —
which of four outcomes happened.

THE SHORTFALL LADDER IS THE WHOLE DESIGN. A check is not a die roll against a
target; it is a question about how far short you are, and the answer degrades
in fixed steps. Meeting it is CERTAIN — no roll at all — because an attribute
you have earned should never fail you, and a 5% chance of disaster on a
requirement you exceeded is the kind of thing that makes players stop trusting
the numbers on their ship.

Being one short is a real attempt. Being four short is a stunt.
```

## Current values

Above `static func shortfall(check: Dictionary) -> int:`:

```text
How far under the requirement you are. Zero or less means you meet it.

Reads the CURRENT value, which is the rule from attributes-and-checks.md §0
and the reason the attributes are derived rather than stored: a holed ship
really does fail a Hull check it would have passed at full, and that is the
damage mattering outside combat.
```

## Failure split

Above `static func roll(check: Dictionary) -> Band:`:

```text
Roll it.

On a shortfall, failure splits evenly between PARTIAL and BOTCHED rather than
everything landing on the worst case. Partial is where the design effort goes:
it is the outcome that has to be interesting rather than merely bad, because
it is the one a marginal attempt produces most often.
```

## Odds badge

Above `static func badge(check: Dictionary) -> String:`:

```text
The label under the option: what it wants, what you have, what that is worth.

All three, always. The requirement alone cannot be judged without your value,
your value alone does not say whether it is enough, and the percentage alone
hides which attribute to go and improve. attributes-and-checks.md §7.3 asks
for exactly this and it is the only honest form: the player is choosing
against odds, so the odds are not a surprise to be sprung.
```

## Odds in words

Above `const VERDICTS: Array[String] = ["certain success", "likely", "uncertain",`:

```text
THE ODDS IN WORDS, and it replaced what one more pip would buy.

The badge used to end "one more: 65%", pricing the next module for you at the
moment you were short. That is a shopping answer to a gambling question: you
are standing in front of a thing you are about to do, and what you want to
know is whether to do it. The number is already there; the word is what it
MEANS, and reading the two together is how the percentage stops being a
digit and starts being a feeling.

ONE WORD PER RUNG, not thresholds on the percentage. `ODDS` has exactly five
steps and they are fixed, so there is nothing to interpolate and no boundary
to get wrong -- the ladder is the vocabulary.

THE BOTTOM RUNG IS NOT "CERTAIN FAILURE" and that is deliberate. It is 5%,
kept off zero on purpose -- see `odds` -- so that a desperate option is a bet
someone will take rather than a disabled button with extra steps. Calling it
certain would talk the player out of the exact choice the floor exists to
preserve, and it would be a lie about a number printed beside it.
```

## Read before outcome

Above `static func odds_line(check: Dictionary) -> String:`:

```text
The short form: what it wanted, and what it was worth.

MUST BE READ BEFORE THE OUTCOME RUNS. `odds` goes through `value_of`, which
reads the CURRENT attribute -- that is the whole point of attributes being
derived -- so an outcome that takes eight hull changes what a HULL check was
worth, retroactively. Asking afterwards would print the odds of the roll you
did not make.
```

## Band names

Inside `band_name()`, above `Band.MET: return "SUCCESS"`:

```text
SUCCESS, not MET. "Met" is what the CHECK did -- you met a
requirement -- and by the time this word is on screen the check is
over and the subject is the thing you were trying to do. It also had
to be read against SCRAPED THROUGH and BOTCHED, which are outcomes,
and one label out of four describing a different noun is the reason
the band never quite parsed.
```

Above `static func band_result(band: Band) -> StringName:`:

```text
The band as the word a spent card wears.

MET AND CLEAN COLLAPSE INTO ONE. The two are a real distinction in the
RESULT drawer -- doing the thing versus getting away with it, which is why
`band_name` keeps them apart -- but a stamp is a summary and "you succeeded"
is the whole of what it has room to say.
```
