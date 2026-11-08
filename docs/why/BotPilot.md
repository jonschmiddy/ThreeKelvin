The reasoning behind `tkg/scripts/net/BotPilot.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Bot as player

Above `const THINK_DEFAULT: float = 25.0`:

```text
A ship in the party that nobody is sitting in front of.

  godot --headless --path . -- bot join ABC-123
  godot --headless --path . -- bot join ABC-123 mailbox=/tmp/crew think=30
  tools/bot.sh ABC-123

It is a PLAYER, not a spectator and not a service. It joins by lobby code
like anybody else, gets a peer id from the relay, rolls its own chassis, and
from that moment holds its own `Run` — its own hull, hold, heat, credits and
`Rng` seat. Nothing about the party knows or cares that the pilot is a
program. That is not a flourish; it is the only design that works, because
`Run` is a singleton and one process therefore holds exactly one ship.

THE PRICE IS A SEAT. `NetTransport.MAX_PLAYERS` bounds the party and the
relay's door policy enforces it, so a bot in the party means one fewer human.
There is no spectator slot to hide in and adding one would mean the relay
counting something it deliberately does not count.

Stated without the number on purpose. This paragraph said "four" and went on
saying it after the cap became eight — the same bump that left NetTest
asserting a four-seat party in nine places. A comment that repeats a constant
is a second copy of it.

WHY NOT READ THE RELAY INSTEAD. The obvious cheaper idea is to watch the
Cloudflare Durable Object and narrate. It does not work, twice over.
`relay/src/index.js` never opens a payload — it checks byte 0, rewrites the
sender id and forwards — so what is on that socket is Godot's binary RPC
frames and nothing else; reading them means reimplementing the engine's
serialiser. And the relay cannot invent a peer, so even after all that the
result is a spectator with no ship, no hold and no cards. The seat is the
feature. See docs/netcode.md §7.
```

## Shot clock

Above `const THINK_DEFAULT: float = 25.0`:

```text
How long a remote brain gets to answer before the autopilot takes the turn.

THE SHOT CLOCK IS NOT OPTIONAL, and it is the single most important number in
this file. `SharedFight.end_turn()` is a barrier: the enemy does not swing
until every ship in the fight has ended its turn, so a bot that is still
thinking is three other people watching a static screen. A brain with a
language model behind it answers in seconds and occasionally in minutes, and
"occasionally in minutes" is a hung party.

So the deal is: the board is offered, an answer is waited for, and when the
clock runs out `Policy` plays the turn and the fight moves on. The bot is
allowed to be slow. It is not allowed to be slow at everybody else.
```

## Following

Above `var follow: bool = false`:

```text
Fly toward the rest of the party rather than off on its own dive.

Without this the bot is a fourth ship in the same galaxy, which is not the
same thing as a crewmate: everybody flies their own route, the routes diverge
on the first fork, and the shared fight — the one feature the party actually
has — never once happens. `Policy.choose_jump` is a SOLO player's model and
correctly so; it has no concept of anybody else being on the map.

Following is deliberately dumb: take a link somebody is standing in, else
take the link that moves toward the nearest of them, else HOLD. Pathfinding
across the whole galaxy would be a better bot and a worse crewmate — it would
arrive by a route nobody watched it take.

HOLDING IS THE HALF THAT MATTERS, and it is the half the first version was
missing. A headless ship plays a complete run in about forty seconds; a
person takes an hour. So a bot that only ever moves TOWARD the party arrives
at their system, wins the fight, and is four jumps deeper before anybody
lands — the two ships visit exactly the same systems and never once meet.
Two bots flown against each other did precisely that: identical first two
fights, identical payouts, not one shared enemy between them.

So a following ship does not leave a system somebody is in, and does not jump
anywhere that does not close the distance. Standing still is a move.
```

## Board numbers

Above `var _seq: int = 0`:

```text
Every board gets a number and every move must quote it.

Without this a move written while the bot was mid-decision applies to the
NEXT board — the brain answers "play 2" about a hand it can still see, the
card is drawn and discarded in the meantime, and 2 is now something else
entirely. A stale move is not a wrong move, it is a move about a different
game, and it has to be dropped rather than clamped.
```

## Patience

Above `const PATIENCE_DEFAULT: float = 150.0`:

```text
How long a wingman waits on a party that is not doing anything.

HOLDING HAS TO EXPIRE. Two following ships that find each other both see a
partner in their own system, both decide the right move is to stay, and both
stay — forever. Flown, and it is not a hypothetical: two bots met at system 7
and sat there until they were killed. The same shape catches a bot whose
human closed the lid.

The clock resets on any sign of life — anybody moving, a fight opening,
anybody arriving or leaving. So it is not a timeout on the wait, it is a
timeout on NOTHING HAPPENING, which is the thing actually worth giving up on.
Generous by default, because a person at a station picking over a shelf looks
exactly like a person who has stopped playing, and of the two mistakes,
abandoning somebody mid-shop is the worse one.
```

## Next system

Above `func _next_system(here: MapGen.MapNode) -> int:`:

```text
Where to go next: an index, HOLD, or -1 for nowhere.

Deciding and moving are separate because HOLD has to be expressible. A
function that jumps cannot return "do not jump" — the first version returned
a bool and had no way to say it, which is how the bot ended up outrunning the
party it was supposed to be flying with.
```

## Wingman rule

Above `func _wingman(here: MapGen.MapNode) -> int:`:

```text
The wingman rule: go where they are, move toward them, or stay put.

Distance is measured in map position rather than in jumps. A jump count would
need a search over a graph that changes as the party moves through it, and it
would buy nothing: what this has to answer is "which of these four systems is
the one toward them", and a straight line answers that correctly almost every
time and harmlessly the rest.

Returns -1 only when there is nobody left to follow, which hands the run back
to Policy — a lone survivor should finish the dive rather than orbit an empty
galaxy waiting for ships that are not coming.
```

## Follow order

Inside `_wingman()`, above `var mine := Net.seat()`:

```text
A WINGMAN FOLLOWS THE SHIPS THAT WERE HERE BEFORE IT. Seat order, and
nothing cleverer, because the alternative was flown and it deadlocks: two
ships that both follow mirror each other exactly. A leaves for the next
system, B follows, A sees B gone and follows back, and the pair bounce
between two stars until the tank runs dry. That is not a bug in the
distance maths — it is what "follow whoever is nearest" MEANS when the
other ship is running the same line of code.

So the order in the roster breaks it: seat 0 leads and never follows,
every later seat follows the seats before it. The host is the human who
opened the party, which is also the right answer socially.
```

## Shelf claims

Above `func _buy(n: MapGen.MapNode, slot: int) -> void:`:

```text
Reach for a shelf slot, and ASK THE PARTY FIRST.

This is the same claim StationScreen makes when a person clicks it, and it
goes through the same `Run.take_option`, so the bot loses the same races a
human loses and for the same reason. Doing it any other way — buying locally
and telling the party afterwards — is how the shop duplication bug worked.
```

## File mailbox

Above `func _ask(board: Dictionary) -> String:`:

```text
Offer the board, wait for an answer, and give up on time.

Files rather than a socket, and that is a considered choice. Godot has no
HTTP server in it, so a socket here means hand-rolling one and a protocol to
go with it, to talk to a process on the same machine. Two files in a
directory need none of that and they have a property a socket does not:
ANYTHING THAT CAN WRITE A FILE CAN PLAY. A shell one-liner, an MCP server, a
person with a text editor and a slow hand — same interface, no client
library, and the whole conversation is on disk afterwards to read back.
```
