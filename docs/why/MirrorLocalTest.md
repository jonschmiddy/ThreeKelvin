Reasoning for `tkg/scripts/sim/MirrorLocalTest.gd`.

## MirrorLocalTest

LOCAL at a station, drawn both ways: moored on the station's left, as ever, and on
its right after an undock (`docs/why/SectorScreen.md#mirrored`). Two made-up
partners (`ConvoyTest.fake_party`) stand in for a party. One process holds one
pilot, so the mixed case (a partner moored the other way) is this pilot's view
drawn each way, with the partners' moves driven through the roster as a presence
would drive them.

- **Layout.** Where the station, your hull and the partners are, that every hull
  faces right, that each name reads, and that nothing overlaps the station or
  leaves the screen.
- **Moves.** A partner docking flies into the mouth (left) or fades where it sits
  (right). One undocking comes out of the mouth: backing out, right to left, or
  nose first, left to right. One arriving jumps in (left) or comes through the
  dock (right).
- **Saved.** `moored_right` goes into the save and comes back out, and a jump
  drops it.
- **Clicks**, pushed into the viewport as a hand makes them. Your hull opens it
  up. The station's mouth is no button and no dead one. DOCK docks: flying in
  from the left, black and the landing from the right.
