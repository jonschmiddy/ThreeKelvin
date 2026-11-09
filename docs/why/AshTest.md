The reasoning behind `tkg/scripts/sim/AshTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## A.S.H. test

Above `var _tree: SceneTree`:

```text
A.S.H. (`Ash`, `AshPortrait`, `AshLines`), on the real screens, headless:
  godot --headless --fixed-fps 60 --path . -- sheet=AshTest

THE LINES are the thirty Jon and Ashlee kept, character for character
(`docs/ash_lines.json`), seven moments.

EACH MOMENT FIRES ITS LINE, through the real LOCAL and the real fight: the
launch; a new hull, once the move is done and not mid-dock; the hull failing
(on LOCAL and in a fight); over the heat cap in a fight; a big haul (a chit,
an epic part) and not a small one; the third wreck opened since docking and
not the second; a doubt on a late jump. Each line said is one of its own
moment's.

THE RATE LIMITS HOLD: one at a time; COOLDOWN_S of quiet before an ordinary
line and only BIG_GAP_S before a big one; one line a fight, a second only for
the hull failing; never started during a card drag; never on the enemy's
turn; a moment past its wait is dropped.

A CLICK NEVER CUTS HER (Jon, Oct 22: "He also clicked to make her shut up
when she was giving her quips"; a quip "plays out and ends on its own"): real
clicks through the viewport on her box and on the picture, a card picked up
and dragged, a wreck's window opened clear of her: she is still saying it,
and ends of herself with her power-down.

NOTHING AFTER LOSS: the hull at 0 or the run over, nothing is said whatever is
waiting, and a line up when the ship goes is gone that frame.

HINTS WIN: with the hints on, she does not start while a hint card is up or a
hint is settling, a hint coming due while she talks waits for her to end, and
she speaks after the hint is done.

THE BOX TEST, on every screen she speaks on -- LOCAL fresh in each weight,
LOCAL with one to six wrecks, LOCAL with an event's subject, a fight against
every kind alone and in packs of two and three, in each weight -- her box is
inside the view and clear of a list gathered here, apart from
`Ash.avoid_rects`, so she cannot pass by agreeing with herself: the HUD, the
goal line's band, the bar under the view and everything on it, the hand
panel and every card, pile, gauge and button in it, your hull, its shield's
oval, its plate, the numbers a hit on it pops (made by the fight's own
`_pop_at`), every enemy's hull, words, plate, oval and pops, every wreck and
its name, an event's subject, a hint card. A screen where no spot is clear
fails: she must have somewhere to stand. Prints which spots were clear where.

THE TALK: the mouth follows the letters, and the face changes 8 to 12 times a
second while she talks (Jon judges motion per second; the fire ruling), every
change a held frame at least TICK_S long; she blinks and the hologram slips.

HER VOICE (`AshLines.VOICE`, `Audio.ash_voice`), read off `Audio.tape`, which
records her takes headless where nothing plays: every voiced line plays its
own take exactly once, VOICE_AT after she appears (after the chirp) on the
frame its words start, and the words type for as long as the take within
10%; the lines with no take yet are text alone, at once, with nothing taped;
END TURN, the ship lost and Settings' switch each stop the voice where they
cut the words (a card picked up and a hint settling no longer cut her);
switched off, no voice.

HER POWER-DOWN AND NO CLICK AS SHE GOES: a line that ends of itself plays the
power-on's two blips reversed (`text_blip_rev`), the higher first, the last
ending on the frame the projection goes and the first CHIRP_GAP before it
(one blip in reduced motion), and so does one a card dragged or a hint
coming due let play out; END TURN, the ship lost and Settings play none, and
a cut during it hushes it. Every take,
rendered through Godot's own decoder (`AudioStreamPlayback.mix_audio`), stops
at the end of her last word without a step: the sharpest sample jump within
30 ms of it under CLICK_MAX times the jumps round it (the takes as first made
measured up to 159: ElevenLabs ends a take mid-waveform, and the chain's
silence after it made the edge a click); the blip and its reverse start and
end at rest; and every looped room tone under her (`Audio.loop_whole`)
crosses its seam without a step (they clicked every lap, 17 to 148 times).

NOT PRESSABLE: everything in her ignores the mouse, no button, no hand.
OFF: under a harness that did not ask, and with Settings' switch off.
```

## Introduction

Inside `_moments()`, above `var intro := String(AshLines.of(&"launch")[3])`:

```text
HER INTRODUCTION, EVERY NEW RUN (Jon, Oct 20): two new runs in a row each
open with launch_04; a later launch in the same run is the bag's; a run
picked up with CONTINUE has none due
```

## Hull line

Inside `_moments()`, above `Rng.forced = 4242`:

```text
HULL: ONLY A HULL BOUGHT MID-RUN (Jon, Oct 18: "New body..." only "when a
player buys a new ship mid run"). Not the chassis select's picks before
launch -- it fits a hull per click, and the first LOCAL heard "New body"
on every new run --, not a resume, not a hull found in the field.
```

## Click never cuts her

Above `func _clicks() -> void:`:

```text
A CLICK NEVER CUTS HER (Jon, Oct 22: "He also clicked to make her shut up
when she was giving her quips"; a quip "plays out and ends on its own"). On
LOCAL, real clicks on her box (where a player clicks to send her away); in a
fight a card pressed and let go, and a card pressed and dragged out to aim;
on LOCAL a wreck's window opened while she talks (she stays if it is clear
of her box, as it is in her corner). Each time she is still saying it, and
it ends of itself with her power-down.
```
