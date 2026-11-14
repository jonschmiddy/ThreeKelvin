- **Added** — three more automatic checks in the merge gate that keep old mistakes from coming
  back: work that belongs in `_ready` (a colour parsed, a resource loaded, an image built)
  creeping into a function that runs every frame, a test harness with no row in the test map,
  and a slip in the gate script itself (a unit defined twice). A developer tool; nothing in play
  changes.
