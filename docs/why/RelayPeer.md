The reasoning behind `tkg/scripts/net/RelayPeer.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Relay peer design

Above `const T_HELLO: int = 1`:

```text
A Godot MultiplayerPeer that speaks to the Cloudflare relay.

This class exists so that NOTHING ELSE HAS TO CHANGE. `NetSession` is built
on Godot RPCs, and RPCs need a `MultiplayerPeer`. A `MultiplayerPeerExtension`
IS one — so this returns from `NetTransport.create_host()` exactly where an
`ENetMultiplayerPeer` used to, and the roster, the handshake, the version
refusal and the launch all keep working without knowing the transport moved
from UDP to a WebSocket on the other side of the planet.

**Why not `WebSocketMultiplayerPeer`, which already exists.** Because its
client mode expects a server that speaks Godot's own multiplayer framing —
peer-id assignment and packet headers defined in engine source rather than in
any specification. A Durable Object could reimplement that, and would then be
reverse-engineering an engine internal that is free to change between Godot
versions, in a file nobody would think to check when upgrading. Owning both
ends of a nine-byte header is less work and cannot rot.

## The wire

Little-endian, binary frames, byte 0 is the type. Must match `relay/src/index.js`.

  HELLO  [1][u32 your_id]
  JOIN   [2][u32 peer_id]
  LEAVE  [3][u32 peer_id]
  DENY   [4][utf8 reason]        ...and then the socket closes
  DATA   [16][i32 from][i32 to][u8 mode][u8 channel][payload]

`from` is written by the relay and never trusted from a sender. `to` follows
Godot's targeting exactly: 0 is everyone, a positive id is one peer, and a
negative id is everyone except that one.
```

## Opening

Above `func open(url: String, hosting: bool) -> Error:`:

```text
Open the socket. The URL carries the room and the role; see the relay.

`hosting` is not a request — the host's peer id is 1 by protocol, so it is
known before the socket opens and is claimed here rather than waited for.
That matters because `NetSession.host_party()` asks `is_host()` in the next
line, and an ENet server is a server the moment it binds. A relay host that
only learned its own id a round trip later would be, for those few frames, a
host that did not believe it was one — which is the sort of difference
between transports the session layer was built specifically not to see.

The status stays CONNECTING until the relay actually says HELLO, so nothing
is sent into a socket that has not opened.
```

## Refusal timing

Inside `_receive()`, above `_shut_down()`:

```text
Disconnected NOW, not when the socket finishes closing. A refusal
is final the moment it is read, and a WebSocket close handshake
takes long enough that waiting for it let the layer above sit on
the ten-second handshake timeout instead — so an answer that
arrived in milliseconds was delivered to the player in eleven
seconds, which reads as a hang rather than as a refusal.
```

## Packet sender

Above `func _get_packet_peer() -> int:`:

```text
THE NEXT packet's sender, not the last one's.

`SceneMultiplayer.poll()` asks who sent a packet BEFORE it asks for the
packet, so these three have to peek at the front of the queue rather than
report what was handed over last. Reporting the previous sender does not look
broken with two machines, because every packet comes from the same peer and
the value is only wrong once — the engine drops the first message of the
handshake with "Condition !connected_peers.has(sender) is true" and the
roster broadcast behind it papers over the loss.

With three or four ships it stops being cosmetic: every packet is attributed
to whoever sent the one before it, so an RPC from one player is processed as
though it came from another. In a design where the host is the authority and
the roster is keyed by peer id, that is as bad as it sounds.
```

## What the relay holds the socket to

Not above a line of `RelayPeer.gd`: this is about `relay/src/limits.js`, which
copies three of this file's numbers and two of `NetSession.gd`'s.

```text
BUFFER_BYTES is the relay's MAX_FRAME. The engine measures a whole frame,
header included, against the buffer: put_packet refuses a larger one, and a
socket that receives one closes itself. So no ship sends a frame over 65,536
bytes, and one that arrived at a ship would cost it its connection. The relay
drops such a frame and keeps the socket.

The relay also counts frames. A ship on a map says where it is at most once
in 150 ms (NetSession.SPOT_EVERY_MS), and the rest of what it sends is one
frame for each thing a player does. A guest talks only to the host, about 7
frames a second. The host passes every ship's spot on to every guest, and the
engine sends a broadcast as one frame to each receiver, so a host of eight
sends up to 8 x 6.7 x 7 = 373 a second. The relay allows a guest 200 a second
and the host 2,000, with ten seconds of that in hand, and closes a socket
that goes past it (code 1008).

And it expects a guest to speak. _on_connected says hello the moment the relay
admits the socket, and the join gives up at HANDSHAKE_TIMEOUT (10 s) if the
host has not answered. A guest's socket that has sent no DATA frame 15 seconds
after it was admitted is closed (1008) and its seat given back. The host is
never closed for being quiet.

None of this is a frame type, a close code or a sentence this file knows
about, and none needs to be: a ship cannot reach any of the three. What it
does mean is that a change here can now break a party at the relay. Raise
BUFFER_BYTES, say spots more often, seat more than eight, or have a guest
wait before its hello, and the relay's number has to move first. relay/test/relay.test.js reads these constants and fails when one
changes, naming the line of limits.js that goes with it.
```
