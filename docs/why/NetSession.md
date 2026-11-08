The reasoning behind `tkg/scripts/net/NetSession.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Session design

Above `const PROTOCOL: int = 16`:

```text
The party: who is in it, whether their builds agree, and what galaxy they
are about to share. Autoloaded as `Net`.

This is the session layer and nothing else. It does not move a ship, resolve
a card or own a run. That separation is on purpose and it is what makes the
thing testable before any of the co-op design in `docs/coop-design.md` exists:
the questions "can four machines find each other, agree, and start together"
and "what happens once they have" are independent, and the first one is the
one that is hard to change later.

Three rules hold the design up.

**The host is the authority.** There is no vote and no merge. The host's
roster is the roster, the host's seed is the seed. `Combat` is already a
plain RefCounted with no UI dependency and `HeadlessSim` already plays whole
runs headless, so the machine that decides is a machine that can already run
the game with nothing drawn — the expensive precondition for authority is
paid for.

**The handshake refuses before it connects.** A party whose builds disagree
does not fail at connect time; it fails forty minutes in, at the one node
where one player's build rolled a module the others do not have. So the
protocol number and a fingerprint of the content tables are checked in the
first message, and a mismatch is refused by name.

**Nothing here knows the transport.** See NetTransport. The code is the
seam.

What is NOT here yet, and is deliberately not here: any gameplay RPC. The
galaxy seed goes across and the dive starts; from that moment the two
machines are running the same generator over the same seed and nothing is
being kept in step. That is not a shipping model — it is the smallest thing
that proves the layer works, and it is the reason RNG determinism is listed
as a prerequisite rather than a nicety.
```

## Protocol versions

Above `const PROTOCOL: int = 16`:

```text
Bumped on any change to the messages below, or to the meaning of the fields
in them. Two builds with different numbers refuse each other immediately.
This is cheap to raise and very expensive to have forgotten.

2: a roster slot carries `build` — the ship that player is flying, as
   `ShipBuild.to_wire()`. A version 1 host would send slots without it and
   every partner would be drawn as an empty hull.
3: a roster slot also carries `at` — which system that player is in — and
   the host holds `claims`, the systems the party has consumed. A version 2
   host answers neither, so every wreck would be strippable four times.
4: a claim names an OPTION within a system rather than the whole system, and
   records WHO took it. A version 3 host would answer a request for one
   option by consuming the entire node.
5: fights are shared. The host owns the enemy — hull, block, brace and
   intent — and decides who it swings at. A version 4 host answers none of
   the fight messages, so two ships in one system would fight two private
   copies of the same frigate and both be paid for killing it.
6: a kill pays ONE bag rather than paying every ship privately, and the
   fight carries how many hands were in it when the last hull came apart.
   A version 5 partner would roll a bag of the wrong size and reach for
   parts nobody else believes are there. The roster's `build` also carries
   the hull's GRADE now, without which every partner is drawn as a C-class.
7: the hellbender. The host counts the party's jumps and owns the roamer's
   position, pushed whole through `_push_hellbender_to`. A fight can now open
   against an enemy already hurt (`cur` on `_open_fight_at_host`), and a
   fight can end because the enemy LEFT (`broke` on the fight wire, kind
   ESCAPE on an intent). A version 6 partner has no hellbender on its chart,
   would fight it at full health, and would sit in a broken-off fight
   waiting for a turn that is never coming.
8: a build names its manufacturer as `manufacturer` rather than `maker`,
   for the hull and for every part on it. A version 7 partner sends a key
   nothing reads, so `from_wire` falls to its `&""` default and the ship
   arrives as an unbranded frame with every part stripped of its
   manufacturer — and therefore of its set count.

   IT ARRIVES THAT WAY SILENTLY, which is why this entry is worth more
   than the rename that caused it. The keys moved in the vocabulary pass
   and this number did not, so the handshake matched. So did
   `content_fingerprint`, which hashes module ids, enemy ids, hull
   manufacturer/weight pairs and affix names — the TABLES, not the wire —
   and the rename touched none of them. Both doors opened on a protocol
   break. The `&""` defaults exist so a malformed build cannot take the
   sector screen down; here they turned a loud failure into a quiet wrong
   one, which is the trade they make and the reason the number matters.
9: the hello carries the BUILD (`BuildInfo.stamp()`: version and commit, or
   "dev" from source), and two exported builds that differ refuse each other
   by name -- "Your friend is on build X; you're on Y." A code-only change
   between two builds (combat, flight, UI) left the protocol and the content
   tables alone, so they connected silently and disagreed later. A version 8
   partner sends a hello one argument short, which this one cannot read.
10: the dive carries the HOST'S UNLOCKS (`_begin_dive`'s second argument,
   `dive_unlocked`). What a wreck, a shelf or a derelict can hold is drawn
   from the manufacturers the run has unlocked (`LootGen.can_appear`), and a
   party's world is one world, so every machine rolls it from the host's
   list. A version 9 partner receives a dive one argument long and would
   roll from its own profile instead: two ships at one derelict opening two
   different hulls, with nothing on either screen saying why.
11: fights opened by an option or an arrival are SHARED (Router.start_ambush),
   and a ship says where it is INSIDE its system (`report_spot`, pushed as
   `_spot_to`), so the SECTOR map draws partners flying round it. A version
   10 partner opens its option fights privately -- a JOIN that can never
   find them -- and sends no spot, so it is never drawn on the map.
12: a guest tells the host the galaxy it built (`_galaxy_at_host`), and a
   galaxy that differs from the host's is said on every screen
   (`_galaxy_differs`). A version 11 partner sends neither.
13: TWO SUNS (ruling 20). A system can have a second star, and a ship can be
   in a close orbit of it: a spot's `body` may be `SystemLayout.STAR_B`
   (-4), sent the way -1 is, since both stars hold still. `galaxy_print`
   hashes each system's `twin`, so two builds that disagree about which
   systems have two suns say their galaxies differ. A version 12 partner
   reads a -4 spot as nowhere and draws the ship at the edge, and lays every
   twin system out round one star.
14: THE PAIR TURNS (ruling 23, Jon, Nov 1: "Orbiting pair"). A binary's suns
   go round their balance point on each system's map clock, so a spot says
   the sender's map clock (`t`), and a spot in either star's close orbit, or
   settled round one sun, goes as the offset from that sun (`host`, the
   settle's `ShipFlight.f.cen_id`), as a world's always has; a ship round
   both suns, or flying, goes as the plane point it is. A system's map clock
   is the party's: a map or LOCAL opening it takes the farthest on a partner
   has said, run on since while that partner's map runs (`held` says it does
   not), `adopt_clock`. A version 13 partner sends a spot three numbers
   short, which this one cannot read, and would draw a ship at star B where B
   stood on another machine's clock.
15: HALF THE STATIONS, SPACED (Jon, Nov 3, S3: `MapGen._place_stations`).
   A version 14 partner builds twice the stations from the same seed, two
   of them often a jump apart, so its galaxy is not this one. `galaxy_print`
   hashes each system's type, so the dive would say so anyway; the version
   says it at the door.
16: ONE CUSTODIAN FOR THE GALAXY (Jon, Nov 4: "The custodian strength and
   icon should be the same for everyone in the galaxy, even if they join
   late."). It grows on the most jumps any ship in the dive has made. A
   presence says the sender's jumps (`_my_jumps`), the host keeps the highest
   (`galaxy_jumps`) and pushes it whole (`_push_growth_to`), at the door too,
   and a fight says the count its hull was grown at (`SharedFight.grown`),
   which the host raises to the galaxy's, mid-fight too (`_regrow`). A
   version 15 partner sends a presence one number short and grows the
   Custodian on its own jumps.
17: FAST TRANSFERS AND FASTER WORLDS (Jon, Nov 4-5). The worlds turn
   `SystemLayout.WORLD_PACE` times faster, so a version 16 partner's worlds
   stand somewhere else at the same clock. A flight lasts about 3 s and bends
   round the stars, and the spots (one every SPOT_EVERY_MS, eased) cut its
   chord, so the flier says the whole flight once, reliably, as it starts
   (`report_flight`: its path from the ride round to its departure to its
   spin-down onto the ring after, burns, place left and place to, on its own
   map clock), and a cancel if it lets go of it; every partner draws the ship
   on that path (`flight_of`), each end moved with its place to this
   machine's clock and held where the sender's clock holds
   (`SystemMapScreen.partner_points`, `sender_clock`); a ship joining while
   one flies is told it (`_tell_flight`).
```

## Take timeout

Above `const TAKE_TIMEOUT: float = 3.0`:

```text
How long a contested option waits for the host to say who got it.

Generous. A relay round trip is well under 200 ms and this only runs when a
player has clicked something, so the cost of being patient is nothing and the
cost of giving up early is a wreck the player watched themselves reach first.
If the host really is gone the session fails on its own and this refuses,
which is the right way round: refusing costs one wreck, assuming costs the
party's whole economy.
```

## Lead ship jumps

Above `var galaxy_jumps: int = 0`:

```text
THE LEAD SHIP'S JUMPS: the most jumps any ship in this dive has made, which
never goes down (PROTOCOL 16). The Custodian grows on it, for everyone
(`RunState.custodian_jumps`). The host's is the authority, folded from every
presence's jumps (`_fold_growth`); a guest's is the host's last push. A max,
so reports arriving in any order, or twice, give the same answer, and a ship
behind the lead, a late joiner or a rejoiner at jump 0 adds nothing. Here
rather than only on `Run` so `-- nettest`, whose peers share one Run, can
see each machine's copy. 0 until the dive; cleared with the session, while
`Run.party_jumps` keeps the figure for a ship that flies on alone.
```

Above `@rpc("authority", "call_remote", "reliable")`:

```text
THE LEAD SHIP'S JUMPS, from the host, whole (PROTOCOL 16). Adopted only in a
dive and never lower, so a push overtaken by this ship's own jump changes
nothing. `quiet` is the door's (`_hello`): the joiner counts the eye it is
shown as already seen, as a loaded save does, so its first screen has no
arrival for jumps it never saw. The session's copy always takes it; the run
only on the dive's galaxy (`_on_dive_galaxy`), so a pilot who died and
pressed NEW RUN keeps the old dive's count off the new galaxy. A run started
on the dive's seed after the push takes it in `_on_run_started`.
```

Above `func _regrow(f: SharedFight) -> bool:`:

```text
A fight grown at less than the lead ship's count grows to it now (decision
2: its hull bar rises, damage done stays done; `SharedFight.regrow`). Every
crew machine adopts the numbers and says so in its log (`Combat._adopt`).
True when a hull moved, for the caller to push; a count that grows nothing
(asleep, or past the cap) raises the fight's `grown` and the next push
carries it.
```

## Build cache

Above `var _builds: Dictionary = {}`:

```text
Everyone's ship, resolved from the wire and kept until the wire changes.
Keyed by peer id, holding `[fingerprint, ShipBuild]`.

The fingerprint is what makes this a cache rather than a delay. A roster
arrives as a whole and REPLACES every slot, so four ships are new objects
every time one player vents a point of heat — and a partner's build being a
new object is what a view uses to decide it has to repaint. Repainting a hull
is fifteen thousand pixels of GDScript, three times over, several times a
turn. So the wire is fingerprinted and an unchanged ship comes back as the
same object it was.
```

## Claims

Above `var claims: Dictionary = {}`:

```text
What the party has used up: `{node index: {option id: peer id}}`.
Host-authoritative and pushed whole.

THE MAP IS ONE INSTANCE, NOT FOUR COPIES. This is the line that decides it,
and it is worth being explicit because the seed alone implies the opposite. A
shared seed gives four machines an identical galaxy: the same systems, the
same fights, the same wrecks holding the same modules, because everything a
node holds is drawn from `Rng.derive(tag, node.index)` and therefore depends
on WHERE it is rather than on who asked. What a seed cannot say is whether
somebody has already been there. Without this list four players strip the
same derelict and each keep the Legendary, and `docs/coop-design.md` §3's closed
per-dive economy is paid out four times.

Whole rather than incremental. A dive consumes tens of systems, not
thousands, and a list that is rebuilt from scratch on every push cannot drift
— which an append-only stream of deltas can, the first time one is dropped
or arrives twice.

AN OPTION, NOT A SYSTEM. A system that offers three or four things to do is
not one resource: one ship strips the wreck and another still wants the
fight, so the unit has to be the option. `MapGen.OPTION_WHOLE` is the id for
an encounter that consumes the system entirely, which is every encounter that
exists today — so a node with one thing to do carries exactly one entry.

AND WHO TOOK IT. The peer id is not bookkeeping: arriving at a wreck that
says "Mercer stripped this" is the whole social texture of flying together,
and it is the difference between a system that is empty and a system that
somebody emptied.
```

Above `@rpc("any_peer", "call_remote", "reliable")`:

```text
"I have used this up." Only the host keeps the list.

The message is a NODE INDEX and an OPTION ID and nothing else. What was in
the system does not travel, because it never had to: `Rng.derive(tag,
node.index)` already puts the same modules in the same wreck on every
machine. This says the wreck is empty now, which is the one fact a seed
cannot carry.
```

Above `func claim(index: int, option: int = MapGen.OPTION_WHOLE) -> void:`:

```text
Use something up, without waiting to hear whether you got it.

For the outcomes you cannot lose a race for: the fight you just won, the hail
you were already inside. Nobody else can arrive and take those out from under
you, so the round trip would buy nothing.

Safe to call in the solo game, where it does nothing at all — which is why
every call site could be changed without gaining a branch.
```

Above `func take(index: int, option: int = MapGen.OPTION_WHOLE) -> int:`:

```text
Ask for something only one ship can have, and wait for the answer. Returns
the peer id that owns it — yours if you won.

ASK, DO NOT ASSUME. This is the half `claim()` gets wrong on purpose and this
one has to get right. Two ships reach the same wreck in the same second; both
mark it locally, both roll the loot, and the flag agreeing a moment later
does not take the module back out of the loser's hold. One wreck, two
Legendaries, and `docs/coop-design.md` §3's closed economy paying out twice.

The host already resolves the race correctly by doing nothing clever:
`_apply_claim` ignores an option somebody already owns, so the first message
to arrive wins and every later one is told who did. All the client has to do
is wait to be told, and a click is exactly the kind of moment that can afford
a round trip.

A timeout refuses rather than assuming. See TAKE_TIMEOUT.
```

## Shared fights

Above `var fights: Dictionary = {}`:

```text
The fights the party is in, as `{node index: SharedFight}`.

THE ENEMY IS THE SHARED OBJECT. Nothing about your own ship is in here, and
that is not an omission — see SharedFight's header. A fight has exactly one
thing in it that several players touch at once, and it is the hull they are
all shooting at.

Host-authoritative like `claims`, and pushed one fight at a time rather than
whole: a fight changes several times a turn while claims change a few times
an hour, and four people in three different systems have no use for each
other's enemy bars.

Kept after `over` rather than deleted. A fight ends by the host saying so,
and the message that says so is the same push everything else arrives on —
dropping the entry would leave the last one with nowhere to land. They are
cleared with the rest of the session.
```

Above `func open_fight(index: int, ids: PackedStringArray, hp: PackedInt32Array,`:

```text
Engage at a system, alone or beside whoever is already shooting.

`hp` and `brace` are what the caller's own `Combat._spawn` produced. They are
passed in rather than worked out here so that danger scaling, boss exemption
and the pack split stay in the one function that has always owned them — the
session layer is not going to grow a second opinion about how tough a frigate
is.

Returns the shared fight, or null. NULL IS A NORMAL ANSWER AND MEANS "FIGHT
IT ALONE": it is what the solo game gets, what a party of one gets, and what
a client gets once the party is gone. All three want the same behaviour,
which is the fight the game has always had.

THE ANSWER MAY NOT BE WHAT YOU ASKED FOR. One fight per system, and the host
seats a second asker in the first: a ship that planned Y here can be handed
X, opened a moment earlier by a partner whose push had not reached it yet
(the same-second race). The caller takes it whole (`Combat.begin` builds
the enemy from its ids; `Router.start_combat` says whose fight it is).

NO PRIVATE FIGHT WHILE THE LINK IS UP (Nov 5). This waited TAKE_TIMEOUT and
then said null, though the host might already have seated the ship: its
private copy never sent END TURN or a leave, so the party sat on "WAIT", and
at the core it was a second Custodian it could win the run against. A
reliable message arrives unless the link drops, and a dropped link is
`party_failed`, which ends the wait. Past TAKE_TIMEOUT, `Router` says
"Waiting for the host."
`cur` is the enemy's CURRENT hull, which is `hp` for everything except a
fight that opens against something already hurt — the hellbender carrying a
previous engagement's damage.
`grown` is the count the caller's hull was grown at (`Combat.grown`, -1 for
a fight with nothing in it that grows).
```

Above `func leave_fight(index: int) -> void:`:

```text
You are out of it — dead, fled, or done. Not optional: a crew list holding
somebody who will never press END TURN again is a fight that never takes
another turn.

A guest stops counting itself in its own copy AT ONCE. The host's push that
says so is a round trip away, and a ship that leaves and asks again (SAVE &
EXIT, then CONTINUE) checks this copy first: still listed, it was handed the
fight it left, joined to nothing, grown by nothing (review, Nov 5). The
leave is the host's own (`SharedFight.leave`): out of `ended` too, and a
fight with nobody left in it is over here at once, so the JOIN bar does not
offer an empty fight while the host's push is on its way. A push the host
sent before it heard puts this copy back as it was, until the next.
```

Inside `_open_or_join()`, above `f.join(by)`:

```text
Already somebody's fight. The second ship in is help, not a second
frigate — see SharedFight.join(). Its `grown` is ignored, as its hp
is: the fight's count is the galaxy's already. Its ids are ignored
too: it planned its own enemy, and this is the answer it takes.
A ship already seated asking again is answered all the same, with
nothing grown: an ask with no push behind it waits for one.
```

## Spots

Above `var spots: Dictionary = {}`:

```text
Where each ship is INSIDE its system, for the SECTOR map: `{peer id: {at,
body, x, z, ang, t, host, got}}`. The roster's `at` says which system; this
says where in it. A body >= 0 means "in orbit of / alongside that world" and
(x, z) is the offset from the world's centre, because a world's place on its
orbit is each machine's own clock -- an absolute position would put a
partner in orbit of nothing. Body -1 is the star (star A of two suns),
`SystemLayout.STAR_B` (-4) star B, -9 open space. A PAIR'S SUNS TURN
(PROTOCOL 14), so either star's close orbit is the offset from that star,
and so is open space settled round one sun (`host` -1 or STAR_B); open space
round both suns' balance point, which holds still, or flying (`host` -9) is
the plane point itself. One sun stays at the plane's origin at every t, so
there each is the very point it always was (`spot_anchor`,
`SystemMapScreen._report_spot`, `partner_points`). `t` is the sender's map
clock for the system as it said it (-1: none, as an arrival says), `held`
whether that clock had stopped (its map put away or held for a move), `got`
this machine's ticks (ms) when it came (`party_t`). -10: just arrived. An
empty entry: arrived, at the edge.

NOT on the roster. It changes several times a second while a ship flies,
and the roster is whole, reliable and rebuilt on every machine per change;
this is one small unreliable message, relayed by the host, last one wins --
except the one saying a map's clock stopped or started (`held`), which goes
reliably (`_spot_at_host_sure`): it is the last a map put away ever sends.
A partner's row goes when it leaves the party, on every machine
(`_push_roster_to`), not only the host's.
```

Above `func report_spot(at: int, body: int, p: Vector2, ang: float, force: bool = false, mt: float = 0.0, host: int = -9, held: bool = false) -> void:`:

```text
Where this ship is in its system, from the SECTOR map. Throttled here, so
the map can call it every frame: sent when it moved and SPOT_EVERY_MS has
passed, or at once when the system, the body or the sun it is said off
changed, and again every SPOT_BEAT_MS though it did not move (its clock runs
on). `body`, `p` and `host` as in `spots` (`spot_anchor`); `mt` this
machine's map clock for the system as `p` was measured, `held` whether that
clock has stopped there (sent at once, and reliably, when it changes).
```

## Galaxy check

Above `var galaxy_mine: Array = []`:

```text
THE GALAXY EACH MACHINE BUILT, as `[seed, systems, fingerprint]`.

The seed is the only thing about the galaxy that crosses the wire; every
machine builds the rest itself. Two machines that build DIFFERENT galaxies
from one seed -- a sine one bit apart on a Mac and a PC, a table a mod
changed -- agree on every index and disagree on what is at it, and nothing
else in the session can see that: a partner's `at` is a number that means a
different star. So each guest says what it built, the host compares it with
its own, and a mismatch is written to godot.log on both machines and said on
both screens (`PartyNotice`). Written before the Win<->Mac playtest of Oct 23,
when it was the only way to tell this apart from a network bug.
```

## Presence

Inside `_ready()`, above `Sig.ship_changed.connect(_mark_presence)`:

```text
Your ship, whenever it changes, so the party can draw it.

This is the one place the session layer reads run state, and it is worth
being explicit about why it is not a breach of the rule at the top of this
file. It does not move a ship or resolve anything: it forwards a picture.
The roster has carried `hull` since the first version for exactly the same
reason — what somebody is flying is a fact about the PARTY.
```

## Null multiplayer

Above `func is_host() -> bool:`:

```text
Both guarded on `multiplayer` itself: it is null while this node is out of
the tree, which is the frames a quitting game spends tearing its screens
down -- and a screen asking who it is then threw (`-- cojoin`, Oct 22).
```

## Content fingerprint

Above `static func sorted_ids(table: Dictionary) -> PackedStringArray:`:

```text
A table's keys as STRINGS, in alphabetical order. Sorted as Strings, never as
the StringNames they are: an Array of StringNames does not sort by its text,
so its order came out of how each process happened to start, and the same
exported build refused itself (one copy windowed, one headless) and the
editor refused the export ("Your content does not match the host's"). Found
Oct 20 testing two exports through the relay; `nettest` runs one process, so
it holds this order to the text itself.
```

Above `func content_fingerprint() -> int:`:

```text
A number that must match across the party, standing in for "we are playing
the same game". It covers the content tables rather than the build, because
two players on the same commit with different mods is the case that actually
happens, and a version string would call that a match.

Deliberately cheap and deliberately coarse. It cannot tell you WHAT differs,
only that something does — the message it produces sends the player to
compare builds, which is the only useful action anyway.
```

Inside `content_fingerprint()`, above `parts.append(GalaxyGen.table_fingerprint())`:

```text
THE GALAXY TABLE, because two peers whose kinds differ lay out DIFFERENT
MAPS from the same seed -- ring populations and every system's position
read it. They would otherwise agree on the fingerprint, connect, and then
disagree about where the galaxy is. Added in the same commit that added
the fields, which is the rule ENCOUNTER_REBUILD 9 states for this class of
bug. GalaxyGen owns the description; see its `table_fingerprint`.
```

Inside `content_fingerprint()`, above `var opt_ids: PackedStringArray = []`:

```text
AND THE OPTION TABLE, for the same reason and by the same rule. What a
system holds is derived POSITIONALLY off `Rng.derive(&"options", index)`,
so two peers whose pools differ roll different lists at the same node --
and would otherwise agree on the fingerprint, connect, and disagree about
what is in front of them. Ids only: the prose is copy and may be edited
without splitting a party, while adding or gating an option may not.
```

## Failed join

Inside `_process()`, above `var peer := multiplayer.multiplayer_peer if multiplayer != null else null`:

```text
A peer that has gone away while we were still joining is a failed join,
whatever the engine did or did not emit about it. Watching the status
directly rather than waiting for a signal is what makes a refusal
immediate: the relay answers "the party is full" in milliseconds, and
without this the player sat through the full ten-second handshake timeout
before being told — an instant answer, delivered late, reads as a hang.
```

## Handshake

Above `@rpc("any_peer", "call_remote", "reliable")`:

```text

Host side is `_hello` and nothing else: one message in, a decision, and
either a roster broadcast or a refusal. Everything the host needs to refuse
is in that one message, so a client that is going to be turned away is turned
away before it has been told anything about the party.
```

## Late joiners

Inside `_hello()`, above `if state == State.DIVING and dive_seed != 0:`:

```text
INTO A DIVE ALREADY UNDER WAY. The seed went out once, at LAUNCH, to
whoever was here then -- so a friend who joined after it (or whose game
fell over and who typed the code back in) was accepted, seated, and left
on "The host starts the dive." for good (`-- cojoin late`, Oct 22). Told
now, with everything else a seed cannot say: what the party has used up,
where the hellbender is, and the fights open.
```

## Presence relay

Above `@rpc("any_peer", "call_remote", "reliable")`:

```text
"This is my ship, and this is where it is." Through the host like everything
else, rather than peer to peer.

Client-to-client would be one hop shorter and it is not worth having: the
host is the authority, `_push_roster()` is already the tested path for
telling four machines one fact, and the relay transport routes through the
host anyway. One message shape, one direction, one place it can go wrong.

The ship and the position travel together because they change for the same
reasons and neither is worth a message of its own. A jump moves you and
cools you; a fight damages you and heats you.
`jumps` is the sender's own (`_my_jumps`, PROTOCOL 16), or -1.
```

## Hello handshake

Above `func _on_connected() -> void:`:

```text
Say hello, once, however the news arrives.

ENet makes SceneMultiplayer emit `connected_to_server`. A custom peer may
instead only produce `peer_connected(1)` — the host appearing — depending on
how the engine derives one from the other. Both are wired, and the flag makes
the second one harmless. A handshake that fires twice is a refused duplicate;
a handshake that never fires is a party that never forms, and the transport
it fails on is the one nobody has tested yet.
```

## Transport reasons

Above `func _why(fallback: String) -> String:`:

```text
What the transport says, if it knows something better.

A MultiplayerPeer has nowhere to put a sentence — it can report that a socket
closed and nothing about why — so a relay that politely answers "the party is
full" and then hangs up arrives here as an ordinary disconnect, and the
player is told to check a port that has nothing to do with it. The transport
keeps the real reason; this is the only place that asks for it.
```

## Party map clock

Above `static func spot_anchor(L: SystemLayout, body: int, host: int, t: float) -> Vector2:`:

```text
WHAT A SPOT IS SAID OFF (PROTOCOL 14), on layout L at map time t: the world
for body >= 0; star A or B for either star's close orbit; for open space
(-9), the sun it is settled round (`host` -1 or STAR_B), else nothing (the
plane's origin: a ship round both suns, or flying, is the plane point it
is). The sender takes it off at its own clock (`SystemMapScreen._report_spot`)
and every other machine adds it back at its own (`partner_points`), so a
partner on a sun's orbit is drawn on that sun wherever the pair stands
there. One sun: its star is the origin at every t, so a star's spot is the
point it always was.
```

Above `func party_t(at: int) -> float:`:

```text
THE PARTY'S CLOCK FOR SYSTEM `at` (PROTOCOL 14): the farthest on of the map
clocks its partners there have said, each run on by the time since it came
while the sender's map is up (map time is wall time there, the sender's as
this one's) and not once it said its clock holds (`held`: its map put away,
or held for a move), or -1.0 when none has said one. Run on regardless, a
partner gone to LOCAL or a fight kept a clock that ran on with nobody
watching, and the next map here jumped the pair by the whole time (review
1). An arrival's spot says none (-1). Only a partner in the party and in
that system counts, as `SystemMapScreen.partner_points` draws only those: a
leaver's last row stayed on every guest (only the host erased it) and ran
on there for good (review 2).
```

Above `static func clock_to_open(own: float, party: float, keep_own: bool) -> float:`:

```text
THE CLOCK A MAP OPENS AT (PROTOCOL 14): its own, or the party's when that is
further on -- never back, which would undo what both machines have seen,
and not where its own ship was put away coasting (`keep_own`: a free ship
not settled is put back at the very plane point it was, and the suns moved
on under it). Anything else is put back relative to what it circles (a
place by its offset, a flight left on its way at its end, a settle round a
sun with that sun, `adopt_clock`), so a jump moves it all together. (It
guarded a flight once, but a flight left on its way is never flown again:
the ship is put down where it was going, `SystemMapScreen._restore_ship`.)
```

Above `const CATCH_CUT := 20.0`:

```text
THE CLOCK A MAP HANDED ITS PAIR BY LOCAL OPENS AT (`Router.pair_handed`):
the kept one, the angle LOCAL showed, while the party's is less than
CATCH_CUT on from it, and the map catches up from there
(`SystemMapScreen._catch_up`). Further behind, the party's at once
(`adopt_clock`): LOCAL holds the clock for its whole visit while a
partner's map runs, so the gap is the time spent there, and caught up a
little faster than time it took four times that (40 minutes after 10 in
LOCAL), the pair at another angle on each machine and a partner flying drawn
off it all the while (review 2). One cut at the swap instead.
```

Above `func adopt_clock(at: int) -> float:`:

```text
A MAP OR LOCAL OPENING SYSTEM `at` takes the party's clock (`clock_to_open`):
kept in `Run.map_clock`, so whatever opens next opens on it too. The clock
to open at; its own, alone or offline. A ship parked settled round one sun of
a turning pair goes with that sun to where it stands at the new clock, so the
map (`ShipFlight.restore_free`) and LOCAL (`LocalSky._situate`, which reads
the parked point as it is) put it in one place, on its circle round that sun.
```

Above `static func carry_parked(L: SystemLayout, d: Dictionary, own: float, t: float) -> void:`:

```text
A PARKED FREE SHIP SETTLED ROUND ONE SUN of a turning pair (`d`, a
`SystemMapScreen._parked` record), its plane point carried with that sun from
where it stood at map time `own` to where it stands at `t`. LOCAL reads the
point as it is; the map put it back on its circle round the sun along the
line to it, so with the clock moved on under it the two disagreed about how
far it was from its sun and which sun lit it (review 1).
AND A SHIP PARKED ON A RING, its point and its motion carried with its
place (a world, or either star's close orbit), so the map puts it back at
the very offset it rode at (`SystemMapScreen._restore_ship`, review 2).
```

## Seat order

Above `func seat() -> int:`:

```text
Which ship in the party this machine is: 0 for the host, then arrival order.

ZERO WHEN FLYING ALONE, and that is what makes it safe to salt a solo run's
streams with — see `Rng.seat`. The order is assigned once by the host and
travels with the slot, so it does not shuffle when somebody reconnects the
way a peer id would.
```

## Enemy turn

Above `func _swing(f: SharedFight) -> void:`:

```text
The enemy turn. The one moment in a shared fight that is not free-running,
because it is the one moment a shared object acts on several private ones.

Each hull swings at ONE ship and the message goes to that ship alone. What
happens next — dodge, block, brace, hull, feedback — is resolved on the
victim's machine against its own `Run`, because those numbers live nowhere
else and no other player has any use for them. Mirroring three partners'
block values across the party would be a lot of wire for something nobody
reads.
```

## Target weighting

Above `func _who_gets_hit(f: SharedFight) -> int:`:

```text
Who it swings at. Weighted by heat, and heat is already on the wire.

THE FIELD REACHES INSIDE THE FIGHT. `docs/coop-design.md` §6 makes signature the
dial for flying together, but every consequence it lists happens on the map —
ambushes on arrival, a Stealth penalty, the overheat burn. This is the same
rule one level down: the loudest ship in the room is the one being shot at.
It gives the Korvan line a job it can do for the party (soak, run hot, hold
the attention) and it makes venting a thing you do FOR somebody rather than
only to survive your own reactor.

The floor is the point. 0.5 base against a ceiling of 0.5 + 1.7 means a
redlining ship draws roughly four times the fire of a cold one and a cold one
is still never safe — a target rule with a zero in it is a party that solves
the fight by electing a victim.
```

## Partner flights

Above `var flights: Dictionary = {}`:

```text
EACH PARTNER'S FLIGHT UNDER WAY (PROTOCOL 17): peer id -> {at, from, to, t0
(its first point, on the sender's map clock), dt (s between points), pts
(PackedVector2Array, plane), burns (PackedByteArray), said (the sender's clock
as it said it), got (this machine's msec as it came), host (the sun the
place left goes round, for an orbit round one sun of a pair: -9 none),
dep_s and arr_s (s from t0 to its departure and its arrival: the ride before
and the spin-down after are its places')}. Dropped with the partner's spots.
```

## Flight point

Above `static func flight_point(fl: Dictionary, L: SystemLayout, t: float, now_ms: int, sp: Dictionary = {}) -> Array:`:

```text
WHERE A PARTNER'S FLIGHT HAS IT NOW (PROTOCOL 17), on layout L at this
machine's map clock `t`: its path at the sender's clock now (`sender_clock`,
its spot `sp`), each end moved with its place to this clock (the place left,
round its sun `host`, as it rides round to its departure; the place gone to
from its arrival and its spin-down onto the ring; blended by smoothstep
along the flight between), so a flight said from a clock seconds apart
still leaves from its world here and lands on its target. [point, screen
angle, burning], or [] when it is not flying now.
```

## Sender clock

Above `static func sender_clock(fl: Dictionary, sp: Dictionary, now_ms: int) -> float:`:

```text
THE SENDER'S MAP CLOCK NOW for flight fl (as this machine's msec now_ms),
its spot `sp` beside it: run on from when the flight was said; held where a
spot said since that its clock holds (a zoom move, LOCAL); and by the spot's
own clock where that is a quarter second or more off the flight's (its
clock held and let go since), so the partner is not flown on by the wall
clock while the sender's ship stands still, and snapped back after (the
code review, Nov 5).
```

## Report flight

Above `func report_flight(at: int, key: int, from: int, to: int, t0: float, dt: float, pts: PackedVector2Array, burns: PackedByteArray, said: float, shape := PackedFloat64Array()) -> void:`:

```text
A FLIGHT LEAVING (PROTOCOL 17), said once as it starts to fly, reliably: its
path decimated to `dt` apart (about 60 points a second), its burns, where it
left from and goes to, and its first point's time on this machine's map
clock `t0` and the clock as it is said `said`. `to` -9 lets go of the last
one said (W off it). Throttled by the plan (`key`): the same flight is said
once.
(`shape` [host, dep_s, arr_s]: the sun the place left goes round, -9 none;
the seconds from t0 to its departure and to its arrival. It is said from the
ride round to its departure on, and its spin-down onto the ring after: a
twin's 17.6 px ring at pace 8 goes 2.4 rad between two spots, and the
partner drawn by them cut across it, the code review, Nov 5)
```
