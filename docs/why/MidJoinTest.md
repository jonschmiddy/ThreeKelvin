The reasoning behind `tkg/scripts/sim/MidJoinTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Mid-join test

Above `const PORT_HOSTING := DirectTransport.DEFAULT_PORT + 29`:

```text
CO-OP: STARTING AND LEAVING A SHARED FIGHT, THROUGH THE GAME'S OWN DOORS:
  godot --headless --path . -- sheet=MidJoinTest

`-- nettest` holds the session and a bare `Combat`; this holds what
`Router`, `Combat` and the escape menu do with them, in the game's own `Net`
(Nov 5, the same-second mismatch and the three holes the review found; slice
1 of joining mid-fight, with no stun and no wire change):

  ON THE HOST, the race's answer path: the game's `Net` hosts, a partner's
  fight is already open here and this ship's check missed it
  (`Router.forced_race`, as a copy still on the wire would). Its own plan
  gives way to the partner's fight: the hulls, their intents, what SAVE &
  EXIT would restart (`current_fight`), and the log's one line, "VELA got
  here first. You join their fight."

  AS A GUEST, the game's `Net` joined to a host session built in this
  process (NetTest's loopback, one branch with its own multiplayer root), on
  plain contacts so the host side touches no `Run`:
  - the race itself, unstaged: this ship asks for a two-hull pack, and in the
    same frame the host opens a one-hull fight; the answer is the host's, and
    the kill ends it here (it used to softlock: the second hull lived only on
    this machine);
  - SAVE & EXIT while waiting on the barrier leaves the fight (the host's
    crew drops the ship) and nothing on this machine breaks when the party's
    turn moves (the fight it left was still listening, and ran a turn with no
    hull: errors counted by a Logger); CONTINUE then JOINS, grown once;
  - ABANDON mid-turn leaves too, so the partner's END TURN moves the turn;
  - a join the host answers in the same frame as the kill comes back over,
    and goes to the win, paid as crew;
  - an arrival ambush at a partner's fight says so rather than "Contact.";
  - a host slow to answer: past three seconds the ship is still asking, not
    fighting alone, and the log says "Waiting for the host."; the late
    answer is taken; and SAVE & EXIT before it comes leaves the fight the
    answer seats it in.

And the review of slice 1 (Nov 5):
  - ON THE HOST, SAVE & EXIT on a turn VELA has ended: the leave closes the
    barrier at once, and the fight left must not be listening when the turn
    moves (`Combat.abandon` lets go first);
  - AS A GUEST, CONTINUE after the party killed the fight this ship saved
    out of does not open a second one ("The fight ended while you were
    away."), while a fight everyone simply left still starts again;
  - while the host holds the ask, END TURN, FLEE, HAIL and cards are refused
    (END TURN ran a private enemy turn), and a fight that ends unbegun
    leaves the seat the late answer gives it;
  - a JOIN answered with a newer fight (the one it meant ended, a partner
    opened another) writes down the newer one for SAVE & EXIT.

And slice 2, JOINING LATE, STUNNED (Jon, Nov 5; PROTOCOL 18), as a guest in
a dive of two (so every fight is built for two, `PartyScale`):
  - a JOIN on turn 2 is stunned: no hand, no energy, END TURN reads STUNNED
    and is greyed, HAIL and FLEE are shut ("You are stunned."), no card can
    be played, END TURN does nothing; the log says "Fighting alongside
    VELA." then "Stunned. You act after the enemy's turn."; the host counts
    it as ended and waits only on VELA;
  - VELA's END TURN with the swing forced to it: it is shot, the turn moves,
    "Your turn.", the overheat check runs once for the turn sat out, and the
    hand comes; a third pilot walking in then is said "MERCER joins the
    fight, stunned until the enemy's turn is over.";
  - the kill while stunned is paid (the wrecks for the party's two);
  - a JOIN on turn 1, after VELA has fired, acts at once;
  - the ask and VELA's END TURN in one host frame, the swing forced to this
    ship: the hit is not lost ("... hit you as you arrived."), and it acts;
  - a JOIN that lands after the kill: "The fight ended before you got
    there.", no fight here, and the host opened none;
  - SAVE & EXIT while stunned leaves the crew; CONTINUE rejoins, stunned,
    the enemy grown by nothing;
  - the party dropping while stunned: the enemy's turn is taken here, then
    the hand.
```

## Host save and exit

Above `func _host_save_exit_closes_the_barrier() -> void:`:

```text
ON THE HOST, SAVE & EXIT on a turn VELA has already ended. The host's leave
is applied at once, and with VELA the only one left it closes the barrier:
the swing, the turn moving and its push, all inside the leave. A fight still
listening then runs the new turn with no hull (`abandon` lets go of the
signal bus BEFORE it leaves; the review found nothing failed with the order
the other way round).
```

## Continue after kill

Above `func _continue_after_the_kill() -> void:`:

```text
CONTINUE AFTER THE PARTY'S KILL: this ship saved out of VELA's fight, she
killed it, and CONTINUE restarted the saved fight. Her fight here was over,
so the ship asked to open one, and the host opened a fresh enemy at full
hull (at the core a second Custodian; for the Hellbender a dead ship's
reward again). And a fight everyone simply left still starts again.
```

## Host holds the ask

Above `func _pressed_while_asking() -> void:`:

```text
WHILE THE HOST HOLDS THE ASK the fight is planned, not begun, and with no
time limit on the wait that is a state a bot (or anything calling Combat)
can act in. END TURN there ran a private enemy turn (hull down, turn 2, a
hand dealt) the answer then wound back; FLEE and HAIL were open. And a
fight that ended unbegun was begun on the late answer anyway, attached: the
ship sat in the host's crew for good.
```

## Join answered otherwise

Above `func _join_answered_with_another() -> void:`:

```text
A JOIN ANSWERED WITH ANOTHER FIGHT: this ship asked to join VELA's cutter;
before the ask was read the cutter died and she opened a lancer and a hulk
here. The answer seats it in the newer fight, `begin` builds that one, and
that is the one SAVE & EXIT must restart, not the cutter that had ended.
```
