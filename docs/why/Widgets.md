The reasoning behind `tkg/scripts/ui/Widgets.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Row builders

Above `static func item_row(thing: Variant, ctx: ModuleContext, price: int,`:

```text
A module entry: name, rarity, manufacturer, rolled affixes, and its cards.

`note` is for a row whose action has already been taken by somebody else. It
replaces the button rather than removing it, because a row that loses its
button changes height and the list reflows under the cursor — and because
"MERCER TOOK THIS" is the single most interesting thing the bag has to say.
Empty for every other context, which is all of them but BAG.
A row for whatever is in the hold, whichever kind it is.

THE ONE PLACE THIS IS DECIDED. Three screens iterate `Run.cargo` and build a
row per entry, and every one of them called `module_row` directly -- which was
correct right up until cargo held two kinds of thing, and then failed at the
parameter type on the first crate. A private branch on each screen would be
the same bug waiting on the fourth.
```

Above `static func material_row(m: MaterialData, ctx: ModuleContext, price: int,`:

```text
One material, as a row.

NOT a branch inside `module_row`. That function reads a rarity, a
manufacturer, a slot, an affix list and a card count -- five things a crate of
ore does not have and never will -- so folding materials into it would be
threading nulls through every one of them to save a panel.

What it shares is the SHAPE: same stylebox, same name-and-grade top line, same
button strip on the right, so a bag holding a gun and a crate reads as one
list rather than as two.
```

## Tooltips

Above `const TIP_W := 168`:

```text
How wide a part's tooltip is, always.

Wide enough for the longest affix sentence to take two lines rather than
five, and narrow enough that it does not read as a second panel. A tooltip
that changes shape as you move along a row of mounts reads as four different
panels rather than as one reading four things -- and an affix is a sentence
while a gauge line is three words, so left alone they differ by a factor of
three.
```

Above `static func module_tip_panel(m: ModuleData) -> Control:`:

```text
A part, as a PANEL, for a tooltip.

Godot tooltips are one label of plain text -- no rules, no colour, and no
wrapping either. That was fine while this said a name; it is not fine for a
rolled part, where the grade, the gauges it moved and the affixes it rolled
are three different kinds of fact and reading them as one paragraph is most
of the work.

`_make_custom_tooltip` takes a Control instead, so this builds the same
vocabulary the module panel uses -- grade in its own ink, a rule under the
name, gauges in ICE, affixes in EMBER, cards last -- at tooltip scale.

Deliberately still shorter than `module_panel`. This is read standing over
something else.
```

Above `static func tip(text: String) -> String:`:

```text
Tooltip text, hard-wrapped so every tooltip in the game is the same shape.

The theme gives TooltipPanel its padding and its plate, but Godot still
sizes the panel to whatever the text asks for — so a long line makes a
tooltip most of the viewport wide and a short one makes a sliver. A Label
inside a themed TooltipPanel cannot be handed an autowrap mode from the
theme, so the wrap has to happen in the STRING, before it is assigned.

Breaks on spaces and preserves newlines already in the text, so a tooltip
written as "NAME\nbody" keeps its heading and only the body folds.
```

## Drag payloads

Above `static func dragged_module(data: Variant) -> ModuleData:`:

```text
The ModuleData inside a drag payload, or null for a material, a chit, or
anything else in the air. The one shape for this refusal: a typed assignment
straight off the dictionary RAISES for a non-module payload -- `as` is the
cast that answers null -- and the drop targets had grown two different
idioms for the same question, one of them the raising kind.
```

## Module row

Inside `module_row()`, above `var counts: Dictionary = {}`:

```text
COUNTED, NOT REPEATED. `resolved_cards()` hands back one entry per copy the
Grant Count Law awards, and this printed a hardcoded "×1" for each of them
-- so a module granting two of one card listed that card twice, identically,
directly under a header already saying "grants 2". Three statements of the
same fact, and the only one that was wrong was the ×1.

Grouped on what the row actually SHOWS rather than on card identity: two
cards that print the same line are the same line, and a player counting
copies on a shelf cannot see any difference the display does not draw.
```

Inside `module_row()`, above `var here := deck_size if deck_size >= 0 else DeckBuilder.build().size()`:

```text
Install-time deck delta, at the point of choice.

Deck size is a managed resource and this is the only moment the player can
act on it, so the number moves where they can see it move — the same
philosophy as printing the odds on an event option before they commit.
Without it the Grant Count Law is invisible: you would feel a thickening
deck three fights later and never know which pickup did it.
Passed in, not rebuilt. DeckBuilder.build() deep-duplicates every card on
every installed module and allocates two Snap Shots plus one per Dross —
and this ran ONCE PER ROW, so a station with twenty rows on screen did
twenty full deck builds to answer the same question twenty times. The
callers below already loop, so they compute it once and hand it down.
```

## Layout helpers

Above `static func clear(node: Node) -> void:`:

```text
Empty a container NOW, not at the end of the frame.

queue_free() is DEFERRED. So the common `for c in box.get_children():
c.queue_free()` followed immediately by add_child() leaves the container
holding the old children AND the new ones until the frame ends, and it is
laid out at that doubled size in between.

Usually invisible — a column of text rows is briefly too tall inside a panel
that clips it. It was very visible on the refit screen: that grid is 44px
module icons, it is rebuilt synchronously from the drop handler, and nothing
in the layout clips, so putting a part in the hold splashed a surplus row of
icons across the screen underneath for a frame.

Ten other screens still free deferred this way. They are not known to misdraw;
this is here so the next one written has the right thing to call.
```

Above `static func pad(child: Control = null, h: int = 8, v: int = 6) -> MarginContainer:`:

```text
A child in a margin. The fourth copy of this was written before it became
obvious it wanted to live here.

Four screens had grown a private `_pad()` — LobbyScreen, PartyScreen, and
StationScreen twice, since it needed two margin sizes in one file and had no
way to say so. They differed only in the two numbers, which is the definition
of an argument rather than a fork.

Horizontal first, because it is the one that varies: every caller so far wants
more air at the sides than at the top.
`child` is OPTIONAL, because half the call sites build the margin before they
build what goes in it — they anchor it, set a mouse filter, park it in the
tree, and only then assemble the column. Passing null gives them the same
configured container to fill in later, which is what let the remaining nine
hand-rolled copies come here instead of being restructured around a signature
that only suited the other half.
```

Above `static func panel_with(child: Control) -> PanelContainer:`:

```text
The big rectangles the information screens are built out of.

THE ALPHA IS LOAD-BEARING, and it is here rather than in the theme because
this override is what the theme's own panel stylebox never gets to answer.
The refit bay, the hold and both galleries all come through this
function, and while the fill was solid they covered every pixel of the sky
`SpaceLayer` draws behind them. See UITheme.PANEL_A for why the number is
high.
```

Above `static func cover_picture(c: Control) -> void:`:

```text
A DIM OR A SCRIM OVER THE WHOLE PICTURE, wherever it is parented.

Every screen sits in Main's content area, which is the picture less an 8 x 7
px margin (and the HUD's row, when there is one), so a dim anchored to its
screen stopped that far short of the edges. The title screen's galaxy runs on
past its own rect to the glass, so it showed through the margin undimmed: a
lighter frame round every popup on the title, which read as a dark box
behind it (Jon, Oct 20, on his welcome note: "a weird dark box around the
background ... in the corners and side of the screen"). The escape menu has
no margin to miss, being on Main's overlay layer. This pins `c` to the
viewport's rect and keeps it there as its parent or the window changes; only
the drawn rect grows, so anything laid out on `c` itself is not a pixel off.
```

## Card readout

Above `static func card_readout(c: CardData) -> PanelContainer:`:

```text
Name, what it is, where it came from, and what its rules words mean.

Shared by the card gallery and by combat. A keyword you can only look up on a
development screen is a keyword the player has to have memorised, which is
the exact thing a glossary exists to prevent.

Deliberately NOT a field dump. An earlier version printed every non-default
property on the card, which was self-maintaining and useless: it told you
`feedback: 4` when what you needed was what feedback does. The numbers are
already on the card face — this panel exists for the things the card has no
room to say.
```

Inside `card_readout()`, above `var mod: ModuleData = DB.modules.get(c.source_id)`:

```text
The two NAMES first, then the two CLASSIFICATIONS. What the card is called
and what granted it are the pair you are looking for; type, rarity, manufacturer
and slot are all the same kind of fact and belong together underneath,
rather than interleaved so that the eye crosses a category line twice.
Two pairs. What the CARD is — its verb and its class — then where it came
FROM — the manufacturer and the module. Each pair is a name over its
classification, and the two questions never interleave.
```

Inside `card_readout()`, above `if mod != null and mod.flavour != "":`:

```text
The quote last, in its own section.

It was sitting with the module's name and slot, where it read as another
specification — and flavour next to specifications always loses, because
the eye is scanning for facts and finds a sentence in the middle of them.
At the bottom, after the rules are answered, it is the thing you read once
you have finished needing the panel.
```

Inside `card_readout()`, above `var fl := UITheme.body("\"%s\"" % mod.flavour, UITheme.QUOTE, UITheme.FS_SMALL)`:

```text
Silkscreen at 8, like everything else — the grey is the whole signal.

A second typeface was tried for this and it was the wrong tool. At
this resolution a different face does not read as a different VOICE,
it reads as a different UI, because there is not enough letterform
left at 8px for character to survive. Colour still works perfectly
well down here, and it costs no asset, no licence and no size guess.
```

## Ability rows

Above `static func ability_row(at: String, title: String, text: String, accent: Color,`:

```text
One manufacturer ability: what it costs, what it is called, what it does.

Shared by the chassis select and the refit screen, because they are asking
the same question at two different moments — "what would flying this manufacturer
give me" and "how close am I now" — and two copies of the row would drift the
first time either one was reworded.

The condition column says it in full ("3+ KORVAN") rather than a bare "3+",
which leaves you to work out three of what. The hull perk shares that column
with "BUILT IN": the other two name what you must collect, so this one names
where it already is.

Locked rows are dimmed rather than hidden. What a manufacturer is FOR is
mostly what it does at 3 and 5 parts, so hiding those until you get there
would hide the reason to chase them — greying says "later", which is the
actual state.
`count` is the progress column — "2 / 3" — and it is why the set chips are
gone from the hardpoints header. A chip reading "KORVAN 2" told you what you
have and left you to remember what you need; the number belongs on the row
that states the thing it unlocks.
```

Inside `ability_rows()`, above `var short := DB.short_name(m.name).to_upper()`:

```text
THE PERK ROW IS GONE FROM HERE. It is named in the masthead's top-right
corner now, with its effect on hover — and a hull can carry four of them,
so four full-width rows of always-on fact would have crowded out the two
rows that are actually a TRACKER. What is left in this block is only
progress: what you have not earned yet and how close you are.

`perk_id` stays in the signature. Every caller has one, the argument costs
nothing, and a block about a manufacturer that cannot see the hull's perk
is the wrong shape to hand the next person.
```

## Manufacturer readout

Above `static func manufacturer_readout(id: StringName) -> VBoxContainer:`:

```text
WHO HOLDS THIS BERTH, on hovering their flag.

A BANNER IS THE ONE MARK IN THIS GAME THAT CARRIES NO WORDS. It is a colour
and a hem, and a player who has not yet learned that the teal one is Cygnet
is looking at a decoration. Every other identifier on these screens says its
own name; this one could only be looked up on the chassis screen, which you
see once at the start of a run and never again.

Built like `perk_readout` and for the same reasons: no plate of its own, the
strings wrapped by `tip()` rather than by a label, and the manufacturer's own
colour on the name alone. The set bonuses come last and carry a live count
when there is a run to count -- at a station the flag is a BERTH, so what you
want to know standing under it is who they are and how close their kit is to
paying out on your ship.
```

Inside `manufacturer_readout()`, above `box.add_child(UITheme.hsep())`:

```text
THE BACKSTORY IS NOT IN HERE. It is three or four sentences of prose per
manufacturer -- `ChassisSelect` gives it a column to itself and still had
to be trimmed to fit. Wrapped at TOOLTIP_WRAP it would be a fourteen-line
panel hanging off a flag, and a tooltip that has to be READ is one nobody
reads. What is here is the identity line, which is the same paragraph's
job done in one sentence.
```

## Module readout

Above `static func module_readout(m: ModuleData, width: float = 0.0) -> PanelContainer:`:

```text
THE MODULE'S OWN PANEL, built like card_readout so a part and a card look
like two things from the same game.

It carries what a part IS and nothing about what its cards DO, because the
cards are drawn beside it — see ModuleIcon._make_custom_tooltip. A panel that
also spelled out the effects would be describing the two objects sitting
right next to it, which is how the module gallery ended up with three copies
of the same facts before the readout panel was deleted.

Same left border in the manufacturer colour, same width, same order of facts: what
it is called, then what class of thing it is, then the flavour last. Flavour
next to specifications always loses — the eye is scanning for facts and finds
a sentence in the middle of them.
`width` FIXES the box rather than merely floors it.

custom_minimum_size is a minimum, so a long name pushed the panel wider
than a card and every row in a column of these started at a different
place — a KH-20 Chatterbox against a Mining Laser was 40px of difference.
Passing a width clamps it too and lets the text wrap inside instead.
```

Inside `module_readout()`, above `var gauges: Array = []`:

```text
WHAT IT DOES TO THE SHIP, which is the half of a part that is not cards and
which nothing showed until the tooltip was rewritten. A legendary carrying
three pips of hull said nothing about them anywhere.
ZERO IS NOT PRINTED, reversing the ruling that used to sit here. That
ruling was that "HULL +0" on a common plate keeps the LADDER legible — it
says the part is on the hull axis and simply pays nothing at this grade,
where a part with no axis at all says nothing. True, and it cost more than
it bought: ATTR_BUMP is [0, 0, 1, ...], so EVERY common and EVERY uncommon
part in the game printed a line that reads as a fact about the part and
means "not yet". Two thirds of the catalogue wearing a +0.

WHAT THIS GIVES UP, stated because it will be rediscovered otherwise: a
common plate and a Ripsaw now read identically in this box, and the only
way to tell that one is on the hull ladder is to find a better one. The
manifest still prints its +0 and draws it dashed, so the information is
not gone from the project, only from the hover.
```

Inside `module_readout()`, above `for a in m.affixes:`:

```text
WRAPPED, AND CAPPED AT THE SAME WIDTH THE FLAVOUR ALREADY USES.

Nothing else in this panel is long: a gauge line is "THERMAL +2" and a
manufacturer is three words. An affix is a sentence -- "STRIPPED - +2
MANEUVER, -1 HULL" -- and a Label with no wrap is as wide as its longest
line, so ONE rolled affix decided the width of the whole panel and a part
with three of them threw it across the screen.

The cap was already sitting eight lines below, on the flavour. This is the
same number for the same reason.
```

## Perk tooltip

Above `static func set_tip(id: StringName, have: int, fitted: int) -> String:`:

```text
Every perk on a hull, in ONE tooltip, grouped by where it came from.

Four perks used to mean four separate hovers, and no hover said whether what
you were reading was a fact about the MANUFACTURER — carried by every hull
they build, at every grade — or a fact about this hull's GRADE. Those are
different things to know: one survives swapping chassis within the manufacturer,
the other is precisely what upgrading bought.

THE EMPTY CASE IS PRINTED. A C-class hull has no grade perks, and a tooltip
that then shows only one section reads as a hull whose perks failed to load.
Saying "none, and B/A/S each add one more" turns the same blank into the
ladder explaining itself — which is the one moment a player is looking
straight at the thing an upgrade would change.
WHAT A SET CHIP SAYS ON HOVER. Both tiers, always, each marked with whether
it is running.

BOTH, because a set bonus does not replace the one below it -- `has_set(id, 3)`
and `has_set(id, 5)` are independent thresholds, so a ship at five is running
Standard Issue AND Full Broadside. Naming only the higher one hid a bonus that
was still applying; naming only the lower one hid the thing being worked
toward. There are exactly two, so there is no reason to show one.

THE HULL'S SHARE IS NAMED. `Run.manufacturer_count` includes the hull, so a
player who fitted one part and sees two pips is owed the reason in the same
breath as the count.
```

Above `static func set_readout(id: StringName, have: int, fitted: int) -> VBoxContainer:`:

```text
How wide the perk tooltip is. Named because two things need to agree on it:
the panel, and the wrapped label inside it that would otherwise have no width
to wrap against.
The same perks as a PANEL, which is what actually shows on hover.

`perk_tip` above is the plain-text fallback and the trigger string; this is
the content. Built like `module_readout` and deliberately so — the border in
the manufacturer's colour, the flat plate, the small type — because a tooltip
that looks like the rest of the game reads as part of it, and one assembled
out of default labels reads as debug output that shipped.

TWO GROUPS, AND THE HEADINGS CARRY THE COLOUR. Which perk came from the
manufacturer and which from the grade is the thing the old per-label tooltips
could not say at all. The manufacturer's own is on every hull they build, at
every grade, and survives swapping chassis inside the same manufacturer; the
grade's are exactly what the upgrade bought, and are lost dropping back down.
THE SET-BONUS PANEL a chip shows on hover.

Built the way `perk_readout` is, and for the reasons written on it: NO PLATE
OF ITS OWN, because Godot already wraps this in the tooltip's own panel and a
PanelContainer here is two plates stacked; and every body string goes through
`tip()`, because an autowrapping Label measures its height off a width it has
not been given yet and the panel comes out three times too tall.

STATE IS COLOUR, NOT A COLUMN. The first version padded "ON" and "2 MORE" into
an aligned gutter, which made a seven-line block of ragged monospace out of
two sentences. A live bonus is EMBER like a perk; a locked one is QUOTE, with
what it still costs on the right of its own row.
```

Inside `perk_readout()`, above `var accent := DB.manufacturer_colour(h.manufacturer)`:

```text
NO PLATE OF ITS OWN, and that is the whole of looking like the other
tooltips. Godot wraps whatever `_make_custom_tooltip` returns in a
PopupPanel styled as TooltipPanel -- `bevel(PANEL2)`, with content margins
already set -- so a PanelContainer here meant TWO plates: a darker
rectangle sitting inset inside the lighter tooltip, with both paddings
stacked. Removing the inner BORDER did not help, because the inner PLATE
was the thing being seen.

Every plain tooltip in the game is a Label on the theme's plate. This is
that, with more rows. It also means the width comes from the same place
theirs does -- `tip()` wrapping at TOOLTIP_WRAP -- so it sits in the same
family of rectangles rather than being its own size.
```

Inside `_perk_rows()`, above `var body := UITheme.body(tip(str(pd.text)), UITheme.COLD, UITheme.FS_SMALL)`:

```text
WRAPPED IN THE STRING, NOT BY THE LABEL, and that is the whole fix for a
tooltip that reached the bottom of the screen. An autowrapping Label
reports its minimum HEIGHT from its current WIDTH -- and a tooltip is
measured the instant it is built, before any container has handed it one.
Measured: this panel asked for 309 rows off-tree and settled at 168 once
laid out, and it is the first number a tooltip believes.

A `custom_minimum_size.x` on the label is not enough either; that was tried
and it still came out at 309. `tip()` above already carries this same
finding for the plain tooltips -- "the wrap has to happen in the STRING"
-- so this uses it, and the label then measures the same on-tree and off.
```

## What an augmented part says

Above `const AUGMENTED_TEXT := "AUGMENTED. The Lab can't add to it again."`:

```text
WHAT AN AUGMENTED PART SAYS, in every box that describes a part: the hover
popup (`module_readout`), the hull's tip (`module_tip_panel`) and the old
list row (`module_row`). One string, so the three cannot drift.

It names the rule and not the affix. The mark is a bool (ModuleData.augmented),
so which line the Lab wrote is not known, and the part reads it in the affix
list above anyway. What the player cannot see anywhere else is that the Lab
is done with this part. STRIP still works on it, so it says "add", not "change".
```
