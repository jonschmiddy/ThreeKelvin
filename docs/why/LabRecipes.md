The reasoning behind `tkg/scripts/ui/LabRecipes.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## The labs recipes page

Above `signal lit_changed`:

```text
THE LAB'S RECIPES PAGE, in AUGMENT's layout (Jon, Nov 5: "Can't we make the
recipes page like the augment page in its layout? Just slightly different
probably."). The rows of words with a MAKE key on each are gone. Now:
  left    what you hold that the Lab takes (survey film, relics), on a rail
          with their pictures, as AUGMENT's FITTED / IN THE HOLD;
  middle  the one in hand, drawn large on its grid, under the Lab's scanner
          (the line that sweeps down it is what makes this page not AUGMENT);
  right   the recipes it can go into, as rings like the affix offers: film
          to DEVELOP FILM, a relic to READ FOR DATA or RELIC ANALYSIS, each
          with what it makes and what it uses;
  bottom  the recipe picked, named, with what it does, its bill and MAKE.
With nothing held, the rail shows each thing as a faded outline with where
it comes from, and every recipe greyed with what it needs.

PORTED FROM THE MOCK (tk-wt/recipes-mock RecipeMock.gd, idea B; stills in
tk-scratch/science/review_lab/recipes/B/): its rail, bench, rings and strip
are drawn where and how it drew them. The recipes are DB.RECIPES, read
through `Fabricator`, so a recipe added there shows up here with no code.

BUILT ONCE. MAKE is made with the page and only restyled on a refresh, so a
click survives the `resources_changed` its own press sends.
```

## The pictures are drawn here

Above `static var _imgs := {}`:

```text
THE PICTURES ARE DRAWN HERE, IN CODE, as shaded images the size of a part's
sprite, and go through AUGMENT's own two hands: its phosphor on the rail,
its schematic (outline, a line at each step of shading, four tones) on the
bench. One drawing in both places; the film's leader, pulled out of its slot
on the bench, is its only change. The relic is a broken slab of precursor
circuitry, not an Earth thing: three faces, a crack, traces that run off its
broken edges, and a ringed core.
```
