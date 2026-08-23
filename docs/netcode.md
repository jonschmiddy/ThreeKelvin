# THREE KELVIN — Netcode
*Companion to `coop-design.md`. That document decides what four players do to each other. This one decides how their four machines are joined, and what it costs to join them. Draft v0.1 — the session layer is built and tested; the transport under it is a decision, not a fact.*

---

## The short answer

**No, you do not need Steam.** Steam is one of four ways to get a host, a code and three friends who can reach it, and it is not the cheapest one to start with. It is, however, probably the one you ship on.

Those two sentences are not in tension. The transport is swappable; the session layer above it is not, and the session layer is where the bugs that ruin an evening live. So the session layer is built first and once, and the transport question stays open for as long as it can.

**What is built and passing today:** a host opens a party, gets a code, and three friends join it by typing that code. The roster reaches every machine, mismatched builds are refused by name before anybody wastes forty minutes, a fifth player is turned away in words rather than by silence, and a launch puts the same galaxy seed on all four machines. Four peers, one process, no hardware:

```bash
godot --headless --path . -- nettest
```

**What is not:** the code today carries an IP address, so the host needs an open port. That is the only piece Steam or a relay replaces, and it is deliberately the last piece.

---

## 1. The four transports

Every answer to "how do a host and three friends find each other" is one of these. They differ in what they need from the world, not in what the game does with them.

| | Needs | Costs | Player friction | Ships on |
|---|---|---|---|---|
| **Direct** | A forwarded port on the host | Nothing | Very high | Anywhere |
| **Rendezvous** | A machine that is always up | ~$5/month, forever | None | Anywhere |
| **Steam** | Steamworks, and everyone owns it on Steam | $100 once | None | Steam only |
| **Epic Online Services** | An EOS app, and an account per player | Nothing | One account | Anywhere |

### Direct — built, tested, and not shippable alone

ENet straight at the host's address, with the address folded into the lobby code. `DirectTransport`.

This needs no service, no account, no bill and no dependency that anyone can switch off. It also asks the host to forward a port, which most players cannot do and some cannot do at all — carrier-grade NAT is now common enough that "forward the port" is not always available advice.

It earns its place anyway, for one reason: it is the only transport that can be tested on one machine with no external parts. Every rule above it — the roster, the handshake, the version check, the launch — is already proven through it. A relay arriving later inherits a session layer that has been made to work, instead of being the thing that has to prove it.

**Verdict: keep forever as the LAN and the fallback path. Never the only one.**

### Rendezvous — a room number and a small server

A machine on the internet hands out room numbers and either introduces the two peers to each other (hole punching) or carries their traffic (relay). The lobby code becomes a room number instead of an address, which is why `LobbyCode` already has both kinds and tells them apart by the first character.

This game is an unusually good fit and it is worth being specific about why. Three Kelvin is turn-based. The session layer sends a roster and a seed. Even a full co-op build sends card plays and jump commits — events, not state, and at human speed. **A relay for this game is measured in kilobytes per party per minute.** One $5 virtual machine carries hundreds of simultaneous parties, and the bill does not move until the game is a success.

Hole punching is cheaper still and fails on some networks, so a relay fallback is not optional. Existing options rather than writing one: **noray** (Foxssake) is a Godot-focused hole-punch-and-relay coordinator and is the closest fit; a plain WebSocket relay is a weekend of work if you would rather own it.

Hole punching is cheaper still and fails on some networks, so a relay fallback is not optional.

**There does not have to be a persistent server.** See §2 — a Cloudflare Durable Object is a rendezvous that exists only while a party is playing, and the numbers are better than a virtual machine's.

**Verdict: the right first choice if the game ships anywhere other than Steam, or before it ships on Steam.**

### Steam — free, excellent, and a fence

Steam Datagram Relay does the hard part for nothing: peer-to-peer with hole punching, relay fallback over Valve's own backbone, no port forwarding, lobbies and invites through the friends list, and a join that costs the player one click instead of a typed code. There is no NAT problem left to solve.

The catch is exactly one thing, and it is not the $100: **it only works between people who own the game on Steam.** No itch build, no demo build, no press build, no key you handed a friend outside Steam. In a game whose selling point is four friends in one evening, that is a real constraint.

Integration is **GodotSteam** — a GDExtension or a custom engine build — plus `SteamMultiplayerPeer`, which slots in under the same `NetTransport` interface as everything else.

**Verdict: add it when you have a Steam page. Do not let it be the only transport, and do not build the session layer around it.**

### Epic Online Services — free, and no fence

EOS gives the same relay and lobby service for nothing, on any store, on any platform, including builds you hand out yourself. The price is that every player needs an Epic account, which is a real cost paid at the worst possible moment: the first time three friends try to play.

**Verdict: the answer if the game ships off-Steam and the recurring bill for a rendezvous is unwelcome.**

---

## 2. Cloudflare — serverless, and the numbers say yes

**A Durable Object is the rendezvous. There is no persistent server, no virtual machine and nothing running while nobody is playing.** Figures below are from Cloudflare's own documentation, read rather than remembered.

### The shape

A Durable Object is a single-threaded actor addressed by name. `env.PARTY.idFromName(code)` means **the lobby code IS the object's address** — no room registry, no allocation service, no database. The `R` code kind in `LobbyCode` already exists for exactly this. The object is created on the first player's connection and ceases to cost anything when the last one leaves.

The object is a **pipe, not an authority**. The host is still a player's machine, exactly as §4 describes. Nothing about the game runs in JavaScript, and nothing should ever be tempted to.

### The two hard constraints

**No UDP. Anywhere.** Workers accept HTTP, WebSocket and HTTP/3 inbound. `connect()` opens outbound TCP only, and inbound TCP is documented as "coming soon". Two consequences, and the second is the one people miss:

1. ENet cannot pass through Cloudflare. The transport becomes WebSocket over TCP. **For this game that costs nothing** — head-of-line blocking is irrelevant at human speed, and the design already commits to the jump tick rather than the frame.
2. **Cloudflare cannot be a hole-punch coordinator.** Punching requires the coordinator to observe each peer's public UDP endpoint and echo it back. No UDP means no punching, which means Cloudflare is a relay or it is nothing. That is fine here, because a relay for a turn-based game is nearly free — see below — but it rules out the noray-shaped design entirely.

**Hibernation is mandatory, not an optimisation.** A Durable Object is billed for wall-clock duration while it is in memory and *not eligible to hibernate*. Accept a WebSocket the ordinary way and you are billed for every second it stays open. Accept it with `ctx.acceptWebSocket()` and you are billed only for the milliseconds you actually spend executing — Cloudflare bills idle-but-hibernatable time at zero, before the runtime has even hibernated the object. `setTimeout`, `setInterval`, alarms and outbound sockets all defeat this. So the relay must be event-driven and hold no timers, and per-connection state goes in `serializeAttachment()` (16 KB cap) rather than in a field.

How large that gap is depends on how long the handler runs, and it has not been
measured — at 1 ms a message it is ~900×, at Cloudflare's own illustrative 10 ms
it is ~90×. The ratio is the wrong lens anyway. What matters is which limit
binds: **hibernating, duration stops being the constraint and requests cap the
free tier at ~490 dives a day. Not hibernating, duration binds at ~28.**

### What a dive actually costs

One party, four players, one hour. Generously: 4,000 inbound messages for the party over the dive, and one millisecond of relay work per message.

| | Per party-dive | Free plan | Paid plan |
|---|---|---|---|
| **Requests** (WebSockets bill 20 incoming messages as 1) | ~204 | 100,000/day → **~490 dives/day** | 1M/month included, then $0.15/M |
| **Duration, hibernating** | ~0.5 GB-s | 13,000 GB-s/day → ~26,000 dives/day | 400,000 GB-s/month included |
| **Duration, NOT hibernating** | ~450 GB-s | → **28 dives/day** | ~$5.60 per 1,000 dives |

Requests are the binding limit and **the free tier carries roughly 490 four-player hour-long dives per day** — well past any playtest, and into the range of a small launch. Durable Objects have been on the Workers Free plan since April 2025, SQLite-backed only.

One thing to know before launch day: free-plan limits are per account, reset at 00:00 UTC, and **exceeding one fails operations with an error rather than throttling them**.

### What it costs to build

The catch is on the Godot side, and it is real.

`WebSocketMultiplayerPeer.create_client()` expects a server that speaks Godot's own multiplayer framing — peer-id assignment and packet headers defined in engine source, not in a specification. A Durable Object could reimplement that, and would then be reverse-engineering an engine internal that is free to change between Godot versions.

The better answer is to own both ends: a **`MultiplayerPeerExtension` written in GDScript** over the core `WebSocketPeer`, with the Durable Object as a protocol-agnostic relay that assigns ids and forwards frames. Roughly 200–300 lines of GDScript and a Worker of similar size.

The important part is what it does *not* cost. `MultiplayerPeerExtension` **is** a `MultiplayerPeer`, so it returns from `NetTransport.create_host()` like any other, and `NetSession` — the roster, the handshake, the version refusal, the launch — does not change by one line. That is what the seam was for.

### The risk worth naming

**A Durable Object can restart mid-dive.** A code deploy, an eviction or a failure drops every WebSocket on that object. A dive is 30 to 60 minutes, which is long enough for this to happen to somebody. The mitigation is that the code maps to the same object, so clients can reconnect and the host can re-sync — but that is real work and it is ruling N6 below, not a footnote.

### Built

`relay/` — the Worker and the Durable Object. `tkg/scripts/net/RelayPeer.gd` —
a `MultiplayerPeerExtension` over Godot's core `WebSocketPeer`, so `NetSession`
did not change by one line. `tkg/scripts/net/RelayTransport.gd` — the
`NetTransport` that mints and consumes `R` room codes.

Joining never asks which kind of party it is: `NetTransport.for_code()` reads
the first character of the code and picks the transport. A `D` code carries an
address, an `R` code carries a room. The player only has to get the code right.

**Deployed and live** at `wss://threekelvin-relay.james-e09.workers.dev`.
Four separate Godot processes through it, zero engine errors, one galaxy —
and a party that survives the object hibernating under it after 45 seconds
idle, which is the property that would otherwise fail only for real players:

```
peer0 err=0  galaxy PGC 6834 (The Salt Silence) — 148 systems
peer1 err=0  galaxy PGC 6834 (The Salt Silence) — 148 systems
peer2 err=0  galaxy PGC 6834 (The Salt Silence) — 148 systems
peer3 err=0  galaxy PGC 6834 (The Salt Silence) — 148 systems
fifth: failed: The party is full.  (~1s)
```

See `relay/README.md` to deploy it, and for the rules about not waking the
object up.

### Verdict

**Yes, and it is the recommended second transport.** Free at playtest scale, no machine to keep alive, and the lobby code doubles as the room address. Pay for it in one GDScript peer class and a reconnect path.

Not WebRTC. Cloudflare would serve that shape well too — Worker and Durable Object for signalling, `stun.cloudflare.com` free and unlimited, Realtime TURN at $0.05/GB with 1,000 GB free — but it needs the WebRTC GDExtension, which is a native dependency to build and ship per platform. It buys real peer-to-peer UDP, and this game has no use for it.

---

## 3. The recommendation

1. **Now — direct.** Built. It is the test harness for everything above it, and it is the LAN path forever.
2. **Before any playtest with people outside your house — a Cloudflare Durable Object relay.** Room codes already exist in `LobbyCode`, and the code is the object's address. Free at this scale, nothing to keep running. This is the smallest thing that makes the game playable by four friends who have never heard of port forwarding, and it is independent of where the game ships.
3. **At the Steam page — add Steam.** One more `NetTransport`. Prefer it when Steam is running; fall back to the rendezvous when it is not.
4. **Only if shipping off-Steam matters and the bill does not — EOS instead of step 2.**

Steps 2, 3 and 4 are each one class. That is the whole reason `NetTransport` exists.

---

## 4. What is built

```
scripts/net/LobbyCode.gd        the string a player reads out
scripts/net/NetTransport.gd     the seam: how machines find each other
scripts/net/DirectTransport.gd  ENet at an address in the code
scripts/net/NetSession.gd       autoload `Net` — the party
scripts/net/RelayPeer.gd        a MultiplayerPeer over one WebSocket
scripts/net/RelayTransport.gd   a room number at the Cloudflare relay
scripts/data/ShipBuild.gd       one ship, small enough to send
scripts/sim/NetTest.gd          four peers in one process
scripts/sim/ConvoyTest.gd       the party display, without a party
```

### The lobby code

Two kinds, told apart by the first character. `D` carries an address (12 characters). `R` carries a room number (7 characters). Both end in a check character.

Crockford base 32 — no `I`, `L`, `O` or `U`, because a lobby code is read aloud over voice chat more often than it is pasted. Parsing folds those four onto the digits they look like, ignores case, and ignores dashes, so a player who hears "oh" and types the letter joins anyway.

**The check character catches 100% of single-character typos** — all 372 of them, measured by the test rather than assumed. This matters more than it sounds: without it, a typo produces a valid-looking address that times out thirty seconds later, and the player cannot tell a typo from a firewall. The two have opposite fixes.

```
DFW0-000C-5M8M     a host at 127.0.0.1:34210
```

### The session

`NetSession` is autoloaded as `Net` and does nothing until somebody hosts or joins. Three rules hold it up.

**The host is the authority.** No vote, no merge. The host's roster is the roster and the host's seed is the seed. `Combat` is already a plain `RefCounted` with no UI dependency and `HeadlessSim` already plays whole runs headless, so the machine that decides is a machine that can already run the game with nothing drawn — the expensive precondition for authority is already paid for.

**The handshake refuses before it connects.** A party whose builds disagree does not fail at connect time. It fails forty minutes in, at the one node where one player's tables rolled a module the others do not have. So the first message carries a protocol number and a fingerprint of the content tables, and a mismatch is refused in words:

```
Different game version. Host is protocol 6, you are 99.
Your content does not match the host's. Compare builds or mods.
The party is full.
The host did not answer. Check the code, and whether the port is open.
That code has a typo in it.
```

Every one of those strings is asserted by the test. A refusal that arrives as a bare disconnect is the same failure as no refusal at all.

**Nothing in it knows the transport.** `host_party()` takes a `NetTransport` and gets back a code. That is the entire coupling.

### The first thing above the seed: everybody's ship

A roster slot carries a `build` — `ShipBuild.to_wire()`, which is a hull's manufacturer and weight class, the `{slot, mount, maker, id}` of every fitted part, and hull points and heat. That is enough to draw somebody else's ship exactly as they assembled it, and it is deliberately not enough to do anything else with: no cards, no affixes, no rolled numbers. It is a picture, not a game state.

Four decisions are worth recording, because each of them is the cheap version of something expensive.

**It rides the roster rather than a channel of its own.** `_push_roster()` was already the tested path for telling four machines one fact, and the roster already carried `hull` — what somebody is flying has always been a fact about the party. So a new gameplay channel was not needed, and the message that arrives is the message that was already arriving.

**It goes through the host.** Peer to peer would be one hop shorter and would mean a second direction for a message to go wrong in. The host is the authority, and the relay routes through it anyway.

**Nothing calls it.** `NetSession` listens to `ship_changed`, `resources_changed` and `player_combat_state_changed`, coalesces to one send a frame, and drops the send when the description fingerprints the same as the last one. A player fitting a gun is what happens; the party seeing it is a consequence, not a call somebody remembered to add.

**Identity travels as ids.** Both machines already agreed on the content tables at the handshake or there is no party, so sending a `HullData` would be sending a copy of something already agreed. A looted hull is a `duplicate()` of a catalogue frame with its numbers rolled up, so manufacturer plus weight class names its appearance exactly — which is why tier is not on the wire.

`-- nettest` sends a ship in both directions and checks what arrives: the maker, the weight class, the hardpoint each part sits on, who built each part, the damage, and an overheat that has to arrive as an overheat rather than clamped on the way. Those are the fields whose loss is invisible — a build that comes back with every mount at zero draws every gun on the spine and looks like a rendering decision.

**Protocol 2** was this change. A version 1 host sends slots with no build in them, and every partner would be drawn as a bare hull.

### One map, not four copies

A shared seed gives four machines an **identical** galaxy. It does not give them a **shared** one, and the difference is the whole of this section.

Everything a system holds is already drawn from `Rng.derive(tag, node.index)` — what is waiting at a fight, what an event offers, what is in a wreck — so it depends on WHERE it is rather than on who asked or when. Four players therefore find the same two modules in the derelict at index 214, which is exactly right and exactly the problem: each of them can strip it, and `coop-design.md` §3's closed per-dive economy pays out four times for one wreck.

So the host holds one more thing: **`claims`, the list of systems the party has consumed.**

```
claim   client -> host   one node index
claims  host -> everyone the whole list
```

Four decisions, and the first is the one that made the rest small.

**A claim is a node index and nothing else.** What was in the system does not travel because it never had to — both machines already agree about that. The message says the wreck is empty now, which is the one fact a seed cannot carry. Determinism paid for this: without `Rng.derive()` the same message would have had to carry the contents.

**The list is pushed whole, not as deltas.** A dive consumes tens of systems. A list rebuilt from scratch on every push cannot drift; an append-only stream of deltas drifts the first time one arrives twice or not at all, and it drifts silently — a wreck that quietly refills is not a crash.

**There is one door in the game code.** `RunState.consume_node()` sets `cleared` and tells the session. Every place that used to write `n.cleared = true` — the derelict, the fight, the hail, the pulsar, and the simulator — goes through it. A new way to finish a system is shared by construction rather than by somebody remembering to add a line. `Net.claim()` returns immediately when there is no party, which is why every call site changed without gaining a branch.

**Positions ride the presence message.** A roster slot carries `at`, the system that player is in, beside their ship. The two change for the same reasons and neither is worth a message of its own: a jump moves you and cools you, a fight damages you and heats you.

The star chart draws the party from that — a diamond and a name per partner, **outside** the visibility filter that hides systems you have not been to. That is deliberate. The filter is right for a place and wrong for a person: a partner four shells coreward is the piece of information you most want and can least reach, and `coop-design.md` §7's leash — everybody's danger tracking the deepest ship — is only a leash if you can see how deep they are.

`coop-design.md` §9 rules that this should be gated on sensor range, with a last-known position and an age stamp outside it. There is no fog in the game yet. When there is, it gates the position going **onto** the wire rather than coming off it, and nothing on the drawing side changes.

**Protocol 3** was this change, and it answers `coop-design.md` ruling 13: the party shares one galaxy instance.

### An option, not a system — and asking instead of assuming

A system that offers three or four things to do is not one resource. One ship strips the wreck and another still wants the fight, so the unit a claim names has to be the **option**, not the node. `MapGen.OPTION_WHOLE` is the id for an encounter that consumes the system entirely, which is every encounter that exists today — so a node with one thing to do carries exactly one entry and nothing reading `cleared` had to change.

A claim also records **who**. That is not bookkeeping: arriving at a wreck that says *Mercer stripped this* is the difference between a system that is empty and a system somebody emptied, and it is most of the social texture of flying together.

The important half is the timing.

**Fire and forget is right for some things and wrong for others.** `RunState.take_whole()` marks the node locally and tells the party without waiting, which is correct for the outcomes nobody can take out from under you — the fight you just won, the hail you were already inside. It is wrong for a wreck. Two ships reach it in the same second, both mark it, both roll the loot, and the flag agreeing a moment later does not take the module back out of the loser's hold. One wreck, two Legendaries, and §3's closed economy paying out twice.

So `RunState.take_option()` **asks and waits**, and returns whether you got it. Every caller has to read the answer, which is why it returns a bool rather than quietly doing nothing.

Three things make that cheap:

- **The host resolves the race by doing nothing clever.** `_apply_claim` ignores an option somebody already owns. First message to arrive wins; there is no clock to trust and nothing to compare.
- **There is no reply message.** The host broadcasts the whole claim list on every change anyway, so the answer is already on its way. The client waits for the option to appear in `claims` and reads the owner off it.
- **A click can afford a round trip.** Well under 200 ms on the relay, and it only runs when a player has pressed something. A timeout refuses rather than assumes: refusing costs one wreck, assuming costs the party's economy.

Today exactly one encounter takes the contested path — salvaging a derelict, the only thing two ships can genuinely race for. Everything else uses `take_whole()`. When a system starts offering a menu, each option picks its path by what it consumes.

**Protocol 4** is this change. Save version 5 carries `MapNode.taken`, so a resumed run remembers which options are gone — which `cleared` alone cannot say.

### One enemy, several ships

Joint combat is smaller than it looks, and the reason is an accident of how `Combat` was already written.

**Your side of a fight is already private.** Deck, hand, energy, block, armor, heat and hull live in `Run` and in `Combat`, on your own machine, and no other player targets them, spends them or reads them. **The contested object in a fight is the thing being shot at.** So the host owns the enemy and nothing else — `SharedFight` carries hull, block, armor and which intent, and that is the entire shared surface. No `Run` refactor was needed to build this.

**Every attack in the game funnels through one function.** `Combat.damage_enemy()` has five call sites, three of them in `CardResolver`. That is the seam, and it is why the change is a field on `Combat` rather than a rewrite of it.

The two directions are deliberately asymmetric.

- **You → enemy.** Your card resolves locally and instantly, so the number appears the moment you play it, exactly as it does alone. The **raw** amount is then sent, and the host redoes the mitigation against the block it actually has — the copy your machine just spent may already have been spent by somebody else. Its push is authoritative. **Death is host-only:** a client that called `_victory()` off its own optimistic view would pay itself for a kill the host has not seen, which is §3's closed economy paid out four times in the easiest place to do it by accident.
- **Enemy → you.** The host picks the target and sends the intent **to that machine alone**. Dodge, block, armor, hull and feedback all resolve there, against numbers that exist nowhere else. Mirroring three partners' block values across the party would be a lot of wire for something nobody reads.

**A partner's shot has to be drawable.** Their card was played on a different computer, so without help their hits land silently and the hull bar drops for no visible reason. The push carries `[who, foe, total, serial]`; you skip your own and draw everyone else's. The serial is what makes "once" mean once — every push carries the last hit, including the ones that are about something else entirely.

**The enemy aims at heat.** Weight is `0.5 + heat_ratio`, so a redlining ship draws about four times the fire of a cold one and a cold one is still never safe — a target rule with a zero in it is a party that solves the fight by electing a victim. It costs nothing on the wire: `ShipBuild` has carried heat since the convoy strip needed it to draw a gauge. This is `coop-design.md` §6's field one level down, and it is the first place heat is a threat inside a fight rather than only on the map.

**One barrier, in one place.** Everybody draws and plays at their own pace, immediately. What cannot happen concurrently is the enemy swinging, because that is one object acting on several private ones — so `SharedFight.end_turn()` collects END TURN from each ship and the enemy acts when the last one is in. That is §5's *do not gate the tick* applied to the turn. `coop-design.md` §5 asked for simultaneous face-down lock-in instead; that needs cards to become deferred effects, and the ones that draw, gain energy or block-then-attack do not survive resolving out of order. The barrier gets the same "nobody waits on a phase" property for no card changes at all.

**Leaving is not optional.** A crew list still holding somebody who will never press END TURN again is a fight that never takes another turn. Dying, fleeing, winning and disconnecting all call `leave()`, and a disconnect that closes the barrier takes the turn immediately. Losing the host mid-fight drops the fight back to local resolution rather than hanging on a button that will never light up.

**The enemy scales, and everyone gets paid.** Each extra ship adds `CREW_SHARE` (0.6) of the enemy's solo value, the same number `Combat.start()` already uses to split a pack — three hands of cards against one intent is an advantage, so a linearly scaled enemy would make the party fight *easier*. Joining at 10% health still grows it, which is the price of arriving late. Everyone still in it when the last hull came apart is paid, and fleeing already paid nothing.

**What is not shared:** an ambush, because `_roll_ambush` draws from `Rng.foe` — a stream, precisely so four ships at one system do not all get jumped, which means two players' ambushes at the same node are different events sharing an address. Nor an event that drops you into a fight, for the same reason. Reinforcements and pacification are off in a shared fight rather than wrong in one; both need the host counting something it does not count yet.

**Protocol 5** is this change.

### One seed, four holds

The first two-client playtest found something the protocol had nothing to do with: **both players were paid the same modules.**

A shared seed gives four machines an identical galaxy, which is the whole point — and `Rng.loot`, `Rng.event`, `Rng.foe` and `Rng.fight` are **cursors, not derivations**. Four machines that have made the same number of draws are sitting at the same place in the same sequence, so two ships that kill the same frigate on the same turn get handed the same two parts. It is worse than plain duplication, because the moment the cursors drift apart it silently stops, which makes a seeding bug look like a network one.

The split is the same one `Rng.derive()` already draws, one level up. **A thing that has a PLACE must agree** — the wreck's contents, the shop's shelves, what is flying at node 46 — and those were already positional. **A thing paid to a PLAYER must not**, and those are the streams. So `reseed()` takes the ship's seat in the party and salts everything except `world`, which builds the galaxy and has to be identical.

Seat 0 is a deliberate no-op rather than a salt of zero, so every solo run still replays bit-for-bit from `-- seed N` and no seed in an old bug report changed meaning.

Neither process can check this about itself, so `tools/cofight.sh` checks it from outside: it compares the two logs and fails if the seats match, if the loot seeds match, or if one kill paid two ships the same part.

### One shelf, four buyers

The same playtest found the shop, and it is a different bug wearing the loot bug's clothes.

**The stock being identical on both machines is correct.** A station's shelf belongs to the station: it is rolled from `Rng.derive(&"shop", n.index)` precisely so four ships docking in four different orders see one shop rather than four. That part was right.

**Buying it was not.** `n.shop.erase(m)` emptied the local copy and told nobody, so two players standing in the same shop both bought the same Legendary. One shelf, two copies, and §3's closed economy paid twice — the wreck bug, at a different address.

It is the first contested thing that is a **list**, which is what `MapGen.OPTION_SHOP + i` is for: a wreck is taken whole, a shelf is taken a part at a time. That forced one change to how the shelf is stored. **The array must not shrink**, because erasing renumbers every slot after the one sold and two machines stop agreeing about what "slot 2" means. So a sold part stays on the shelf and is hidden by `n.taken` — which is the field's whole purpose.

Ordering matters here more than at the wreck, because money is involved: **ask, then pay.** A purchase that charged first and lost the race would take credits for a part somebody else is carrying home. Fixing that also closed a solo bug of the same shape — buying into a full hold used to take the credits, erase the part off the shelf, and then log "left behind", so the module was gone from both places and paid for.

`tools/cofight.sh` checks the pair from outside: the two shelves must MATCH, and exactly one ship may walk away with the part.

### One kill, one bag

The second two-client playtest found the thing the first one's fix had hidden.

**Seat salting stopped two players being handed the identical module. It never
addressed the actual problem, which is that one frigate paid the party twice.**
`Combat._victory()` ran on every machine in the fight and each one rolled its own
drop off its own stream — different parts, yes, but two ships walked away from a
single kill with two full payouts. `coop-design.md` §3 runs the dive economy as a
closed loop, and a kill that pays per head is not closed. It is the wreck bug and
the shelf bug for the third time, at the one address nobody checked because the
fix for the *previous* bug was sitting on it.

So a shared kill leaves a **bag at the node**, and the bag is the third contested
thing in the game.

```
bag       rolled locally    Rng.derive(&"bag", index) — never sent
OPTION_BAG + i              the i-th part, claimed like a shelf slot
```

Four decisions, and three of them are the shelf's, reused without change.

**It is a list, so it is the shelf's shape rather than the wreck's.** A wreck is
taken whole; a bag is taken a part at a time, which is exactly what
`MapGen.OPTION_SHOP + i` was built for. `MapNode.bag` therefore must not shrink
either — a taken part stays in the array and `taken` says it is gone, or two
machines stop agreeing what "part 2" is.

**Nothing about the bag crosses the wire.** It is rolled from
`Rng.derive(&"bag", node.index)` on every machine independently, so four ships
look at one pile for the price of one integer. Deliberately not `Rng.loot`: that
stream is salted by seat *precisely so* that what is paid to a player differs per
player, and a bag is paid to the party.

**Its SIZE is the one thing a seed cannot say**, because it came from how many
ships were in the fight. `SharedFight.paid` is that number, frozen by the host in
`hurt()` at the moment the last hull came apart — not read from `crew.size()` at
payment time, because winning makes every ship call `leave()` and each machine
would sample the crew list at a different point in its unwinding. Two ships
disagreeing about how many parts are floating is worse than either answer.

**Reaching in asks and waits**, like the wreck and unlike the fight. And the hold
is checked *before* the claim, not after: claiming a part you have nowhere to put
would burn it for the whole party — gone from the bag, in nobody's hold — which
is "ask, then pay" seen from the other end.

Solo is untouched and that is deliberate. One hand reaching into a bag is a menu
between a player and their own loot, so a fight nobody else was in still stows
straight to the hold.

`tools/cofight.sh` checks the pair from outside, because neither process can see
the other's: the two bags must MATCH, neither hold may have been paid directly,
and exactly one ship may walk away with part zero.

### The core is a place you arrive at

The same playtest reported the core boss as solo, and the sharing was never the
problem. `tools/cofight.sh boss` puts two ships on the custodian, and
`tools/cofight.sh boss late` has the second one arrive at a fight the first has
already opened — the enemy grows from 120 hull to 192, both ships' cards land on
one copy of it, and the barrier holds. All of that worked before anything was
changed.

**What was wrong is that arriving at the core opened the fight, on the frame you
landed.** Two people never arrive at a system in the same second, so whoever
jumped first was already in the boss fight while the other was still three jumps
out. There was nothing to join by the time they got there. The run's one set
piece was solo by construction, and no amount of correct netcode underneath it
was going to show.

So `Router.resolve_current_node()` shows the sector instead, and the button says
ENGAGE. That wiring already existed for resumed runs — `_on_action` and
`_quiet_lines` both had the GOAL case — so this makes the restored path the
ordinary one rather than adding a path.

It also closed a second hole in the same branch: winning consumed the node, and
GOAL never checked `cleared`, so the next ship to arrive rolled a fresh custodian
and killed the galaxy's boss a second time. FIGHT has checked that since it was
written.

### A partner drawn as the ship they picked

`ShipBuild` carried a manufacturer and a weight class and, on purpose, not a
grade — the note in its header said an A-tier Korvan Frigate and a C-tier one
were the same picture. That was true when it was written and stopped being true
the day `DB.hull_sprite()` was keyed on the class letter as well as the weight.

From that commit every partner in the party was drawn as a C-class hull whatever
they were flying, and it is the worst kind of silent: the ship on the other
screen is a perfectly ordinary ship, just not the one that player picked.

The fix is one field on the wire and `DB.at_tier()` on the way off it. The lesson
is smaller than the bug and worth writing down: `ShipBuild` describes what is
DRAWN, so any field the renderer starts reading has to arrive there on the same
day.

**Protocol 6** is these three changes. Save version 6 carries `MapNode.bag`.

### The first thing on the wire with a position that MOVES

Everything shared before this was either fixed by the seed (the galaxy, what a
wreck holds) or a fact about the past (a claim, a bag). The stoker —
`docs/coop-design.md` §18 — is neither: it is a rival ship with a node index
that changes, and this game deliberately has no shared clock for it to change
on. Four players jump at their own pace; there is no tick.

So the party's jumps ARE the tick, and the host counts them. Its own jumps
count in `RunState.jump_to()`; everybody else's are read off the presence
message, which already carries `at` — a presence whose `at` moved is a jump,
and no new client-to-host message was needed. Every `STOKER_STRIDE` of them the
host moves the stoker one link and broadcasts the whole state — position, hull,
move counter — through `_push_stoker_to`. Whole, like claims, so a dropped push
costs one update rather than a drift. WHERE it goes is still derived
(`Rng.derive(&"stoker", move counter)`), so solo runs replay bit-for-bit from a
seed and the wire only exists to carry the one thing a seed cannot: when.

Three smaller things ride the same bump:

- **A fight can open against an enemy already hurt.** `_open_fight_at_host`
  gained `cur`, the current hull beside the capacity, because the stoker
  carries its damage between engagements and both machines have to start the
  fight from the same number.
- **A fight can end because the enemy LEFT.** `SharedFight.broke` says the
  fight is over with nobody paid and nothing consumed, and intent kind
  `ESCAPE` names the spool-up turn — an intent in no template list, so it
  travels as a kind rather than an index and every machine builds the same
  card from it (`Combat.escape_intent()`).
- **The host keeps the map honest from outside the fight.** A host three
  systems away has no `Combat` to run `_victory()` in, so `_apply_hurt` and
  `_apply_leave` write the stoker's death or its surviving hull back to
  `RunState` when its fight ends by kill or by everybody walking out.

**Protocol 7** is these changes. Save version 8 carries the stoker and
`MapNode.eaten`.

### Eight seats, flown before the number was raised

`NetTransport.MAX_PLAYERS` is eight. It was four, and the way it was raised is
the point: `tools/coplay.sh 6` put six windows in one party on one code before
the constant was called shippable. Six ships readied, one seed, the same 161
systems on every machine, no errors in any of the six logs.

**Nothing in the session layer had an opinion.** The seed is one integer however
many machines receive it. Seat salting is `_mix(base, seat)` for any seat.
Claims, the bag and `SharedFight.crew` are lists that got longer. That is what
the layer was built for and it is the least surprising result here.

**The interface had two, and both were the same bug.** The lobby roster had no
scroll, so at about six ships READY and LAUNCH DIVE walked off the bottom of a
540px viewport — the six-ship party above could only be launched because `auto`
pressed the button programmatically. And the convoy strip is a fixed-height
column: three rows of 118 against the 378 the arena leaves. Photographed at
seven, the fourth ship was cut in half by the quiet strip and the last three
were not drawn at all, silently.

The strip is now **three places rather than three ships** — when more ships are
here than there are places, the last place holds a `+N MORE` chip instead of a
hull. A counter beside three hulls does not fit; the block goes ten rows over
and, because the column is centred, spends half of that writing the first
partner's name across the name of the system.

**Two constants, and they must agree.** `NetTransport.MAX_PLAYERS` and
`MAX_PLAYERS` in `relay/src/index.js`. Both ends police the door independently,
so a mismatch is a player the relay admits and the host then turns away, which
reads to them as a random disconnect.

**What is allowed and not tuned:** `SharedFight.CREW_SHARE` is linear with no
ceiling and has been flown at two. An eight-ship custodian is 120 + 7×72 hull
against eight hands of cards. The cap permits that fight; nobody has played it.

And one cost worth naming before it is discovered on a bill: `_push_roster_to`
sends the **whole** roster to **everyone** on any change, and every slot carries
a full `ShipBuild`. That is O(n²) per presence change, and presence changes
whenever anybody's hull or heat moves. At four it is invisible. At eight it is
four times the traffic for twice the party, on a relay where Cloudflare bills 20
incoming messages as one request.

### The party page

`PartyScreen`, on the HUD beside SECTOR and STARCHART, hidden when there is no
party. Every ship in the party with its hull drawn, its hull points, its heat
against **its own cap**, the system it is in, and whether it is in a fight.

**Not one new message was added to build it.** A roster slot has carried the
ship, the gauges and the position since the convoy strip needed them, and that
is the test of whether a screen deserves to exist: one that needs a new channel
is a feature, one assembled out of facts the party already agrees on is a view.

It scrolls, so it has no opinion about party size — which is what lets the
convoy strip keep the job it is good at (who is in this room, at a glance,
without leaving the sector) and hand off the one it cannot do.

What it deliberately does not show is anything `ShipBuild` does not already
carry. No cards, no affixes, no fuel, no credits. `coop-design.md`'s first
pillar is that the wallets stay separate; what the party shares is exposure, and
exposure is hull, heat, position and contact.

### Two processes, one galaxy

The end of the chain, run for real rather than argued:

```
$ godot --path . -- lobby host auto
[lobby] code DR2M-08BB-TD49
[lobby] 2/4  PILOT-839* PILOT-228*
[lobby] dive on seed 1290740162
[lobby] galaxy ESO 1342 (The Burning Harvest) — 190 systems

$ godot --path . -- lobby join DR2M-08BB-TD49 auto
[lobby] connecting
[lobby] 2/4  PILOT-839* PILOT-228*
[lobby] dive on seed 1290740162
[lobby] galaxy ESO 1342 (The Burning Harvest) — 190 systems
```

Two operating-system processes, one code typed between them, and the same 190
systems on both. **Nothing about that galaxy was sent.** One 32-bit number
crossed the wire and both machines built the rest from it — which is the entire
reason the RNG work came before the netcode, and the thing that would have been
impossible to add afterwards.

What it is not: a game. There are no gameplay messages above the seed, so from
the moment both sectors draw, the two runs diverge the instant either player
does anything. See the table above.

### The test

The trick that puts every peer in one process is `SceneMultiplayer.root_path`. Each peer gets its own branch under the tree root and its own `MultiplayerAPI` rooted there, so every peer's `NetSession` answers to the same relative path while living at a different absolute one. Without it this needs one process per peer and cannot run in CI.

It proves: codes round-trip and refuse typos; a full party forms and the roster reaches every machine; both version refusals fire with readable text; the seat past the last is turned away in words; a launch puts one seed on every machine; and losing the host is reported rather than swallowed. The party size is read from `NetTransport.MAX_PLAYERS` rather than written down here, so raising the cap raises what the test proves.

It does **not** prove that any of it works through a NAT. Nothing that runs on one machine can, and pretending otherwise is how the direct transport gets shipped as if it were finished.

---

## 5. What stands between this and playable co-op

The session layer is the part that is hard to change later, which is why it is built first. It is not the expensive part. From `coop-design.md` §15, measured against `main`:

| | Why it blocks | Size |
|---|---|---|
| ~~**RNG determinism**~~ | ✅ **Done.** The seed `_begin_dive` sends is now honoured: `Rng` puts one galaxy, one map and one set of shelves on every machine that shares it. | Was the top item. See `Rng.gd` and `-- rngtest` |
| **`Run` is a singleton** | 655 references across 33 files. A host holding four ships needs four of it. | Largest single item; gates most of the rest |
| **Gameplay messages** | Three exist. A roster slot carries the ship each player is flying and the system they are in; the host holds which OPTIONS the party has consumed and who took each one; and the host owns the enemy in any fight more than one ship is in. Still missing: the shared heat field on the map, the shared fuel tank, danger tracking the deepest ship. | Real work, but `Combat` is already UI-free and already headless. §7 is now cheap — every position is already on the wire |
| ~~**Lobby UI**~~ | ✅ **Done.** `LobbyScreen` — host, code, COPY/PASTE, join, roster, ready, launch. Reached from the title screen under **FLY TOGETHER**; the `-- lobby host` / `-- lobby join CODE` / `auto` flags exist to test it, not to use it. | Two processes have now formed a party and landed in the same galaxy. See below |
| **§0's gate** | `coop-design.md` rules that heat must gate reward before a commons is built on it, and the measurement says it does not yet. | A design gate, not a code one |

**Determinism is done.** It was the only item on that list that paid for itself before a second player existed, and it did: `-- seed N` replays a run exactly, and `-- sim seed=N` makes a whole balance sweep reproducible.

**The `Run` singleton is now the top item**, and the lobby screen is the cheapest.

---

## 6. Rulings still open

| # | Ruling | Blocks |
|---|---|---|
| N1 | Rendezvous, Steam, or EOS as the second transport | Nothing yet — that is the point of `NetTransport`. It becomes urgent at the first outside playtest |
| ~~N2~~ | ~~Does the host simulate all four ships, or does each client simulate its own and report?~~ — **ANSWERED, for combat: neither.** The host owns the CONTESTED object and each client owns its own ship. In a fight the contested object is the enemy, so that is all the host holds. It is the answer that needed no `Run` refactor, and it generalises: the shared fuel tank and the summed heat field are the same shape. | Closed for combat. Still open for anything a client could lie about — the game is trusted-peer today |
| N3 | Can a party survive the host dropping? | Migration is expensive; "the dive ends" may be the honest answer for a 30–60 minute session |
| N4 | Does a dropped player rejoin the same dive, and how? | Interacts with the wreck rules in `coop-design.md` §10 |
| N5 | Is the content fingerprint strict enough to block mods, or should it warn and continue? | Mod support, later |
| N6 | Reconnect after a Durable Object restart — does the client rejoin silently, or does the dive end? | §2. A 30–60 minute session is long enough that this will happen to somebody |

---

## 7. The ninth seat: a ship nobody is sitting in front of

`godot --headless --path . -- bot join ABC-123`, or `tools/bot.sh`.

A bot joins by lobby code exactly like a person: it reaches the relay, gets a
peer id, readies, waits for the dive and then rolls its own chassis on the
party's galaxy. From that moment it holds its own `Run` — its own hull, hold,
heat, credits and `Rng` seat. Nothing anywhere in the session layer knows or
cares that the pilot is a program, and that is not a flourish, it is the only
design available: `Run` is a singleton, so one process holds exactly one ship.

### Why not just read the relay

This is the obvious cheaper idea and it deserves a straight answer, because it
fails twice.

`relay/src/index.js` never opens a payload. The whole of its handling of a
gameplay frame is: check byte 0 is `T_DATA`, overwrite `from` with the real
sender id, forward. What is on that socket is Godot's binary multiplayer
serialisation and nothing else, so "read Cloudflare" means reimplementing the
engine's serialiser against a format that is an engine implementation detail.

And the relay holds no game state **on purpose** — see §2. The Durable Object
must hibernate or it bills for wall-clock time, so anything that keeps it awake
or accumulates state turns a free relay into a metered one. Adding a readable
mirror of the fight there is not a small change to a dumb pipe; it is a
different service with a different bill.

Even granting both, the relay cannot invent a peer. The result would be a
spectator with no ship, no hold and no cards — able to narrate a fight and not
to be in one. **The seat is the feature.**

### The price

`NetTransport.MAX_PLAYERS` bounds the party and the relay's door policy enforces
it, so a bot in the party means one fewer human. There is no spectator slot to
hide in, and adding one would mean the relay counting something it deliberately
does not count.

Deliberately without the number. This said "four" and kept saying it after the
cap became eight, alongside the same sentence in `BotPilot.gd` and a `NetTest`
that asserted a four-seat party in nine places. Prose that restates a constant
is a copy of it that nothing checks.

### Where the decisions come from

The brain is behind a mailbox: two files in a directory. Before every decision
the ship writes `board.json` — the fight, the hand, the enemy's telegraphed
intent, the systems in range and what each costs, the shelf and who has already
bought from it — and waits for `move.json` holding `{"seq": N, "do": "play 2"}`.
Every board lists the moves that are actually legal, so a brain never has to
infer legality and never has to spell an illegal move.

Files rather than a socket: Godot has no HTTP server, so a socket means
hand-rolling one and a protocol to talk to a process on the same machine. Two
files need neither, and **anything that can write a file can play** — a shell
one-liner, `tools/crew-mcp.mjs` (an MCP server, so a Claude session can play
without a shell), or a person with a text editor. The whole conversation is on
disk afterwards to read back.

`seq` is what makes an answer belong to a board. Every push carries a number and
every move must quote it; a move written about a hand that has since been played
is dropped rather than clamped, because it is not a wrong move, it is a move
about a different game.

### The shot clock

**`SharedFight.end_turn()` is a barrier.** The enemy does not swing until every
ship in the fight has ended its turn, so a bot that is still thinking is three
other people watching a static screen — and a brain with a language model behind
it answers in seconds and occasionally in minutes.

So: the board is offered, an answer is waited for, and when the clock runs out
`Policy` — the simulator's competent-player model, the one the merge gate
measures — plays the turn and the fight moves on. The bot is allowed to be slow.
It is not allowed to be slow at everybody else.

### Following, and holding

A bot with `follow` flies toward the party instead of off on its own dive. Both
halves of that rule were arrived at by flying it wrong first.

A headless ship plays a complete run in about forty seconds; a person takes an
hour. A bot that only ever moves *toward* the party therefore arrives at their
system, wins the fight, and is four jumps deeper before anybody lands — two
ships visiting exactly the same systems and never once meeting. So **holding is
a move**: a following ship does not leave a system somebody is in, and does not
jump anywhere that does not close the distance.

And two ships that both follow *the nearest partner* mirror each other exactly:
A leaves, B follows, A sees B gone and follows back, and the pair bounce between
two stars until the tank runs dry. Flown, at system 7, until both stranded. Seat
order breaks it — **a wingman follows the seats that arrived before it**, so
seat 0 leads and never follows, which is also the human who opened the party.

Holding expires, but on `patience` seconds of *nothing happening* rather than on
the wait itself: the clock resets on anybody moving, arriving, leaving, or
opening a fight. A person picking over a station shelf looks exactly like a
person who has closed the lid, and of the two mistakes, abandoning somebody
mid-shop is the worse one.

### What is proved, and what is not

Flown, not argued — two processes on a real lobby code:

- A bot joins a party, rolls a chassis on the shared galaxy at its own `Rng`
  seat, flies the map, fights, shops and dies of its own decisions.
- The mailbox round-trips: a board is offered, a move comes back, the ship obeys
  it, and the resulting board is the one that move produced.
- The shot clock fires and `Policy` takes the turn — seventeen boards, seventeen
  timeouts, one complete run.
- Two ships end up in **one** fight: the enemy grew from 18 hull to 29 when the
  second arrived, both ships named the other in the crew, and the same kill paid
  both.
- `tools/crew-mcp.mjs` drives all of it over MCP.

Not proved: any of it through a NAT, and none of it is in the merge gate — for
the same reason `tools/cofight.sh` is not. It needs two live processes and a
party, and the gate runs neither.

---
