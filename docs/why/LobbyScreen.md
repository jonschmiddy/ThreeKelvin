The reasoning behind `tkg/scripts/ui/LobbyScreen.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Lobby design

Above `const READY_COLOUR := UITheme.GOOD`:

```text
The party, before the dive. Read a code out, type a code in, watch four
names arrive.

This is the first screen `NetSession` has ever had. Everything it shows was
already working headless — `-- nettest` forms a party of four in one process
— so nothing here decides anything. It reads `Net` and it calls four methods
on it. That is deliberate: the session layer must not learn about screens,
and a lobby that held state of its own would be a second roster to disagree
with the first.

**The address problem is on this screen and it cannot be solved on it.**
`DirectTransport` folds the host's address into the code, and a machine
behind a router cannot learn its own public address by looking inward. So the
host gets a LAN address by default and a field to type a real one over. That
is honest rather than good, and it is the whole argument for the relay
transport in `docs/netcode.md` §2.
```

## Party signals

Inside `setup()`, above `Sig.party_changed.connect(_rebuild)`:

```text
Connected, and never disconnected. Leaving this screen is not leaving the
party — the dive starts from here and the peer has to survive the swap
into the sector — so there is nothing to tear down. Godot drops the
connections with the node.
```

## Defaults

Inside `setup()`, above `_name_text = "PILOT-%d" % (randi() % 900 + 100)`:

```text
Defaults live here rather than in _build_offline(), because the rebuild is
deferred by a frame and the command-line flags below fire before it. The
fields are a view of these strings; nothing reads a field to decide
anything, which is what makes the two orders equivalent.

A different callsign per instance, so two windows on one machine are
telling each other apart before the player has typed anything. Testing
this screen means running it twice, and two rows both reading PILOT is
the first thing that makes the roster unreadable.
```

## Dev flags

Above `func _run_flags() -> void:`:

```text
Dev flags:
  godot --path . -- lobby host          opens a party, prints the code
  godot --path . -- lobby join CODE     joins that code

They exist because testing a lobby means running it twice at once, and
reading a code off one window to type into another is a slow loop to be in
while the thing you are changing is the code itself. They also make the whole
party path testable headless, which is how this screen was checked at all.
```

Inside `_run_flags()`, above `for i in argv.size():`:

```text
`-- lobby host crowd 6` fills the roster with ships nobody is flying.

The only other way to see this page at six is to start six Godot
processes, and the thing worth looking at — whether READY and LAUNCH
DIVE are still on the screen — is a layout question that does not need
six real peers to answer. The roster is faked; the page is not.
```

## Host options

Above `func _host_box() -> Control:`:

```text
Two ways to open a party, and the difference between them is the whole of
`docs/netcode.md` §1 compressed into two buttons.

The relay is offered first and reads as the ordinary choice, because it is:
nobody opens a port and nobody types an address. Direct stays because it is
the only one that works with no service behind it — on a LAN, on a plane, or
on the day the relay is down.
```

## Roster scroll

Inside `_build_party()`, above `var rows := VBoxContainer.new()`:

```text
THE LIST SCROLLS, and it is READY and LAUNCH DIVE that this protects.

A row is 51px of panel plus 8 of separation and the first one starts at
154, so the buttons underneath walk off the bottom of a 540 viewport at
about six ships. Measured, not guessed: `-- lobby host` and a ruler. At the
tuned party of four there is room and this changes nothing; the moment
MAX_PLAYERS is raised it is the difference between a host who can press
LAUNCH and one who cannot.

That is not hypothetical — a six-ship party formed correctly on the wire in
testing and could only be launched because the `auto` flag pressed the
button programmatically. Nobody could have done it by hand.
```

## Copy button

Above `func _code_box() -> Control:`:

```text
The code, big, with a button that puts it on the clipboard.

COPY is not a convenience. A lobby code is shared by pasting it into a chat
window, and a code that can only be READ off the screen makes the player
transcribe fourteen characters by hand into the one place a typo is most
likely — which is the exact failure the check character exists to catch, now
caused by the interface rather than caught by it.
```

## Note wrapping

Inside `_code_box()`, above `var note := UITheme.body(`:

```text
WRAPPED, and its absence was not cosmetic.

A Label with no autowrap reports a minimum width of its whole line, and
this line is about two hundred characters — so the lobby's column claimed
roughly 1200px inside a 960px viewport. A Control does not clip its
children, so nothing looked broken; the page simply extended past the right
edge of the window and everything anchored to that edge went with it. BACK
was cut to "B", and every roster row's READY / STANDING BY chip was off
screen entirely.

Which is how a wrapping bug gets reported as "the host cannot see who is
ready". The chips were being built and bound correctly the whole time.
```

## Launch seed

Above `func _on_launched(seed_value: int) -> void:`:

```text
The seed the host rolled, made into a galaxy on this machine.

This is the payoff and it is worth being precise about what it proves: both
machines now run `MapGen` and `GalaxyGen` over the same master seed, so both
sectors hold the same systems with the same names, the same danger and the
same shelves. Nothing is being kept in step — there are no gameplay messages
yet. The galaxy agrees because it was derived, not because it was sent.

It goes through Router.new_run() rather than starting a run here, so the
party lands on the chassis select exactly as a solo run does. Four players
pick four different ships on one galaxy, which is the party composition rule
rather than an oversight.
```
