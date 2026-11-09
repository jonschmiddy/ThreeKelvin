The reasoning behind `tkg/scripts/net/RelayTransport.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Relay transport

Above `const DEFAULT_URL: String = "wss://threekelvin-relay.james-e09.workers.dev"`:

```text
A room number, and a Cloudflare Durable Object to meet in.

This is the transport that makes the game playable by four friends who have
never heard of port forwarding, and it is the reason `LobbyCode` has always
had two kinds of code. `DirectTransport` puts an ADDRESS in the code, which
works and asks the host to open a port. This puts a ROOM NUMBER in it — and
the room number is the Durable Object's own name, so there is no registry,
no allocation service and nothing to clean up. A party exists for exactly as
long as somebody is connected to it.

See `docs/netcode.md` §2 for the cost, which is roughly nothing, and for the two
constraints that shaped it: Cloudflare cannot carry UDP, and a Durable Object
must hibernate or it bills for wall-clock time.
```

Above `const DEFAULT_URL: String = "wss://threekelvin-relay.james-e09.workers.dev"`:

```text
Filled in after `wrangler deploy` prints it. Empty means the relay has not
been deployed yet, and the lobby says so rather than offering a button that
cannot work.

`wss://`, not the `https://` that deploy prints. Same host, and the scheme is
the difference between a socket and a page.
```

Above `static func url_from_args() -> String:`:

```text
The relay to talk to: the command line if it named one, otherwise the
deployed default.
The token after `relay` is only taken as a URL if it looks like one. Without
that check, `-- lobby host relay auto` sets the relay address to "auto" and
fails with a connection error about a host that was never named — the flag
reads as a transport switch, so it has to keep working as one when no
address follows it.
```
