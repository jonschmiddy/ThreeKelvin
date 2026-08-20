# Handoff — ship builder, module gauges, and the melt/scrap resolution

**19 Aug 2026 · Jon's session · for James**

All of this is **uncommitted, on `main`**. 25 files modified, 2 new. The merge gate
passes — `SIM_RUNS=300 bash .github/scripts/validate.sh` came back green at
**22% wins, 58.7 avg jumps, 0 errors**, which is on the documented baseline.

---

## James — read this bit first

**`Market.gd` is byte-identical to HEAD.** So is `sim/MarketTest.gd`. I verified both
with `git diff --stat`, which returns zero lines for each. I started editing `Market.gd`
mid-session, was told the market is your area, and reverted it with
`git checkout --` rather than trying to unpick the edit by hand.

But **things around it changed**, and three of those touch your territory:

1. **`Market.melt()` is no longer reachable from gameplay.** Its only caller is
   `RunState.scrap_value_of()`, which is still the price behind the SCRAP button.
   The function, `MELT`, `MELT_PERK` and the `melt <= ask` invariant are all exactly
   as you left them, and `-- market` still exercises and passes them. Nothing is
   broken; the vocabulary just moved (see *Scrap vs melt* below).

2. **Alloy is retired.** It came off every part you scrapped, which made it behave
   like a second currency. It is gone from `DB.MATERIALS`, `ALLOY_BY_RARITY` is
   deleted, and the corona event now pays 85 credits instead of 70 scrap + 2 alloy.
   `exotic` and `relic` are untouched.

3. **Two fabricator recipes went with it** — `HULL PATCH` (10 scrap + 2 alloy → 12 hull)
   and `FUEL SYNTHESIS` (8 scrap + 2 alloy → 20 fuel). Both duplicated a station
   service (`REPAIR`, `REFUEL`) at every development level, and their real cost was the
   alloy. Re-costing them in pure scrap would have undercut `Market.repair_rate()` and
   `refuel_price()` — your numbers — so I retired them instead of guessing at a price.
   **`COOLANT BRAID` kept its exotic** and lost its alloy: 25 credits + 1 exotic → +3 heat
   cap. `RELIC ANALYSIS` untouched.

**Consequence worth your opinion:** the fabricator now has two recipes, both `dev = 3`.
`Database.gd` carries a note saying *"the two basic recipes are dev 0. A station on
unclaimed ground is still a station, and gating cheap fuel behind a flag on the wall is
what strands people."* That is no longer true of the fabricator. Nobody is actually
stranded — `REFUEL` is sold at every station — and stranding held flat at 34% across
sims either side of the change. But the fabricator is now a deep-space feature only,
and if you want the dev-0 rung back it needs a cost that isn't alloy and isn't a
better deal than your service desk.

---

## Scrap vs melt — they were the same thing

This caused real confusion and is worth knowing before you read any of the diff:

```gdscript
func scrap_value_of(m: ModuleData) -> int:
	return Market.melt(m)          # RunState.gd, unchanged
```

One operation. The UI said **SCRAP**, your pricing file said **melt**, and a
drag-to-destroy cell added earlier in the session said **MELT**. Three names, one verb.
That third name is what made it look like two mechanics.

Where it landed:

- **Scrapping survives and pays credits only.** `SCRAP +14` on the station and the
  sector salvage prompt. The `· 2 ALLOY` half is gone.
- **The MELT drag-cell on the refit screen is gone.** A drag-to-destroy target sitting
  beside the storage grid made the one irreversible verb the easiest thing to hit by
  accident.
- `RunState.scrap_module()` no longer calls `materials_from()`; that function is deleted.

---

## What was built

### 1. Ship builder — drag and drop, with fixed hardpoints

`ShipScreen.gd` is rebuilt as a workbench. Two new files:

| file | what it is |
|---|---|
| `scripts/ui/ModuleIcon.gd` | a module as a 44px inventory icon — maker field plate, house stripe, verb glyph from `CardData.glyph_kind()`, rarity border |
| `scripts/ui/ModuleCell.gd` | a place a module can sit: `HARDPOINT` or `STORAGE`, plus the drag plumbing |

**`ModuleData.mount` is the load-bearing new field.** `ShipView` has always drawn
weapons at three fixed places on the hull — dorsal ordnance, ventral barrels, aft
mount — but it read that index off the **order of the `installed` array**. So taking
the dorsal gun off slid the ventral one up onto the spine, and the ship rearranged
itself under a change the player never made. `mount` stores the choice.

Touches: `RunState.free_mount()` / `module_at()`, every install/uninstall path,
`ShipView` (three draw loops → `_draw_weapon` / `_draw_system` / `_draw_util`),
`ShipSprite` (the real-art path picks its anchor the same way), and `SaveGame`
(round-trips `mount`; a pre-`mount` save gets its fitted parts seated on load rather
than coming back as a ship with no guns).

Dragging one fitted part onto another **exchanges** them rather than sending one to
the hold — arranging the ship shouldn't cost a part or need hold space.

### 2. Modules now feed the ship's gauges *(behaviour change — read this)*

This is the one with real gameplay consequences.

Four of the six attributes ignored modules entirely. `max_hp()` returned
`hull.max_hull` and stopped, so **armour plating added no armour** — in combat as well
as on the ship tab. It went unnoticed because Sensors and Stealth, the two attributes
with no underlying gauge, always summed `installed`.

`Run.max_hp()`, `heat_cap()`, `dissipation()` now sum fitted modules, and
`dodge()` / `initiative()` / `fuel_factor()` are new accessors that do the same.
`ModuleData` gained the matching passive fields.

**The rule, now in `CLAUDE.md`: sum in the GAUGE, never in `attr_*()`.** An attribute
is a *reading*. A plate that only moved the reading would show on the ship tab and do
nothing in a fight, because `Combat.gd` calls `max_hp()` and never calls `attr_hull()`.
`Combat.gd:298` now rolls enemy misses against `Run.dodge()` for the same reason.

`RunState._clamp_hp` rides `Sig.ship_changed` so unbolting plate takes its hull back.
It's hung on the signal rather than called from the four places that move `installed`,
because one of those is the drag handler editing the array directly.

Values went on 18 modules whose names already implied them (plate/bracing/slag/lattice
→ hull; shroud/overdrive → heat cap; coolant lines → dissipation; Ghost Drive and Chaff
→ dodge). **Nothing carries `fuel_factor`** — it raises Thrust and the price of every
jump together, and the sim already strands a third of runs, so a number invented for it
would move the most fragile figure in the game. The gauge sums it; the catalog waits
for an actual engine module.

Measured: 600 runs before and after, both **20%**. The values are small enough to sit
inside noise.

### 3. Attribute block shows chassis / gained / lost

`Run.attributes()` now returns `base` alongside `value` — the same attribute read off
the bare chassis. `AttrBlock` paints three states:

- **base** — the manufacturer's accent colour, solid
- **gained** — solid **bright white**
- **lost** — an unlit cell with a **red diagonal slash**

Both choices dodge a palette collision. The seven accents (`#d97b2e`, `#ef9f27`,
`#b3924e`, `#e24b4a`, `#8a7340`, `#58c8d8`, `#3f8f6b`) cover orange, gold, red,
cyan and green — so white is the only bright colour no house flies, and a red
*fill* would be invisible on a Redline ship. The loss cell therefore does not
compete on colour at all: it is drawn exactly like an empty cell, and only the
slash is added. It is the sole diagonal anywhere in the interface.

Verified both branches on a real ship: a Redline medium reads SENSORS base 2 /
value 3 (one white cell, from the Signal Board), and fitting a Solari Flare Rack
takes STEALTH from base 3 to value 2 (one slashed cell).

`base` and `value` are both computed in `RunState` rather than differenced by the
caller, because the difference has to be taken **after** the rounding and clamp — a
module worth 0.4 of a cell moves neither number, and subtracting raw values would paint
a bonus cell the attribute does not have. The tooltip states the arithmetic in words
("Chassis 40, fitted modules +3") so a sub-cell contribution is still visible.

Also: `board` (Signal Board) and `scope` (Ranging Scope) now grant +1 Sensors. They were
carrying their names as pure flavour.

### 4. Two bugs

**Salvage prompt re-offered your own parts.** `SectorScreen._refresh_salvage` re-opened
on `Run.cargo.size()` growing. That was correct until the refit screen learned to drag a
part off a hardpoint *into* the hold — which also grows it. So stowing your own coolant
line made the sector offer it back as fresh salvage. Fixed with `Run.hauls`, bumped by
`stow()` and nothing else: salvage, purchases and fabrication are hauls; a part moved off
a mount is not. Deliberately outside the save.

**Containers laid out at double size for one frame.** `queue_free()` is deferred, so the
common `for c in box.get_children(): c.queue_free()` followed by `add_child()` leaves the
container holding old *and* new children until the frame ends. Usually invisible; very
visible on a grid of 44px icons rebuilt synchronously from a drop handler with no
clipping. Extracted as **`Widgets.clear()`** (remove, then free).

> **Ten other screens still free deferred this way** — `StationScreen`, `EventScreen`,
> `SettingsMenu`, `ChassisSelect`, `EncounterView`, `SectorScreen`. None is known to
> misdraw. `Widgets.clear()` exists so the next one written has the right thing to call.

### 5. Refit screen layout

Manufacturer banner spans the ship's full height; ship centred beside it. Header is
three lines — name, **manufacturer in its own colour**, then `MEDIUM CHASSIS · C TIER`
in grey. Set progress moved out of the hardpoints header into the abilities block as a
`2 / 3` column, with other manufacturers' progress listed below it.

`STORAGE_COLS` is **6, and the number is load-bearing**: measured, at 8 the two panels
demanded 985px of a 944px viewport and the last column hung off the screen. The left
panel can't give any back — its 527px is the banner plus the ship at 2x. 6 columns is
303px and the total is exactly 944.

Empty hardpoints draw their outline as a **child** at icon size, not as the cell's own
stylebox border — the panel is 48px and its content rect is 44px, so an empty mount was
showing a 48px border where a filled one showed a 44px plate, and the empties read
inflated. They also carry their mount number.

Picking up a part now marks **every cell that refuses it with an X**, via
`NOTIFICATION_DRAG_BEGIN` (which fires on every control in the tree — `_can_drop_data`
only fires on the one cell under the cursor).

---

## Rulings added to `CLAUDE.md`

Two rows, both in the "do not silently reverse" table:

- **A gauge is the chassis PLUS everything bolted to it.**
- **`fuel_factor` cuts both ways, so no module carries it.**

`CLAUDE.md` has **not** been updated for the alloy/recipe/melt changes yet — its economy
section still describes scrapping as yielding materials. That edit is waiting on your
read of the fabricator question above.

---

---

## Currency is now CREDITS, and the hold got bigger

Two more changes landed after the above. Neither touches `Market.gd`.

**`Run.scrap` → `Run.credits`**, `add_scrap()` → `add_credits()`,
`CardData.scrap_cost` → `credit_cost`, `CardData.scrap_gain` → `credit_gain`,
`EnemyTemplate.scrap_reward` → `credit_reward`, and the `RECIPES` cost key
`scrap` → `credits`. All player-facing text says credits.

**`ModuleData.scrap_value` is deliberately NOT renamed.** It is a *valuation* —
"what this part is worth when scrapped" — and it is **the only code reference to
`scrap` anywhere in `Market.gd`** (line 47, `return m.scrap_value`). Leaving it
alone is what let a 216-site rename happen without touching your file. Please keep
that name if you can.

The verb survives too: you still *scrap* a module, and you are paid in credits.
`scrap_module()`, `scrap_value_of()` and the SCRAP button all keep their names.

Persistence: the `SaveGame` key is now `credits` (the `VERSION` gate discards older
files anyway) and `RunHistory` writes `credits`. The Audio sound id `&"scrap_gain"`
is an asset filename and was left alone.

**Cargo slots 4 / 8 / 12 → 8 / 12 / 16.** Every frame gained four, and the spread
narrowed from 3× to 2×, which is a real cost to heavies — taken deliberately,
because valuables are coming and a 4-slot skiff could not carry a trade good and a
spare weapon at once. `HeadlessSim.HOLD_LIMIT` stays 4: it is a *behaviour*
(what a competent player chooses to haul), not a capacity, and it must stay at or
under the smallest hull.

Measured across the pair: **20% → 22% at 300 runs each.** Inside noise.

The refit screen's storage grid is 4 columns, so 8/12/16 draw as exactly 2, 3 and
4 full rows — no ragged last row on any ship. Measured worst case (heavy, hold
full): right panel wants 421px of a 494px viewport and 229px of width.

---

## Spec: valuables *(not built — this part is yours)*

Jon's idea, and the reason the hold was widened. **Not implemented**, because the
price model belongs in `Market.gd`.

**The concept.** Credits are electronic, so physical *valuables* become a carryable
item — ore, art, medical stock, contraband luxuries. They sit in the same hold as
modules and compete for the same slots. That competition is the design: a hold full
of cargo means no room for the loot that IS your build.

It fits a ruling you already wrote — *"the profit is in the distance between two
places, not in one transaction."* Valuables are the purest expression of it.

**What exists already and should be reused:**

- `Run.cargo` is `Array[ModuleData]` and `Run.stow()` is the single door in, with
  the capacity check already in it.
- `Run.hauls` (new) already distinguishes "something arrived from outside" from
  "a part moved off a mount", which the sector salvage prompt keys on.
- `ModuleCell` / `ModuleIcon` render a hold slot. **`ModuleIcon` derives its glyph
  from `module.cards[0].glyph_kind()`** — a valuable has no cards, so it needs
  either its own icon path or a `glyph_kind` of its own.
- `_saturation(n)` already stops one station absorbing an unlimited hold.

**What Market needs — the actual ask.** A valuable has no manufacturer, so
`demand(n, manufacturer)` has nothing to key on. It needs a parallel price model,
something like:

```gdscript
## What THIS place pays for a good of that kind. The trade map already exists on
## the chart; this is the second axis on it.
static func good_price(n: MapGen.MapNode, kind: StringName) -> int
```

keyed on a good's kind against the node's `development` / `region` / `makers` —
an industrial world is long on ore and short on medical, and the reverse in a
capital. The existing `ask` / `bid` / `SPREAD` / `_saturation` machinery should
carry over unchanged; it is only `demand()` that has no answer for a crate.

**Open questions for you:**

1. Do valuables have a *buy* side (a real trade loop) or are they loot-only? A buy
   side makes a pure trading strategy possible, which `CLAUDE.md` currently calls
   out as the failure mode to avoid.
2. Does a valuable stack, or is one slot one crate? Stacking changes the hold
   pressure that motivated the whole change.
3. Do they interact with inspections the way contraband does?

---

## Still open

| | |
|---|---|
| **Valuables** | Spec above. Needs your price model. |
| **Fabricator is dev-3 only** | Both dev-0 recipes retired with alloy. Wants your call on whether a basic rung comes back and at what cost. |
| **`salvage_rack` perk** | *"Scrapping modules pays +50%"*, on all three Dredge hulls. It broke when melting was removed and **works again** now that scrapping is back — it multiplies `Market.melt()`. No action needed, but you should know it's the only gameplay path left into that function besides the SCRAP button. |
| **`CLAUDE.md` economy section** | Stale on materials-from-scrapping, and still says "One currency: scrap". |
| **Nothing is committed** | ~25 modified, 2 new, all on `main`. |

## Verification run

```
SIM_RUNS=300 bash .github/scripts/validate.sh     # PASSED
  market      ok          # your invariant, untouched, still holds
  savetest    ok          # 0 mismatches, incl. the new `mount` field
  sim         300 runs · 22% wins · 58.7 jumps · 7.7 kills · 0 errors
  boot        ok
```

Plus `-- ship` and `-- station` booted by hand with no errors or warnings.
