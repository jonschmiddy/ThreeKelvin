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
