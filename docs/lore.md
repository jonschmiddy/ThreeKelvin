# THREE KELVIN — Lore
*The world the mechanics are already describing, written down. Companion to `design-doc.md` §The Setting, which established that the universe is running down and people are out here collecting warmth. This says who is paying them, what the price of everything is, and why nobody will answer the only question that matters. Draft v0.1.*

---

## The one idea

> **Corporations are eternal and they are buying heat. People are temporary and they want scrap and credits. You are a person, and you work for the eternal things, and they will not tell you what the heat is for.**

Everything below is that sentence. If a piece of fiction cannot be traced back to it, cut the fiction.

It does three jobs at once, which is why it is the frame and not a flourish:

**It explains the economy that is already in the build.** `Market.gd` runs one base value and three prices, and the whole dive is denominated in scrap and credits. That is the HUMAN economy, and it is human because the people in it will be dead long before the dark arrives — a station broker will sell you a brace frame for thirty credits because thirty credits is a real number on a timescale a person can hold. Heat is not on that shelf. Heat is what the houses buy, in quantities no person needs, for reasons no person is given.

**It protects `design-doc.md`'s standing ruling instead of breaking it.** That document says: *no prophecy, no chosen crew, no faction explaining the cosmology in a text box.* The obvious way to add lore is to have somebody explain the world, and that ruling forbids it. Under this frame nobody explains the world because **the people who could are not talking, and the things that are talking are not people.** The silence stops being an authorial choice the player has to tolerate and becomes a fact about the world that the player can be angry at. That is a much better version of the same restraint.

**It makes the player's position the horror.** You are a contractor. You are competent, you are equipped, you are paid on delivery, and you are working for an institution that has outlived everyone who founded it and will outlive you without noticing. Nothing hunts you for narrative reasons. You are simply small and warm and on a schedule that is not yours.

---

## 1. Two economies, and the gap between them

| | **The human economy** | **The corporate economy** |
|---|---|---|
| Trades in | Scrap, credits, parts, fuel, repairs | Heat, delivered and banked |
| Runs on | A lifetime | No stated horizon |
| Who sets the price | Whoever is behind the counter | Nobody you will meet |
| Where it happens | Stations. Faces. Haggling. | A docking clamp and a receipt |
| What it is for | Getting through the year | Not stated |

**Scrap and credits are what people want.** A hab ring turning with its lights on is full of people who need a working reactor, a hull patch and a reason to get up. They will trade you anything for the things that keep a station alive this decade. They are not stupid and they are not in denial — they have simply done the arithmetic and concluded that the end of the universe is not a personal problem. Most of them are right.

**Heat is what the houses want.** Every one of the seven will take delivery of banked heat at any station where they hold a berth, in any quantity, without asking where it came from, and will pay in whatever the yard has. The rate is good. The rate has always been good. The rate does not move when supply does, which is the first thing about it that should worry you and the last thing anybody mentions.

**The gap is the dread, and it is arithmetic rather than atmosphere.** A person pays you a fair price for a thing they will use. A house pays you an unreasonable price for a thing they will not explain. Both parties are behaving rationally by their own lights and only one of them has told you what those lights are.

### What the player is told, and when

Never. The game does not answer this and must not.

A run can be flown start to finish without the question ever being raised, and that is the default experience — you are paid, you refit, you go deeper. The question is available to a player who reads what they find, and reading it does not produce an answer, only a better-shaped hole. See §5.

---

## 2. Why a house would fit out a stranger

Because it is cheaper than doing it themselves, and because the loss of you costs them a hull.

This is the whole of the employment relationship and it wants no more romance than that. The houses do not recruit, inspire, or induct. They underwrite. A contract is a line of credit against a chassis, a schedule of what they will take delivery of, and a clause about what happens if you do not come back — which is nothing, because nothing is what happens.

Three consequences worth holding on to:

- **Nobody is coming for you.** Every house's terms say so, in seven different registers. Korvan says it plainly, Halcyon says it beautifully, Redline does not put it in writing at all. It is the only thing all seven agree on.
- **Your death is a line item.** It is recorded, it is priced, and the next contract is written the same afternoon. `RunHistory` is not a memorial; it is somebody's ledger.
- **There is no promotion.** You do not rise within a house. There is no rank to reach, no inner circle, no point at which they start telling you things. The relationship is exactly as deep on your two hundredth dive as on your first, and a player who expects otherwise is having the correct experience.

---

## 3. The seven, on the end of everything

Their backstories are already written and live in `Database.BACKSTORY` — that is who they are as companies. This is the narrower thing: **where each one stands on the dark, in its own register, without any of them explaining it.** One line apiece is deliberate. A house that needs a paragraph is a house that is explaining.

**Korvan Heavy Works** — *"The frames were drawn for a war that ended. They will outlast this too."* Korvan does not discuss the end because Korvan does not discuss anything. The jigs are set, the parts are stamped, and the invoices go out on the same schedule they have gone out on for two hundred years. Nobody has asked who is still receiving them.

**Solari Foundry** — *"Heat is only waste if you fail to aim it."* The only house that sounds pleased. Solari's position is that a universe full of unspent warmth is an engineering opportunity that has been sitting there the entire time, and that everyone else's grief is a failure of nerve.

**The Dredge Combine** — *"Everything ends. We file first."* Dredge does not prospect and does not speculate. It follows disasters and it invoices. The end of the universe is the largest disaster on the schedule and the Combine's only observable preparation for it is paperwork.

**Redline Shipyards** — no position, no comment, no address. Redline will buy your heat for more than the rate and will not issue a receipt. What Redline thinks about the heat death is not recorded anywhere, which is consistent with everything else about Redline.

**Halcyon** — *"We repair what we sold you. Forever."* Halcyon has made fewer than four hundred hulls in two centuries and maintains every one of them. The word in the warranty is *perpetuity*, and the warranty was drafted by people who knew what the sky was doing.

**Cygnet** — the literature does not address it. Cygnet solved autonomy and then spent forty years not discussing that either. Pilots report that the drones anticipate them. Deliveries to Cygnet berths are accepted, weighed and receipted without a person appearing at any point in the process, and this is not remarked upon in any Cygnet document because Cygnet documents do not remark on things.

**Calyx Biosystems** — *"Every specification has a tolerance. So does this one."* Calyx hulls are cultured, trimmed and warranted, and every contract carries a clause about feeding one something it was not rated for. Calyx is the only house whose paperwork implies it expects the end to be survivable by something, and it is not clear from the wording that the something is us.

---

## 4. What is out there

The texture. None of this is explained in play; all of it is encountered.

**The warm things.** Megafauna swim between systems and they are warm — which is why they are hunted, and which means the player and the whale are the same kind of animal doing the same thing for the same reason. A player who works that out has been told the game's cruellest joke without a line of dialogue. `Combat.pacify` exists so that working it out can change what you do.

**Wrecks older than anyone who could have built them.** Already in the build as a rarity tier: precursor fragments come off deep wrecks and nowhere else. The hulls are wrong in ways that are structural rather than mysterious — bays that do not open onto anything, a mass distribution nobody would choose. Nothing in the game ever says who. The correct amount of information about the precursors is the amount currently in the game, which is a rarity tier and a material.

**The loops.** Transponders that are still running. Not distress calls — schedules, inventories, a berth number repeated on a forty-one year cycle by a station that is not there. This is the cheapest horror in the setting and the most reusable: a system that is empty and still talking.

**The cold that is not just absence.** `coop-design.md` has cold cards — a card source nobody owns, that arrives. They are the one thing in the game that is neither loot nor manufacture. They should never be explained and should never stop arriving.

**The core, and the thing at it.** Something is guarding the last warm place, and `design-doc.md` already rules that whether it guards it *from* you or *for* you is not answered. Keep it that way. The Custodian does not speak, has no dialogue, and gets no lore entry of its own. What can be found is other people's paperwork about it, which is not the same thing and is much better.

**The vaults.** Nobody has seen one. Heat is delivered at a station berth, weighed, receipted, and is then somewhere else. Every house has a different name for the place it goes and none of the names is a location.

---

## 5. The Archive: how the world is told

**The rule: primary sources, never exposition.** The player does not read *about* the world. The player reads the world's paperwork.

An archive entry is a document that existed for a reason that was not the player's benefit — a manifest, a contract rider, an inspection note, an invoice, a transponder transcript, a survey log. It was written by somebody with a job to do and an audience who already knew the context, which is exactly why it is worth reading and exactly why it cannot explain anything.

### Six rules for writing one

1. **It has an author with a job.** Not a narrator. A clerk, a broker, an inspector, a pilot, an underwriter. The prose is theirs, including the parts of it that are bad.
2. **It knows less than the reader wants and more than the reader expects.** A document that answers the question is a document that has been written by the designer rather than by a clerk.
3. **It is dated, and the dates do not resolve into a calendar.** Enough internal consistency that a careful reader gets a sense of duration; never enough to build a timeline. Duration is the horror; chronology is a wiki.
4. **It contradicts another entry.** Not everywhere, but somewhere. Two houses' accounts of the same incident should not agree, and neither should be marked correct.
5. **The unsettling thing is never the subject.** It is a clause, a footnote, a routing code, a line item. Nobody in the document finds it remarkable. That is what makes it land.
6. **It fits on one screen.** A hundred and fifty words is a long entry. This is a game about flying a ship, and an archive that takes an evening to read is an archive that gets read once by three people.

### How entries arrive

**By going somewhere.** An entry is recovered, and where it was recovered is part of it — a manifest off a stripped derelict at layer three reads differently from the same manifest at layer eight. Nothing is granted for time played, and nothing is bought.

This makes the archive the one part of the game that rewards depth with something other than power, which matters: `design-doc.md`'s greed clock says you die because you went one jump too far, and it is worth there being something down there that is not a better gun.

**They persist across runs.** A dive ends and the ship is lost; what you read, you have read. This is the second crack in "the flight record is a record, not meta-progression" and it is a safe one for the same reason `Unlocks` was: **an entry grants no power.** It widens what you know and changes nothing about how hard the next run is.

### What the archive must never contain

- An entry written in the voice of the game.
- A summary, an index of factions, a timeline, or a map key.
- Anything about the Custodian written by anyone who saw it and understood it.
- An answer to what the heat is for.

The last one is not a tease to be paid off later. **There is no answer written down anywhere**, including in this document, and that is a commitment rather than an omission — the moment one exists, somebody will eventually put it in an entry, and the game will be worse the day they do.

---

## 6. Contracts, at stations

*Ruled: the employment frame reaches the player as work posted at stations, not as a choice at the yard.*

A station with a house berth carries that house's standing offer. Taking one is a decision made mid-run with information — you know what you are carrying, how hot you are running and how deep you are willing to go — where a choice made at the chassis select is a choice made in ignorance.

The design constraints, before anything is built:

- **A contract is an offer to take delivery, not a quest.** No objectives, no waypoints, no completion narration. A schedule and a rate.
- **It must not gate loot.** `coop-design.md` §0's ruling stands: winning a fight pays the loot, and heat has nothing to do with what a fight drops. A contract pays for heat DELIVERED; it does not touch the drop table.
- **It must not become a to-do list.** The greed clock is the only clock. A contract that expires, or that pushes the player deeper on somebody else's schedule, replaces a self-authored death with an imposed one and repeals the third pillar.
- **Refusing must be free and common.** Most contracts should be declined. An offer you always take is a tax with extra steps.
- **The rate is good and never explained.** See §1.

Not built yet. This section is the specification, and the archive is the part that ships first — the fiction has to exist before the economy that sits on top of it.

---

## 7. What this does not license

`design-doc.md`'s list stands unchanged and this adds to it.

- **No corporate representative.** Nobody from a house ever appears, speaks, or is described as present. The houses reach the player through documents, prices and clamps.
- **No conspiracy the player can uncover.** The houses are not secretly aligned, not secretly one thing, and not secretly anything. They are institutions doing something they have not explained, which is what institutions are like.
- **No sympathetic reveal.** The heat is not being gathered to save a child, restart a sun, or preserve a record. Any answer of that shape converts cosmic dread into a plot, and there is no version of that trade the game wins.
- **No moral position on taking the work.** The game does not think you are complicit and does not think you are a hero. You needed a hull.
- **Nothing that makes the player special.** Not the first, not the best, not the one who noticed. Somebody else's paperwork is already down there and it is older than you.

---

## 8. Where the fiction lives, in order of how much of it there is

1. **Prices.** The economy is the argument. Nothing states the setting harder than a shelf.
2. **Log lines.** `Run.log_line` is the most-read prose in the game by an enormous margin.
3. **Module and hull flavour.** Already written, already good, already carrying it.
4. **Sector descriptions.** Where you are, said in one line.
5. **The archive.** Deepest, most optional, least often read. Correct in that order.

A player who never opens the archive should still be able to tell you what this world is like. If that stops being true, the archive has become the setting rather than a corner of it, and the fix is to cut the archive rather than to promote it.
