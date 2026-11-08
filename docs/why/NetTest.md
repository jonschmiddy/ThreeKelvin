The reasoning behind `tkg/scripts/sim/NetTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Test scope

Above `const PORT_BASE: int = 34210`:

```text
Four peers, one process, no network hardware.

  godot --headless --path . -- nettest

RUN THIS AFTER TOUCHING ANYTHING IN scripts/net/. A session layer fails the
same way a save file does: silently, and in front of other people. A roster
that drops a player, a refusal that arrives as a bare disconnect, or two
machines that launch on different seeds all look like working code and are
only visible when four humans have already set aside an evening.

The trick that makes this possible in one process is SceneMultiplayer's
root_path. Each peer gets its own branch under the tree root and its own
MultiplayerAPI rooted at that branch, so every peer's NetSession answers to
the same relative path "Net" while living at a different absolute one. RPCs
resolve by the relative path, so the peers can talk to each other exactly as
they would across a wire. Without this the test would need four processes
and could not run in CI.

What this proves: codes survive a round trip and refuse typos; a party forms
and the roster reaches everyone; the two version refusals fire and arrive as
readable text; a full party turns the next one away; a launch puts the
same seed on every machine; a ship crosses the wire and comes back as
the same ship on the other machine; a system consumed on one machine is
consumed on all of them; and losing the host is reported rather than
swallowed.

What this does NOT prove: that any of it works through a NAT. Nothing that
runs on one machine can prove that, and pretending otherwise is how the
direct transport gets shipped as if it were finished.
```

## Fingerprint order

Above `func _fingerprint_order_tests() -> void:`:

```text
THE FINGERPRINT MUST NOT DEPEND ON HOW A PROCESS STARTED. Two exports of one
commit refused each other (Oct 20) because the ids were sorted as StringNames,
whose order is not their text. One process cannot see two orders, so this
holds the ids to the text: alphabetical, whatever order the table was built
in, and the module and enemy tables read that way.
```

## Protocol refusals

Inside `_refusal_tests()`, above `await _one_refusal("a version 13 peer", PORT_BASE + 32, 13, 0,`:

```text
THE ONE BEFORE THE PAIR TURNED (PROTOCOL 13): its spots are two numbers
short and say star B's close orbit as the point where B stood on its own
clock, so it is turned away at the door, by name
```

Inside `_refusal_tests()`, above `await _one_refusal("a version 15 peer", PORT_BASE + 33, 15, 0,`:

```text
ONE CUSTODIAN FOR THE GALAXY (PROTOCOL 16, Jon, Nov 4): a 15 peer sends a
presence one number short and grows the boss on its own jumps, so it is
turned away at the door, by name
```

## Wire tests

Above `func _wire_tests() -> void:`:

```text
The description on its own, before any network is involved.

Deliberately given values a real run would take a while to reach — a part on
the third hardpoint, a part built by somebody who did not build the hull, a
ship over its heat cap — because those are the fields whose loss is invisible.
A build that comes back with every mount at zero draws every gun on the spine
and looks like a rendering decision.
```

## Build test

Above `func _build_test() -> void:`:

```text
A ship described on one machine, drawn on another.

The failure this catches is not "no ship appears" — that is loud. It is a
partner drawn as the WRONG ship, which looks like art rather than like a bug
and which cannot be seen without two machines.

Nothing here asks for a build to be sent. That is the point: fitting a
chassis is what a player does, and the party seeing it is supposed to be a
consequence rather than a call somebody remembered to make.
```

## Per-ship claims

Above `func _per_ship_claim_tests() -> void:`:

```text
A PARTNER'S CLAIM NEVER CLOSES THIS SHIP'S OWN OPTIONS (Oct 22). A placed
event quest and a contract pickup are each one ship's (`OptionTable.is_mine`):
taking one asks nobody, and a claim on the same system and slot index, which
on the partner's map is their own quest or pickup, leaves mine open. Before
my list is rolled the claim is kept, and the roll drops it if it lands past
the rolled list, so what I append there next is not born taken.
```

## Map test

Above `func _map_test() -> void:`:

```text
The networked half: one machine uses a system up, and every other machine
agrees that it is used up.

This is the message that stops four players each stripping the same derelict.
The wreck holds the same two modules on all four machines already — that is
what the shared seed and `Rng.derive()` buy — so without this the hold
economy in `docs/coop-design.md` §3 pays out four times for one wreck.
```

## Boss growth

Above `func _growth_rules_test() -> void:`:

```text
THE BOSS GROWS MID-FIGHT (Jon, Nov 4, decision 2), with no wire under it:
a Custodian opened at 20 jumps, joined and hurt, grown to 33. Its hull is the
joined hull times hull_at(33) / hull_at(20), the damage done stays done, a
later joiner adds 0.6 of the new hull, and a pilot who left first changes
nothing (join growth never shrinks back).
```

## Targeting

Above `func _targeting_test(host: NetSession) -> void:`:

```text
Who the enemy swings at.

The rule is `0.5 + heat_ratio`, and both halves matter. The ratio is what
makes running hot dangerous INSIDE a fight rather than only on the map, which
is `docs/coop-design.md` §6 one level down. The floor is what stops a party from
solving the fight by electing a victim: a cold ship is safer, never safe.
```

## Fight race

Above `func _race_test() -> void:`:

```text
TWO SHIPS, ONE SYSTEM, TWO DIFFERENT FIGHTS, ONE SECOND. A guest cannot know
whether it is opening a fight or joining one, so it plans its own enemy and
asks; the host keeps one fight per system and seats the second asker in the
first. Until Nov 5 the asker kept the enemy it planned and painted the
party's numbers on it: Y's attack names over X's hulls, a softlock when Y had
more hulls than X (its extra hull lived only on that machine, so the kill
never came), a second hull nobody could shoot when X had more. Jon: "Yeah
you can fix it." So every asker takes the host's answer: `Combat.begin`
builds the enemy from the fight's ids when they are not the ones it planned.

Each asker here is a real `Combat`, planned, asked through its session and
begun on the answer, as `Router.start_combat` does it. The packs differ in
size both ways: an asker that planned one hull and got two, and one that
planned two and got one.
Then the two session holes: an ask the host is slow to answer is still
answered (no private fight while the link is up, and null once it drops),
and a ship that left a fight and asks again is joined again, grown once,
never handed the copy it left.
```

Inside `_race_test()`, above `host.hold_asks = true`:

```text
THE SLOW ANSWER. Past TAKE_TIMEOUT the ask used to come back null and the
guest fought a private copy of the enemy, though the host had seated it:
its fight never said END TURN, so the party sat on "WAIT", and at the core
that was a second Custodian it could win the run against. Now it waits for
as long as the link is up.
```

## Late join

Above `func _late_join_test() -> void:`:

```text
A FRIEND WHO JOINS AFTER LAUNCH IS IN THE DIVE. The seed went out once, at
LAUNCH, so a late joiner (or a friend whose game fell over and who typed the
code back in) was accepted, seated, and left in the lobby for good -- the
Oct 22 playtest's "kinda a mess". `-- cojoin late` flies it in two processes;
this holds the wire: the seed, the unlocks, what the party has used up, and
the fight open, all handed to the late ship at the door.

And THE SPOT (PROTOCOL 11): where a ship is inside its system, relayed by the
host to everybody else, so the SECTOR map can draw partners flying round it.
Answered only for the system it was said about.
```

## Turning pair

Above `func _turning_pair_test() -> void:`:

```text
A TURNING PAIR, SEEN FROM TWO CLOCKS (PROTOCOL 14, ruling 23). Two machines
in one binary, their map clocks 5 s apart (a flying peer never takes the
party's clock, so they can drift), at 8 of the pair's angles round a lap, a
wide pair and a close one: a spot said by one at its clock and drawn by the
other at its own (`NetSession.spot_anchor`, as `SystemMapScreen._report_spot`
and `partner_points` use it). In star B's close orbit, settled round star B,
settled round star A: on that sun where it is on the drawing machine, to a
thousandth of a pixel. Settled round both suns: the plane point it was --
the balance point holds still, where turning it with the pair (the design's
first rule) would have swung it by the angle between the clocks. A world's
offset off the world, the world round star B carried with it. And one sun:
a star's spot is the plane point it always was, to the bit.
```
