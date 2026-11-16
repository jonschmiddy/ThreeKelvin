# SetBonusTest

## The promise

Every set bonus's text is checked against what the code does, from a used run,
with the set on and off. The texts sit in the test (`TEXTS`), so a changed text
fails until its check is changed too.

The Nov 14 audit found seven of fourteen texts wrong, most of them since the
first commit, and nothing that tested a single bonus. What changed, and which way:

- **Korvan 3, Standard Issue.** Said "Charge cards charge 1 turn faster". The code
  floored the wait at 1, so the 1-turn Mass Driver, Korvan's first charge card, got
  nothing, and only Korvan cards were ever counted. CODE to the text for the 1-turn
  case (it fires when played); TEXT to the code for whose cards ("Korvan charge cards").
- **Solari 3, Sunward.** Said "Plasma weapons gain +2 damage". The code gave it to
  Solari cards with heat scaling: in the first commit that was the Plasma Lance, which
  was the only plasma weapon, and the flashpoint guns and heat-damage cards that came
  later never got it. CODE to the text: every Solari card that deals damage.
  Nov 16: replaced by **Heat Blast** (Jon's pick 2A): "When you vent heat, the
  enemy takes half of it as damage." Any vent, rounded up
  (`docs/why/CardResolver.md#heat-blast`).
- **Verity 5, Provenance.** Said "Start each combat with 1 extra energy". The code
  gives 1 every turn (`RunState.reactor`, kept flat on purpose). TEXT to the code:
  a 5-set worth one energy a fight would be the weakest bonus in the game.
- **Cygnet 3, Swarm Logic.** Said "act twice on the turn they launch". Drones
  attack at the start of your next turn, so none ever attacked on its launch turn.
  TEXT to the code: twice the first time it attacks.
- **Cygnet 5, Hive Mind.** Said "Drones persist between encounters". No code did
  anything. New code (`Combat._hive_in`/`_hive_out`, `Run.hive_drones`, save 44):
  the three strongest attack drones a fight ends with are out at the next one's
  start. Capped, because uncapped drones grow every fight for sixty jumps.
- **Calyx 3, Cultivar.** Said "Heal 3 after each combat". A flee heals nothing, as
  PATCH CREW does not. TEXT to the code, in PATCH CREW's words.
- **Calyx 5, Symbiosis.** Said "1 exotic material after each fauna encounter". It is
  one more in each killed creature's wreck; a flee pays nothing (the loot ruling).
  TEXT to the code.

The other seven matched their code and kept their text.
