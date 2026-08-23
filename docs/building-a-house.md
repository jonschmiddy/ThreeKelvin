# Building a house

How Korvan and the unbranded stock were written, in the order it happened, so
the next five manufacturers can be built the same way rather than rediscovered.

`docs/catalogue.md` is the **rules** — what a module is, what it may grant, what
a grade is worth. This is the **method**: the sequence, the checks at each step,
the questions to ask at the end, and the traps that cost real time on the first
two houses.

One house is roughly **40 cards across 20-25 parts**. Korvan took a day and
about eight passes, most of them because the checks in step 4 did not exist yet.
They exist now, so the next one should take fewer.

---

## §1 Read the house's own line first

Every manufacturer has one sentence on the chassis screen, and **it is a
contract, not decoration**:

| House | The line |
| --- | --- |
| Korvan Heavy Works | Ex-military surplus parts. Ballistics run cold; ordnance and plate run hot. |
| Solari Foundry | The line between reactor and weapon is philosophy. |
| The Probate Combine | Everything is salvage. Even you. |
| Redline Shipyards | Still flying? Then we did our job. |
| Cygnet Dynamics | You are never alone. |
| Verity Ateliers | Made once, made properly. |
| Calyx Biosystems | Grown, not built. |

Korvan's line turned out to be **enforceable**: ballistics run cold, ordnance
runs hot, and the card data already told the two apart — ordnance banks the shot
(`charge_turns`), ballistics fire (`hits`/`salvo`). Four cards were breaking it
and nobody had noticed, because nothing was looking.

**Before writing a card, ask whether the house's line implies a rule that can be
checked.** If it does, write the check first. It will find things.

---

## §2 Count what is missing

    godot --headless --path tkg -- content

Prints parts, unique cards, target and shortfall per house. Run it before and
after; it is the only number that says whether the pass is done.

---

## §3 Write the parts

In `tkg/scripts/autoload/Database.gd`, as `_module()` calls, grouped by house.
All the laws are in `docs/catalogue.md`; the four that shape a pass most are:

- **Every module grants two cards** (§2). Verity grants one.
- **Shape decides the card grades** (§3). 1-2 cells is grade-plus-lower; 3-4
  cells is two at grade. This also decides which parts *may* be a pair.
- **About one in four parts is a pair** (§5) — two copies of one card, right for
  the parts whose own flavour says they do one thing.
- **A house's parts grant that house's cards** (§4), with the shared library
  (§6) as the exception any part may draw on.

### Fill the gauge ladder, but only where the house owns it

Every gauge should be reachable at +1, +2, +3 and +4. **A rung nobody can buy is
a rung that does not exist**, and a player building for an attribute finds that
out by not finding the part.

**Do not fill a gap with an off-brand part.** Korvan is heavy, slow and loud, so
its maneuver and stealth rungs were left empty for Redline and Cygnet. Writing a
nimble Korvan part to complete a table is the Spinal Mount mistake — a
heat-scaling gun on the low-heat house, which was caught only because a person
read it and said so.

Exotic and Artifact are unbranded by definition, so **the top of every ladder is
the yard's problem**, never a house's.

---

## §4 Run the gates

    godot --headless --path tkg -- holdtest    # the catalogue laws
    godot --headless --path tkg -- attrtest    # gauges move by what a grade promised
    godot --headless --path tkg -- reactor     # frames launch with a playable deck
    godot --headless --path tkg -- content     # the shortfall

`-- holdtest` is the one that matters most for a content pass. It enforces:

    every module obeys the card rarity law
    no two names share one effect
    no two effects share one name
    no card is named after a keyword
    no card repeats its own name in its effect
    Korvan ballistics run cold; only its ordnance runs hot
    all N parts fit the smallest hold
    art on ground / ink on void, both at 3.0:1

**Nine of these exist because a person found the problem by reading a list.**
Bolt On was Brace; Sight In was Load was Lay the Guns; Range Finding was Range;
a card called Hold Fast sat beside a different card called Hold Fast. Every one
shipped. The checks are the reason the last pass went in clean on the first run.

---

## §5 Export, build the page, look at it

    godot --headless --path tkg -- content json
    node tkg/tools/manifest.mjs out.html

Then publish `out.html` as an artifact and read it. **This is not decoration.**

The manifest sorts every card **by effect rather than by name**, which is the
only reason the earlier duplicates were ever visible — two cards that do the
same thing end up adjacent instead of eleven screens apart. It also groups by
cell count, draws the power-by-grade chart, and runs the duplicate check itself
rather than quoting the gate's verdict, because two implementations disagreeing
is information.

Both ends are gated (`validate.sh` step *"The catalogue export is a shape the
manifest can read"*), so a field that changes type cannot silently empty the
page.

---

## §6 Measure

    godot --headless --path tkg -- sim 200 seed=4242

**Always at a fixed seed, before and after.** The gate's own sweep is unseeded
and swings five points on a run that changed nothing; reading it as a regression
signal will send you chasing ghosts. Stash, run, unstash, run:

    git stash push -q -- tkg/scripts
    godot --headless --path tkg -- sim 200 seed=4242
    git stash pop -q

**A win-rate rise is not automatically a regression.** Pillar 5 says the ceiling
is meant to break. Watch the death causes, not the win rate — a run stopped by
arithmetic did not author its death; a run that spent its options and pushed
anyway did.

---

## §7 The audit, at the end of a pass

Six questions. All of them are answerable with a script over
`user://modules.json`; none should be answered by impression.

**Does every card speak the house's language?** Check the house's line from §1
mechanically where you can. Korvan: which attacks cost heat, and do they charge?

**Are the unbranded cards general enough for any frame?** No drones (Cygnet), no
credits (Probate), no heat-scaling or brace-from-heat (Solari). Yard stock has
to work on anything.

**Is every gauge covered, at every rung the house can honestly reach?**

**Does strength fit the grade?** Score every card, group by grade, and look at
the shape — power should climb and efficiency should stay roughly flat, meaning
a grade buys more *and* costs more.

**Does an uncommon beat the common doing the same job?** This is the sharper
test and the average will not show it. Five cards failed it and **three were
worse than a common a player already has** — Ripple Fire dealt 6 where the
common Slug deals 8.

**Does the flavour sound like the house?** Korvan is clipped ex-military
surplus and averages 8 words. Three tells that a line has drifted:

- **it explains the mechanic** — the card already says that
- **it repeats an opener** — `Surplus.` began two different lines
- **it argues** — *"that is the whole advantage and it is enormous"* is the
  writer telling you the part is good

---

## §8 Traps, all of which cost time on the first two houses

**A gate only protects what it is looking at.** Twice the check was right and
the page a person reads was wrong: the manifest printed reactor cells gross
while `-- reactor` printed net, and a gauge stringified to `["hull"]` while the
export kept writing valid JSON. Neither was in the gate. Both are now.

**Rendering nothing is how a broken contract looks like an empty catalogue.**
The page throws on data it does not understand rather than drawing a blank cell.

**Survey before a wide rename.** `armor` → `brace` was 183 references and worked
because four flavour strings were protected by hand first. `block` → `deflect`
was attempted an hour later without a survey, hit 40 files, and turned *"a dark
cloud blocks whatever is behind it"* into *"deflects"*. Only 14 files touched
the stat.

**A metric that cannot read a card scores it zero.** The first power table
scored six real cards at 0.0 — Brace from heat, Negate, both drone verbs, Evoke,
discard for credits — which reads as *those cards are weak* and means *this
cannot read them*. It nearly drove a retune of cards that were fine. The chart
has an **Unread** column now, and a bar with unread cards under it is a bar not
to trust.

**A `\n` inside a heredoc arrives as a real newline.** It has split a GDScript
`print` in half and produced a space-indented line the gate caught. Build the
string with `chr(10)` or an explicit backslash.

**A harness that fails to compile looks like a hang, not an error.** `RunState`
carries no `class_name`, so `RunState.PER_PIP` is a parse error — `.new()`
returns nothing, `get_tree().quit()` never runs, and Godot sits there until the
gate's watchdog kills it at 120 seconds. Autoload constants are reached through
the singleton (`Run.PER_PIP`) from a harness, and through a `preload` from
`Database`, which runs before the autoload exists.

**A multi-step edit that aborts partway writes nothing.** Twice a Python
`assert` failed on the third of four replacements and I read the success line
from the *next* command as proof the first two had landed. Apply edits
independently and report each one.

---

## §9 The order, in one block

    1  read the house's line; write a check for it if it implies a rule
    2  -- content                     what is missing
    3  write the parts                Database.gd
    4  -- holdtest -- attrtest        the laws
       -- reactor  -- content
    5  -- content json                the export
       node tools/manifest.mjs        the page
       publish, and read it
    6  -- sim 200 seed=4242           before and after, stashed
    7  the six audit questions
    8  commit with the numbers in the message
