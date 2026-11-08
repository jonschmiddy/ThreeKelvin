The reasoning behind `tkg/scripts/data/ShipBuild.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Wire format

Above `var pilot: String = ""`:

```text

THIS FILE IS THE WIRE FORMAT. A key renamed here is a protocol change, and
the number that guards it lives in NetSession -- so the two move together or
two builds shake hands and draw each other wrong. `content_fingerprint`
cannot help: it hashes the TABLES, not the wire.

The annotation above is read by .github/scripts/version_guard.py.

One ship, described well enough to draw it — and small enough to send.

Every screen used to draw the player's ship by reaching into `Run` for the
hull, the fitted modules, the hull points and the heat. That is correct for
exactly one ship: yours. A party has up to four, three of which are being
flown on other machines, so the renderer needs a SUBJECT rather than a
global. This is that subject, and `ShipView` now takes one.

Two rules decide what is in here and what is not.

**It carries what is drawn, not what is played.** No cards, no affixes, no
rolled stats. A partner's Chatterbox has an affix on it and a scrap value and
eleven other fields; none of that changes a single pixel, and every one of
them would be on the wire four times a second. What changes pixels is the
hull's weight and manufacturer, which hardpoint each part sits on, who built it, and
the two gauges the art reacts to — heat and damage.

**Identity travels as ids, never as objects.** `to_wire()` sends a
manufacturer and a weight class rather than a `HullData`, and a module id
rather than a `ModuleData`. Both machines already hold the same content
tables — `NetSession.content_fingerprint()` refuses the join otherwise — so
sending the tables again would be sending a copy of something already agreed.

A looted hull is a `duplicate()` of a catalogue frame with its numbers rolled
up, so manufacturer plus weight plus GRADE names its appearance exactly.

The grade is on the wire and it did not used to be. The note that stood here
said an A-tier Korvan Frigate and a C-tier one were the same picture, and
that was true right up until `DB.hull_sprite()` was keyed on the class letter
as well as the weight — four sprites per weight, which is what finally made C
through S something a player can see. From that commit every partner in the
party was drawn as a C-class hull whatever they were actually flying, and the
failure is silent in the worst way: the ship on the other screen is a
perfectly ordinary ship, just not the one that player picked.

The lesson is smaller than the bug: this file describes what is DRAWN, so any
field the renderer starts reading has to arrive here on the same day.
```

## Parts

Above `var parts: Array = []`:

```text
What is bolted on, as `{slot, mount, manufacturer, id}`. Plain dictionaries rather
than `ModuleData` on purpose: a remote part has to be resolved from the
catalogue, and the catalogue entry is SHARED — writing the sender's `mount`
onto `DB.modules[id]` would move that hardpoint on every ship in the game.
```

## Fitted out

Above `static func fitted_out(h: HullData, parts_on: Array) -> ShipBuild:`:

```text
A hull with a GIVEN set of parts on it, rather than the ones you are flying.

THE SHIP YOU ARE LEAVING IS NOT `Run.hull` ANY MORE. The moment a swap is
paid for, `Run.hull` is the new frame and `Run.installed` is empty -- but the
transfer screen has to draw the old one still wearing its guns, because that
is the ship you are stripping. `local()` cannot answer that and `showroom()`
answers it bare.

Cold and undamaged like a showroom hull, deliberately: the heat and the
scorch marks belong to a ship that is being flown, and this one is parked.
```

## Part entry

Above `static func part_entry(m: ModuleData) -> Dictionary:`:

```text
ONE PLACE THAT KNOWS WHAT A PART LOOKS LIKE ON THE WIRE.

It was written twice the moment there were two ways to build a ship, and two
copies of a SERIALISED shape is exactly the drift `version_guard.py` exists
to catch -- `parts` goes over the wire in co-op, so a key added to one copy
and not the other is a peer drawing a different ship from the same message.
The guard caught the second copy on the day it was written, which is the
system working.
```

## Showroom

Above `static func showroom(h: HullData) -> ShipBuild:`:

```text
A hull nobody owns yet: bare, cold and undamaged.

This is what the chassis select shows, and it replaces the `preview` flag
`ShipView` used to carry. A showroom ship is not a special MODE of the
renderer — it is an ordinary build that happens to have no parts on it and
full hull points, so every "suppress this when previewing" branch in the
drawing code stopped needing to exist.
```

## From wire

Above `static func from_wire(d: Dictionary) -> ShipBuild:`:

```text
Everything read here came off a socket, so everything read here is checked.

Not because a peer is expected to lie — the handshake already refused anyone
whose content tables differ — but because this is the only door remote data
uses to reach the renderer, and the renderer dereferences a hull. A weight
class of 99 resolves to no hull at all, and the convoy slot that asks that
hull for its manufacturer takes the sector screen down with it.
```

Inside `from_wire()`, above `b.tier = clampi(int(d.get("tier", 0)), 0, HullData.TIER_NAMES.size() - 1)`:

```text
And at the grade they are flying it at, because that is what picks the
sprite. `at_tier()` hands back a DUPLICATE, which is the only reason this
is safe: it re-rolls hull points and hardpoints off the catalogue frame,
and writing those onto the shared frame would regrade every ship in the
game that happens to be the same make.

The numbers it computes are thrown away — hp, max_hp and heat_cap are all
read off the wire a few lines down, because a partner's hull has been shot
at since it left the yard. What survives is the picture.
```
