The reasoning behind `tkg/scripts/net/LobbyCode.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Lobby code

Above `const ALPHABET: String = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"`:

```text
The short string one player reads out and three others type in.

A lobby code is not a nicety. It is the only part of joining that a player
touches, and every transport below it has to produce one, so it is defined
here once and independently of how the packets actually travel.

Two kinds exist, told apart by the first character:

  D  DIRECT  — the code carries the host's address. 12 characters.
               Needs no service of any kind. Needs a reachable host.
  R  ROOM    — the code carries a random room number. 7 characters.
               Needs a rendezvous service. Needs nothing of the host.

The alphabet is Crockford base 32: no I, no L, no O, no U. Those four are
the characters people mis-read and mis-type, and a lobby code is read aloud
over voice chat more often than it is pasted. Parsing is case-insensitive,
ignores dashes and spaces, and maps the four excluded letters onto the
digits they look like, so a player who types ILO gets 110 and joins anyway.

Every code ends in a check character. Without it a mistyped code produces a
valid-looking address that times out thirty seconds later, and the player
has no way to tell a typo from a firewall. With it the typo is refused
immediately and by name.
```

## Bit plumbing

Above `static func _push(bits: Array[int], value: int, count: int) -> void:`:

```text

Base 32 packs five bits per character, and neither payload is a multiple of
five: DIRECT is 48 bits into 10 characters (50), ROOM is 25 into 5 (25). The
spare bits are zeros on the end and are read back as zeros, which is why
_unpack pads rather than trims.
```
