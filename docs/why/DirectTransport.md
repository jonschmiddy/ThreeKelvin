The reasoning behind `tkg/scripts/net/DirectTransport.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Direct transport

Above `const DEFAULT_PORT: int = 31337`:

```text
ENet at a plain address, with the address folded into the lobby code.

This is the transport that needs nobody: no service, no account, no bill,
no dependency that can be switched off. It is also the one that asks the
host to forward a port, which is a real cost paid by a real person before
anyone can play. Both halves of that are true at once and neither should be
hidden from the host.

It earns its place regardless of what ships, because it is the only
transport that can be tested on one machine with no external parts. Every
rule above it — the roster, the handshake, the version check, the launch —
is exercised by the headless test through this class. A relay or a platform
backend arriving later inherits a session layer that has already been made
to work, rather than being the thing that has to prove it.
```

## Public guess

Above `func public_guess() -> String:`:

```text
The best address this machine can name for itself WITHOUT asking anything
on the internet, which on a home connection is a LAN address and therefore
wrong for anyone outside the house.

This is not a gap to be closed by trying harder. A machine behind NAT cannot
learn its own public address by looking inward; something outside has to
tell it, and the moment you add that something you have a service, and once
you have a service the room transport is strictly better than this one. So
the LAN address is the honest answer here, and the lobby is expected to let
the host type a public address over it.
```
