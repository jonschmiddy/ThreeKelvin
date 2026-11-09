The reasoning behind `tkg/scripts/sim/WreckSiteTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Wreck site rules

Above `var h := Harness.new()`:

```text
EACH PLACE KEEPS ITS OWN WRECKS (Jon, Oct 14: "each planet or POI you can
visit should contain its own wrecks/fights").
  godot --headless --path . -- sheet=WreckSiteTest

A wreck lies where your ship was when its hull died (`Jetsam.site`: the body
it orbited, -1 the star, -9 open space), and LOCAL draws the wrecks of the
place you are parked at and no other's:
  - two fights at a world leave their hulls at that world; the star next door
    has none of them, and its own fight's hull is its alone;
  - back at the world, its two are there again;
  - the real LOCAL draws exactly the place's wrecks, each with the death roll
    and fight marks of its number among the whole system's wrecks (what the
    kill was keyed on), and open space with none draws the place picture;
  - a save keeps each wreck's place; a wreck from a save before wrecks had a
    place shows wherever you are, as it did then;
  - and SECTOR LOOT (Jon, Oct 15: "When a wreck is opened, and all or some of
    the parts are left behind, those should also show up in the sector loot
    pool for that sector"): nothing of a wreck before it is opened; once it
    has been, through LOCAL's own door, the button shows what is left in it,
    from any place in the system; a take through SECTOR LOOT is the wreck's
    own claim, a part put down goes on the pile, one put back that came out
    of the wreck goes back into it; a save keeps which wrecks were opened;
  - ONE PLACE, ONE FIGHT (Jon, Oct 15): the Hellbender and the core's
    Custodian are engaged at their own place on the map and nowhere else --
    LOCAL anywhere else sends you to the map -- and a jump arrives at the
    edge, wherever the ship was left on the last visit;
  - THE WRECKS STAY OFF YOU (Jon, Oct 17): after a fight won on LOCAL, every
    door off it and back -- the cutaway with a part moved or a wreck emptied
    in it first of all -- leaves every wreck where it lay, clear of your hull
    (`_round_trips`);
  - AND IN THEIR SYSTEM (Jon, Oct 17): a real jump to the next system draws
    none of them there, and a save made where they lie keeps them there
    (`_other_systems`);
  - AND OFF THE WORLD YOU ORBIT (fit means nothing overlaps): their words
    never on its disc, their pictures not either while the pile is a
    fight's worth (`_off_the_world`).
```

## Hellbender doors

Above `func _hellbender_doors() -> void:`:

```text
AFTER THE HELLBENDER, EVERY DOOR STILL OPENS (Jon, Oct 22: "Fighting the
Hellbender totally breaks the sector and local buttons. You are able to click
starchart."). The map was held shut while it was anchored in the system
(`Router.show_sector` / `show_system` sent every way to it back to LOCAL),
from before it had a place of its own on the map, the one way to that place.
Each ending through the real fight and its panels: killed, its escape burn
(gone from the system, not hopped straight back in), and you breaking contact
(it stays anchored). Then where the fight left you, and the HUD's LOCAL,
SECTOR and STARCHART and Tab each opening their own screen. The gate fails
on any script error in the log.
```

## Wreck clearance

Above `func _round_trips() -> void:`:

```text
THE WRECKS STAY CLEAR OF YOU, WHEREVER YOU HAVE BEEN (Jon, Oct 17: "fix
destroyed ships from going on top of you when you edit your ship after a
fight"). A two-ship fight won on the real LOCAL, then every door off LOCAL
and back, and each time every wreck's drawn boxes -- its picture's ink, its
name and its SALVAGE / STRIPPED tag -- against your hull and its plate. The
cutaway is the one that broke: a part moved or a wreck emptied with the scene
zoomed 2x laid the wrecks out in the zoomed picture's room, and shut, they
stood across your bow.
```

## Wreck systems

Above `func _other_systems() -> void:`:

```text
DESTROYED SHIPS STAY IN THEIR SYSTEM (Jon, Oct 17: "destroyed ships still
show up in other systems"). Hulls killed at a world and at the star of system
A; then every other place in A draws none of them, a save made in A and
loaded keeps them in A at their own places, and a real jump to system B
arrives where none of them is drawn, at B's edge or at any of B's places.
```

## Wrecks off the world

Above `func _off_the_world() -> void:`:

```text
WRECKS OFF THE WORLD YOU ORBIT (Jon's rule: fit means nothing overlaps). On
the real LOCAL, parked at every world of four systems in each of six
galaxies -- worlds and giants of every size, on either side of the view --
with one to six wrecks there: no wreck's name, bar or tag on the world's
disc, ever; no wreck's picture on it while the pile is a fight's worth (three
or fewer); and a count of the bigger piles whose pictures had no room off it.
The words draw over the world (the sky is the view's first child, the hulls
its row), but a grey name on a lit yellow face cannot be read: it is kept
off rather than drawn over.
```

## Twin suns

Above `func _twin_sites() -> void:`:

```text
TWO SUNS (ruling 20, Oct 30): star B (`SystemLayout.STAR_B`, -4) is a place
of its own, as the star is. A fight won in star B's close orbit leaves its
hull there and not at star A, and star A's own hull is star A's; the real
LOCAL at each star draws exactly its own; a save keeps both places; read back
in a system with one sun, the hull and a ship left at star B are the star's
(`Run.star_site`); and at no place in a system without a Hellbender or a
Custodian is the ship at one (their places are -2 there, "none", and the two
checks compared against it unguarded: a site of -2 read as at the Hellbender).
```
