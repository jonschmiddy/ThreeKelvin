# The catalogue

Every rule that decides what a module is, what cards it grants, and what those
cards may be called. Written down because the catalogue is about a quarter
built — 63 parts and 73 cards against a target of 63 and 300 — and the last
two hundred and twenty-seven cards will be written by somebody who was not in
the room when these were decided.

Most of what follows is **enforced**. That is the important half of this
document: a rule that lives only in prose is a rule that holds until the first
tired afternoon, and four duplicate cards shipped that way before anything
checked. Where a rule is enforced, this says which check enforces it. Where it
is judgement, this says that too, so the difference is never guessed at.

    godot --headless --path tkg -- holdtest      # every rule below marked "gate"
    godot --headless --path tkg -- content       # how much is written, per house
    godot --headless --path tkg -- content json  # the export the manifest is built from

---

## §1 What a module is

A part you find in a wreck, pack in the hold, and bolt to a hardpoint. It has a
**shape** in cells, a **slot** (weapon, system, utility), a **house**, a
**grade**, a line of flavour, and the **cards it grants**.

The cards are the point. A module is not a stat stick; it is a way of putting
particular verbs into a deck. Everything below is about keeping that honest.

Modules live in one place — `tkg/scripts/autoload/Database.gd`, in `_module()`
calls. There is no editor and no resource file per part, deliberately: sixty
parts in one file can be read top to bottom, and reading them top to bottom is
the only way anybody has ever noticed two of them were the same.

---

## §2 The Grant Count Law

**Every module grants exactly two cards.** `ModuleData.grant_count()`.

Fixed by module **class**, never by grade. A legendary drop must not make the
deck clumsier, because "declining the reward" arithmetic has no place in a loot
game. Rarity buys better verbs and bigger magnitudes; it never buys more cards.

Making the count a function of class rather than a per-module number makes the
invariant *a rarer module never produces a larger deck than its common sibling*
true by construction. There is no review step to forget.

It was 2 for weapons and systems and 1 for utilities, on the reading that a
utility is the situational third slot. The reading was sound and the result was
not: a utility was a part you found, packed and bolted on for a single card,
which made half the catalogue feel like a rounding error next to a gun.

**Verity Ateliers grants one.** The exception is a ruling, not an oversight —
the thin perfect deck the house is named for, made mechanical instead of
flavourful. It is why a Verity card is allowed to be stronger than its
neighbours at the same grade.

Affixes may move the count. Nothing else may.

---

## §3 The Card Rarity Law

**The grades of the two cards are decided by the module's SHAPE, not by its
grade alone.** `ModuleData.card_rarities()`, enforced by the gate.

| Module | Card grades |
| --- | --- |
| 1–2 cells | one at the module's grade, one **below** it |
| 3–4 cells | **both** at the module's grade |

An epic 4-cell bay grants two epic cards. An epic 2-cell system grants one epic
and one rare. The part that takes up half your hold is the part that pays you
twice.

This settles a question that has no good answer from grade alone: two legendary
cards off one part is too much, and one legendary plus a common is a reward with
a shrug attached. Shape is the dial that was already there.

**It also decides which parts MAY be a pair, which is stronger than a
guideline.** A pair is two copies of one card, so both copies are at one grade —
which the law only permits for commons (nothing below to drop to) and for 3–4
cell parts. An uncommon 2×1 cannot be a pair; its second card has to sit below
it. Nothing had to be told this.

**Gate:** `ok every module obeys the card rarity law`. Order-insensitive — which
card a module lists first is a fact about typing, not about the card.

---

## §4 A house's parts grant that house's cards

Korvan modules grant Korvan cards. Unbranded modules grant unbranded cards. The
exception is the shared library (§6), which anyone may draw on.

**Judgement, not gate.** A card carries no house field; the association is that
it is authored inside the module's `_module()` call. The check that would
enforce this is worth writing when the catalogue is larger and the cost of
getting it wrong is higher.

A house's cards should be recognisable as that house *without the name*:

| House | What its cards do |
| --- | --- |
| Korvan Heavy Works | Ballistics, armour, cold. Big numbers, no heat. |
| Solari Foundry | Heat as a resource. Pays in temperature for everything. |
| The Probate Combine | Salvage, credits, taking things apart. |
| Redline Shipyards | Cheap, improvised, hot. Draw attached to everything. |
| Cygnet Dynamics | Drones. Things that keep fighting after the card is gone. |
| Verity Ateliers | One card, better. Precision and filtering. |
| Calyx Biosystems | Growth, healing, cards that change through use. |
| Unbranded | Exotic (grown) and artifact (precursor). No house voice. |

A card that contradicts its house is a bug even when the numbers are fine —
Spinal Mount was a heat-scaling gun on the low-heat house, which made it a
Solari card wearing a Korvan name.

---

## §5 About a quarter of parts grant a pair

A **pair** is two copies of one card. It is how a part says *this is the only
thing I do, and I do it twice* — and it is right for exactly the parts whose
flavour already says so. Slug Thrower is "chemical propellant and a tube".
Ranging Scope "tells the guns where the thing is, that is all it does". Hull
Plating "does not have to be clever".

Target is roughly **one in four**. Above that the catalogue reads as smaller
than it is; below it, every part is a combination and nothing is a statement.

**Judgement, with a printed measurement.** The gate prints the shape rather than
failing on it, because the right number is a matter of feel:

    shape: 33 of 63 modules grant a pair (52%), 22 draw on shared cards (35%)

52% overall, because the six houses that have not been rewritten yet sit at 97%.
Korvan and the unbranded stock, which have been, sit at 25%. **Bringing the
other six houses down to a quarter is the largest single job left in the
catalogue.**

---

## §6 The shared library

Eleven common cards in `Database.SHARED` that any module may grant, by
`StringName` rather than by writing the card out again:

    &"brace" Bolt On      &"block" Hold Fast    &"vent" Bleed Heat
    &"reroute" Reroute    &"range" Range        &"slug" Slug
    &"cut" Cutting Beam   &"patch" Patch        &"scuttle" Scuttle
    &"sort" Sort          &"feed" Feed

**All eleven are common.** That is what makes them safe to hand out: under §3 a
common card can sit beneath any grade, so a shared card is always a legal second
card. A shared uncommon would be legal on some parts and not others, which is a
rule nobody would remember.

They exist so a part can be a **combination** rather than a verb with a name on
it — a house card and a plain one beside it. It is also what makes a catalogue
of sixty read as more than sixty things: two parts sharing a card while each
keeping something of their own are related without being the same.

Anything with a house's fingerprints on it stays written where it is granted.
That is what makes it that part's card.

---

## §7 No two cards are the same card

**Gate**, both directions:

    ok  no two names share one effect
    ok  no two effects share one name

The first is the catalogue claiming more than it has: 73 cards that are really
69, and a player offered a choice that is not one. The second is worse — two
different things printing the same word, and a deck list that lies.

They hide because nothing in the game ever puts two cards next to each other. A
card is authored on one module, drawn from a deck of fifteen, and rendered by
its own name, so two cards with one effect look like a varied catalogue from
every angle except the one nobody has: all of them, side by side.

Four were found by a person reading a list before this existed — Bolt On was
Brace, Sight In was Load was Lay the Guns, Range Finding was Range, and a card
called Hold Fast sat beside a different card called Hold Fast. The check found
two more the first time it ran.

The fingerprint is **every field but five**, by reflection rather than a hand
written list. Excluded: `name` (the thing under test), `copies` and `rarity`
(the same card at two grades is still one card), `lane` (a label), and
`source_rarity` (stamped on at grant time by whatever part handed it over).

### The near misses, printed and not failed

    one verb, block:   Chaff, Deflect, Hold Fast
    one verb, lock_on: Range, Bore Sight, Flare

A card that does exactly one thing has nothing but its number to tell it apart
from the next card that does that one thing, and that is the family every
duplicate so far has come out of. Different numbers make them legitimately
different cards, so this cannot be a gate — but three under one verb is worth a
look, and it is how Range was caught costing Korvan's own Bore Sight its reason
to exist.

---

## §8 A card is never named after a keyword

**Gate**, both forms:

    ok  no card is named after a keyword
    ok  no card repeats its own name in its effect

A keyword is the **rule**; a card is a **thing** that uses it. The shared brace
card is called Bolt On and not Brace for exactly this reason, and that comment
held for one card until something checked the rest — at which point Lock On,
Evoke, Launch Drone and Wasp Screen all walked in. The last two were the effect
line with the number taken off:

    Launch Drone  —  Launch drone 3.

A card whose name is its effect tells a player nothing they could not read off
the corner, and it costs the glossary its referent: "lock on" ends up meaning
both a mechanic and one piece of Korvan hardware.

**Two of those four were the keyword's fault.** "Wasp screen" was Cygnet's own
flavour standing in for a mechanic any house could have. A keyword has to be
house-neutral, so it prints "Screen drone" now and Wasp Screen keeps its name.
When a card and a keyword collide, ask which one is wearing the other's clothes.

The glossary the check tests against is **collected from the cards** —
`CardData.keywords()` is the only place a keyword is defined, and asking every
card in the game what it explains is the only version of this that survives a
keyword added next month. Its one blind spot is a keyword no card uses yet,
which cannot collide with anything until a card uses it.

---

## §9 The grade ladder

`ModuleData.Rarity`, and two colours per grade, not one.

| Grade | Colour | Notes |
| --- | --- | --- |
| Common | `#98a0a8` | Near-neutral grey. The grade with no colour, because it has no claim. |
| Uncommon | `#4fbf82` | |
| Rare | `#6a9ad4` | |
| Epic | `#8b4fd4` | |
| Legendary | `#d99b29` | |
| Exotic | `#e05fa8` | Grown. Unbranded only. |
| Artifact | `#e0402e` | Precursor. Unbranded only. |
| Contraband | `#05070a` | Black. **No parts yet** — see below. |

**`rarity_colour()` is the plate's ground; `rarity_ink()` is what the name is
written in.** They are the same for seven grades and different for Contraband,
whose black is darker than the screen — a contraband plate has no visible
ground, only a bone edge. Those looked like one job only while every grade was a
mid-tone.

**Gate:** every ink clears 3.0:1 on the void, and every one of the 56
house-by-grade pairings clears 3.0:1 for art on ground.

### Reading a grade off a plate

A grade is read off a 30-pixel rectangle, not off a word. The ground is the
colour mixed `ModuleIcon.GROUND` of the way into the void — **0.82**, pulled
back from 0.88 because at 0.88 the whole ladder was squashed into a band 22
CIELAB units wide and the closest pair of plates sat at 2.5, against a
just-noticeable difference of 2.3. Two grades were, to an eye, one grade.

The ceiling is **Verity's `#8a7340`**, the darkest house colour, against a green
ground. Nothing else binds. Brightening that one colour is what would buy real
room; 0.80 is the most the current colours allow and clears the floor by three
hundredths.

### Contraband: a ruling, not yet built

Contraband is the one grade that is a fact about **who sold you the thing**
rather than how well it was made. It comes only from **the Probate Combine,
Redline and Cygnet** — the scrappers, the hackers and the technologists, the
three houses with a reason to move something off the manifest.

Not implemented. `LootGen` currently gates `rarity >= EXOTIC` behind
`allow_unbranded`, which swallows Contraband along with Exotic and Artifact —
that filter needs saying differently before the first contraband part exists, or
it will drop from wrecks like a precursor relic.

---

## §10 Malfunctions are not modules

They live in `Database.MALFUNCTIONS`, sixteen of them, and nothing grants them.
A module that made a malfunction was a bug once — a dead `dross` module nothing
could hand out, which also made the content counter report one malfunction when
there were sixteen.

A malfunction arrives unasked, costs a hand slot, and charges you **at the end
of your turn**. That timing is the design: a card that hurt you on the draw is a
tax you cannot see coming and cannot answer, because it has happened by the time
you know about it. Charged at the end, the same card is a question — you are
holding something that will cost you, and you have a turn to find a way to throw
it away.

Three keywords, and they combine:

| Keyword | What it does |
| --- | --- |
| **Corrode N** | N damage at end of turn, while it is still in hand. |
| **Smoulder N** | N heat at end of turn, while it is still in hand. |
| **Fused** | Not discarded at end of turn. Discarding works; it costs you a card. |

Fused is the only one that **compounds** — everything else charges once and goes
with the hand. Answered by the discard verbs, and permanently by
`SYSTEM REPAIR` at a station, which removes one malfunction of the player's
choice.

---

## §11 Shape

Sizes are stored **width × height**, so a "1×2" in conversation is `2×1` in the
data. Parts rotate in the hold, so orientation is the player's choice and only
the shape is fixed.

Holds are 4×3 (light, 12), 5×4 (medium, 20) and 6×5 (heavy, 30).

**Gate:** every part fits the smallest hold. A 5-wide part could never be picked
up by anyone flying a light and would fail by being silently left behind at
every wreck.

A 4×1 fills an entire row of a light's twelve cells and does not fit at all
stood upright. That is a real decision rather than a side effect: it makes the
longest guns something a light frame pays dearly to carry.

---

## §12 The loop

1. Write parts in `Database.gd`.
2. `godot --headless --path tkg -- holdtest` — every gate in this document.
3. `godot --headless --path tkg -- content` — the shortfall, per house.
4. `godot --headless --path tkg -- content json` — the export.
5. `node tkg/tools/manifest.mjs out.html` — the Yard Manifest.
6. Publish `out.html` as an artifact and read the catalogue.

**Step 6 is not decoration.** Every duplicate found so far was found by a person
looking at a list where the cards sat next to each other; the manifest sorts
every card by *effect* rather than by name for exactly that reason. Two cards
that do the same thing end up adjacent instead of eleven screens apart.

The manifest is **generated, never typed**. A hand-copied catalogue is wrong the
day after it is copied, and a stale one is worse than none — the version that
still listed Range Finding cost a review that found two problems already fixed
and one card that had never shipped. It also runs the duplicate check itself
rather than quoting holdtest's verdict, because two implementations of one rule
disagreeing is information and a page repeating what the test said is not.

Standing artifact: **Yard Manifest**, republished in place each time.

---

## §13 Where it stands

    korvan          19 parts   30 cards   want 40   short 10
    (unbranded)     13         12         want 20   short  8
    solari           6          6         want 40   short 34
    probate          6          6         want 40   short 34
    redline          6          6         want 40   short 34
    cygnet           4          4         want 40   short 36
    verity           5          5         want 40   short 35
    calyx            4          4         want 40   short 36
    malfunctions     -         16         want 15   done

    73 unique cards across 63 modules; 227 still to write

A card counts toward the first house that uses it, so the eight shared cards are
counted once. Both `-- content` and the manifest do it that way; two answers to
one question is how a number stops being believed.

The six untouched houses are the work: 209 cards, and 97% of their parts are
still pairs.
