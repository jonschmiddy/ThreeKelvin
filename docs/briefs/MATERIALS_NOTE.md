# Materials become items

*Reconstructed 2026-08-28, and ruled the same day. The original was written
outside the repo and never landed; `ROADMAP.md` and `MaterialTable.gd` both cite it, and the code quotes it
in four places. Everything in §1 is recovered from those quotes or from the
catalogue itself and is therefore **settled**. §3 is what did not
survive, now answered — and §3.4 reaches well beyond materials.*

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

## 3. Ruled 2026-08-28

The five open questions, answered. Two of them turned out to answer each other.

### 3.1 Materials do not stack

Two `COIL STOCK` take two cells. Every pickup is a real decision about space,
which is the point of putting them in the hold at all.

**Leave the door open.** If hold pressure turns out to be too tight to play
against, stacking is the first knob to reach for — so the code carries a single
switch for it rather than assuming one-per-cell everywhere. It is a balance
lever held in reserve, not a maybe.

### 3.2 An instance, because of 3.1

*The question was: when you pick up a `DECK PLATE`, does the game make an object
for that particular plate — which remembers where it sits in your hold, the way
a module does — or does the hold just keep a tally, "3 × DECK PLATE"?*

**3.1 settles it.** A tally cannot say "one is here and the other is over
there", and not stacking means exactly that. So a material becomes an instance
with its own `hold_at`, mirroring `ModuleData`.

This is also the cheaper answer: `HoldGrid` already places, drags and draws
anything that has a footprint and a cell. A tally would have needed a second
kind of cell that the grid does not have.

### 3.3 `value` is the price, and stations buy

*The question was: every row carries a `value`. Is that simply the price
everywhere, or does what you are paid depend on where you sell — a core station
paying more for ore than a rim outpost — or on the danger of the system it came
from?*

**Flat.** `value` is what a station pays, anywhere, and stations are the only
buyer. Nothing else in the game prices by region, and a material whose worth
changes with the map is a spreadsheet the player has to keep.

A regional multiplier can be added later without touching one row of the
catalogue, so this is reversible if selling turns out to be too flat to think
about.

### 3.4 Nothing is ever destroyed for you

**The strongest ruling here, and it is not only about materials.** The game
never scraps, sheds or leaves behind anything of yours to make room. If
something will not fit, it does not go in — and you decide what leaves.

`take_from_bag` already works this way and is the model: *"The hold is full.
%s stays where it is."* It refuses. It does not tidy up.

**Four paths in `RunState` currently break this** and must be fixed as part of
the work. All three pick the cheapest thing you own by `scrap_value` and destroy
it, telling you afterwards in the log:

| Where | What it does today |
| --- | --- |
| `install_module` — slot full | Uninstalls your cheapest module of that slot; if the hold has no room, *"It was left behind."* |
| `install_module` — reactor loop | Shuts down the cheapest installed modules until the power fits; same silent loss |
| `transfer_to_hull` | *"Shed anything that no longer fits, cheapest first."* |
| `reseat` | Re-packs the hold after a hull swap; anything that finds no cell is *"Left behind."* |

Each becomes a refusal or a prompt. `Policy.gd`'s auto-scrap is a separate
thing — that is the SIMULATOR deciding, and a simulated pilot does have to
decide something. What it must not do is use a power the player does not have.

### 3.5 Jettison applies to everything

Not just materials. Any physical thing in your hold can go overboard: pays
nothing, lands in the node's bag, recoverable until you jump. Modules therefore
have both — `SCRAP` destroys and pays, `JETTISON` drops and does not.

### 3.6 Every physical grant is a container

Falling out of 3.4, and larger than materials: **if something hands you a
physical item, it hands you a container, not the item.** An event that pays out
in cargo opens the same two-grid view a wreck does — its grid on one side, your
hold on the other — and you drag across what you want, jettisoning or scrapping
your own things to make space if you need it.

This makes the wreck view *the* way physical property enters your ship, rather
than one special case of it. It is also the only way 3.4 can hold: a payout that
cannot refuse has to either destroy something or overflow.

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
