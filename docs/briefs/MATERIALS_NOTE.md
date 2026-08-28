# Materials become items

*Reconstructed 2026-08-28. The original was written outside the repo and never
landed; `ROADMAP.md` and `MaterialTable.gd` both cite it, and the code quotes it
in four places. Everything in §1 is recovered from those quotes or from the
catalogue itself and is therefore **settled**. §3 is what did not survive and
needs a ruling before the work starts.*

---

## 1. What is already decided

**Materials are a second item class in the existing spatial hold.** Tiers,
shaped cells, sold at stations. Not a new storage system, and not a currency.
`MaterialTable.gd` says this in as many words.

**Credits are the only currency.** `RunState` still says so. Materials *sell*;
they never *price*. Nothing in the game may be bought with ore.

**`cells` is authored and load-bearing.** Every one of the 64 rows carries the
shape the item will occupy — `1x1`, `2x1`, `2x2`, `3x1`, `4x1` — and it is
carried unused today for exactly one reason: it is a decision somebody already
made, and deriving it later from a name would be guessing at it.

**The zero-migration rule.** `exotic` and `relic` are live ids in the material
ledger today and appear in the catalogue with their values and text unchanged,
so recipes, combat drops and saved runs keep working across the change. Every
other row is additive.

**`drops` is a loot-table key and never a fiction.** There are exactly five
tables, and a row belongs to the one its fiction earns:

| table | rows | |
| --- | --- | --- |
| `wreck` | 24 | precursor pieces sit here because the lore says fragments come off deep wrecks and nowhere else |
| `event` | 22 | |
| `fauna` | 9 | |
| `fight` | 7 | |
| `mining` | 2 | **known to be thin.** The next batch feeds it |

**Tier gating mirrors `LootGen`.** Rarity is a property of where you are
standing, so a rim system cannot hand out the good stuff and the deep galaxy is
worth the trip. Two deliberate exceptions:

- **CONTRABAND is ungated** — its gate *is* the risk. Security scans care what
  you are carrying, so a rim run with contraband aboard is already paying for it.
- **EXOTIC is ungated.**

**Scrapping does not yield materials, on purpose.** The scrap button used to
read `SCRAP +14 · 2 ALLOY`, and the alloy was the half that made a part into a
second currency. It was removed. Do not put it back.

**The catalogue is real and ships today.** Draft 1, 64 rows, authored
2026-08-27: ids, tiers, shapes, values and text are all live.

    tier    artifact 4 · common 16 · contraband 8 · epic 9 · exotic 9
            legendary 5 · rare 13
    cells   1x1 40 · 2x1 14 · 2x2 4 · 3x1 4 · 4x1 2

**`grant()` is the shim, and it is one function body.** It rolls a real row and
pays that row's `value` in credits. Deleting it is the change. Its only two
callers today are `OptionTable`'s payout paths.

---

## 2. Ruled 2026-08-28 — how a material leaves a hold

A module can always be cleared out of the way: `SCRAP` destroys it, pays its
scrap value, and its own tooltip rules that this works anywhere — *"Break it
down where you stand. The floor under every part — no station and no route
needed."*

**Materials have no equivalent, and cannot borrow that one.** They sell rather
than scrap, and scrapping deliberately stopped paying materials. So a hold full
of ore with no station in range would be a hold with no exit.

**The ruling: materials get JETTISON.**

- It pays **nothing**. Selling is what stations are for; this is throwing
  something overboard because you want the space more than the ore.
- The item drops into **the node's bag** — `MapNode.bag`, the same one a kill
  fills. The sector drawer already lists what is loose at a node, so a jettisoned
  material shows up there with no new state and no new screen.
- It is therefore **recoverable until you jump**, and gone the moment you do.
  Changing your mind costs nothing; changing it late costs the whole item.

This reuses the bag wholesale. `bag_left()` counts by index against `n.taken`,
so appending is index-stable and safe.

---

## 3. Not recovered — needs a ruling before the work starts

These were in the original and did not survive in any quote. Each one shapes
code, so none of them should be settled by whoever writes it first.

| # | Question | Why it matters |
| --- | --- | --- |
| 1 | **Instance or row-and-count?** Does a material become an object like `ModuleData` with its own `hold_at`, or does the hold carry a row id and a quantity? | Decides whether `cells` is per item or per stack, and whether the hold grid needs a new cell type at all |
| 2 | **Do materials stack?** Two `COIL STOCK` in one `1x1`, or two cells? | The whole feel of hold pressure. Stacking makes ore cheap to carry; not stacking makes every pickup a real decision |
| 3 | **The station sale.** Which screen, what price, and does danger or tier move it? | `value` exists per row but nothing reads it as a price yet |
| 4 | **Does `HOLD_LIMIT` count materials?** `Policy.gd` enforces a cap by scrapping the cheapest thing aboard | If materials count, the sim's make-room policy needs to know how to choose between a gun and a crate of sand |
| 5 | **Does JETTISON also apply to modules?** A free drop alongside the paying SCRAP | Dropping a module into the bag to pick it back up later is a different game from destroying it for credits |

**Question 2 is the one to answer first.** Everything else bends around it.

---

## 4. Verification

- `-- checks` and `rngtest` already exercise the option payouts that call
  `grant()`; both must still pass with the shim gone.
- A new gate in the shape of `-- mounts`: every catalogue row's `cells` parses,
  and every shape is one the hold can actually hold.
- `validate.sh` end to end. A material that occupies space changes the economy,
  so **the 500-run baseline moves under this** — take a fresh one, and do not
  read a 200-run delta as a result. Three consecutive 200-run readings of one
  build gave 20% · 13% · 16%.
