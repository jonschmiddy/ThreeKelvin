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

## The relay holds the same check

Not above a line of `LobbyCode.gd`: this is about `relay/src/limits.js`, which
holds a copy of the ROOM half of `parse` (`isRoomCode`).

```text
The relay used to take any one to sixteen letters and digits as a party's
name. It now takes only what encode_room can make: R, five characters of the
alphabet, and the check character. A path that fails is answered by the Worker
in the words of a code nobody is hosting, and no party is woken for it.

The copy is exact and narrow. It is the ROOM kind only (a DIRECT code never
goes to the relay), and it takes the code as RelayTransport._open sends it:
normalise() has already folded case, dropped the separators and mapped the
four left-out letters, so the relay forgives case and nothing else.

So the two change together or not at all. A ROOM code the game makes and the
relay refuses is a host told "No party with that code" about the code it has
just been given. relay/test/relay.test.js is what catches it: it holds the
copy to 300 codes this file made and to this file's verdict on 430 strings
near them (relay/test/codes.fixture.json), and it reads this file and fails
when the alphabet, the lengths or _check_char are edited. That list was
written once, by this file. When the form of a code changes, make the list
again from encode_room and parse, and deploy the relay BEFORE the build that
makes the new codes goes out.
```
