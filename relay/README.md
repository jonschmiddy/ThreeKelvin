# Three Kelvin — party relay

A Cloudflare Worker and one Durable Object per party. It assigns peer ids and
routes frames between four ships. It holds no game state, makes no decisions,
and is not an authority — the host is still a player's machine.

**There is no server to keep alive.** A party's Durable Object is created when
the host connects, hibernates while nobody is talking, and is gone when the last
ship leaves. Nothing runs between dives and nothing is billed for it.

Design and costs: `../docs/netcode.md` §2.

---

## Deploy it

You need a Cloudflare account. The free plan is enough — see the numbers below.

```bash
cd relay
wrangler login          # opens a browser; run it yourself
wrangler deploy
```

`deploy` prints the URL it published to:

```
Published threekelvin-relay (x.xx sec)
  https://threekelvin-relay.<your-subdomain>.workers.dev
```

Put that in the game as a **`wss://`** URL — `tkg/scripts/net/RelayTransport.gd`.
Deployed and wired in already:

```gdscript
const DEFAULT_URL: String = "wss://threekelvin-relay.james-e09.workers.dev"
```

`ws://` will not work from a shipped build and `https://` is the wrong scheme
for a socket. While `DEFAULT_URL` is empty the lobby says so and offers only
direct hosting, rather than a button that cannot work.

Then rebuild the class cache and play:

```bash
cd ../tkg && godot --headless --path . --import
godot --path .          # FLY TOGETHER > HOST PARTY
```

## Verified live

Four Godot processes through the deployed Worker, and a party that survives the
Durable Object hibernating underneath it:

```
peer0 err=0  galaxy PGC 6039 (The Drowned Tide) — 152 systems
peer1 err=0  galaxy PGC 6039 (The Drowned Tide) — 152 systems
peer2 err=0  galaxy PGC 6039 (The Drowned Tide) — 152 systems
peer3 err=0  galaxy PGC 6039 (The Drowned Tide) — 152 systems

host opens a party, idles 45s, then a friend joins:
  host:   err=0  galaxy MCG 433 (The Sundered Wheel) — 133 systems
  joiner: err=0  galaxy MCG 433 (The Sundered Wheel) — 133 systems
```

That second test is the one worth keeping. Cloudflare evicts an idle object
after about ten seconds, so a lobby left open while somebody makes tea is
hibernating by the time the next friend arrives. If any room state lived on the
instance instead of in socket attachments, the join would fail — and it would
fail only for real players, never in a test that never waits.

## Run it locally

```bash
cd relay && wrangler dev --port 8787 --local
```

Point the game at it without editing anything:

```bash
godot --path . -- lobby host relay ws://localhost:8787
godot --path . -- lobby join <CODE> relay ws://localhost:8787
```

Add `auto` to press READY and LAUNCH by itself, and `wait 4` to hold the launch
until four ships are in. That is how the four-machines-one-galaxy claim is
checked without four people clicking at once:

```bash
godot --path . -- lobby host relay ws://localhost:8787 auto wait 4
godot --path . -- lobby join <CODE> relay ws://localhost:8787 auto
```

## What the door lets through

The relay still opens no payload. It has five limits, and each number is one of
the game's own. They are in `src/limits.js` with the reasoning; this is the
short form.

| The relay | The number | Where the number comes from |
|---|---|---|
| answers a path that is not a party code itself, and wakes no party for it | `R`, five characters, a check character | `LobbyCode.gd` (the ROOM kind) |
| drops a frame larger than the game's buffer | 65,536 bytes, header included | `RelayPeer.BUFFER_BYTES` |
| closes a guest that talks faster than | 200 frames a second, 2,000 at once | a ship sends about 7 a second (`NetSession.SPOT_EVERY_MS`) |
| closes a host that talks faster than | 2,000 frames a second, 20,000 at once | a host of eight sends up to 373 a second |
| closes a guest that has sent nothing | 15 seconds after it joined | a ship says hello at once, and gives up at 10 (`NetSession.HANDSHAKE_TIMEOUT`) |

**A path that is not a code.** The Worker holds the same check as
`LobbyCode.parse`. A path that fails it gets the answer a code nobody is hosting
gets, the same DENY frame on the same open socket, and no Durable Object is
reached. The game never sends such a path: it checks what a player typed before
it opens a socket.

**A frame too large.** The engine measures a whole frame against the buffer, so
no ship sends a larger one, and a ship that received one would hang up. The
relay drops it and keeps the socket.

**A socket too fast.** Each socket has a token bucket in its attachment. Every
frame that arrives takes a token, whatever it holds. A socket with none left is
closed with code 1008 and the party is told it left; if it was the host, the
party ends as it does when a host leaves. The bucket holds ten seconds of its
rate, so a connection that stalls and then delivers what it queued is not taken
for a fast one.

**A guest that never speaks.** A guest's socket that has sent no DATA frame 15
seconds after it was admitted is closed with code 1008, the party gets its
LEAVE, and the seat is free. The host is never closed for this: it may wait
alone in a lobby as long as it likes. There is no timer. The relay looks when a
frame or a connection arrives, so a silent guest in an otherwise silent party
stays until the next ship knocks, and that ship gets the seat.

A socket that was refused, or closed by one of these, and sends a frame anyway
is closed with 1008 too.

None of this changes a frame, a close code or a sentence a real ship sees.

### Test it

```bash
node --test relay/test/*.test.js      # from the repo root; nothing to install
```

Plain Node 20 or newer, no network, about a second. It holds the code check to
a list of codes the game's own `LobbyCode` made (`test/codes.fixture.json`),
checks the numbers above against the game's source files, and runs a party
through the real `src/index.js` on stand-in sockets. The merge gate runs it
(`unit_relaytest`). It is not a test on Cloudflare: after a change, run the
relay locally (below) and join it with two copies of the game before deploying.

## What it costs

Verified against Cloudflare's own pricing documentation, not recalled. One
party, four players, one hour, generously estimated at 4,000 inbound messages.

| | Per dive | Free plan |
|---|---|---|
| Requests (20 incoming WebSocket messages bill as 1) | ~204 | 100,000/day → **~490 dives/day** |
| Duration, hibernating | ~0.5 GB-s | 13,000 GB-s/day → ~26,000 dives/day |
| Duration, *not* hibernating | ~450 GB-s | → **28 dives/day** |

The hibernating duration figure assumes about 1 ms of work per message, which
has NOT been measured — Cloudflare's own worked example assumes 10 ms, which
would be ~5 GB-s a dive. Either way duration stops being the binding limit and
requests take over at ~490 dives/day, which is the point. The two only diverge
if the handler ever grows expensive.

Requests bind first. The free tier carries roughly **490 four-player hour-long
dives a day**, which is past any playtest and into a small launch. Free-plan
limits are per account, reset at 00:00 UTC, and exceeding one **fails
operations with an error rather than throttling them**.

## Rules for changing this Worker

**Never keep the object awake.** No `setInterval`, no `setTimeout`, no alarms,
no outbound sockets. Duration is billed in wall-clock time whenever a Durable
Object is in memory and unable to hibernate, so one stray keepalive bills for
every second a party is connected — 450 GB-s an hour — instead of for the
milliseconds this Worker actually executes.

In capacity terms that is the difference between the free tier carrying about
**490 dives a day and about 28**. A heartbeat is the obvious temptation and it
is the expensive mistake.

**Never hold state on `this`.** Hibernation wipes memory. Everything the room
knows lives in a socket's `serializeAttachment()` or in `ctx.storage`. A field
on the instance reads back as `undefined` after ten idle seconds, which is a bug
no test that never idles will find.

**Never put a limit on a timer.** The limits above are asked when a frame or a
connection arrives, which is when the object is awake anyway. A timer that
closed a quiet socket on the dot would be the keepalive under another name.
What a limit needs to remember (when a socket joined, whether it has spoken,
its tokens) goes in that socket's attachment, which may hold 16,384 bytes and
holds about 70.

**Change a limit's number with the game's.** Each one is a constant in
`tkg/scripts/net/`, named in `src/limits.js`. A relay limit that drifts below
what the game sends cuts a real party off. The test reads the game's files and
fails when one of those constants moves.

**Never trust the `from` field.** `webSocketMessage` rewrites it with the id the
relay assigned. Without that any peer can post as the host, and the host is the
authority for the whole party.

**Never close a socket immediately after sending it a reason.** The close races
the message and the client is left reporting a bare disconnect — the one message
that tells a player nothing they can act on. Send, and let the client hang up.

## The wire

Little-endian binary frames, byte 0 is the type. The other end is
`tkg/scripts/net/RelayPeer.gd`; the two have to agree and nothing else depends
on either. A frame is at most 65,536 bytes, header included.

```
HELLO  [1][u32 your_id]
JOIN   [2][u32 peer_id]
LEAVE  [3][u32 peer_id]
DENY   [4][utf8 reason]                        socket stays open; client closes
DATA   [16][i32 from][i32 to][u8 mode][u8 chan][payload]
```

`to` follows Godot's targeting exactly: `0` is everyone, a positive id is one
peer, a negative id is everyone except that one.
