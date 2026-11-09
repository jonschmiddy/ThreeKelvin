The reasoning behind `tkg/scripts/ui/StationScreen.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Station overview

Above `var _header: RichTextLabel`:

```text
Stations are paid campfires. Every service costs credits, and credits are the same
currency you would rather spend on modules — that tension IS the difficulty.

A station is five decks: a shelf, a service desk, a BUYER for what is in
your hold, a hiring board, and a laboratory, where DATA buys the run's
routines (`Science`) and the bench turns film and relics into DATA or a part
(`Fabricator`). Every price on the screen comes from `Market`, `Fabricator`
or `Science`, and none of them is stored: a price is a function of this place
and that part, so there is nothing here to drift, to save, or to come back
from a save as a discount.
```

## Five decks everywhere

Above `var _tabs_on: Dictionary = {}`:

```text
Which tabs this station actually has. Every station has all five since Jon's
Nov 3 ruling (a lab at every level, a dock desk where no manufacturer
berths), so today this is all on; the switch stays for a deck that ever
needs to go.
```

Inside `_refresh_bench()`, above `_enable_tab(&"bench", true)`:

```text
EVERY STATION HAS ITS LABORATORY (Jon, Nov 3: all five decks at every
station, at every level). The tab used to go below a city, where no recipe
was open; RELIC ANALYSIS is dev 0 now, priced by the level.
```

Inside `_refresh_work()`, above `_enable_tab(&"work", true)`:

```text
EVERY STATION HAS ITS HIRING BOARD (Jon, Nov 3: all five decks at every
station). The tab used to go at a station with no manufacturer behind it;
such a station posts for its dock desk now (`Contracts.dock_desk`). A board can
still come up bare, with no ordinary system in reach to send you to or every
offer signed and done, and then it says so on a note of its own (below).
```

## Hull portrait height

Above `func setup() -> void:`:

```text
How tall the hull portrait is. Enough for a heavy at 2x without the panel
growing past the service column beside it.
Sized off the deepest hull plus the bob, at 1x. See ShipScreen for why the
magnification came down. 140 rows of heavy canvas and the bob's four: the
heavy grew from 100 rows when the hull art was redrawn, and this number is
derived from it rather than chosen, so it moves whenever that does.

WITH SIX ROWS OF SLACK, matching ShipScreen. The bare derivation is 144 -- the
heavy's 140-row canvas plus the bob's four -- and at exactly 144 this sits on
a knife edge: `ShipView._resize_canvas` sets `clip_contents` when the canvas
is TALLER than the view, so any hull one row deeper, or one call asking for a
bob of three, starts clipping the ship's top and bottom rows as it bobs. Rows
winking in and out at the edges of a moving sprite is not a loud failure; it
reads as the ship shimmering.
```

## Five pages

Above `const TABS := [`:

```text
FIVE PAGES, NOT FIVE PANELS STACKED.

A station does five things — repair you, post work, sell you parts, buy what
you are carrying, and build things where there is a laboratory — and all five
were on screen at once in one scrolling column. At a developed station that is
a service desk, two contracts, four shelf parts, twelve hold slots and a
recipe list, and the player has to scroll past the thing they came in for.

Tabs, because these are five separate ERRANDS rather than five parts of one.
Nobody buys a gun and sells a plate in the same gesture; they do one, then
decide. A column implies a reading order that does not exist.

Every page is built once and hidden, not built on demand: the shelf has to be
able to empty while you are looking at the hold — `Sig.party_map_changed`
fires when a partner buys something — and a page that only exists while it is
visible cannot be refreshed when it is not.
```

## Decks as a building

Above `const DECKS := [`:

```text
THE SAME FIVE ERRANDS, DRAWN AS A BUILDING RATHER THAN A TAB STRIP.

A row of five identical buttons says these are five views of one thing. They
are not: they are five different counters, and the tab strip's real cost is
that it hides four fifths of the station behind whichever one you are on --
you cannot see that there is work posted while you are looking at the shelf.

Stacked as DECKS the strip becomes a section through the station, which does
three things a row cannot. It is always fully visible, so nothing is hidden.
It has room for a second line, so each deck can say what is on it and how
much. And it puts your own berth at the bottom of the stack with your ship in
it, which is the one fact the old screen never showed: you are inside a place
and the place has a shape.

ORDERED HIGH TO LOW, berth last. The order is not arbitrary and is not the
TABS order: a player reads the rail downward and arrives at their own ship,
which is where UNDOCK belongs.
```

## Header and undock

Inside `_build()`, above `_header = RichTextLabel.new()`:

```text
--- the header, and the way out.

UNDOCK is a button on this line rather than a panel of its own on a column
of its own. It was three hundred pixels wide inside a three-hundred-pixel
rail, for a control that is pressed once and is never the reason anybody
opened this screen. Leaving is not an errand.
```

## Header wrapping

Inside `_build()`, above `_header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART`:

```text
WRAPS, AT A WIDTH THIS SCREEN CHOOSES.

Both obvious settings are wrong here and they are wrong in opposite
directions. Autowrap ON inside a shrinking panel collapses to the narrowest
legal width and stacks the line into a column. Autowrap OFF reports the
WHOLE UNWRAPPED LINE as a minimum width -- and a Control is never laid out
smaller than its minimum, even when anchored -- so the header grew the
entire screen to 983 inside a 960 window and every panel on it hung off the
right edge. The symptom looked exactly like a missing margin.

A fixed width and wrapping is the only combination that is neither.
```

## Rail flags

Inside `_build()`, above `var rail := VBoxContainer.new()`:

```text
--- WHOSE YARD THIS IS, at the top of the rail.

It was a panel of its own across the full width, and it was mostly air: a
flag is 39x66 and the two lines of text beside it are 24, so eighty of the
hundred and ten pixels that band cost were empty. The rail is already the
column that says where you are standing -- the flag belongs at the head of
it, over the decks it holds, and the sentence about the place goes on one
line above the page it describes.

The FLAG rather than the badge, because this is a place and not a listing:
the chassis list badges seven manufacturers you are choosing between, and
this is the one you are inside of.

ONE BANNER PER BERTH, not one for the station. A contested station is held
by two or three manufacturers, and the header named all of them in a trade
clause while the rail flew one flag -- so the screen said "GLUT
SOLARI/CYGNET/KORVAN" and showed a single Solari banner. Flags say it
without a sentence.

--- the section: the berths, five decks and a berth, down the left
```

## Rail particulars

Inside `_build()`, above `rail.add_child(_header)`:

```text
THE STATION'S PARTICULARS, WHERE THE BANNERS WERE.

The head of the rail held the manufacturers' banners, and the particulars sat
in a band across the top of the deck. The banners are in the rooms now --
hung in the hangar, pinned to the board, over the till -- so the facts about
the place move up here, one to a line, and the deck gets its band back.
```

## Decks as floors

Inside `_build()`, above `var shaft := Control.new()`:

```text
--- THE DECKS ARE FLOORS OF ONE BUILDING.

They were five buttons in a column, which tells you which page you are on.
A cutaway tells you where you are STANDING, costs the same vertical, and is
the only one of the two that makes the station a place. The cells sit OVER
the drawing with their plates taken off, so the room shows through and the
labels stay on top of it.

The berth that used to close this column is gone. It drew your own ship at
the bottom of a rail whose whole subject is the station you are standing
in, and it was the second place on the screen the hull appeared. What it
was using is ninety pixels, and the floors have them now: five rooms at
sixty-odd rows each instead of five slivers at forty-six.
A LIFT SHAFT: the window clips, and the building inside it is TALLER than
the window and slides. Picking a deck moves the station, not a highlight.

The overflow is deliberately small -- see `FLOOR_H`. A building that
scrolled far enough to hide a floor would be a navigation bar you cannot
navigate with: every deck has to stay clickable at every scroll position,
so the travel is forty pixels and the worst-clipped floor still shows half
of itself.
```

## Building sizing

Inside `_build()`, above `_building = Control.new()`:

```text
SIZED IN A CALLBACK WITH A GUARD, not by anchors. An early version ran the
sizing before the shaft had a size and got five floors sharing zero height
-- three rendered and two vanished. The guard is the whole fix: nothing is
sized until the shaft has been.
```

## Undock cell

Inside `_build()`, above `rail.add_child(_undock_cell())`:

```text
The berth is the bottom of the section, and UNDOCK lives in it.

It used to sit in the tab row, grouped left, because pinned to the right of
an expanding row it was at the mercy of the window width -- on a 960
screenshot it came back sliced in half. In a fixed-width rail that failure
cannot happen: the column is RAIL_W whatever the window does, so the button
can go where it belongs instead of where it is safe.
NO SPACER. There was one here, pushing UNDOCK to the floor of a column
whose other children were all fixed height. The building expands now, so
the button is already at the bottom -- and an expanding spacer beside an
expanding building is two things splitting the slack down the middle,
which is exactly what it did: the station got 178 pixels of 362 and read
as a cutaway that had been cropped.
THE WAY OUT, and nothing else. `_berth_cell` used to hand back a panel with
your ship in it and this button under it; the panel is gone and the button
is not, because leaving is still a thing you do from here.
```

Above `func _undock_cell() -> Control:`:

```text
The bottom of the rail: the way out, and nothing else.

This used to draw your own ship in a berth above the button. It went for two
reasons -- the rail is a cutaway of the STATION now and a picture of your hull
is not a floor of it, and the hull was already on screen on the Yard whenever
there was anything to compare it against.
```

Inside `_undock_cell()`, above `out.size_flags_vertical = Control.SIZE_SHRINK_END`:

```text
SHRINK, NOT EXPAND. `_commit_button` hands back a control that takes the
slack -- which is right where it is one of two things in a row and wrong
here, because the other thing in this column is the STATION. The two of
them split the rail down the middle and the building got 178 pixels of a
347-pixel column, which looked like the cutaway had been cropped when what
had happened is that a button was as tall as five floors.
```

## Page header line

Inside `_build()`, above `var body := Control.new()`:

```text
ONE LINE, NOT TWO ENDS OF ONE. What this market is short of used to be its
own amber label pinned to the right-hand edge, half a screen from the
sentence it belongs to -- and read as the station's name rather than as a
price signal. It is a clause of the same sentence now, in the same amber, so
it is still the one thing on the line you can act on.
CENTRED IN THE BAND IT HAS, rather than sitting on the floor of it.

The line has about fifty pixels of air between the HUD and the first panel
and occupies sixteen of them, and a `RichTextLabel` in a VBox takes its own
height and pins to the top of whatever is left -- so the sentence sat low
against the panel below and the gap read as a hole under the bar rather
than as margin around a line.
NO HEADBAND. The station's particulars sat here in a band across the top of
the deck; they head the rail now, where the banners were, and every deck is
that much taller for it.
NO PLACE BLURB HERE AT ALL. It lived in the Yard's right-hand column, where
a sentence about megafauna and salvage read as something the repair shop was
telling you, and moving it to the top of the page only made it wrong on five
decks instead of one. The starchart already says what a system is like, and
that is the screen you read before deciding to come here -- by the time you
are docked it is a fact about a choice you have already made.
```

## Services panels

Was above `func _heading(title: String) -> MarginContainer:` (deleted, unused):

```text
Repair, refuel, and the yard that sells whole ships.

TWO PANELS STACKED, not two columns side by side. The services are a list of
one-line prices and the shipyard is two ships being compared; side by side,
the ships got half a page to do the harder job in and the price list got the
other half to print seven short rows in. Stacked, each gets the shape it
wants -- the list is wide and short, the comparison is wide and tall.
```

## The yard

Above `func _page_services() -> Control:`:

```text
THE YARD: one hall per development level, your ship and the one for sale on
their stands, and the four services flying over yours on the station's drones.

THE SERVICES USED TO BE A TABLE ON TOP OF THE PICTURE, and then four machines
standing on its floor (`ServiceRig`), which Jon found "feel weird". They are
drones now, as on the Yard Drones page he judged the Yard on: each carries its
offer on a screen of its level's make, a click buys, and a drone with nothing
left to do after a sale says so and flies off. Same four actions, same four
prices. `YardScene` draws all of it; this deck only feeds it the offers and
does the buying.
```

## Yard size

Inside `_page_services()`, above `var col := VBoxContainer.new()`:

```text
NO HEADING, AND NO PANEL AROUND IT EITHER.

The word SHIPYARD sat over a rule above a drawn hangar with two ships in
it, which is a caption on a photograph of a room you are standing in. The
deck rail already says SHIPYARD and the picture already says so.

THE YARD IS 766 x 482, the size the Yard Drones page was drawn at and every
number in it is in: seven pixels either side of it and one under it are
what this panel keeps of the twelve it used to, so the hall Jon passed lands
pixel for pixel.
```

## Yard ships

Above `func _yard_ships(h: HullData) -> void:`:

```text
THE SHIPS, stood again only when they changed: your hull and what is fitted
to it, and whatever is on the blocks.

BOTH SHIPS STAND IN THE HALL NOW, on the level's own stands, with their names
over them the way the Yard Drones page wrote them -- yours amber, the one for
sale ice, and what each one is under it. Pointing at either still brings up
its figures against the other.
```

## Offer slab

Above `func _offer_slab(h: HullData, against: HullData, title: String) -> Control:`:

```text
The gauges, the mounts and the perks, on a slab dark enough to read over art.

ONE BLOCK WITH A SIGNED CHANGE COLUMN, not two blocks to diff by eye. The
first version of this comparison painted your value as the floor and the
offer as the fill: compact, and unreadable, because the base cells take the
manufacturer accent -- so wherever that accent is itself red, four gauges on
which the new frame was BETTER came out red under a legend saying red meant
loss. A signed number cannot be misread by anybody.
```

Inside `_offer_slab()`, above `var head := HBoxContainer.new()`:

```text
--- WHAT IT IS, AND WHAT THE PLUSES AND MINUSES ARE AGAINST.

ONE SLAB FOR EITHER SHIP. Pointing at the hull for sale reads its figures
against yours; pointing at yours reads them against the hull for sale. The
same panel both ways round, so the comparison is symmetrical and there is
one thing to learn. `against` is null when the yard has nothing on the
blocks, and then there is simply nothing to subtract.
```

Inside `_offer_slab()`, above `if pk.get_minimum_size().x > float(SLAB_W - 22):`:

```text
WRAPPED ONLY IF IT NEEDS WRAPPING. An autowrap width is the narrowest a
Label may be, not the widest -- so setting it on every perk made the
slab 448 wide to carry one short line, which is the empty half of the
box. Measured before autowrap is switched on, because with it on the
minimum is the number just written rather than the text.
```

Inside `_offer_slab()`, above `var slab := PanelContainer.new()`:

```text
OPAQUE, and FRAMED IN THE COLOUR OF THE SHIP IT DESCRIBES. It sat at 86%
once, and what showed through was a hull -- grey plating behind grey
figures, the one background text cannot be read on.
```

## Hiring board

Inside `_page_work()`, above `var stack := Control.new()`:

```text
--- THE WHOLE DECK IS THE BOARD.

It was a board hung on a hall's wall, with a door and a terminal and benches
round it -- a room with a noticeboard in it. A hiring hall IS its board: the
paper is what you came for, and the paper is also how the rest of the
station's life shows. So the cork runs edge to edge in a wooden frame, the
work is pinned down the left wherever there was room, and the right is
the town's own -- see `PostingBoard`.
```

## Promenade

Above `const PICK_W := 256`:

```text
THE PROMENADE: one part shown large, the rest as a list beside it.

It was a scrolling column of full-width rows, every one carrying its name,
manufacturer, slot, affixes, both card faces and a price -- four parts stated
at identical weight, so nothing on the shelf was bigger than anything else and
none of the art we drew appeared anywhere on the screen.

Now the shelf has a FOCUS. One part is open at full size with its card
illustration at double scale, and the others are a compact list you click to
bring forward. See `mocks C · The Cutaway`, which is the layout Jon picked.
HOW WIDE THE OPEN PART'S COLUMN IS, and it is fixed rather than fitted so
that the cards beside it start at the same x whatever is open.

TWO NUMBERS SET IT, and both are the widest case rather than the common one:

  the plate   a SPINE part is 4x1, which at CELL is 176 -- plus the size
              caption beside it, about 60 more.
  the name    "Widowmaker Siege Driver" is 23 characters, and Silkscreen at
              FS_HEAD advances 10.5 a character. 242.

256 clears both. Fitted to the CONTENT instead, the column was 176 and the
cards jumped sideways every time you opened a part with a different footprint
-- a 1x1 sight and a 4x1 rail moved the whole right-hand half of the panel.
```

## Promenade room

Inside `_page_stock()`, above `_shop = ShopScene.new()`:

```text
NO SECTION HEADING AT THE TOP. "STOCK" over a rule, above a part that
already names itself in 16px, was a title for a page with one thing on it
-- and it cost thirty pixels off the top of the only band that is short of
them. The word moved down to the list it actually labels.
--- THE WHOLE DECK IS ONE ROOM, and it is one of Jon's fifteen.

The rack and the counter used to stand in a row the screen laid out, in
one of four orders, on a wall `ShopScene` drew round them. The room is his
layout now (see `ShopScene`): the rack and the counter stand exactly where
he put them, and the room is drawn in layers around them -- the wall and
what is seen through it behind, the lamps, the light and the glow in
front. Nothing here places anything by itself.
```

## Till

Inside `_page_stock()`, above `var made := _room_page(_shop, func(stack: Control) -> void:`:

```text
--- AND THE TILL YOU CARRY IT TO.

A SHELF IS NOT A SHOP UNTIL THERE IS SOMEWHERE TO PAY. The stock was
objects standing on boards and the way to buy one was to click the little
price card under it -- three hundred credits gone on a single click, with
nothing carried anywhere, which is exactly the gesture this game threw out
of the hold when right-click-to-jettison was cut.

THE SAME COUNTER THE EXCHANGE HAS, turned around. See `TradeCounter.Side`:
one is where a market pays you and the other is where it charges you, and
they are the two sides of one spread that `MarketTest` proves cannot be
farmed. Carrying a part off the shelf to the till is the same gesture as
carrying one out of your hold to the counter, which is the point -- a
station should have one way of doing business, not one per deck.
```

## Till purchase

Above `func _on_till(item: HoldItem) -> void:`:

```text
A part was carried off the shelf to the till.

THE TILL HAS ALREADY SAID YES. `TradeCounter.refusal` checked the price, the
credits and the room before it let go, so this is the purchase and not a
second opinion about it -- `_on_action` re-checks anyway, because it is also
the thing that races the other players for the slot.
```

## Exchange

Above `func _page_hold() -> Control:`:

```text
THE EXCHANGE: your hold, and a buyer standing in front of it.

ONE COUNTER AND ONE PRICE. There was a scrap chute beside this, paying a
lower flat rate for the same part, and it made a module into two prices in
two places -- which is a second currency wearing a verb's clothes even when
both of them pay credits. A market is somewhere you sell things. What this
place will bear is the only number on the deck.

DRAGGING IS THE CONFIRMATION. Carrying a thing across the deck is the
deliberation, which is the same argument that let the refit screen's hatch
destroy a part without asking -- and it is why the counter needs no button:
the hardpoints are on your ship (click it in the Shipyard), and this is where things become money.

And the hold is the REAL grid, not a list of its contents. It is the thing
you pack, it already drags, and every part on it already answers a hover with
its own readout and cards.
```

## Exchange room

Inside `_page_hold()`, above `_exchange = ExchangeScene.new()`:

```text
--- THE DECK IS ONE ROOM, and it is one of Jon's five.

It was a loading dock `ExchangeScene` drew round the grid -- a shutter, a
crane, a painted bay and a cage off the grid's own rect -- with the counter
in a column of its own. It is the shop's room turned to face the other way
now (see `ExchangeScene`): the hold stands in its frame where he stood it,
the counter where he stood it, and the room is drawn in layers round both,
exactly as the Promenade's is. Nothing here places anything by itself.
```

## Laboratory

Inside `_page_bench()`, above `var stack := Control.new()`:

```text
--- ONE OF JON'S FIVE LABS, ITS OWNER'S SIGN-ON ON ITS SCREEN.

A painted lab per development level (`LabScene`). Its big screen is too
small for the Lab itself (Jon, Nov 4: "is the screen really big enough for
a player to see all of it?"), so in the room it holds the station owner's
logo, a sign-in while you point at it (Jon, Nov 5), and pressing the glass
moves the camera onto it (`LabZoom`), where the pages are at their own
size. Three layers: the lab, lit and running; the glass, which the
power-on's scan opens, with the sign-on and the key on it; and what the big
screen does, over the sign-on.
```

## Deck cells

Above `func _deck_cell(id: StringName, deck: String, what: String) -> Button:`:

```text
Show one page. The lit stylebox is the HUD's, so an active tab looks the same
wherever the player meets one.
One deck of the section.

A Button with Labels inside it rather than a Button with text, because a
Godot Button draws ONE line in ONE colour and a deck needs two of each -- the
name, and what is on it. Children set to MOUSE_FILTER_IGNORE let every click
fall through to the button underneath, so this keeps the focus, hover and
disabled behaviour of the control it replaces and only changes what it looks
like.
```

## Deck power on

Above `func _power_deck(id: StringName) -> void:`:

```text
A DECK POWERS ON ONCE A DOCKING. Jon: once a station's or a lab's power-on
has played, going to the star chart and back must not play it again. Coming
back builds this screen afresh, so `Router.powered` remembers which decks are
on; those come up settled, quiet and already running. Undocking clears it.
```

## Deck cell plates

Inside `_show_tab()`, above `b.add_theme_stylebox_override("normal", UITheme.empty())`:

```text
NO PLATE ON EITHER STATE ANY MORE.

The active cell used to paint a brown bevel and the inactive ones used
to REMOVE the override and fall back to the theme's Button plate. Both
of those are opaque rectangles over the top of a drawing of a room, so
between them they hid the entire cutaway -- the rail looked exactly as
it always had and the spine appeared not to be rendering at all.

`StationSpine` says which floor you are on by turning its lights on,
which is the same statement made out of somewhere instead of out of a
rectangle. The labels still carry the colour.
```

## Cutaway deck count

Inside `_enable_tab()`, above `_light_floor(false)`:

```text
THE CUTAWAY HAS TO HEAR ABOUT IT TOO. Hiding the cell is half the job:
`StationSpine` divides the shaft by the floors it was last told about,
so a rail showing three decks behind a building drawn in fifths puts
every room -- and the car -- off its own label. Only `_show_tab` used
to say so, which is why it corrected itself the moment you clicked
anything and looked fine in every screenshot that clicked first.

NOT A RIDE. The deck set settles on arrival; a car that travels because
a station turned out to have no laboratory is answering a journey
nobody made. See `_ride_to`.
```

## Purge picker

Above `func _open_purge() -> void:`:

```text
WHICH FAULT COMES OUT, chosen from the cards themselves.

THE CARD IS THE QUESTION. A malfunction is a card that will be dealt into
your hand, and the thing you are weighing is which of them you least want to
draw -- so a list of names in grey is the one presentation that withholds the
deciding fact. `CardView` already draws them, keyword tooltips and all.

Priced per removal and not per fault: `clear_dross` takes out exactly one, so
carrying three of a thing means paying three times, and the count on each
card says so before you spend the first one.
```

## Building height

Above `func _size_building() -> void:`:

```text
Give the building its height, once the shaft has one.

IT FILLS THE SHAFT. An earlier version made it taller and slid the whole
station when you picked a floor, which was the wrong object to move: the
building is not what travels in a building. Sliding it also meant a floor was
always partly out of frame, and this rail is the navigation for the screen.
```

## Elevator car

Above `func _ride_to(index: int, ride: bool = true) -> void:`:

```text
Send the car to a floor.

THE CAR MOVES AND THE STATION DOES NOT. It is a lit frame one floor tall, and
it travels THROUGH the rooms between where it was and where it is going --
so picking the Laboratory from the Promenade takes it down past the Yard, the
Exchange and the Hall, brightening each as it passes and letting it go again.
That is the whole of the elevator, and it is why `StationSpine.car` is a float
rather than an index.

`ride` is false on arrival at the station and on a resize: a car that travels
because a panel got wider is a bug you can watch happen.
```

## Ride timing

Inside `_ride_to()`, above `var span := absf(float(index) - _spine.car)`:

```text
LONG ENOUGH TO BE A JOURNEY, and scaled by how far it is going: two floors
should take longer than one, because in a building they do.

FOUND BY BRACKETING IT. A second longer read as a wait; half the original
was "WAY too fast" -- a one-floor hop at 0.13 s is barely a movement and
was nearly all landing. Then: "maybe slightly slower than where it was".
So a THIRD longer than the original, which is 0.34 s for one floor where
the original was 0.26 and the fast one 0.13.

Both wrong answers left something behind: the long one found the tick
buried at 0.46 s in the fan take, and the fast one made the fade a
fraction of the ride instead of a constant.
```

## Ride sound

Inside `_ride_to()`, above `var fade := int(clampf(secs * 250.0, 25.0, 60.0))`:

```text
THE SOUND LASTS EXACTLY AS LONG AS THE RIDE. Jon: "calculate how long it
takes for the elevator animation ... that should be how long the sound
lasts." A ride is 0.24-0.72 s by distance, so the file is longer than any
ride and is faded out on the frame the car stops. A ride cut short by a
new pick is killed above and never finishes; the new ride's own sound
carries on instead.

AND THE FADE IS A FRACTION OF THE RIDE, NOT A CONSTANT. It is 60 ms at
every length that matters here, so at this pace it changes nothing -- it
is kept because it is the correct shape: a sound that is mostly its own
fade never lands, which is what a flat 60 ms did to a 0.13 s ride when the
lift was briefly twice this speed.

AND THE CAR ARRIVES WITH A SOUND OF ITS OWN: "a ca chunk where the
animation ends". It cannot be the tail of the ride -- the ride is cut to
however far the car travels, so a chunk baked into the file would land
wherever the fade did, which is to say never on the stop. Its own sound,
played on the frame the tween finishes, lands every time. Two dB under the
ride, because the first pass at it was four dB over and "too loud".
```

## Cutaway floors

Above `func _light_floor(ride: bool = true) -> void:`:

```text
Tell the cutaway which rooms it has and which one you are in.

THE FLOORS ARE THE DECKS THAT EXIST, not always five. An outpost has no
Laboratory, and a spine that drew one would be a picture of a building with a
room you cannot get to -- so the list comes from the tabs that are actually
enabled, in rail order.
```

## Shop stocking

Above `const SHOP_CELLS := 16`:

```text
Roll what is on the shelf, ONCE per system per run.

The guard used to be `shop.is_empty()`, and that was an exploit rather than a
style choice: buying the shelf out emptied the array, so leaving and coming
back re-rolled a full one. An unlimited supply of parts at a fixed price is an
unlimited supply of money the moment any part is worth more melted than
bought, which is exactly what happened. `stocked` says what was meant — this
station has been visited, and what somebody brought here is what there is.

Nothing is priced here any more. Market prices a part from the place it is
standing in, so the shelf holds parts and not price tags.
THE TWO LIMITS ON A SHOP, and they are not the same limit.

`SHOP_CELLS` is the most stock a shop can carry, counted as the parts' own
area. A shelf is four cells across and two high and the rack has two of them,
so a full rack is sixteen cells and that is the ceiling.

`SHOP_COLS` is what the rack can physically stand. PARTS DO NOT STACK -- they
stand side by side on a board -- so a 1x1 fitting occupies a whole one-wide
column and leaves the cell above it empty. Eight columns is the rack, and it
binds long before the cell ceiling does: eight 1x1 fittings fill the rack
having spent only eight of the sixteen cells.

A shop rolls its fill in COLUMNS, half a rack to a full one, because columns
are the thing you can see: a rack with two bare columns reads as a thin shop,
whereas the same stock rolled on cells fills the rack anyway and only changes
how tall the parts on it happen to be. Depth is not in here. Depth is
rarity, below.
```

Inside `_stock_up()`, above `var trial: Array = n.shop.duplicate()`:

```text
AND IT HAS TO STAND ON TWO BOARDS. Eight columns is two boards of four
only if the parts divide that way: two three-wide parts and a two-wide
one are eight columns that no two boards hold. The rack used to grow a
third board for that; a shop room's rack is the two-board one Jon
placed, so a part that would not stand on it is put back like one that
does not fit the cells.
```

## Hull on the blocks

Inside `_stock_up()`, above `var hull_odds := 0.0`:

```text
WHETHER THIS YARD HAS A HULL ON THE BLOCKS, by how built-up the place is.

It was a flat 0.4 everywhere, which meant six stations in a row with
nothing was a 5% event -- and 5% events happen. Worse, it made an outpost
and a capital equally likely to have a ship for sale, which is backwards:
a yard is a thing a place builds once it can afford one.

Lawless space still never has one. A hull is the largest legitimate
purchase in the game and a fence does not sell you a chassis.
```

## Customs inspection

Above `func _inspect() -> void:`:

```text
High-law space inspects; lawless space does not.

Its own function, and called on every dock rather than from inside the stock
roll. It used to sit under that early return, which meant the customs officer
only ever looked at you on the visit that happened to roll the shelves — dock
clean, fly out, come back carrying, and nobody checked. `n.inspected` is what
makes it once per system; the shelf has nothing to do with it.
```

## Refresh split

Above `func _refresh() -> void:`:

```text
Everything on screen. One function per tab body, mirroring `_refresh_work`,
which was already broken out on its own.

This was one 110-line run that rebuilt the header, both gauges and all five
tab bodies in sequence, so a reader looking for where the shelf is drawn had
to read the repair prices to get there.
```

## Undock gate

Above `func _refresh_undock() -> void:`:

```text
Whether the door opens, and if not, what is holding it.

THE GATE IS ON UNDOCKING AND NOWHERE ELSE, and that placement is the whole
design rather than the obvious spot. The first instinct is to stop the JUMP
-- but `has_legal_jump()` loops `can_jump_to`, and `check_stranded()` ends
the run the moment that returns false for every system. A pad that blocked
jumps would not stop you leaving; it would kill you for buying a ship.

Gating the door instead is both safe and sufficient: the Yard is the only
place in the game that hands you a hull, so a loaded pad cannot reach the
star chart if it cannot get off the station.

THE REASON IS ON THE BUTTON. A disabled control with no explanation is the
worst version of this -- you are standing on a screen with five decks and no
idea which one owes you something. `ready_to_fly` returns the reasons rather
than a boolean for exactly this line.
```

Inside `_refresh_undock()`, above `var how := "Click your ship in the Shipyard and fit parts from the hold."`:

```text
WHAT TO DO, said for the reason it is. The pad's line used to send you to
the Shipyard's ship to stow things, and the cutaway that opens there never
showed the pad (Jon, Oct 23): clicking your ship with the pad loaded opens
the move now, which is the screen that does.
```

## Rail header

Inside `_refresh_header()`, above `var note := ""`:

```text
ONE FACT TO A LINE, at the head of the rail.

It was a sentence across the top of the deck -- "city station · high security
· danger 5 · glut solari/cygnet" -- which is four separate facts wearing
punctuation. Stacked in the rail's head they read as what they are, and the
place's name gets to be a title.
```

## Yard services

Inside `_refresh_services()`, above `var missing := Run.max_hp() - Run.hp`:

```text
--- AND THE FOUR SERVICES, EACH ON A DRONE OVER YOUR SHIP.

The same four the machines in the bay sold, at the same prices: a drone
carries what it will do and what it costs, and when there is nothing left
for it to do its screen says why and it flies off (REFUEL at a full tank:
TANK FULL); FAULTS opens the picker. Broke with a tank that cannot reach
another dock, REFUEL sells the fuel to reach one for what you have, and its
tip says so (`Run.dock_rescue`).
```

## Hold plate

Above `const PART_CELL := 44`:

```text
THE PART ITSELF, ON THE CELLS IT WILL TAKE UP IN THE HOLD.

The module sprite and the card illustration were drawn for different jobs and
the panel needs both: the sprite is the OBJECT -- a silhouette drawn to read
at twenty pixels bolted to a ship -- and the card is what owning it does to
your deck. So the part gets its sprite and the cards get their own faces,
and neither is a crop of the other.

ON A GRID, because that makes the second picture answer a question the first
cannot. "2×1" is a string you have to convert; two squares is the shape of the
hole it leaves in a hold you are already packing.

FORTY-FOUR, and it follows from the art rather than from taste. Module sprites
are authored at twenty pixels to the cell, so a cell of 44 holds one drawn at
exactly 2x with two pixels of air around it -- and 2x is the only enlargement
this art has, the same rule the card window follows.
```

## Part column

Above `func _part_column(mod: ModuleData) -> VBoxContainer:`:

```text
THE OPEN PART'S LEFT-HAND COLUMN: what the thing IS.

SHARED BY THE PROMENADE AND THE EXCHANGE, because they are the same panel
asked two different questions -- one about a part on a shelf and one about a
part in your hold -- and the answer to "what is this" cannot be allowed to
differ between them. It was written twice for a day and the two copies had
already drifted on the flavour line.

Everything above the actions, and nothing below: the caller owns the buttons,
because buying and selling are the half that genuinely differs.
```

## Part description

Inside `_part_column()`, above `var desc := VBoxContainer.new()`:

```text
NO FIXED HEIGHT HERE ANY MORE. This box was padded to DESC_H so that the
price and its button, which used to sit underneath it, would land at the
same y on every part -- a part with one affix and a one-line flavour is two
labels where a part with a two-line flavour is one, and the extra
separation moved the button four pixels. The money is its own column now,
so nothing below this has to be held still and the text can simply be as
long as it is.
```

## Commit button

Above `func _commit_button(text: String, action: Callable) -> Button:`:

```text
THE BUTTON THAT SPENDS SOMETHING, in the one ink this screen reserves for it.

BUY, INSTALL, TAKE IT, MAKE and UNDOCK are the five controls on this station
that actually commit -- money, a hardpoint, a material, or the berth itself.
Everything else is navigation. They were the same grey box as a deck tab, so
the moment of paying looked like the moment of browsing, and UNDOCK had been
given ember by hand while BUY had not.

DISABLED IS SPELLED OUT, and it has to be: an override on `normal` alone
leaves the disabled state ember too, so a BUY you cannot afford would look
exactly like one you can. It goes to LINE on VOID, which is the quietest
thing on the page.
```

## Card fan

Above `func _card_fan(mod: ModuleData, heading: String) -> VBoxContainer:`:

```text
WHAT IT PUTS IN YOUR DECK, as the cards themselves.

THE REAL CARD FACE, not the illustration lifted out of it. Cropping `Z_ART`
and reprinting the rules line underneath in grey is a card taken apart and
laid out again worse -- the face already carries the art, the name, the cost
and the text, drawn by the one class that knows how a card in this game looks.
```

## Slab width

Above `const SLAB_W := 470`:

```text
How deep the berth is. The panel gives it everything under the heading; this
is the floor under that, so the scene never collapses on a short page.
The details slab's WIDEST, not its width. Wide and short rather than narrow
and tall -- two columns of gauges fit in the band of empty wall above the two
berths, where a single column could only fit by lying across the ship it was
describing. It is a ceiling because it was read as a floor for a while and
the slab came out 470 wide whatever was in it, with the right third empty on
every hull whose perk fits on one line. Only a perk long enough to need
wrapping ever reaches it now.
```

## Shelf stock

Inside `_refresh_stock()`, above `var on_offer: Array = []`:

```text
WHAT IS LEFT, which is not the same as what is on the shelf. A sold part
stays in `n.shop` so that everybody's slot numbers keep meaning the same
thing -- see MapGen.OPTION_SHOP -- and is hidden here instead.
NO HULL ON THIS SHELF. The Promenade is where parts are laid out and a hull
is not a part -- it is the thing you bolt them to. It sold here because this
was the only page with a shop on it; the Yard has one now, beside the gauges
for the ship you are standing in.
```

## Shelf display

Inside `_place_shop_furniture()`, above `var shelf := ShelfDisplay.new()`:

```text
NO OPEN PART, NO CARD FAN, NO BUY COLUMN.

THE SHELF ANSWERS ALL THREE NOW. The top band existed because a list of
names cannot tell you what a part is -- so one of them was opened at a time,
blown up on the left with its cards beside it and a price with a button. The
stock is OBJECTS on a shelf now, and pointing at one gets you the identical
readout and the identical cards from `ModuleIcon` without displacing
anything. A panel that shows you one part at a time, above a shelf showing
you all of them, is a worse version of the shelf.

What went with it is the whole top half of the deck, which the shelf takes:
boards down the full height instead of one board and a readout.
```

Inside `_place_shop_furniture()`, above `var shelf := ShelfDisplay.new()`:

```text
--- AND THE STOCK IS STANDING ON A SHELF.

IT WAS A LIST OF ROWS. A rack drawn under that list was better than a
picture behind it and was still a table of names -- what is actually on a
shelf is THINGS, at the size and shape they are. A four-cell rail takes
four cells of board and a fitting takes one, so the shelf says what you are
buying before you have read a word of it.

The hover comes free: `ModuleIcon` already answers with the part's readout
and every card it grants, which is the same panel the refit screen uses.
```

## Hold listing

Above `func _refresh_hold(n: MapGen.MapNode) -> void:`:

```text
What you brought, priced at what this place will pay for it.

THE SAME TWO BANDS THE PROMENADE HAS, and deliberately so: one thing open
across the top, everything else as a list along the bottom. The two decks ask
the same question about a part -- what is it and what does it put in my deck --
and the only honest difference is the buttons, so `_part_column` and
`_card_fan` are shared and this file owns nothing but the actions.

It was a scrolling column of full-width rows, each carrying the name, the
manufacturer, the slot, the affixes, both card faces, a deck count and three
buttons. Four of those is more text than the Promenade ever showed, on the one
page where you already know what you are carrying.
```

## Recipe rows

Inside `_refresh_bench()`, above `for r in recipes:`:

```text
A ROW, NOT A BUTTON THE WIDTH OF THE PAGE.

Each recipe was one wide button whose whole label was "NAME · COST", so the
thing you get was a tooltip and the page was two grey bars. What a recipe
makes is the reason to stand here; it goes on the row in the ink the rest of
the station prices things in.
```

## Buy checks

Inside `_on_action()`, above `if not Run.has_room_for(m):`:

```text
Before the money, not after. Buying into a full hold used to take
the credits, erase the part off the shelf and then log "left
behind" â€” the module was gone from both places and paid for.
FOR THIS PART'S SHAPE, not one free cell: a wide part into a hold
with a single gap passed a `hold_full` test and was then paid for
and lost when `stow` found nowhere to put it.
```

## Work board

Above `func _refresh_work(n: MapGen.MapNode) -> void:`:

```text
What this manufacturer wants doing, and what you can close standing here.

Three groups, in the order a player acts on them: things you can be PAID for
right now, then things you have already agreed to that this desk cannot close,
then the board. Money first — a player walking into a berth holding finished
work should see that before anything else on the page.
```

## Signed offers

Above `var _signed_here := {}`:

```text
THE OFFERS SIGNED ON THIS VISIT, by `_offer_key`. Each stays on the board
where it hung, stamped SIGNED, rather than coming down and going onto the
SIGNED, ELSEWHERE card at the front -- which moved every note on the board
along by one, and with them everything the board scatters round the work
(Jon, Oct 22: "When you pick a quest from the hiring board... the whole
hiring board resets"). Next visit it is on the card, as before.
```

## Board sync

Above `func _sync_notes(want: Array) -> void:`:

```text
THE BOARD UPDATES IN PLACE. `want` is the notes in order, each [what it
says, a callable that makes it]; a note already up that says the same stays
up, the same node in the same place, and only one that changed is made
again, in its own slot. Clearing and rebuilding the column on every refresh
put new paper up for a frame and moved whatever had changed size, and a
board laid out round its notes laid itself out again.
```

## Deck subject

Above `func deck_subject(tab: StringName) -> Rect2:`:

```text
THE MAIN THING ON DECK `tab`, global, once it is up and still; Rect2() before
(the first-visit hints, `Hints.DECK_HINTS`, point at it). The yard: its
drones, each home over your ship, once all that came have flown in (the box
takes in their bob, so the outline holds still while they move). The
Promenade: the shelf. The Exchange: the counter that pays. The Hiring Board:
the notes, once its lamp is lit. The Laboratory: the recipes on its screen,
once the power-on's scan has passed.
```

## Yard flight speed

Above `const YARD_M := 2.4`:

```text
the yard's flight's speed at its far end, in units of its length over its
duration (`ZoomLadder.herm`): 2 is one smooth fall to rest (or rise from it).
2.4: undocking, your ship leaves the yard at about the speed it comes out of
the hull on LOCAL (about 1130 px a second), the black between
```

## Yard flight in

Above `var _lad := {}`:

```text
THE YARD'S OWN HULL FLIES IN (3B, Jon: "can we have the ship enter the
shipyard from the left.... without the elevator... and then the elevator slides
in?"). k is 1 with the hull off the left edge and the elevator gone, 0 with the
hull on its stands; the elevator slides back in once the hull has settled
(`ladder_cam_end`), as it does when the cutaway shuts. Undocking runs it
backwards (`ladder_pre`): the elevator out first, then the hull lifts and goes.
```

## Landing sound

Above `const YARD_ROAR_FROM_S := -0.2`:

```text
THE LANDING, HEARD (Jon, Oct 21: "as the ship enters the station and lands on
the holds... there is no thruster sound. Can't we have it have the roar of
the thruster and then putter out to nothing before it lands?"). The yard's
flight in, on the ladder's clock (`ZoomLadder._step_pan` hands it `t`, s since
your ship started in from off the left, and `dur`, the flight's length, at
whose end it is on its stands):
  1. THE ROAR from `YARD_ROAR_FROM_S`: the engines lit at the cruise burn
     (`ShipView.burn`, the flame LOCAL's ENTER draws) and heard as that burn
     is (`Audio.ship_thrust` at `SectorScreen.DOCK_BURN_LEVEL`);
  2. THE PUTTER from `YARD_COUGH_AT_S`: the burn out and the arrival's own
     flameout (`ShipView.sputter`, a FLAMEOUTS row), its clip for that row
     at this hull's weight heard from its first cough, at the burn's level
     so the two are one engine (as undocking plays it), the coughs drawn
     being the coughs heard;
  3. NOTHING for at least `YARD_QUIET_S` before touchdown: the last cough
     over and the clip done (it is silent past its last cough), the flame at
     the idle, only the yard's own sounds;
  4. THE CLAMPS as it touches down (`Router.pay_dock_clamps`).
The row is picked at random from those whose coughs fit between 2 and 3; if
none does, the shortest, begun early enough to end in time. A press mid-dock
(`ZoomLadder.finish_now`) parks your ship on its stands with all of it
hushed (`ladder_cam_end`); reduced motion never flies it in, so it is never
heard. The path and its timing are the flight's own, untouched.
s after the flight starts: negative is heard over the empty yard first, as an
arrival's drive is heard before the ship is seen (its flame lit off the
picture)
```

## Elevator slide

Above `var _rail_slide: PanelSlide = null`:

```text
THE ELEVATOR COMES IN LIKE EVERY OTHER PANEL (Jon, Oct 20: "The left panel
coming into the station doesn't come in correctly"). Filmed, it slid in as a
column of words and deck pictures with nothing behind them: the yard's hall
run on into its column (`_YardEdge`) showed through its header and round its
cells all the way in, and on the frame it landed the hall went and the dark
column and the yard's frame appeared under it at once -- a pop of the whole
column. It also eased in on its own cubic, off the whole pixel, in silence.
Now it is the side panel's slide (`PanelSlide`): the control itself moved,
in whole pixels, on the panels' one curve (`ZoomLadder._calm_slide_curve`)
over `ZoomLadder.CALM_SLIDE_S`, heard as they are (`chrome_on`), carrying its
own ground with it -- the dark the column stands on at rest and the yard's
frame beside it (`_RailBack`) -- over the hall, so when it lands the picture
is already what the column is at rest and the hall goes under it unseen.
Nothing on it takes a click while it moves (`_RailBlock`): a press there
lands it at once and goes no further.
```

## Figures slab

Above `func _float_slab(slab: Control, v: ShipView, at: Vector2) -> void:`:

```text
A ship's figures, directly above the ship.

ABOVE THE SHIP YOU ARE POINTING AT, which is where the eye already is. It used
to be parked over the OTHER ship, on the reasoning that it must not cover the
one you are reading about -- but the band of wall over the berths is tall
enough to hold it without covering either. Centred on the hull's ink, kept
inside the hangar, and sized to its own content: all four offsets written here,
because a preset writes the control's current rect into them.
```

## Hung banners

Above `const BANNER_K := 2.0`:

```text
How a hung banner is sized, the gap between two, and the rod they hang from.

LONG AND NARROW. Its own width units at `BANNER_K`, but `BANNER_LEN` tall
rather than its own height: the rail's flag blown up to the same proportions
read as a sign on a wall, where a hung length of it reads as colours. The
emblem sits at the top and the manufacturer's hem at the foot, so the length
between is plain field -- which is what a real hanging banner is.
```

Above `func _hang_banners(room: Control, n: MapGen.MapNode, spots: Array) -> void:`:

```text
Hang the station's manufacturer banners in a room.

THE BANNERS LEFT THE RAIL AND WENT INTO THE ROOMS. At the head of the rail they
were two flags over a list; in the rooms they are what a manufacturer actually
does to a station it holds -- its colours hung in the hangar, pinned on the
board, over the till. Still real `ChassisSelect.Banner`s rather than pictures of
them, so pointing at one still gets the manufacturer's readout.

Children of the ROOM, so they draw over its walls and under everything that
stands in it. Each spot is a horizontal anchor fraction and a top; the whole set
hangs side by side from a rod, centred on it.
```

## Board posts

Above `func _board_posts(n: MapGen.MapNode) -> Array[StringName]:`:

```text
Which manufacturers have a notice of their own up on the Hiring Board.

WHOEVER HOLDS THE STATION, first, because a notice is how a place says who runs
it; where nobody does, the dock desk that posts its work (`Contracts.dock_desk`).
Then the place itself: lawless space gets Redline's flyer, since Redline is
never at the address on its invoices and a lawless board is exactly where it
would turn up; a cosmopolitan station gets a couple of visitors, picked off the
station's own index so the same station always carries the same ones. Three at
most -- the board has three places to put them.
```

## The camera into the lab carries

Above `var _lab_chrome_a := {}`:

```text
THE CAMERA INTO THE LAB CARRIES THE DECK'S PLATE (`LabZoom`, its
`_frame`): the plate round the room is drawn through the camera with the
room, so the deck's own is hidden (`away`) from the frame the camera leaves
the room to the frame it lands back, and then put back exactly as it was.
Never faded (Jon, Nov 5: "the fact that the frame pops in is kinda
awkward, yeah?"). It goes by its self_modulate, so the room it holds stays.
```

## The camera carries the elevator and

Above `var _lab_carry := {}`:

```text
THE CAMERA CARRIES THE ELEVATOR AND THE HUD OUT (Jon, Nov 5, of the zoom:
"can we have a smoother transition with the elevator?"). They used to fade
before the camera moved, and the room stood off to the right of an empty
dark column where the elevator had been; on the way back the room landed
beside that hole and the elevator faded in after it. Now they stay whole
and ride the deck frame's edges as the camera closes in: the elevator goes
out of the window's left with the frame's left edge, the HUD out of its top
with the frame's top, and coming back out they ride in with the room and
stand in their places on the frame it lands. They are moved, never scaled
(the camera's scale would blur their words), and drawn over the zoom
while it has them (`z_index`). `d` is how far the deck's frame has moved on
screen from where it stands (the camera draws it with the room); `on`
false puts both back exactly.
The yard's edge sets the rail's alpha and height every frame where there
is a berth (`_YardEdge`), so it reads `_lab_lift` and `_lab_rail_a` too.
```

## Undock from a deck above the

Above `var _undock_wait := false`:

```text
UNDOCK FROM A DECK ABOVE THE YARD RIDES DOWN TO IT FIRST (Jon, Nov 5: the
slide for every elevator choice). Undocking (3B) is the elevator out and
your ship off its stands, and your ship is in the yard: pressed on the Lab
it used to play over the Lab, the elevator going and the hull flying out
unseen. Now the car takes you down to the SHIPYARD on the slide and the
undock starts as it stops. A floor picked on the way cancels it; a second
press waits for the same ride. Where the undock does not move the yard (the
ladder off, another design, reduced motion, a harness) it leaves at once.
```

## The decks change over the ride

Above `var _ride_s := 0.0`:

```text
THE DECKS CHANGE OVER THE RIDE, NOT AT THE CLICK (Jon, Nov 5: "a smoother
transition with the elevator"). The deck you left used to vanish on the
frame you pressed the floor, the car still standing at it: from the yard,
lit, to the Lab, black before its power-on, in one frame. Now the deck you
are leaving goes down into the dark over the first half of the car's ride
(`_ride_to`, 0.24 to 0.72 s by distance), the decks change hands under the
dark, and the deck you are going to comes up out of it as the car arrives.
The Lab's power-on starts as it comes up, so its lights strike just after
the car stops. A dip through a dark sheet over the deck's panel, not the
pages' own alpha: the painted rooms are drawn by shaders that do not take a
node's alpha (the Lab's went black at once over the fading yard). Nothing
on either deck moves (don't move what can be clicked), and the deck you
leave takes no clicks while it goes. Only on a ride: arriving, and in a
harness, the deck is there at once.
```

## The decks ride with the car

Above `static var deck_move: StringName = &"slide"`:

```text
THE DECKS RIDE WITH THE CAR (the review of the dip, Nov 5: a fade to black
is still a cut, and an elevator goes up and down). On a ride the deck you
leave and the deck you go to are one tall shaft, a floor slab between them,
and the shaft moves past the panel in the car's direction on the car's own
curve and time: going down a floor, the deck you leave rises out of the top
and the new one comes up from below. It is a camera move: both decks are
whole and drawn as they are, only moved, and neither takes clicks till the
car stops. A press mid-ride starts from where the shaft is.

EVERY DECK, BOTH WAYS (Jon, Nov 5, round three: "The slide can be the main
transition for every elevator choice"): PROMENADE, SHIPYARD, EXCHANGE,
HIRING BOARD and LABORATORY, up and down, at every level, and UNDOCK from a
deck above the yard (`_undock_press`). `deck_move` &"dip" keeps the dark dip
(`_cross_decks`) as the fallback; either way no deck change is a cut while
the game animates (reduced motion and a harness change on the press).
```

## The ride never jumps a long

Above `const RIDE_STEP_S := 1.0 / 30.0`:

```text
THE RIDE NEVER JUMPS A LONG FRAME (StationDeckTest, Nov 5: the first frame a
deck is shown builds it, and at an outpost one took 0.13 to 0.17 s, so a
first ride onto a deck landed whole on its first frame: a cut). The car and
the slide are stepped here, together, by the frame's time but never more
than RIDE_STEP_S (two frames at 60): a frame that stalls holds the shaft
where it was, and the ride goes on from there.
```

## The lower deck over the upper

Inside `_slide_decks()`, above `var lower := mate if dir > 0.0 else from`:

```text
THE LOWER DECK OVER THE UPPER (the r5 film: from the yard up to the
PROMENADE the yard went dark on the press). A deck is taller than the
panel: the PROMENADE's page is 1004 px for a 483 px panel and the
EXCHANGE's 1200 (their till notes, autowrapped in a column, ask that
much), and at rest the rest of it is off the bottom of the window. In the
shaft that rest lies over the deck below, and the page's translucent
plate darkened the whole yard. So the deck lower in the shaft is drawn
over the one above it, and the slab over both; and each is clipped to
itself, so nothing of a deck's inside runs on past its own plate.
```

## The labs reminder

Above `const LAB_REMIND := 10`:

```text
THE LAB'S REMINDER (Jon, Nov 8, S1A: "Labs get a reminder to spend when the
player holds 10 or more DATA", on his stripped-down UI push: no new panels or
boxes, no second button for something already there). The sim had runs ending
with 19 DATA unspent on average. So the Laboratory's line under its name on
the elevator, which read "DATA 21", reads "SPEND 21 DATA" once DATA reaches
LAB_REMIND, and it is EMBER on every deck, not only the deck you are on. It
is the same label, the same size, in the same place: nothing new on screen.
10 is the second step's price, so the line comes up when DATA would buy any
row's next step but a last one (15). With science off it never shows.
```

