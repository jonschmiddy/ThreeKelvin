# batch-01 — Whitelist Verification

Per `README.md` step 1: every effect line in `events/batch-01.md` parsed
against the closed MVP whitelist in `events/EXPANSION.md`.

**README expected zero violations. There are 30.**

| | Count |
|---|---|
| Outcome bands in batch | 46 |
| Parse clean against the whitelist | 16 |
| Carry at least one non-whitelisted effect | 29 |
| Whitelist-clean but violate the pile-on guard | 1 |
| **Fully conforming** | **15 of 46 (33%)** |

No mechanic was improvised and nothing was rewritten, per the README's
closing rule. This is a report.

---

## 1. The finding, in one line

**The whitelist's DEFERRED list reads like an inventory of batch-01's
mechanics.** These two documents were written against each other and
never reconciled. This is not a batch that drifted from its contract —
it is a batch built on the systems the contract explicitly defers.

`EXPANSION.md` states the rule that decides it:

> Every event must fully resolve within itself. If an outcome wants to
> be remembered later, it isn't an MVP event.

Roughly half of batch-01 consists of outcomes that want to be remembered
later, *by design*. The ghost that keeps spending your name until you
resolve it. The lane that stays open region-wide. The fence at the
crossroads who prices you kindly for the rest of the run. That is the
best writing in the batch and it is precisely what the rule excludes.

---

## 2. Violations by category

Bands can carry more than one, so these sum above 29.

| Deferred system | Bands | Where |
|---|---|---|
| Run-state / cosmetic flags | 13 | `ghost_active` ×5 · `solari_blessed` · `blasphemer` · lane-open ×2 · `frame_groan` · blessing-effects ×2 · hidden flag |
| Price modifiers | 6 | Solari −30% · annex +15% · crossroads fence +10% · unannounced discount |
| Forced routing / time costs | 4 | route +1 jump · route +2 jumps · one encounter tick · ejected off-course |
| Notoriety −N | 3 | EVT-005 opt 1, all three bands |
| Next-jump fuel modifiers | 3 | EVT-073 opt 4, all three bands |
| Module / attribute debuffs | 2 | Thermal −1 · Thrust −1 |
| Encounter suppression | 1 | EVT-084 opt 1 CLEAN |
| Ally combat entities | 1 | EVT-084 opt 1 PARTIAL |
| Pacify conditions | 1 | EVT-029 opt 2 BOTCHED |
| Moving map hazards | 1 | bloom migrates one node |
| Consumables / temporary buffs | 1 | false registry, 1 charge, Stealth +2 |
| Non-whitelisted combat parameter | 1 | "enemy knows your chassis weaknesses" |
| Station access change | 1 | "docking refused" |

---

## 3. Line by line

Legend: ✅ parses · ❌ non-whitelisted effect · ⚠ pile-on guard

### EVT-005 — Registry Ghost
| Option | Band | Verdict |
|---|---|---|
| 1 Pull logs | MET | ❌ Notoriety −1 · ❌ consumable + temporary Stealth +2 |
| 1 | SHORTFALL CLEAN | ❌ Notoriety −1 |
| 1 | PARTIAL | ❌ Notoriety −1 |
| 1 | BOTCHED | ❌ `ghost_active` flag, persists past the event |
| 2 Board her | CLEAN | ✅ scrap · module (rarity rolled) · reveal node |
| 2 | PARTIAL | ✅ scrap · destroy installed module · hull damage 1 |
| 2 | BOTCHED | ❌ "enemy knows your chassis weaknesses" is not a listed combat parameter |
| 3 Hail her | RESULT | ❌ `ghost_active` flag |
| 4 Shear the mast | CLEAN | ❌ "ghost resolved" (flag clear) |
| 4 | PARTIAL | ❌ "ghost resolved" |
| 4 | BOTCHED | ⚠ hull damage 2 **+** combat — two of {hull, malfunction, combat} |
| 5 Log and jump | RESULT | ❌ `ghost_active` persists |

### EVT-029 — Spore Bloom
| Option | Band | Verdict |
|---|---|---|
| 1 Go dark | MET | ✅ exotic +2 · Heat ≤1 hard gate is legal |
| 2 Run it hot | CLEAN | ✅ heat +1 |
| 2 | PARTIAL | ❌ Thermal −1 until station service |
| 2 | BOTCHED | ❌ "pacifiable by dropping to Heat 0" |
| 3 Flare decoy | RESULT | ❌ route +1 jump (scrap −30 itself is fine) |
| 4 Feed it | MET | ❌ map flag: lane open region-wide |
| 4 | SHORTFALL PARTIAL | ❌ flag · ❌ bloom migrates (moving map hazard) |
| 4 | SHORTFALL BOTCHED | ✅ combat, enemy initiative |
| 5 Reroute | RESULT | ❌ route +2 jumps |

### EVT-047 — The Tithe
| Option | Band | Verdict |
|---|---|---|
| 1 Vent heat | MET | ✅ heat → 0 · ❌ −30% prices · ❌ `solari_blessed` |
| 2 Pay cold tax | MET | ✅ scrap −120 · Scrap 120 hard gate is legal |
| 3 Fake a surge | CLEAN | ❌ inherits blessing effects |
| 3 | PARTIAL | ✅ heat → capacity · ❌ blessing effects |
| 3 | BOTCHED | ✅ Notoriety +1 · ❌ docking refused · ❌ `blasphemer` |
| 4 Profane annex | RESULT | ❌ services at +15% |
| 5 Burn past | RESULT | ✅ no effect |

### EVT-073 — Fuel Skim
| Option | Band | Verdict |
|---|---|---|
| 1 Shallow skim | CLEAN | ✅ fuel +2 · heat +1 |
| 1 | PARTIAL | ✅ fuel +1 · heat +2 |
| 1 | BOTCHED | ✅ heat → capacity · ❌ Thrust −1 |
| 2 Deep skim | CLEAN | ✅ fuel +4 · heat +2 |
| 2 | PARTIAL | ✅ fuel +2 · heat +2 · hull damage 1 |
| 2 | BOTCHED | ✅ fuel · hull damage 3 · ❌ `frame_groan` cosmetic flag |
| 3 Collectors | RESULT | ✅ fuel +1 · ❌ one encounter tick |
| 4 Gravity assist | MET | ❌ next jump fuel cost 0 |
| 4 | SHORTFALL PARTIAL | ❌ next jump free |
| 4 | SHORTFALL BOTCHED | ✅ hull damage 2 · ❌ ejected off-course · ❌ next jump double |
| 5 Admire it | RESULT | ✅ no effect |

### EVT-084 — The Apprentice
| Option | Band | Verdict |
|---|---|---|
| 1 Escort | CLEAN | ❌ encounter table suppressed · ❌ fence +10% sell rates |
| 1 | PARTIAL | ✅ combat · ❌ ally ship as a combat entity |
| 1 | BOTCHED | ✅ combat, enemy initiative — *depends on "bounty hunter" existing in the region table* |
| 2 Chart cold routes | MET | ✅ region reveal +1 |
| 3 Fuel and rations | RESULT | ✅ fuel −1 · scrap −20 · ❌ hidden flag + later discount |
| 4 Buy the junker | MET | ✅ scrap −200 · claimable hull, perk rolled · Notoriety +1 |
| 5 Wish her luck | RESULT | ✅ no effect |

---

## 4. What the batch gets right

Worth stating plainly, because the violation count is not a verdict on
the writing:

- **Structure is correct throughout.** Every event has 5 options — inside
  the 4–7 range — with at least one check-linked option, at least one
  ungated middling option, and exactly one safe exit that costs nothing.
- **Every safe exit is genuinely unpunished.** Non-negotiable per §4, and
  honoured five times out of five.
- **Costs-shown / consequences-hidden discipline holds.** EVT-029 opt 4
  labels its hull damage "(fixed cost, shown pre-choice)" — the exact
  distinction §6 draws.
- **Band prose is post-resolution**, correctly separated from pre-choice
  labels in the file header. No outcome telegraphing.
- **The failure-domain rule holds.** A ram costs hull; a sneak costs
  detection; a burn costs heat. Botches surprise in degree, never in kind.
- **PG-13 and the register rules hold.** No profanity, no gore, and
  EVT-084's kid is endangered as a hook and never harmed — she scatters
  for the debris line and survives every band she appears in.
- **Hard gates are correctly reserved** for meter payments and physical
  impossibility: Heat ≤1, Heat ≥3, Scrap 120, Scrap 200. Exactly the §4.1
  rule.
- **Notoriety is correctly rolled on the ladder** rather than gated hard
  (EVT-084 opt 1), per §2.

The batch is well-built against a *different* contract.

---

## 5. The pile-on ruling in card-design §15

§15 flags two Botches as predating the guard and blocks batch-02 until
they are ruled on:

- **EVT-005 opt 4 BOTCHED — confirmed.** `hull damage 2 · combat: neutral
  initiative` stacks two of {hull damage, malfunction, combat entry}.
  It is the only pile-on in the batch.
- **EVT-092 opt 2 — cannot be verified. EVT-092 is not in batch-01.**
  "The Free Lunch" is `active` in the seed CSV but was never authored
  here. §15 points at content that does not exist.

Either §15 refers to a batch-01 revision that isn't this one, or the
EVT-092 reference is an error. **This needs a human ruling before
batch-02 can start**, since §15 makes it a hard block.

---

## 6. Recommendation

Three ways out. The third is the one I'd take.

**a) Rewrite batch-01 to the whitelist.** Loses the ghost, the lane, the
fence, and the blessing — the four things that make this batch worth
having. Cheapest in engineering, most expensive in craft.

**b) Widen the whitelist.** Contradicts `EXPANSION.md`'s own resolution
rule, which is load-bearing: it is what stops MVP events from needing a
persistence layer nobody has built.

**c) Promote run-state flags into the MVP.** ← recommended

Run-state flags are the single deferred system that unlocks the most.
Flags, price modifiers, encounter suppression and "remembered later"
outcomes all hang off one run-scoped key-value store, and it is already
the acknowledged long pole — **9 of the 100 seeds are marked `deferred`
for exactly this reason** (EVT-036, 060, 062, 067, 085, 089, 090, 091,
095). Building it turns 13 of the 29 violating bands legal outright,
unlocks those 9 seeds, and makes batch-01 usable close to as written.

It would move the whitelist from "closed" to "closed plus flags", which
is a deliberate, single, reviewable widening rather than a series of
per-event exceptions.

The remaining deferred systems — ally entities, pacify conditions,
moving hazards, next-jump modifiers — stay deferred, and the handful of
bands that use them get authored down. That is a much smaller edit than
rewriting the batch.

---

## 7. Note on the supplied copy

The copy of `batch-01.md` provided has been through a bad encoding
round-trip — `·` reads as `Â·`, and em dashes as `â`. It was verified
as-is, since encoding does not affect effect parsing, but **the clean
original should be the one that lands in the repo.** Do not transcribe
the damaged copy.
