class_name SaveGame
extends RefCounted

## The run in progress, on disk. One slot, rewritten at every safe point.
##
## This is a SUSPEND SAVE, not a checkpoint. Loading deletes the file, and the
## file is rewritten from live state at the very next safe point — so there is
## never an older state on disk to go back to. Quitting is a bookmark. It is not
## a way to retry a fight you are losing or a jump you regret.
##
## That restraint is not fussiness. "Lateral map travel is always available and
## cheap, so every death is self-authored" is a design ruling, and it only means
## anything while a death is final. A reloadable save repeals the greed clock
## without appearing to change a single number.
##
## COMBAT IS DELIBERATELY OUTSIDE THE SAVE. A safe point is a moment when the
## only live state is RunState's, so restoring one cannot strand a half-resolved
## fight. The autosave lands immediately BEFORE a fight begins rather than after
## the jump that led to it, so force-quitting mid-fight costs you the fight, not
## the jump — you resume on the sector with the contact still there and ENGAGE
## still offered. It does refund the hull the fight had already taken, which is
## the one hole in this; closing it would mean serialising deck order, enemy
## intent loops, drones and charge timers for a case reached only by force-quit.

const PATH := "user://run.save"
## Bumped whenever the shape below changes. An old file is discarded rather than
## guessed at — a half-understood save produces a run that is subtly wrong,
## which is worse than no save at all.
## 2: the economy. `exotic` became the first row of a materials ledger, station
## stock stopped storing a price and started deriving one, and a node learned
## whether it has ever been stocked and how much has been sold into it.
## 3: heat reached the map. A node now carries whether it rolled for an ambush
## and what that roll produced, so a hostile attracted by your own heat cannot
## be refused by quitting and coming back cold.
## 6: a node carries the BAG a shared kill left in it, and whether one has been
## rolled. Stored by value like the shelf rather than re-derived: the roll is
## deterministic from the node, but its SIZE came from how many ships were in the
## fight, and nothing on a resumed map remembers that.
## 7: the contract ledger and manufacturer standing. A version 6 save has neither, so
## it resumes with an empty board and no accounts — which is survivable but
## silently loses work the player had already flown for.
## 8: the hold became a GRID. A part carries the cell it sits in, so a hold you
## arranged comes back arranged rather than re-packed from scratch.
## 9: the hellbender — where the galaxy's other harvester is, what hull it has
## left, and how many moves it has made (the counter is a seed source, so
## losing it would re-derive a different walk). A node also carries `eaten`:
## a save that forgot it would resume a derelict the rival stripped as one
## somebody in the party did.
## 10: a hull carries the perks its GRADE grants, on top of its manufacturer's one.
## They are granted by `at_tier` and the loader does not call it, so they are
## written and read back explicitly. A version 9 save has none of them, and
## an S-tier ship restored from one is three perks short with every number
## still right — unreadable rather than wrong, which is what the rule at the
## top is for.
## 11: the vocabulary pass. A node's manufacturers-with-berths moved from
## `makers` to `berths`, and a contract's manufacturer from `house` to
## `manufacturer`. A version 10 file has neither key, so it would resume
## with every node stripped of its berths and every contract unbranded — a
## galaxy that looks intact, posts no work anywhere, and tints nothing on
## the chart. Discarded instead.
##
## THE RENAME DID NOT TOUCH THIS NUMBER, and that is the whole reason this
## entry exists. The keys moved and the gate above went on saying 10, so an
## old save PASSED the check and was read with keys that are not in it —
## the exact failure the rule at the top of this file forbids, arrived at by
## renaming rather than by shipping a new shape. See the note below: the
## number is not the defence, it is only how the defence notices.
##
## 8 rather than either side's number, and the reason is worth writing down: two
## branches both shipped a "6" — the shared-kill bag on one and the hold grid on
## the other — so a file stamped 6 could be either shape and there is no way to
## tell which from the number. This format has BOTH, so it is readable by
## neither, and taking a fresh number is the only answer that keeps the rule
## above true. Anything stamped 6 or 7 is now discarded, which is the correct
## outcome and the whole reason the field exists.
##
## AND THEN IT HAPPENED AGAIN AT 8. The hold grid and the hellbender were written
## on separate branches and both stamped 8, so an 8 can be either shape by
## exactly the argument above. 9 has both.
##
## Which says something the paragraph before it did not: the number is not the
## defence. It collides whenever two branches are open at once, and it will
## collide again. What actually keeps a wrong save from being loaded is the
## rule at the top -- an unreadable file is DISCARDED rather than guessed at --
## and the number is only how that rule recognises one. 8 is discarded now for
## the same reason 6 and 7 were.
## 12: THRUST BECAME A FIELD. It was read off fuel_factor -- the gauge and the
## price of a jump were one number -- so every fuel-efficiency part quietly
## lowered the pilot's thrust and made them worse at thrust checks for fitting
## a thriftier engine. HULL_FIELDS gained 'thrust', so a version 11 hull has
## no such key and would restore with a thrust of whatever the default is
## rather than what its weight class says. Discarded instead.
##
## Caught by .github/scripts/version_guard.py, which is the first time that
## has happened in anger -- and it needed fixing first: a field LIST declares
## its keys as bare quoted strings, and the guard could not read one. It said
## PASS on this very change until it was taught to.
## 13: THE AFFIX VOCABULARY CHANGED, and this is a break the version guard
## cannot see. An affix is stored as its NAME — a string VALUE in the save, not
## a key — and the guard watches keys. Seven of the ten names are gone
## (Overbored, Autoloader, Salvaged, Mass-Fed, Efficient, Grafted, Heat-Sinked),
## and `_module_from` resolves a name by walking DB.affixes and simply skipping
## what it cannot match. So a version 12 save would load, and every rolled part
## on it would come back stripped of its rolls: no crash, no warning, a quietly
## weaker ship. Discarded instead.
##
## Worth writing down because it is the shape of break the guard is blind to by
## construction: renaming the VALUES a save stores is exactly as destructive as
## renaming its keys, and nothing automated is watching for it.
## 17: THREE NODE TYPES DELETED. FIGHT, EVENT and DERELICT are gone and SYSTEM
## replaces them, because what is at a place is `options` now and those three
## were only labels for what got rolled there.
##
## THE ENUM RENUMBERED, and that is the whole reason this line exists. `type` is
## serialised as an INT, so a version 16 save loaded against this build would
## come back with every node pointing at a different kind of place -- stations
## reading as cores, cores as pulsars. It would not crash and it would not warn;
## it would simply be a different galaxy wearing the old one's name.
##
## Discarded, and that discard IS the migration: there is no forward-read worth
## writing when the mapping is meaningless. This bump is what arms it.
##
## 16: THE AMBUSH IS A FLAG. `MapNode.ambush` held the pack itself; it is now
## `ambush_pending`, with the pack derived positionally at fight time. A version
## 15 save carries the old array and it is read forward as "pending if it was not
## empty" -- so a run suspended mid-approach still gets jumped, by the SAME pack,
## because `_roll_foes` answers the same way it did when the array was written.
##
## 15: A SYSTEM HOLDS A LIST. `MapNode.options` carries the ids of what was
## rolled at each node, so the shape of a saved system changed. A version 14
## save has no such key and every node comes back with an empty list, which
## re-rolls once on the next arrival -- the same contract `foes` has, and not a
## corruption. KEPT rather than discarded for that reason: the worst case is one
## system offering a different set than it did before the quit, against losing
## the run entirely.
##
## 14: SENSORS CAN SEE. Every map node carries a `sensed` mark now -- set when
## the ship is close enough and never cleared -- so the shape of a saved system
## changed. A version 13 save has no such key, and every node would come back
## unsensed: not a corruption, but a chart quietly narrower than the one the
## player left, which is the same class of lie as a stripped module. Discarded.
## 18: THE HOLD CARRIES TWO KINDS OF THING. Cargo rows gained a `kind`, and a
## material row stores an id and a cell instead of a rolled part.
##
## Backward compatibility actually holds -- `kind` is absent on every module row
## ever written, so a version 17 save reads back through exactly the old path.
## The bump is about the OTHER direction: a version 17 build handed a material
## row would run it through `_module_from` and produce a nameless part with no
## affixes sitting in your hold. That is the stripped-module lie again, so the
## number moves and the save is discarded rather than half-understood.
## 19: MONEY IS A THING IN A CONTAINER. A bag row can now be `kind = credits`,
## which a version 18 build would push through `_module_from` and land in your
## hold as a nameless part worth nothing. Same argument as 18 and the same
## direction: old saves read back fine, new ones must not be handed backwards.
## 20: A SYSTEM HOLDS CONTAINERS. One per hull you killed plus one of its own,
## each with its own items and its own claims -- and they persist, which is the
## point: a wreck you left half stripped is somewhere you can go back to.
##
## A version 19 save has no `jetsam` key and reads back with none, which is
## correct for it: nothing was ever put in one. The bump is for the other
## direction, as 18 and 19 were -- a 19 build handed this save would show you a
## sector with the loot missing and no wrecks in it.
## 21: `hoards` became `jetsam`. A RENAME AND NOTHING ELSE -- same shape, same
## contents, same claims -- but the key a save is written under is the key a
## save is read from, so a version 20 file would come back with no containers in
## it and a version 20 build handed this one would do the same. `SaveGame.load`
## refuses a mismatch, which is what makes the discard the migration.
## 22: and `flotsam` became `jetsam`, for the reason 21 should have used --
## `jettison` is the verb and jetsam is its noun. Same rename, same argument:
## the key a save is written under is the key it is read from.
## 23: A SPENT OPTION REMEMBERS WHAT IT CAME TO. `taken` said an option was
## done and nothing said what happened, which was enough while a spent option
## vanished off the list and is not now that the card stays and wears its band.
## `results` is written as two parallel arrays because JSON has no integer
## keys -- a dictionary keyed by option index comes back keyed by "0" and "3".
##
## A version 22 save has no `results` and reads back with none, which draws
## every already-spent option as RESOLVED rather than as the band it actually
## got. That is a downgrade rather than a lie, and it is the direction the
## version guard does not care about; the bump is for the other one, as 18
## through 22 were.
## 24: THE MATERIAL LEDGER IS GONE. `materials` was a dictionary of id to count
## saved beside `cargo`, which already stored the same materials as objects with
## shapes and positions -- and the objects are what the game reads now, so the
## dictionary is not written and not read. A version 23 save carries one and a
## version 24 build would ignore it, which is the quiet half; the loud half is
## that a 23 build handed this save would find no ledger and show you nothing
## for a hold full of crates.
## 25: A SYSTEM HAS A SKY. `star`, `gas_giant` and `near_pulsar` decide whether
## four options may appear at all -- the pulsar sweep, the two flare-star
## encounters and the gas giant -- and all three are rolled at generation off
## `Rng.world`. They are saved rather than recomputed because a save carries the
## MAP, not the seed that made it: a 24 save read by this build would come back
## with an ordinary sky everywhere, and the systems that had been offering those
## options would quietly stop.
## 26: THE GALAXY TABLE LOST TWO KINDS AND GAINED FOUR. `galaxy_kind` is an
## INDEX into `GalaxyGen.KINDS`, so removing Barred Ring Spiral and Collisional
## Ring renumbered everything after them. The rolled parameters are saved
## alongside the index and would still restore correctly -- the map would be
## intact -- but the run would name itself after a different galaxy than the one
## it is, on the one screen that exists to tell you where you are.
const VERSION := 26

## Every rolled scalar on a hull. The frame supplies the art and the anchors; a
## saved hull is a frame plus the numbers LootGen rolled onto it.
const HULL_FIELDS: Array[String] = ["weight", "tier", "reactor", "hand_size",
	"max_hull", "heat_cap", "dissipation", "dodge", "initiative", "fuel_factor",
	"thrust", "weapon_slots", "system_slots", "utility_slots", "sensors",
	"stealth"]

# --------------------------------------------------------------------- queries

static func has_save() -> bool:
	return FileAccess.file_exists(PATH)

## What the launcher prints on the CONTINUE button. Reads the file WITHOUT
## consuming it — only load_into_run() is allowed to do that.
static func summary() -> Dictionary:
	var d := _read()
	if d.is_empty():
		return {}
	return {
		galaxy = str(d.get("galaxy_title", "")),
		jumps = int(d.get("jumps", 0)),
		hp = int(d.get("hp", 0)),
		max_hp = int(d.get("max_hp", 0)),
		danger = int(d.get("danger", 1)),
		system = str(d.get("system", "")),
	}

# ---------------------------------------------------------------------- write

## Called from Router at every safe point. Cheap enough to be unconditional:
## the map is the bulk of it and a hundred and fifty nodes stringify in a
## millisecond or two, which is nothing beside the screen swap that triggered it.
##
## The map guard is doubled here and in Router._autosave() on purpose. This is
## the one function that writes, and _snapshot() indexes `Run.map[Run.at]` with
## nothing in front of it — a half-populated run reaching this call takes the
## process down rather than declining to write.
static func save() -> void:
	if Run.hull == null or Run.map.is_empty() or Run.dead or Run.won:
		return
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_warning("SaveGame: could not open %s for writing (%d)" % [
			PATH, FileAccess.get_open_error()])
		return
	# full_precision, not the default. Without it JSON rounds floats hard enough
	# to move systems on the chart by a visible fraction of a pixel.
	#
	# It is still not bit-exact, and it is worth writing down what was measured
	# rather than leaving the next person to wonder: over 20,000 random floats,
	# 63% round-trip exactly and the worst relative error is 9.3e-14. That is
	# three orders of magnitude below single precision and it cannot reach any
	# observable in this game — fuel is int(round(distance * 10)), so flipping
	# one would need a distance sitting within 1e-13 of a .5 boundary.
	#
	# JSON is kept over FileAccess.store_var, which WOULD be bit-exact, because
	# a save you can read in a text editor is worth more during development than
	# fourteen digits nothing consults.
	f.store_string(JSON.stringify(_snapshot(), "", true, true))
	f.close()

static func clear() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))

static func _snapshot() -> Dictionary:
	var installed: Array = []
	for m in Run.installed:
		installed.append(_module_to(m))
	var cargo: Array = []
	for m in Run.cargo:
		cargo.append(_item_to(m))
	var nodes: Array = []
	for n in Run.map:
		nodes.append(_node_to(n))
	var here: MapGen.MapNode = Run.node_at()
	return {
		version = VERSION,
		# Denormalised for summary(). The launcher should not have to rebuild a
		# hundred and fifty map nodes to print one line of button text.
		system = MapGen.star_name(here),
		danger = here.danger,
		max_hp = Run.max_hp(),

		started_at = Run.started_at,
		galaxy_kind = Run.galaxy_kind,
		galaxy = Run.galaxy,
		galaxy_seed = Run.galaxy_seed,
		# Where every roll stream had got to. Without this, loading a run
		# rewinds them all to the start of the run, and the next module you
		# find is the first module you found. See Rng.state().
		rng = Rng.state(),
		galaxy_spin = Run.galaxy_spin,
		galaxy_name = Run.galaxy_name,
		galaxy_title = Run.galaxy_title,

		hull = _hull_to(Run.hull),
		installed = installed,
		cargo = cargo,
		found_hull = _hull_to(Run.found_hull) if Run.found_hull != null else null,

		hp = Run.hp,
		heat = Run.heat,
		heat_cap_bonus = Run.heat_cap_bonus,
		credits = Run.credits,
		# The whole ledger, not the one row that used to be a field. A material
		# added to DB.MATERIALS is saved by construction rather than by somebody
		# remembering to add a line here.
		fuel = Run.fuel,
		dross = Run.dross.map(func(x: StringName) -> String: return String(x)),
		whale_boon = Run.whale_boon,
		# The ledger and the accounts. Both are RUN state — a contract points at a
		# node index in this galaxy and standing is spent inside this dive — so
		# both belong here and neither survives the dive ending.
		contracts = _contracts_to(),
		next_contract_id = Run.next_contract_id,
		standing = _standing_to(),

		map = nodes,
		at = Run.at,
		trail = Array(Run.trail),
		jumps = Run.jumps,
		kills = Run.kills,

		hellbender_at = Run.hellbender_at,
		hellbender_hp = Run.hellbender_hp,
		hellbender_max = Run.hellbender_max,
		hellbender_moves = Run.hellbender_moves,
		hellbender_ticks = Run.hellbender_ticks,
	}

# ----------------------------------------------------------------------- read

static func _read() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return {}
	var raw := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var d: Dictionary = parsed
	if int(d.get("version", -1)) != VERSION:
		return {}
	return d

## Restores the run and consumes the file. True when a run is now live.
##
## The delete is the whole point of the model, but it also opens a window: a
## crash between here and the next safe point would lose the run. Router saves
## on the very next screen swap, which is the one this call is about to cause,
## so that window is a few milliseconds wide.
static func load_into_run() -> bool:
	var d := _read()
	if d.is_empty():
		clear()
		return false

	# Checked before the first write to Run, not after the last one. Everything
	# below overwrites the live run field by field, and this check used to sit
	# at the bottom — so a file with a good version and a truncated map returned
	# false having already left a hull, an economy and an empty map behind, and
	# the launcher this failure routes to autosaved that and indexed map[at].
	var saved_map: Variant = d.get("map", [])
	if typeof(saved_map) != TYPE_ARRAY or (saved_map as Array).is_empty():
		clear()
		return false

	Run.started_at = float(d.get("started_at", 0.0))
	Run.galaxy_kind = int(d.get("galaxy_kind", 0))
	Run.galaxy = _galaxy_from(Run.galaxy_kind, d.get("galaxy", {}))
	Run.galaxy_seed = int(d.get("galaxy_seed", 0))
	Rng.restore(d.get("rng", {"master": Run.galaxy_seed}))
	Run.galaxy_spin = float(d.get("galaxy_spin", 0.0))
	Run.galaxy_name = str(d.get("galaxy_name", ""))
	Run.galaxy_title = str(d.get("galaxy_title", ""))

	# The hull before the map: ring_radius() reads Run.galaxy, and half the
	# screens read Run.hull the moment a signal reaches them.
	Run.hull = _hull_from(d.get("hull", {}))
	var installed: Array[ModuleData] = []
	for e in d.get("installed", []):
		var m := _module_from(e)
		if m != null:
			installed.append(m)
	Run.installed = installed
	# A save written before mounts existed carries -1 on every fitted part, which
	# reads as "in the hold" and would draw a fully-armed ship with an empty rack.
	# Anything unplaced gets the first free hardpoint, so an old file loads as the
	# same loadout in a tidy arrangement rather than as a ship with no guns on it.
	for m in Run.installed:
		if m.mount < 0:
			m.mount = Run.free_mount(m.slot)
	var cargo: Array[HoldItem] = []
	for e in d.get("cargo", []):
		var m := _item_from(e)
		if m != null:
			cargo.append(m)
	Run.cargo = cargo
	# Anything that came back without a cell — a pre-grid save, or a part whose
	# position no longer fits the hull it was loaded onto — gets one now. Done
	# AFTER the assignment because repack_hold reads Run.cargo, and after the
	# hull is set for the same reason: the grid's shape is the hull's.
	var unplaced := false
	for m in Run.cargo:
		if m.hold_at.x < 0 or not Run.can_place(m, m.hold_at):
			unplaced = true
			break
	if unplaced:
		Run.repack_hold()
	var fh: Variant = d.get("found_hull", null)
	Run.found_hull = _hull_from(fh) if typeof(fh) == TYPE_DICTIONARY else null

	Run.hp = int(d.get("hp", 1))
	Run.heat = int(d.get("heat", 0))
	Run.heat_cap_bonus = int(d.get("heat_cap_bonus", 0))
	Run.credits = int(d.get("credits", 0))
	# JSON hands back String keys and float values; the ledger is StringName to
	# int. Rebuilt entry by entry rather than assigned wholesale, because a
	# dictionary that compares equal but hashes its keys as Strings prints
	# differently from the one it replaced — and that difference is the sort of
	# thing that gets chased for an hour later.
	var mats: Dictionary = {}
	Run.fuel = int(d.get("fuel", 0))
	# A save written when dross was a COUNT restores as that many Dross, which is
	# exactly what it meant at the time. Nothing is lost and nothing is invented.
	var raw: Variant = d.get("dross", [])
	var ids: Array[StringName] = []
	if typeof(raw) == TYPE_FLOAT or typeof(raw) == TYPE_INT:
		for i in int(raw):
			ids.append(&"dross")
	else:
		for x in (raw as Array):
			ids.append(StringName(x))
	Run.dross = ids
	Run.whale_boon = bool(d.get("whale_boon", false))
	Run.contracts = _contracts_from(d.get("contracts", []))
	Run.next_contract_id = maxi(1, int(d.get("next_contract_id", 1)))
	# ZEROED, not restored — these two are deliberately outside the save, so a
	# load has to clear them the way `start_new_run()` does. Without it, SAVE &
	# QUIT to the launcher and CONTINUE inside the same process carries the
	# previous run's haul count and its dismissed salvage rail into the loaded
	# one: the rail stays shut in-session and opens after a cold start, which is
	# the same save behaving two different ways.
	Run.hauls = 0
	Run.salvage_hushed_hauls = -1
	Run.salvage_hushed_bag = -1
	var stand: Dictionary = {}
	var saved_stand: Variant = d.get("standing", {})
	if typeof(saved_stand) == TYPE_DICTIONARY:
		for k in (saved_stand as Dictionary).keys():
			# Filtered against the catalogue: a manufacturer that no longer exists is
			# standing the player can never spend and a row they can never clear.
			var manufacturer := StringName(str(k))
			if DB.manufacturers.has(manufacturer):
				stand[manufacturer] = int((saved_stand as Dictionary)[k])
	Run.standing = stand

	var map: Array = []
	for e in saved_map:
		map.append(_node_from(e))
	Run.map = map
	Run.at = clampi(int(d.get("at", 0)), 0, maxi(0, map.size() - 1))
	var trail := PackedInt32Array()
	for i in d.get("trail", []):
		trail.append(int(i))
	Run.trail = trail
	Run.jumps = int(d.get("jumps", 0))
	Run.kills = int(d.get("kills", 0))

	# Clamped like `at`, because a stale index here is not a wrong marker — it
	# is an index error inside whatever reads the hellbender's node next.
	Run.hellbender_at = clampi(int(d.get("hellbender_at", -1)), -1, map.size() - 1)
	Run.hellbender_max = maxi(0, int(d.get("hellbender_max", 0)))
	Run.hellbender_hp = clampi(int(d.get("hellbender_hp", 0)), 0, Run.hellbender_max)
	Run.hellbender_moves = maxi(0, int(d.get("hellbender_moves", 0)))
	Run.hellbender_ticks = maxi(0, int(d.get("hellbender_ticks", 0)))

	Run.won = false
	Run.dead = false
	Run.death_reason = ""
	# Jump range is a pure function of a system and the galaxy, and both just
	# changed underneath it.
	Run._range_cache.clear()

	clear()
	Sig.run_started.emit()
	Sig.resources_changed.emit()
	Sig.ship_changed.emit()
	Run.log_line("Reactor warm. Resuming from %s." % MapGen.star_name(Run.node_at()), &"big")
	return true

# --------------------------------------------------------------- galaxy params

## JSON has one number type, so a round-trip turns every int in the parameter
## block into a float — and `arms` is a loop count. Rebuilding from the KIND
## template and coercing each saved value to the template's type restores the
## rolled numbers without restoring them as the wrong type.
static func _galaxy_from(kind: int, saved: Variant) -> Dictionary:
	var out: Dictionary = GalaxyGen.params(kind).duplicate()
	if typeof(saved) != TYPE_DICTIONARY:
		return out
	for raw_key in (saved as Dictionary).keys():
		# JSON hands back String keys; the template's are StringName. Godot
		# hashes the two alike so lookups work either way, but a String key
		# added beside StringName ones makes the restored dictionary print
		# differently from the one it copied — and that difference is the sort
		# of thing that gets chased for an hour later.
		var k := StringName(str(raw_key))
		var v: Variant = (saved as Dictionary)[raw_key]
		if out.has(k):
			match typeof(out[k]):
				TYPE_INT: v = int(v)
				TYPE_FLOAT: v = float(v)
				TYPE_BOOL: v = bool(v)
				TYPE_STRING: v = str(v)
		else:
			# `hole` is rolled rather than authored, so it has no template entry.
			v = float(v) if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT else v
		out[k] = v
	return out

# -------------------------------------------------------------------- modules

## A module is a template id plus what LootGen rolled onto it. Affixes are
## stored by name and resolved back to the shared DB instances, which is how
## they are held during a run too — LootGen picks out of a shallow duplicate.
##
## There used to be a "price" meta in here as well, because a station stamped one
## on its stock and a shelf that came back without it silently held a sale.
## Market removed the whole class of problem: a price is a function of the place
## and the part, computed when it is asked for, so there is no longer a price
## anywhere to lose. A derived number that is saved is a second copy of the
## truth, and it only ever goes one way.
## Cargo is two kinds of thing now, so the hold's rows say which they are.
##
## A material stores ONLY its id and where it sits. Everything else -- name,
## tier, value, shape, text -- is rebuilt from `MaterialTable`, which is the
## right way round: a catalogue row that changed between versions should change
## what you are carrying, rather than leaving a save that contradicts the table
## it was authored against. A module cannot do this, because a module is rolled
## rather than looked up: its affixes and its wear are the instance.
##
## `kind` is absent on every module row, old and new, so a save written before
## materials existed reads back exactly as it did -- there is nothing to migrate
## and the version did not need to move for this.
static func _item_to(m: HoldItem) -> Dictionary:
	if m is CreditChit:
		return {kind = "credits", amount = (m as CreditChit).amount}
	if m is MaterialData:
		var mat := m as MaterialData
		return {
			kind = "material",
			id = String(mat.id),
			hold_at = [mat.hold_at.x, mat.hold_at.y],
			turned = mat.turned,
		}
	return _module_to(m as ModuleData)


static func _item_from(e: Variant) -> HoldItem:
	var row := e as Dictionary
	if row == null:
		return null
	if String(row.get("kind", "")) == "credits":
		# Only the amount. A chit has no other state and never sits in a cell.
		return CreditChit.of(int(row.get("amount", 0)))
	if String(row.get("kind", "")) == "material":
		var mat := MaterialData.by_id(StringName(row.get("id", &"")))
		if mat == null:
			# The row was dropped from the catalogue between versions. Losing the
			# item is better than carrying a nameless shape that sells for zero.
			return null
		var at: Array = row.get("hold_at", [-1, -1])
		mat.hold_at = Vector2i(int(at[0]), int(at[1])) if at.size() == 2 \
			else -Vector2i.ONE
		mat.turned = bool(row.get("turned", false))
		return mat
	return _module_from(e)


static func _module_to(m: ModuleData) -> Dictionary:
	var affixes: Array = []
	for a in m.affixes:
		affixes.append(a.name)
	return {
		id = String(m.id),
		rarity = int(m.rarity),
		scrap_value = m.scrap_value,
		affixes = affixes,
		# Which hardpoint it is bolted to. Without this a resumed ship keeps every
		# part it had and rearranges them, because -1 is "in the hold" and the
		# refit screen would draw a full rack of empty mounts over a full loadout.
		mount = m.mount,
		turned = m.turned,
		hold_at = [m.hold_at.x, m.hold_at.y],
	}

## Null when the id is gone from the database — content changed under a save.
## The module is dropped and the rest of the run loads, which beats refusing the
## whole file over one retired part.
static func _module_from(e: Variant) -> ModuleData:
	if typeof(e) != TYPE_DICTIONARY:
		return null
	var d: Dictionary = e
	var id := StringName(str(d.get("id", "")))
	if not DB.modules.has(id):
		push_warning("SaveGame: dropped unknown module '%s'" % id)
		return null
	var m := (DB.modules[id] as ModuleData).duplicate(true) as ModuleData
	m.rarity = int(d.get("rarity", int(m.rarity))) as ModuleData.Rarity
	m.scrap_value = int(d.get("scrap_value", m.scrap_value))
	m.mount = int(d.get("mount", -1))
	m.turned = bool(d.get("turned", false))
	# Version 6. A save from before the hold was a grid carries no position, and
	# -1,-1 is exactly what a part not yet placed looks like — so the loader
	# below re-packs those rather than leaving them claiming no cells.
	var at: Array = d.get("hold_at", [-1, -1])
	m.hold_at = Vector2i(int(at[0]), int(at[1])) if at.size() == 2 else -Vector2i.ONE
	var affixes: Array[AffixData] = []
	for want in d.get("affixes", []):
		for a in DB.affixes:
			if a.name == str(want):
				affixes.append(a)
				break
	m.affixes = affixes
	return m

# ---------------------------------------------------------------------- hulls

## `manufacturer` is written alongside perk_id rather than added to HULL_FIELDS,
## and that is not a style choice: the restore loop below coerces every listed
## field to int or float, so a StringName in that list would come back as 0.
##
## It is written at all — rather than inherited from the frame matched by name —
## because who built your hull decides a set bonus. The name lookup happens to
## resolve it today, but its fallback is hull_frames[1], an UNBRANDED frame, so
## any save whose hull name stopped matching would silently cost you a set piece
## and nothing would report it.
static func _hull_to(h: HullData) -> Dictionary:
	# `tier_perks` goes here beside perk_id and NOT in HULL_FIELDS, for the
	# reason stated above it: that loop coerces every field to int or float,
	# so a list of StringNames put in it comes back as 0.
	var wrote: Array = []
	for tp in h.tier_perks:
		wrote.append(String(tp))
	var d := {name = h.name, perk_id = String(h.perk_id),
		manufacturer = String(h.manufacturer), tier_perks = wrote}
	for f in HULL_FIELDS:
		d[f] = h.get(f)
	return d

static func _hull_from(e: Variant) -> HullData:
	var d: Dictionary = e if typeof(e) == TYPE_DICTIONARY else {}
	var base: HullData = DB.hull_frames[1]
	# MANUFACTURER AND WEIGHT FIRST, name only as a fallback.
	#
	# The warning above came true: hulls gained a name per CLASS, so a save
	# holding a Halberd Cutter found nothing in `hull_frames` — those carry
	# the tier-0 name — and silently restored an unbranded Medium Frame with
	# somebody else's perk. Manufacturer and weight are both written into the save
	# and neither is renameable, so they identify the frame outright.
	var manufacturer := StringName(str(d.get("manufacturer", "")))
	var found := false
	if manufacturer != &"":
		for frame in DB.hull_frames:
			if frame.manufacturer == manufacturer and int(frame.weight) == int(d.get("weight", -1)):
				base = frame
				found = true
				break
	if not found:
		for frame in DB.hull_frames:
			if frame.name == str(d.get("name", "")):
				base = frame
				break
	var h := base.duplicate(true) as HullData
	# THE NAME IS RESTORED, not inherited. It used to come free because the
	# frame was FOUND by name; matching on manufacturer and weight instead means the
	# frame carries the tier-0 name, so a Halberd Cutter came back as a Picket
	# Cutter — same ship, same stats, wrong badge. Intermittent, because it
	# only shows on a hull rolled above C.
	var saved_name := str(d.get("name", ""))
	if saved_name != "":
		h.name = saved_name
	h.perk_id = StringName(str(d.get("perk_id", "salvage_rack")))
	# RESTORED, NEVER RE-DERIVED. `_hull_from` does not go through `at_tier`
	# -- it copies a tier-0 frame and puts the saved scalars back on it -- so
	# nothing here would grant the grade's perks a second time. An S-tier ship
	# would come back carrying only its manufacturer perk, three short, with every
	# number on the screen still correct. That is the same shape of fault as
	# the Halberd that came back a Picket, and it is why the version below
	# moved: a save written before this cannot be told from one written after.
	var tp: Array = d.get("tier_perks", []) as Array
	var restored: Array[StringName] = []
	for e2 in tp:
		restored.append(StringName(str(e2)))
	h.tier_perks = restored
	# Absent in a save written before hulls had berths, in which case the frame
	# matched by name above already carries the right one.
	if d.has("manufacturer"):
		h.manufacturer = StringName(str(d["manufacturer"]))
	for f in HULL_FIELDS:
		if not d.has(f):
			continue
		h.set(f, float(d[f]) if typeof(h.get(f)) == TYPE_FLOAT else int(d[f]))
	return h

# ----------------------------------------------------------------- map nodes

## The map is stored whole rather than regenerated from a seed. MapGen draws on
## the global RNG rather than a seeded stream, so there is no seed that would
## reproduce it — and even if there were, the run's own marks (visited, cleared,
## inspected, rolled shop stock) are not in it.
static func _contracts_to() -> Array:
	var out: Array = []
	for c in Run.contracts:
		out.append((c as ContractData).to_wire())
	return out


static func _contracts_from(raw: Variant) -> Array:
	var out: Array = []
	if typeof(raw) != TYPE_ARRAY:
		return out
	for e in (raw as Array):
		if typeof(e) == TYPE_DICTIONARY:
			out.append(ContractData.from_wire(e))
	return out


static func _standing_to() -> Dictionary:
	var out: Dictionary = {}
	for k in Run.standing:
		out[String(k)] = int(Run.standing[k])
	return out


static func _node_to(n: MapGen.MapNode) -> Dictionary:
	var berths: Array = []
	for m in n.berths:
		berths.append(String(m))
	var shop: Array = []
	for m in n.shop:
		shop.append(_module_to(m))
	# Everything the bag was rolled with, including the parts already claimed.
	# `taken` is what says which are gone, and dropping the claimed ones here
	# would renumber the rest — the array must not shrink, on disk any more than
	# in memory. See MapGen.OPTION_BAG.
	var bag: Array = []
	for m in n.bag:
		bag.append(_item_to(m))
	# EVERY CONTAINER IN THE SYSTEM. They persist across a jump by being node
	# state, and across a session by being here -- a wreck you left half
	# stripped is somewhere you can go back to, which is most of the point.
	# TWO ARRAYS, NOT A DICTIONARY. See VERSION 23: JSON keys are strings, so a
	# map from option index to outcome comes back with "0" where 0 went in and
	# every lookup misses silently.
	var res_at: Array = []
	var res_of: Array = []
	for k in n.results:
		res_at.append(int(k))
		res_of.append(String(n.results[k]))
	var jetsam: Array = []
	for raw in n.jetsam:
		var h: MapGen.Jetsam = raw
		var items: Array = []
		for m2 in h.items:
			items.append(_item_to(m2))
		jetsam.append({slot = h.slot, art = String(h.art), label = h.label,
			scanned = h.scanned, items = items})
	return {
		index = n.index, layer = n.layer, row = n.row,
		rows_in_layer = n.rows_in_layer,
		region = int(n.region), development = int(n.development),
		star = int(n.star), gas_giant = n.gas_giant,
		near_pulsar = n.near_pulsar,
		security = n.security, berths = berths,
		manufacturer = String(n.manufacturer), fauna = n.fauna,
		danger = n.danger, type = int(n.type),
		visited = n.visited, cleared = n.cleared, eaten = n.eaten,
		sensed = n.sensed,
		taken = Array(n.taken),
		inspected = n.inspected,
		fled = n.fled, stocked = n.stocked, trades = n.trades,
		foes = _names(n.foes), event_key = n.event_key,
		ambush_pending = n.ambush_pending, ambush_rolled = n.ambush_rolled,
		in_nebula = n.in_nebula, nebula_emission = n.nebula_emission,
		pos = [n.pos.x, n.pos.y], gal = [n.gal.x, n.gal.y],
		links = Array(n.links),
		shop = shop,
		shop_hull = _hull_to(n.shop_hull) if n.shop_hull != null else null,
		bag = bag, bagged = n.bagged, jetsam = jetsam,
		options = _names(n.options),
		results_at = res_at, results_of = res_of,
	}

static func _node_from(e: Variant) -> MapGen.MapNode:
	var d: Dictionary = e if typeof(e) == TYPE_DICTIONARY else {}
	var n := MapGen.MapNode.new()
	n.index = int(d.get("index", 0))
	n.layer = int(d.get("layer", 0))
	n.row = int(d.get("row", 0))
	n.rows_in_layer = int(d.get("rows_in_layer", 1))
	n.region = int(d.get("region", 0)) as MapGen.Region
	n.development = int(d.get("development", 0)) as MapGen.Development
	n.security = int(d.get("security", 1))
	var berths: Array[StringName] = []
	for m in d.get("berths", []):
		berths.append(StringName(str(m)))
	n.berths = berths
	n.manufacturer = StringName(str(d.get("manufacturer", "")))
	n.fauna = bool(d.get("fauna", false))
	n.danger = int(d.get("danger", 1))
	n.star = int(d.get("star", 0)) as MapGen.Star
	n.gas_giant = bool(d.get("gas_giant", false))
	n.near_pulsar = bool(d.get("near_pulsar", false))
	n.type = int(d.get("type", 0)) as MapGen.NodeType
	n.visited = bool(d.get("visited", false))
	# Absent on a save from before sensors could see. False is the honest
	# default -- an old run simply has not charted anything it did not fly to,
	# and the next arrival fills it in.
	n.sensed = bool(d.get("sensed", false))
	n.cleared = bool(d.get("cleared", false))
	n.eaten = bool(d.get("eaten", false))
	# Absent on a save written before a system could offer more than one thing
	# to do. A cleared node with no list is a node whose single option was the
	# system itself, which is what it always was.
	var taken := PackedInt32Array()
	for o in d.get("taken", []):
		taken.append(int(o))
	if taken.is_empty() and n.cleared:
		taken.append(MapGen.OPTION_WHOLE)
	n.taken = taken
	n.fled = bool(d.get("fled", false))
	# Absent on a save written before the node carried its own roll. Left empty,
	# which makes the node roll once on the next arrival and keep it from then
	# on — the old behaviour for exactly one more visit, rather than a crash.
	var foes: Array[StringName] = []
	for f in d.get("foes", []):
		foes.append(StringName(str(f)))
	n.foes = foes
	n.event_key = str(d.get("event_key", ""))
	# Absent on a save written before a system held a LIST of things to do. Left
	# empty, which makes the node roll once on the next arrival and keep it from
	# then on -- the same contract `foes` and `ambush` state above.
	#
	# Ids rather than definitions, so a save can be rebuilt after the table has
	# changed underneath it. `OptionTable.resolve` drops an id this build does
	# not have with a warning; a missing option must never refuse a save.
	var opts: Array[StringName] = []
	for o in d.get("options", []):
		opts.append(StringName(str(o)))
	n.options = opts
	# Absent on a save written before heat had a map layer. An unrolled node
	# rolls once on the next arrival, which is the old behaviour for exactly one
	# more visit rather than a crash — same contract as `foes` above.
	var amb: Array[StringName] = []
	for a in d.get("ambush", []):
		amb.append(StringName(str(a)))
	n.ambush_pending = bool(d.get("ambush_pending", not amb.is_empty()))
	n.ambush_rolled = bool(d.get("ambush_rolled", false))
	n.inspected = bool(d.get("inspected", false))
	# Whether the shelf has ever been rolled, and how much has been sold into
	# this market. Both are run marks like `visited` — losing either would let a
	# save-and-resume re-roll a bought-out station or reset a saturated one.
	n.stocked = bool(d.get("stocked", false))
	n.trades = int(d.get("trades", 0))
	n.in_nebula = bool(d.get("in_nebula", false))
	n.nebula_emission = bool(d.get("nebula_emission", false))
	n.pos = _vec(d.get("pos", []))
	n.gal = _vec(d.get("gal", []))
	var links := PackedInt32Array()
	for i in d.get("links", []):
		links.append(int(i))
	n.links = links
	for m in d.get("shop", []):
		var mod := _module_from(m)
		if mod != null:
			n.shop.append(mod)
	var sh: Variant = d.get("shop_hull", null)
	n.shop_hull = _hull_from(sh) if typeof(sh) == TYPE_DICTIONARY else null
	var res_at: Array = d.get("results_at", [])
	var res_of: Array = d.get("results_of", [])
	for ri in mini(res_at.size(), res_of.size()):
		n.results[int(res_at[ri])] = StringName(res_of[ri])
	for raw in d.get("jetsam", []):
		var row: Dictionary = raw
		var h := MapGen.Jetsam.new()
		h.slot = int(row.get("slot", 0))
		h.art = StringName(row.get("art", ""))
		h.label = String(row.get("label", "SECTOR LOOT"))
		h.scanned = bool(row.get("scanned", false))
		for e2 in row.get("items", []):
			var it := _item_from(e2)
			if it != null:
				h.items.append(it)
		n.jetsam.append(h)
	for m in d.get("bag", []):
		var part := _item_from(m)
		if part != null:
			n.bag.append(part)
	n.bagged = bool(d.get("bagged", false))
	return n

static func _names(a: Array[StringName]) -> Array:
	var out: Array = []
	for s in a:
		out.append(String(s))
	return out

static func _vec(v: Variant) -> Vector2:
	if typeof(v) != TYPE_ARRAY or (v as Array).size() < 2:
		return Vector2.ZERO
	return Vector2(float((v as Array)[0]), float((v as Array)[1]))
