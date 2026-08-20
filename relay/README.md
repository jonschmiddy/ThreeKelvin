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

**Never trust the `from` field.** `webSocketMessage` rewrites it with the id the
relay assigned. Without that any peer can post as the host, and the host is the
authority for the whole party.

**Never close a socket immediately after sending it a reason.** The close races
the message and the client is left reporting a bare disconnect — the one message
that tells a player nothing they can act on. Send, and let the client hang up.

## The wire

Little-endian binary frames, byte 0 is the type. The other end is
`tkg/scripts/net/RelayPeer.gd`; the two files have to agree and nothing else
depends on either.

```
HELLO  [1][u32 your_id]
JOIN   [2][u32 peer_id]
LEAVE  [3][u32 peer_id]
DENY   [4][utf8 reason]                        socket stays open; client closes
DATA   [16][i32 from][i32 to][u8 mode][u8 chan][payload]
```

`to` follows Godot's targeting exactly: `0` is everyone, a positive id is one
peer, a negative id is everyone except that one.
