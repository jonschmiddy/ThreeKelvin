The reasoning behind `tkg/scripts/data/CardData.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Heal scale

Above `@export var heal_scale: int = 0`:

```text
+1 hull healed for every N hull you are MISSING. Zero for a flat repair.

THE LIFELINE DIAL, and the reason it exists rather than a bigger flat number.

A flat heal is priced for the turn you play it on, which means it is priced
for a healthy turn — and the turn that actually needs it is three hull and one
energy, where a card that costs two is not a card at all. Raising the flat
number instead fixes that turn by also handing free value to every turn that
did not need it, which is how a repair card becomes a power creep card.

Scaling on what is MISSING solves both ends at once. At full hull these cards
are nearly dead weight, so nothing is inflated. At three hull they are the
biggest thing in the deck. The card is worth exactly as much as the trouble
you are in, which is what a lifeline is.

It also sharpens the greed clock rather than blunting it, and that ordering
matters: `design-doc.md`'s third pillar says deaths are self-authored — you
went one jump too far. An out does not remove that. It means you go one jump
FURTHER because you have one, and then die there. A player who never had the
option was stopped by arithmetic; a player who spent it and pushed anyway
authored the death, which is the pillar working rather than bending.
```

## Junk charging

Above `@export var hand_damage: int = 0`:

```text
Junk you are still holding when the turn ends.

AT THE END OF THE TURN, not when it is drawn. A card that hurt you on the
draw is a tax you cannot see coming and cannot answer — it has happened by
the time you know about it. Charged at the end, the same card is a QUESTION:
you are holding something that will cost you, you have a turn to find a way
to throw it away, and the discard verbs below are the answer. Same numbers,
and the difference between a punishment and a decision.

Every unplayed card is discarded at end of turn anyway, so "still in hand"
means every malfunction you drew and could not get rid of.
CORRODE and SMOULDER, as they read on a card.
```

## Fused

Above `@export var fused: bool = false`:

```text
FUSED. Not discarded at the end of your turn — it stays in your hand until
you get rid of it, and discarding works, it just costs you a card.

The only malfunction keyword that COMPOUNDS. Everything else charges you once
and goes with the hand; a fused card charges you again every turn you leave
it there, and it is holding a hand slot the whole time.
```

## Discard and decommission

Above `@export var discard: int = 0`:

```text
GETTING RID OF THINGS. Two verbs, because they are two different sizes of
decision.

DISCARD is the ordinary one: you pick, it goes to the discard pile, and it is
back in the deck the moment that pile reshuffles. `discard_hand` is the same
verb at the scale of a whole hand and pairs with `draw` — a real cost,
because it throws away what you wanted too.

DECOMMISSION is the expensive one: the card is off the books for the rest of
the fight. Against junk that is the whole difference, because a discarded
malfunction comes back and a decommissioned one does not. The word is the
setting's own register — this is a universe of filings, riders and invoices,
and a part struck off the register is exactly what has happened.

`self_decommission` is a card that takes ITSELF off the books when played,
which is how a card earns the right to be much stronger than its cost.
```

## Card type

Above `func type_name() -> String:`:

```text
What KIND of card this is, derived rather than authored.

Type is carried by structure on the card face — a charge pip track, a
persists tag, a negative heat pip — never by colour, which belongs to the
manufacturer. Deriving it means a card cannot be drawn as one type and
resolve as another: the pips appear because charge_turns is set, and
charge_turns is what CardResolver reads.
Three types, not six.

Attack, Skill, Malfunction. The earlier roster split Defend, Charge, Drone
and Utility into types of their own, which confused two different questions:
what a card IS in the rules, and what it happens to do. Charge is not a type
— a charged slug is an ATTACK that banks a turn first. A drone that deals
damage is an attack; one that only screens is a skill.

Nothing is lost by collapsing them, because the behaviours never lived on
the type line anyway. They live in STRUCTURE — the charge pip track, the
negative heat pip, the art silhouette — and structure is where a player reads
them at 96px. See glyph_kind(), which still tells all six apart.
```

## Glyph kind

Above `func glyph_kind() -> StringName:`:

```text
What the art window draws. Finer than the type, on purpose: the type line
answers "how do the rules treat this", the silhouette answers "what does it
do", and those are different questions with different right answers.
What the art window draws.

THE VERB, NOT THE TYPE, and it used to be the type. There were five kinds —
attack, defend, charge, drone, utility — and the type line prints the same
answer one row below the picture, so the largest element on the card was also
the most redundant thing on it. Suppressing Fire, Full Auto, Ripple Fire,
Drumfire and Siege Round drew one identical round; Brace, Bulwark, Sink Plate,
Dig In and Bulkhead drew one identical plate. A hand of eight was two pictures.

So this answers "what does playing it DO" instead, which is the question a
player is actually asking when they look at a card they cannot yet read.

PRIORITY IS THE HEADLINE, and it is why this is a ladder rather than a set of
flags. Dig In braces, blocks AND vents; the picture has to pick one, and the
one it picks is the thing you played the card for. Defence outranks the vent
that came with it, an attack outranks the draw stapled to it, and the two
kinds that change how a card is USED rather than what it does — a charge that
fires later, a drone that fires without you — outrank everything, because
getting those wrong costs you a turn.

Shape, never colour. Colour is the manufacturer channel and the two must never
share an encoding, so every one of these reads for a colourblind player.
```

## Base glyph

Above `var base_glyph: StringName = &""`:

```text
What this card's picture was before any affix touched it.

THE HAZARD THIS GUARDED AGAINST IS GONE, and the field is kept anyway. Affixes
used to mutate card fields — `resolved_cards()` called `AffixData.apply_to()`
on a duplicate — so a rolled part handed out cards with properties their
designer never gave them, and the ladder in glyph_kind() then drew the AFFIX
instead of the card. A Lock On that rolled Grafted stopped being a reticle and
became a weld; a Brace Frame that rolled Overbored drew a round. The picture
is supposed to say what a card is FOR, and +2 damage on a plate is not what
the plate is for.

Affixes now pay in ship attributes and never touch a card, so a card's picture
can no longer be hijacked. What remains is the rule that produced the right
answer anyway: the glyph is decided once, on the base card. Empty on a card
nothing has resolved — the gallery and the tests build cards directly — and
glyph_kind() falls through to computing it, which is the same answer.
```

## Card art

Above `@export var art: StringName = &""`:

```text
WHICH ILLUSTRATION this card shows, without the folder or the extension.

Empty is the ordinary case: `art_key()` then slugs the card's own name, so a
card called "Scored Barrel" looks for `scored_barrel.png` and no entry has to
be written for it. Seventy-six cards times one bookkeeping line each is the
kind of edit that goes wrong quietly, and the name is already the identity a
player uses.

Set it when the file cannot follow the name: two cards that should share one
picture, or a card whose name changes and whose art should not be orphaned by
the rename.
```

Above `func art_key() -> StringName:`:

```text
The file this card's illustration lives under, name-derived unless overridden.

Lowercased, spaces and punctuation to underscores, runs collapsed. Written
once here rather than at each call site, because a slug rule that exists in
two places is a slug rule that disagrees with itself the first time a card is
named with a hyphen.
```

## Resolved sprite

Above `@export var sprite: Texture2D`:

```text
THE RESOLVED ILLUSTRATION, looked up ONCE when the catalogue is built.

NEVER LOAD THIS FROM INSIDE `_draw`. That is not a style preference, it is
the bug this field exists to prevent: `load()` called during a draw pass
hands back a resource whose CPU image is perfectly correct and whose GPU
texture is not yet bound, so the card paints a SOLID WHITE RECTANGLE of
exactly the right size. Every probe says the texture is fine, because it is
-- it simply is not on the card when the draw command is recorded.

`ModuleData.sprite` was right by accident on both counts: Database assigns it
while building the catalogue, which is nowhere near a frame, and it is
EXPORTED.

Exported matters here as much as the timing. A card is `duplicate()`d on its
way into a deck, and Resource.duplicate copies exported properties and drops
everything else -- so a plain `var` holding the picture survives the
catalogue and is null on every card a player actually holds. The failure is
quiet and looks exactly like "the art did not load".
```

## Shared cards

Above `@export var shared: bool = false`:

```text
FROM THE SHARED VOCABULARY -- see Database.SHARED. A card more than one
module is allowed to grant.

It matters because a shared card must look the SAME wherever it came from.
Range is granted by Ranging Optics, the KX-9 Fire Director, the Signal Board
and the Ranging Scope; the first two are Korvan and sit at different rarities,
so stamping the granting part's identity onto the card produced four Ranges in
the catalogue wearing two manufacturers and three rarity ticks -- for one line of
rules text that is identical in every case. The card is common and unbranded;
the PART it came off is a fact about the part.
```

## Card rarity

Above `@export var rarity: int = -1`:

```text
THIS CARD'S OWN rarity, as a ModuleData.Rarity. -1 means "the module decides",
which is what almost every card wants — see ModuleData.card_rarities for the
law that fills it in.

Separate from `source_rarity`, which is the rarity of the PART it came off. A
legendary bay grants a legendary card and a common one; both have the same
source and only one of them is legendary.
```

## Keyword glossary

Above `const KW_NEGATE := "Negate"`:

```text
The rules words on this card, each with what it actually does.

Lives here, beside the fields it explains, because these two go stale
together or not at all: a keyword whose definition sits in a UI file drifts
from the mechanic the first time somebody tunes the mechanic. Every entry
below was written against Combat.gd rather than from memory — brace really
is charged a heat per turn, feedback really does fire once per attacking
enemy — and if that changes, this is the file already open.

Only the words that need explaining. "Deal 6" explains itself; Salvo does
not.

Two of them are also the names of what they leave on your ship, the fight's
status chips (`SectorScreen._refresh_player`), which read them from here.
```

## Rich description

Above `func describe_rich(live: int = -1,`:

```text
The same line, with every explainable word marked up.

Derived from describe() rather than written beside it: two strings that must
say the same thing are one string with a transform. The terms come from
keywords(), so a word is highlighted if and only if this card can explain it
— there is no list to keep in step, and a keyword that stops applying stops
being underlined on the same edit.

Longest first. "Brace from heat" contains "Brace", and replacing the short
one first would leave markup inside the long one.
`live` is what the card will ACTUALLY throw per hit right now -- see
`Combat.card_output`. -1 means "print what the card was printed with", which
is what every caller outside a fight passes.
`hot` names the clauses that are currently paying -- see `Combat.card_hot`.
They go the same green as the raised damage number, so the clause reads as
THE REASON the number moved rather than as a second sum on top of it.

Without this the face said the same thing twice: a live salvo card printed
"Deal 5 x 2. Salvo +2." where the 5 already contained the +2, which reads as
a promise of two more. Removing the SALVO status chip put the fact on the
card; this stops the card double-counting it.
```

Inside `describe_rich()`, above `if live >= 0 and damage > 0 and live != damage:`:

```text
COLOURED AFTER THE KEYWORDS, not inside `describe`. A number that silently
differs from the one you learned is worse than either number: a player who
knows Charged Slug hits for 8 and sees 12 cannot tell whether the card
changed or they misremembered. Higher reads as a gain, lower as a loss.

Safe in this order because no keyword is "Deal" or a digit, so the clause
survives the replacement above untouched -- checked against `keywords()`,
which is all capitalised game terms.
```

## Describe

Above `func describe(live: int = -1) -> String:`:

```text
Short human-readable effect line for the card face.

`live` overrides the printed damage with what the card will throw per hit
right now. Default -1 prints the card as authored, which is what `BotBoard`
and `AttrTest` want and what everywhere outside combat wants -- in a shop you
are comparing this card against another one, and a figure inflated by a
lock-on you happen to be holding is the wrong answer to that question.
```

## Heal scale text

Inside `describe()`, above `if heal_scale > 0:`:

```text
A WORD PLUS ITS FLOOR, which is the pattern Brace and Salvo already use:
the number on the face is what the card is guaranteed to do and the RULE
lives in the keyword, where there is room to say it properly.

It also has to be spelled this way to work at all. describe_rich() marks
up only the terms this card's own keywords() can explain, by literal
string match — so a face reading "Heal 2 +1 per 4 missing" contains no
keyword, gets no underline, and the rule explaining the whole card is
unreachable from the card. The phrase on the face and the key in
keywords() are one string or the feature does not exist.

Never the number it happens to be worth right now. A printed value that
changes as you take damage is a card you cannot plan around before you
take it.
```
