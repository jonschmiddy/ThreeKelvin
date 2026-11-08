The reasoning behind `tkg/scripts/net/NetTransport.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Transports

Above `enum Kind { DIRECT, ROOM, PLATFORM }`:

```text
How four machines are joined. Nothing above this line knows or cares.

There are only three real answers to "how do a host and three friends find
each other across the internet", and they differ in what they need from the
world, not in what the game does with them:

  DIRECT    ENet straight at the host's address. Needs a forwarded port or
            an open NAT. Costs nothing and depends on nobody. Works today.
  ROOM      A rendezvous service hands out room numbers and either punches a
            hole between the peers or relays the traffic itself. Needs a
            machine that is always up, and a bill.
  PLATFORM  Steam, or Epic. The platform is the rendezvous service and the
            relay, at no cost, for players who own the game on it.

This class exists so that choosing between them stays a one-line decision
for as long as possible. NetSession never names a transport; it asks for a
peer and gets one. The lobby code is the seam: every transport can produce a
string and consume the same string, and that is the whole contract.

The interface is deliberately thin. Godot's MultiplayerPeer is already the
abstraction for moving packets — re-wrapping it would buy nothing. What
Godot does NOT abstract is the part before the packets: finding the host.
That is the only thing this adds.
```

## Max players

Above `const MAX_PLAYERS: int = 8`:

```text
How many ships one galaxy holds. The number lives here rather than in
NetSession because a platform transport gets it from the lobby it created,
and would otherwise have two of them to keep in step.

IT IS ALSO IN `relay/src/index.js`, and the two must agree. Both ends police
the door independently — the relay denies with "The party is full." and
`NetSession._hello` refuses at `roster.size() >= MAX_PLAYERS` — so a mismatch
is a player the relay lets in that the host then turns away, which reads to
them as a random disconnect. Raise both or neither.

EIGHT, RAISED FROM FOUR AND FLOWN BEFORE IT WAS RAISED. `tools/coplay.sh 6`
put six windows in one party on one code: six ships readied, one seed, the
same 161-system galaxy on every machine, and no errors in any of the six
logs. Nothing in the session layer had an opinion — the seed is one integer
however many receive it, seat salting is `_mix(base, seat)` for any seat, and
claims, the bag and `SharedFight.crew` are lists that simply got longer.

What did have an opinion was the interface, twice, and both are fixed rather
than tolerated: the lobby roster had no scroll and pushed READY and LAUNCH
DIVE off a 540px viewport at about six ships, and the convoy strip is a
fixed-height column measured for three partners. See LobbyScreen._build_party
and EncounterView.CONVOY_MAX.

What is still only argued: `SharedFight.CREW_SHARE` is linear with no ceiling
and has been flown at two. An eight-ship custodian is 200 + 7x120 hull early,
up to 400 + 7x240 (2080) from jump 33, since it grows with the lead ship's
jumps (`EnemyTemplate.hull_at`, `NetSession.galaxy_jumps`) and each joiner
adds 0.6 of the grown hull. That is
against eight hands of cards, and nobody has played it. The cap allows it; the
tuning has not been done.
```

## Transport from code

Above `static func for_code(code: String) -> NetTransport:`:

```text
The transport a code belongs to, from the code itself.

Joining should never ask which kind of party this is. `LobbyCode` already
tells a room number from an address by its first character, so the answer is
in the player's hand before they press anything — and a wrong choice here
would fail as "could not connect", which is the least useful sentence in
networking.
```
