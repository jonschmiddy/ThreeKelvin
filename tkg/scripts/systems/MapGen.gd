class_name MapGen
extends RefCounted

## Procedural galaxy. Layers run edge -> core; danger and loot quality both
## climb coreward. Layers are fully connected laterally so you can farm a
## danger band before choosing to descend. That lateral freedom is what makes
## the greed clock work: every death is self-authored.

## A place is described by three independent axes rather than one label.
## Development is how built-up it is, security is how policed, and the berth
## list is who operates there - nobody, one manufacturer, or several competing. They
## are independent on purpose: a rich city with no law is a story, and so is a
## lone policed outpost at the edge of nothing.
enum Development { UNCLAIMED, OUTPOST, SETTLEMENT, CITY, CAPITAL }

## Kept, but no longer authored - derived from the axes at generation time.
## Loot bias, fauna pools, contraband stock and station inventory all branch on
## it across five files, and collapsing three axes onto one label in exactly one
## place beats teaching every one of those sites the new vocabulary.
## WHERE YOU ARE, as a kind of place. Every value here is somewhere you visit
## and the encounters gate on it.
##
## `CORE` USED TO BE THE LAST ONE AND IT WAS NEVER A REGION. `_derive_region`
## handed it to `NodeType.CORE` and to nothing else -- the boss at the centre --
## and `OptionTable.ensure` refuses to roll options for the boss, so the gate
## selected exactly the one node that would never be asked. Four authored
## encounters were gated on it: the last lit dock, the barge on its final leg,
## the relay counting down, the six ships holding. All four were committed,
## reviewed, and impossible.
##
## DEEP is the region those four were written for -- the approach, where the
## claims have run out and the traffic has stopped. The word is the game's own:
## it says "nobody disinterested comes this deep" in that very encounter.
##
## Same ordinal, so a saved region still reads back as what it was.
enum Region { FRONTIER, TERRITORY, COSMOPOLITAN, LAWLESS, FAUNA, DEEP }
## WHAT KIND OF PLACE, never what is in it. FIGHT, EVENT and DERELICT were
## removed 2026-08-27: what a system holds is `options` now, and those three were
## only ever labels for what got rolled there.
##
## The four that survive share one rule -- a type is a place the CHART NAMES and
## that has its own interaction. A station is the telegraphed safe node with its
## own screen; the core is one hand-authored boss; a pulsar is placed against a
## nebula shell and harvested. SYSTEM is everything else, and 1 says so: every
## system but a station looks identical from the chart.
##
## THE ORDER IS A SAVE FORMAT, because `type` is serialised as an int. Removing
## three values renumbered every one after them, which is only survivable because
## `SaveGame.load` refuses a version mismatch outright -- the discard is the
## migration and the version bump is what arms it. Change this list again and the
## version goes with it, in the same commit.
enum NodeType { START, STATION, CORE, PULSAR, SYSTEM }

## The option id meaning "the system itself, all of it".
##
## Every encounter in the game today consumes the whole node: you strip the
## wreck, you win the fight, you answer the hail, and there is nothing else
## here. A system that offers three or four things to do consumes them one at a
## time, and this is the id reserved for the case where there is only one.
##
## Zero on purpose. It is what an absent field reads as, so a save or a message
## written before options existed says "the system" rather than "option zero of
## a list nobody wrote".
const OPTION_WHOLE := 0

## A station's shelf: `OPTION_SHOP + i` is the i-th part standing on it.
##
## The shelf is the second contested thing in the game, and the first that is a
## LIST. One station, four buyers, and one Legendary — the same shape as the
## wreck, except that a wreck is taken whole and a shelf is taken a part at a
## time. That is what the option id was for.
##
## INDEXED, WHICH MEANS THE ARRAY MUST NOT SHRINK. `n.shop` used to have the
## bought part erased out of it, which silently renumbered everything after it:
## one purchase and every machine's idea of "slot 2" disagreed. So a sold part
## stays on the shelf and is marked gone in `taken` instead, which is what that
## field has always been for.
##
## Based at 100 so the ids read as a namespace rather than as a count, and so a
## fourth kind of option added later has somewhere obvious to live.
const OPTION_SHOP := 100
## And the hull on the rack, which is one object rather than a list.
const OPTION_SHOP_HULL := 110

## What a shared kill left floating: `OPTION_BAG + i` is the i-th part in it.
##
## The third contested thing, and the second that is a LIST — so it is the
## shelf's shape rather than the wreck's, and for the same reason: a bag is taken
## a part at a time. `MapNode.bag` therefore never shrinks either. See `taken`.
##
## Based at 200 rather than 120 so the shelf keeps room to grow. A station that
## one day stocks more than ten parts must not start renumbering into the bag.
const OPTION_BAG := 200

## What a system holds: `OPTION_SITE + i` is the i-th option rolled at it.
##
## The fourth contested thing, and the LIST the other three were rehearsals for
## -- `OPTION_WHOLE`'s comment says almost apologetically that it is the id for
## "the case where there is only one", and this is the case where there is not.
##
## BASED AT 300 RATHER THAN 210, following the same reasoning `OPTION_BAG` gives
## for not sitting at 120: the bag keeps room to grow, and a system may one day
## hold more than the current 2-4. Never re-base an existing constant -- these
## numbers are in saved `taken` arrays and in the co-op claims table.
##
## AND THE LIST MUST NEVER SHRINK, which is the lesson `OPTION_SHOP` learned the
## hard way: `n.shop` used to have the bought part erased out of it, silently
## renumbering everything after it, so one purchase and every machine disagreed
## about slot 2. A taken option stays in `MapNode.options` and is marked in
## `taken`.
## The sky over a system, for the options that describe it.
##
## ORDINARY is most of them and says nothing. FLARE is a star that throws
## tantrums, which is what `corona` and `flare_shelter` are both about, and it
## is the one that has to be MUTUALLY EXCLUSIVE with a quiet star -- you cannot
## shelter from a flare at a system whose star does not throw any.
## RED and BLUE are both hypergiants -- the two ways a star can be big enough to
## be a problem -- and ORDINARY is everything else, which is most of it.
##
## `FLARE` was the first name for the red one, from when it existed only to gate
## two encounters about a star throwing tantrums. It is RED now because the
## chart paints it: what you see from three systems away is the colour, and a
## name that describes the hazard rather than the star reads backwards the
## moment the star is the thing on screen.
enum Star { ORDINARY, RED, BLUE }

const OPTION_SITE := 300

## WHAT BECAME OF AN OPTION. `MapNode.results` holds one of these per spent
## index, and the drawer turns it into the word stamped across the dead card.
##
## `GONE` is the one that is not an outcome: it is the other half of an
## exclusive set, closed by the choice you made rather than by anything you did
## to it. Kept distinct from `DONE` because "you resolved this" and "you can no
## longer resolve this" are opposite facts that would otherwise share a word.
const R_SUCCESS := &"success"
const R_PARTIAL := &"partial"
const R_BOTCHED := &"botched"
const R_DONE := &"done"
const R_GONE := &"gone"
const RESULTS: Array[StringName] = [R_SUCCESS, R_PARTIAL, R_BOTCHED, R_DONE,
	R_GONE]

## Every container in a system: `OPTION_JETSAM + h * JETSAM_STRIDE + i` is the
## i-th thing in the h-th one.
##
## The fifth contested list, and the first that is a list OF lists. A system used
## to hold one bag, so `OPTION_BAG + i` was enough; it now holds one container
## per hull you killed plus one of its own, and those are separate piles that
## have to be claimed separately.
##
## BASED AT 1000, and the reason is the one this file already gives twice: never
## re-base an existing constant, because these numbers are in saved `taken`
## arrays and in the co-op claims table. `OPTION_BAG` keeps its hundred slots and
## keeps meaning what it always meant; nothing renumbers.
##
## THE STRIDE IS A CEILING ON ONE CONTAINER, not on how many there are. Sixty-four
## is far past what a wreck holds -- drops are single digits -- and the cost of
## being wrong is two containers sharing a claim, so it is deliberately loose.
const OPTION_JETSAM := 1000
const JETSAM_STRIDE := 64


## One container of loose things, sitting in a system.
##
## NAMED FOR THE VERB. `jettison` is what you do to fill one, and jetsam is that
## verb's own noun -- goods put over the side of a ship. The two words teach
## each other, which no other candidate did: this was `Hoard`, which implied
## treasure, and then `Flotsam`, which is wreckage that floats free rather than
## anything anybody decided to drop.
##
## A wreck's contents are the half this name fits least -- nobody threw those
## overboard, the ship simply stopped being one. It is still the right word,
## because the thing a player DOES here is throw things away and come back for
## them, and the container is named after the action rather than the accident.
##
## A WRECK IS ONE, AND SO IS THE FLOOR. What a hull was carrying when you killed
## it and what you have put down here are both piles you reach into, and making
## them the same class means the popup, the claim, the sweep and the save all
## have one thing to know about.
##
## They persist. Jump away and come back and your wrecks are still where you left
## them with whatever you did not take still in them, which is the whole point of
## it being the system's state rather than the fight's.
class Jetsam extends RefCounted:
	## Its slot in `MapNode.jetsam`, and what its claims are numbered from. Never
	## reused and never renumbered -- see `OPTION_JETSAM`.
	var slot: int = 0
	## The enemy template whose hull this is, or empty for the system's own pile.
	## Empty is what makes it the floor rather than a wreck.
	var art: StringName = &""
	var label: String = "SECTOR LOOT"
	## MUST NOT SHRINK. A taken thing stays in it and is marked in `MapNode.taken`,
	## exactly as `shop` and `bag` learned to.
	var items: Array = []
	## Whether the sweep has already run on this one. Once per container, so
	## opening a wreck you have already been through is not a discovery.
	var scanned: bool = false

	func is_wreck() -> bool:
		return art != &""


	## THE WORD OVER THE GRID, which is not one word.
	##
	## Jetsam is what you throw over the side, and nothing was thrown over the
	## side of a ship you shot: it stopped being a ship and what it was carrying
	## is now yours to recover, which is the dictionary definition of salvage.
	## One class, because a pile is a pile and the popup, the claim, the sweep
	## and the save all want exactly one thing to know about -- but ONE class is
	## not one noun, and the screen should say the true one.
	##
	## Asked of the container rather than set on it, because there is nothing
	## here a wreck knows that `art` does not already carry. A third kind (what
	## an event outcome hands you) needs a door in the sector before it needs a
	## field, so it is not invented here.
	func title() -> String:
		return "SALVAGE" if is_wreck() else "JETSAM"


	## The claim id of the i-th thing in here.
	func option(i: int) -> int:
		return OPTION_JETSAM + slot * JETSAM_STRIDE + i

## Eight shells, wide apart, rather than twenty-four thin ones.
##
## Twenty-four rings put the systems in a shape where nothing was near anything:
## a ring step was 0.03 of the disc while the gap between neighbours ON a rim
## ring was 0.51, a factor of seventeen. Neighbours along your own ring were
## half a galaxy away, and a system that looked adjacent was four rings deep and
## therefore unreachable. Eight shells with populations set by perimeter puts
## every neighbour at roughly the same distance in every direction, which is
## what makes "fly to anything close enough" a rule you can actually see.
##
## FIFTEEN, up from nine, and the paragraph above is why this is safe now.
##
## The twenty-four-shell version failed because the ring STEP collapsed while
## the gap along a ring did not. That was not a fact about the ring count -- it
## was a fact about `target` below, which set the radial gap and the ring
## POPULATION with one number. Shrink the gap and every ring inflated to match,
## so the geometry that made nothing near anything came back at any layer count.
##
## `RING_SPACING` now owns the gap and `LAYERS` owns the depth. With them apart,
## fifteen shells is fifteen shells at the spacing that was hard-won.
##
## WHY THE RUN GOT LONGER ANYWAY. `_link()` gives every system a coreward link,
## so the shortest path to the core is one hop per ring: it was 8, it is now 14.
## That is the forced minimum, not the typical run -- the sim takes 38 jumps
## either way -- so what this buys is that the fast dive is longer, not that the
## ordinary run is.
const LAYERS := 15

## How far apart systems sit ALONG a ring, as a fraction of the disc.
##
## NOT THE GAP BETWEEN RINGS, despite being split out of a value that was. That
## is the whole subtlety: `ring_count` divides a ring's perimeter by this to
## decide how many systems it holds, so it sets the spacing AROUND a ring, and
## the gap BETWEEN rings is (RIM - CORE) / (LAYERS - 2), which necessarily
## shrinks as layers are added because the disc does not grow.
##
## Holding it constant is the point of phase 3. It used to be the derived ring
## gap, so adding layers shrank it and inflated every ring's population at the
## same time -- LAYERS 15 gave 528 systems and pinned sixteen rings at RING_MAX.
## Fixed at the value it had when the geometry was tuned, LAYERS 15 gives ~287.
##
## The rings being closer together than the systems along them is fine and is
## not the twenty-four-shell failure: `range_from` derives the jump radius from
## your NEAREST neighbour, so a tighter ring stack gives a tighter radius rather
## than a map where nothing is near anything.
const RING_SPACING := 0.1157

## The foreshortening `ring_count` treats as nominal, so `density = 1.0` means
## "as many systems as an ordinary galaxy holds" rather than "as many as a
## perfect circle would". 0.62 is the Grand-Design Spiral's, which is the
## archetype the rest were authored around.
const SQUASH_REF := 0.62

## What share of a ring's systems carry a link inward.
##
## The dial for phase 5. At 1.0 every system has a door, the shortest path is
## one hop per ring, and lateral travel is decoration -- which is what it was.
## Below that, crossing a ring becomes how you find the way down.
##
## PARKED AT 1.00, WHICH TURNS THE FEATURE OFF. Every system carries a door, as
## it always did, and the machinery below is inert until this moves.
##
## The MAP is not the problem: `-- maptest` passes on 120 galaxies at 0.40, with
## every ring enterable and the core always reachable, and the forced path rises
## from a flat 14 to 17..21..28. What does not work is the simulated pilot --
## `Policy.choose_jump` has no way to ROUTE. With a door under every system it
## never needed one: take a forward link if there is one, farm otherwise. On a
## sparse map it must walk to a door it cannot see, and instead it circles the
## rim. Measured at 0.40: 98.8% of runs stranded, average danger reached 1.72,
## seventy-seven jumps without leaving the first two rings.
##
## So this waits on pathfinding in the sim, not on a different number here.
## Turning it on before that would be tuning a game against a model that cannot
## play it -- the mistake FUEL_PER_DISC_RADIUS's own comment warns about.
##
## PICKED FROM MEASUREMENT, not from the 0.5-0.66 the brief suggests -- that
## range was guessed against a mechanism that turned out to be inert, because
## the old reachability pass restored a door for every forward system whatever
## this said. With that relaxed, `-- maptest` over 120 galaxies gives:
##
##     share   doors/ring   forced path  min .. mean .. max
##     1.00       20.4          14  ..  14.0  ..  14      (what it was)
##     0.55       11.0          15  ..  17.9  ..  22
##     0.40        7.9          17  ..  21.2  ..  28      <- here
##     0.30        6.1          18  ..  25.1  ..  33
##     0.18        3.8          23  ..  34.8  ..  59
##
## 0.40 puts the fast dive at 21 against a farming run of about 38, so diving is
## still faster and no longer nearly free. The spread matters as much as the
## mean: the forced path used to be 14 in EVERY galaxy, and how hard a galaxy is
## to descend is now a property of that galaxy.
const DOOR_SHARE := 1.00

## The fewest ways into a ring, whatever DOOR_SHARE rolls.
##
## Two rather than one, so a ring is never a single point of entry that every
## route in the galaxy has to funnel through -- that is a corridor with extra
## steps, and it would make one unlucky system placement decide the whole run.
const MIN_DOORS := 2

## Where each ring sits, as a fraction of the disc radius. Lives here rather
## than in the chart because the map's populations are derived from it: if the
## two ever disagreed, ring counts would be weighted for radii the chart does
## not draw.
##
## RIM IS AUTHORED, and it was briefly derived from the ring spacing before the
## starchart objected. `ring_radius()` spreads however many rings it is given
## across RIM..CORE, so raising LAYERS packs them tighter rather than widening
## the disc -- which looked like a fault worth fixing by deriving RIM upward.
##
## IT IS NOT ONLY THE OUTER RING'S RADIUS. It is the extent the whole chart
## normalises against: `StarchartScreen._radius()` is screen-derived and never
## reads this constant, so node positions, the halo that paints the disc, and
## the pan clamp all assume galaxy coordinates top out near here. Pushing RIM to
## 1.61 put the rim outside the painted halo -- a hard elliptical edge with
## unpainted space inside it -- and outside the pan limit, so the sides of the
## galaxy could not be reached while zoomed.
##
## That is one constant doing two jobs, which is the same fault this phase set
## out to fix in `target`. What made it hard to see is that the second job lives
## in a file which does not import it.
const RIM := 0.92
const CORE := 0.11
## How far the rings bend from equal-area spacing toward tracking the galaxy's
## light. All the way packs the inner rings closer than a system glyph is wide.
const LIGHT_BLEND := 0.42

## The Core is not a ring, it is the middle. Spreading the schedule across all
## LAYERS spent the innermost ring on the Core and then drew the Core at zero,
## which left a third of the disc radius — the brightest part of the galaxy —
## with nothing in it at all. The populated rings run RIM to CORE between them;
## the Core sits inside the lot.
## THE HOLE IS APPLIED HERE, so that everything asking where a ring is gets the
## same answer. It used to be applied at the placement site only, which meant
## `ring_count` sized a ring's population from the un-holed circle while
## `galaxy_pos` drew that ring somewhere else entirely.
##
## On a Collisional Ring (`ring = 0.52`) the innermost ring was counted for
## radius 0.110 and drawn at 0.573 -- 5.2x the circumference, carrying the
## population of the small one. The field thinned toward the middle, which is
## the opposite of what the weighting in `ring_count` exists to do, and left
## gaps a sensor-gated ship cannot see across.
static func ring_radius(layer: int) -> float:
	var rn := _ring_radius_raw(layer)
	# Galaxies with a hole in the middle have no systems in the hole.
	var hole: float = float(Run.galaxy.get("ring", 0.0))
	if hole > 0.0:
		rn = hole + rn * (1.0 - hole)
	return rn


## The schedule before the hole is punched in it. Private on purpose: a caller
## that wants "where is this ring" wants `ring_radius`, and the whole bug was
## two callers disagreeing about which of these two they meant.
static func _ring_radius_raw(layer: int) -> float:
	if layer >= LAYERS - 1:
		return 0.0
	var depth := float(layer) / float(maxi(1, LAYERS - 2))
	var equal := sqrt(lerpf(RIM * RIM, CORE * CORE, depth))
	var k := maxf(1.0, float(Run.galaxy.core_pow))
	var lit := pow(lerpf(pow(RIM, 1.0 / k), pow(CORE, 1.0 / k), depth), k)
	return lerpf(equal, lit, LIGHT_BLEND)

## How many systems a ring holds: enough that the gap between neighbours along
## it matches the gap between rings.
##
## This is what makes the field even, and it is worth being clear about the
## trade. Populations proportional to perimeter mean uniform density by AREA,
## not density that follows the galaxy's light — a rim ring carries 42 systems
## and a core ring 14 because the rim ring is enormous. Some light bias survives
## anyway, because the rings themselves are packed toward the core, so systems
## per unit area still rises as you go in. What is gone is the deliberate
## coreward crowding; what is bought is a map where your neighbours are your
## neighbours.
## Danger runs 1 to 10. The number you see is the fine-grained one; the systems
## whose balance was tuned against a five-tier ladder — enemy pools, loot rarity
## gates, hull tiers, station stock — read it through tier() instead, so widening
## the scale changed how precisely difficulty ramps without silently reweighting
## every drop table in the game.
const DANGER_MAX := 10

static func tier(danger: int) -> int:
	return clampi((danger + 1) / 2, 1, 5)


## THE FIVE RUNGS, IN WORDS. Display only.
##
## The ladder was always there -- `tier()` has collapsed danger to five since the
## scale widened, and enemy pools, loot gates, hull tiers and station stock have
## all been read through it -- but it had no name a player could see, so the one
## number they DO see (danger, 1 to 10) carried the whole ladder implicitly.
##
## NEVER IN ENCOUNTER PROSE. An encounter says what is in front of you; naming
## its tier would be the fiction reading its own gate out loud. This is for the
## chart and the tooltip, where the question is "how bad is it over there".
const TIER_NAMES: Array[String] = ["", "EASY", "ROUGH", "HARD", "BRUTAL", "LETHAL"]

static func tier_name(danger: int) -> String:
	return TIER_NAMES[tier(danger)]

const RING_MIN := 5
const RING_MAX := 60

static func ring_count(layer: int) -> int:
	if layer >= LAYERS - 1:
		return 1
	# DENSITY, NOT SQUASH. This used to read the galaxy's foreshortening --
	# `squash` is a CAMERA ANGLE, per its own docstring, "1.0 is face-on round,
	# 0.3 is edge-on" -- and multiply ring populations by it. You do not lose a
	# fifth of a galaxy's stars by tilting the camera. Measured over 500 runs it
	# was worth 132 systems on a Lenticular against 188 on a Round Elliptical.
	#
	# `density` is the same variation, authored per kind and said out loud.
	var den := float(Run.galaxy.get("density", 1.0))
	# THE RING SPACING, not a value derived from LAYERS. It used to be
	# `(RIM - CORE) / (LAYERS - 2)`, which meant this divisor moved every time
	# the layer count did -- so adding rings inflated every ring's population as
	# well, and the node count grew faster than the shells. Measured: LAYERS 15
	# with the old derivation gives 528 systems and pins sixteen rings at
	# RING_MAX; with the spacing held it gives ~287.
	var target := RING_SPACING
	# Perimeter of the squashed ring, near enough for counting purposes.
	var r := ring_radius(layer)
	# A ROUND ring's perimeter, referenced to the NOMINAL galaxy. It was
	# `PI * r * (1.0 + sq)` -- the squashed ellipse's -- which is where the
	# camera angle got in.
	#
	# SQUASH_REF rather than 2.0, and that matters. The true circumference is
	# 2*PI*r, and using it raised every ring's population by about a quarter
	# because the old formula was measuring a foreshortened ellipse: ~287
	# systems became ~360. Anchoring to the tilt of a nominal galaxy means
	# `density = 1.0` reproduces exactly what that galaxy always had, and no
	# galaxy's population depends on its own camera angle any more.
	var perim := PI * r * (1.0 + SQUASH_REF) * den
	# Weighted toward the middle. Populations straight off the perimeter give
	# even spacing everywhere, which reads as a uniform grid of places — and it
	# puts most of the galaxy out on the rim, where the danger is lowest and
	# there is least reason to be. Tilting it inward means the frontier is
	# genuinely thin and the deep galaxy is genuinely crowded, which is the
	# shape of the run: sparse and safe at the edge, dense and lethal in.
	# The curve matters more than the endpoints. A linear tilt from 0.44 to 1.5
	# still put roughly the same number of systems on every ring — the perimeter
	# shrinks inward at almost the rate the weight grows, so they cancel and the
	# field comes out flat however the endpoints are set. Raising f to a power
	# breaks that cancellation: the weight stays low across the outer half and
	# then climbs steeply, which is what actually empties the frontier and packs
	# the deep galaxy. Areal density now runs about fifty to one from rim to
	# core, against six to one before.
	# DEPTH OFF THE UNHOLED SCHEDULE, not off where the ring is drawn. `r` above
	# is the drawn circle, and on a ring galaxy the drawn circles are compressed
	# into [hole, 1] -- so reading depth off it tells this weighting that every
	# ring is out near the rim, and the innermost gets the rim's weight of 0.14
	# where it wants the core's 3.3. Perimeter is geometry and weight is depth;
	# they were the same number only because the hole used to be applied later.
	#
	# Identical for every galaxy with no hole, where the two radii are equal.
	var depth_r := _ring_radius_raw(layer)
	var f: float = clampf(1.0 - (depth_r - CORE) / maxf(0.001, RIM - CORE), 0.0, 1.0)
	# FLATTENED, from 0.14-3.3, so that a FIXED jump radius can work at all.
	#
	# The steep curve above is still the right description of what this used to
	# do and why -- it emptied the frontier and packed the deep galaxy, about
	# fifty to one by area. It is incompatible with a fixed range: options scale
	# as (R / spacing)^2, so a 3x spacing gradient is a 9x option gradient, and
	# no single radius serves both ends. Measured at R = 0.12, the rim offered
	# zero systems and the deep galaxy offered ten.
	#
	# At 0.80-1.80 spacing varies 1.4x instead of 3x and every ring is jumpable.
	# What the galaxy loses in radial character it should get back from its
	# SHAPE -- dense along the arms, thin between them -- which is a property a
	# player can actually see, and which a fixed radius does not fight.
	var weight: float = lerpf(0.80, 1.80, pow(f, 1.6))
	return clampi(int(round(perim / maxf(0.001, target) * weight)),
		RING_MIN, RING_MAX)

class MapNode extends RefCounted:
	var index: int = 0
	var layer: int = 0
	var row: int = 0
	var rows_in_layer: int = 1
	## Derived from the axes below at generation time, never authored. Loot bias,
	## fauna pools, contraband stock and station inventory all branch on it.
	var region: Region = Region.FRONTIER
	var development: Development = Development.UNCLAIMED
	## 1 lawless ... 5 extreme.
	var security: int = 1
	## Who operates here. Empty is nobody's space; two or more is contested.
	var berths: Array[StringName] = []
	## The dominant manufacturer, or empty. Loot rolls take a single manufacturer to bias to.
	var manufacturer: StringName = &""
	## Migration route. Independent of the social axes - whales do not care who
	## polices the sector.
	var fauna: bool = false

	## WHAT THE STAR HERE IS. One per system, because a system has one star.
	##
	## PULSAR IS DELIBERATELY NOT IN THIS LIST. `NodeType.PULSAR` already means
	## "a pulsar, and you can fly to it and harvest the beam" -- so a SYSTEM
	## whose star was also a pulsar would make some pulsars harvestable and
	## some not, which is two rules for one object. What an option like
	## `the_sweep` actually says is "a pulsar, CLOSE", and that is `near_pulsar`
	## below: a fact about the neighbourhood rather than about this star.
	var star: Star = Star.ORDINARY

	## A gas giant in the system. Its own flag rather than a value of `star`
	## because it is not one: a system can have a temperamental star AND a gas
	## giant, and `slipping_orbit` only cares about the second.
	var gas_giant: bool = false

	## Is there a pulsar near enough to matter? Computed once at generation --
	## see `_seed_pulsars` -- rather than measured when an option asks, because
	## `admits` runs for every option against every system and a distance scan
	## per question is a scan nobody needs to repeat.
	var near_pulsar: bool = false
	var danger: int = 1
	var type: NodeType = NodeType.SYSTEM
	var visited: bool = false

	## SEEN FROM A DISTANCE, without having been flown to.
	##
	## Set by `RunState.chart_from` whenever the ship is close enough, and never
	## cleared -- see the note on RunState.sense_radius. A run mark like
	## `visited` and `cleared`, saved with them.
	var sensed: bool = false
	var cleared: bool = false
	## Cleared by the Hellbender rather than by anybody in the party. The sector
	## reads it to say "something fed here" instead of "stripped", which is
	## most of what makes the rival feel like a rival. See RunState.hellbender_land.
	var eaten: bool = false
	## Contact was broken here and you have not left since. NOT the same as
	## cleared: the hostile is still out there, so returning re-engages, and
	## nothing was salvaged. It exists because the sector has to be able to tell
	## "you have not fought this yet" from "you just ran from it" — the first
	## offers ENGAGE, the second must not, or the button that got you out of a
	## fight is the same button that puts you back in one.
	var fled: bool = false
	## Which of this system's options have been used up, by option id.
	##
	## `cleared` says the system as a whole is finished; this says WHICH parts of
	## it are gone. They are not the same question the moment a system offers
	## more than one thing to do — one ship strips the wreck and another still
	## wants the fight, and a single boolean cannot hold that.
	##
	## Option `MapGen.OPTION_WHOLE` is the system itself, which is what every
	## encounter that exists today consumes. So a node with one thing to do
	## carries exactly one entry and the two fields agree, which is why nothing
	## reading `cleared` had to change.
	##
	## In a party this is a copy of what the host holds. See NetSession.claims.
	var taken: PackedInt32Array = PackedInt32Array()
	## WHAT EACH SPENT OPTION CAME TO, by its index in `options`.
	##
	## `taken` says an option is done and nothing said what happened. That was
	## enough while a spent option vanished off the list; it is not enough now
	## that the card stays and says SUCCESS or BOTCHED across itself, and it has
	## to survive a jump away and back -- what you did in a system is a fact
	## about the system, exactly as its wrecks and its jetsam are.
	##
	## One of `MapGen.RESULTS`. Absent means an option nobody has touched.
	var results: Dictionary = {}
	## What followed your heat trail in, rolled once on arrival. Stored on the
	## node for the same reason `foes` is: an ambush that re-rolled on resume
	## would be a hostile you could refuse by quitting and coming back cold,
	## which is save-scumming through the front door.
	## Whether a fight is OWED here because your heat brought one in.
	##
	## A FLAG RATHER THAN THE PACK. `ENCOUNTER_REBUILD.md` 6 asks for the node
	## state to go away entirely, and that cannot be taken literally: `_roll_here`
	## runs at Router:253 and the autosave at :263, so whatever arrival decided is
	## on disk BEFORE the ambush resolves at :272. With nothing stored, a player
	## who quits on arrival resumes with `ambush_rolled` already true and nothing
	## waiting -- which is exactly the refusal the safe-point rule exists to stop,
	## and which the comment above states in as many words.
	##
	## What is waiting is not stored because it need not be: `_roll_foes` is
	## positional off `Rng.derive(&"foes", index)`, so it answers the same way
	## every time it is asked, on every machine.
	var ambush_pending: bool = false
	## Whether the roll has HAPPENED, which is not the same as whether it hit.
	## Without this an empty `ambush` cannot be told from "not rolled yet", so a
	## quiet arrival would roll again on every redraw until something bit.
	var ambush_rolled: bool = false
	var pos: Vector2 = Vector2.ZERO
	## Where this system sits in the galaxy, as a fraction of the disc radius
	## with the disc's foreshortening already applied - so it is exactly what the
	## chart draws. Links and fuel costs are both derived from it, which is what
	## makes a long jump look long and cost more.
	var gal: Vector2 = Vector2.ZERO
	## Sitting inside one of the galaxy's gas clouds. Set at generation from the
	## same placement the chart draws, so a system that plainly looks like it is
	## in a nebula is one.
	var in_nebula: bool = false
	## And whether that cloud is lit from within.
	var nebula_emission: bool = false
	var links: PackedInt32Array = []
	## What the party's kill left floating, as `ModuleData`. See
	## `MapGen.OPTION_BAG` and `RunState.open_bag()`.
	##
	## ONE POOL, NOT ONE PER SHIP. Two ships used to each roll their own drop off
	## their own seat-salted stream, which is duplication solved and distribution
	## never attempted: the party was paid twice for one frigate. The bag is what
	## the kill was worth to the party, and who ends up carrying each part is a
	## decision somebody makes rather than a thing the game decides for them.
	##
	## Like `shop`, THIS ARRAY MUST NOT SHRINK — a taken part stays in it and is
	## marked gone in `taken`, or two machines stop agreeing what "part 2" is.
	var bag: Array = []

	## Every container in this system: wrecks in the order you made them, plus
	## the system's own pile whenever something has been put down here.
	##
	## SEPARATE FROM `bag`, which stays exactly as it was. That array is the
	## shared-kill pool and its claims are numbered from `OPTION_BAG`; renumbering
	## it into here would break saved runs and the co-op claims table for no gain.
	## New work uses jetsam; `bag` is left alone until it has no callers.
	var jetsam: Array = []

	## What this system holds, as option IDS rather than definitions.
	##
	## Ids so a save can rebuild the list after the table has changed underneath
	## it -- an unknown id is dropped with a warning rather than refusing the
	## save. Definitions are resolved lazily through `OptionTable.by_id`, never
	## stored: at ~290 systems, building every closure to answer "what is here"
	## is the pattern `ENCOUNTER_REBUILD.md` 5a warns about.
	##
	## Rolled once in `Router._roll_here()` before the autosave, like `foes` and
	## `event_key`, so quitting and resuming cannot re-roll them.
	var options: Array[StringName] = []
	## Rolled once, and never again. The same distinction `stocked` draws for the
	## shelf, and it exists here for a sharper reason: every machine in the party
	## rolls this bag independently off `Rng.derive(&"bag", index)`, so a second
	## roll is not a re-stock, it is one machine disagreeing with the others about
	## what is in the room.
	var bagged: bool = false
	## Populated lazily by StationScreen
	var shop: Array = []
	var shop_hull: HullData = null
	## Stocked ONCE, and never again.
	##
	## Not the same test as `shop.is_empty()`, which is what this used to be, and
	## the difference was an exploit: buying a shelf out emptied the array, so the
	## next visit re-rolled a full one. A station was an infinite supply of parts
	## and — before Market closed the other half of it — an infinite supply of
	## money. A station is a place, not a vending machine. What is on the shelf is
	## what somebody brought here, and when it is gone it is gone.
	var stocked: bool = false
	## How many parts you have sold into this market. Every sale moves the price
	## down a little; see Market._saturation().
	var trades: int = 0
	var inspected: bool = false
	## What is waiting here, rolled on arrival and then fixed for the life of the
	## run. [0] opens the fight and the rest are the pack.
	##
	## On the node rather than in Router for the same reason `shop` is: it has to
	## survive a save. Rolled at the moment the fight started, a force-quit and a
	## resume re-rolled the enemy, so a bad draw cost nothing to reject — which is
	## the one thing SaveGame's header says a suspend save must never buy.
	var foes: Array[StringName] = []
	## Which hail this system is offering, by title. Same reason as `foes`, and
	## the title rather than an index so that inserting an event into the table
	## does not silently repoint every save in flight at a different one.
	var event_key: String = ""

const _BAYER := ["ALPHA", "BETA", "GAMMA", "DELTA", "EPSILON", "ZETA", "ETA",
	"THETA", "IOTA", "KAPPA", "LAMBDA", "SIGMA", "TAU", "OMEGA"]
const _STEM := ["FLINT", "ABYSSAL", "GALLOWS", "KESTREL", "TALLOW", "MARROW",
	"CINDER", "HOLLOW", "VESPER", "BRINE", "AUGUR", "SABLE", "THORN", "GRIST",
	"MERIDIAN", "CALLOUS", "WICK", "FALLOW"]
const _SUFFIX := [" PRIME", " SECUNDUS", "-9", "-4", " V", " IX", " MINOR",
	" WATCH", " REACH", "-2", " III", " GATE"]

## A name, fixed for the life of the run. Hashed from the index rather than
## rolled, so the same system is called the same thing every time you look.
static func star_name(n: MapNode) -> String:
	if n.type == NodeType.CORE:
		return "THE CORE"
	var h := (n.index + 1) * 2654435761
	var a := (h >> 3) % _BAYER.size()
	var b := (h >> 11) % _STEM.size()
	var c := (h >> 19) % _SUFFIX.size()
	if n.type == NodeType.START:
		return "%s %s" % [_BAYER[a], _STEM[b]]
	return "%s %s%s" % [_BAYER[a], _STEM[b], _SUFFIX[c]]

## PROSE, NOT KEYS, which is why this cannot read `Region.keys()` the way
## `type_label` does: FAUNA is "Migration Route" and CORE is "Precursor Ruins".
## A constant rather than a literal inside the function so `-- maptest` can check
## its length against the enum -- see `MapTest._labels` for the bug that makes
## that worth doing.
const REGION_NAMES: Array[String] = ["Frontier", "Territory", "Cosmopolitan",
	"Lawless", "Migration Route", "Precursor Ruins"]

static func region_name(r: Region) -> String:
	return REGION_NAMES[r]

## Colour follows the axes: one manufacturer flies its colours, several read as neutral
## trade, and unclaimed space is dim.
## What colour a system is drawn.
##
## Five states you can name, and deliberately NOT one colour per manufacturer.
##
## The manufacturer colours are accents: small highlights on a module sprite, where
## being a few points apart is exactly right. Reused as the identity of a whole
## system they stopped working — redline and calyx are both muted greens within
## a hair of each other, probate and korvan are both browns, and cygnet sits on
## top of the unclaimed grey-blue. On a chart of a hundred and fifty icons that
## is not a code, it is noise that looks like a code.
##
## Which manufacturer holds a place is a detail you read when you point at one, and the
## tooltip and the panel both say it in words. What the chart has to carry at a
## glance is whether anyone holds it at all.
## THE STAR, IN WORDS. Beside `star_colour` because they are two readings of
## one fact and the panel prints both -- the swatch says which and the words say
## what, and a player who never learns the colour can still read the row.
##
## `star_kind` and not `star_name`: that name was taken sixty lines up by the
## thing that names a SYSTEM -- Epsilon Tallow III -- which is what you would
## reach for first and would have compiled quietly in half the places it is
## wrong.
static func star_kind(n: MapNode) -> String:
	if n.type == NodeType.PULSAR:
		return "NEUTRON STAR"
	if n.type == NodeType.CORE:
		return "NOTHING THAT SHINES"
	match n.star:
		Star.RED: return "RED HYPERGIANT"
		Star.BLUE: return "BLUE HYPERGIANT"
	return "ORDINARY"


## WHAT COLOUR A PLACE IS, and it is the colour of its star.
##
## This was a development gradient: two berths pale, one berth grey, none dark,
## lawless-but-held amber. It read as a manufacturer map because more berths
## meant brighter, and it meant the whole galaxy was tinted by PAPERWORK -- who
## holds a claim here -- rather than by anything you could see out of a window.
##
## It feeds more than the chart. `SpaceBackdrop` takes the dust from it,
## `EncounterView` tints the whole sector with it, and the chart glyphs and
## nebula wash both use it -- so standing in a red hypergiant's light now looks
## like standing in a red hypergiant's light, everywhere at once.
##
## WHAT IS LOST: fauna space was teal and lawless-but-held was amber, both
## readable at a glance. Those are facts about people and animals rather than
## about the sky, and they stay on the tooltip and in the destination panel.
## A star is the thing a system IS.
static func star_colour(n: MapNode) -> Color:
	return swatch(n.type, n.star)


## THE SAME ANSWER WITHOUT A NODE TO ASK ABOUT, for the chart's key.
##
## The key had its own hard-coded colours and they had gone wrong: it drew
## SYSTEM in violet (#b08ad0) and STATION in pale blue (#8ec8e6) from back when
## a system was tinted by who held it. Since the colours became STARLIGHT the
## chart has drawn both in the colour of the star -- so the legend was naming
## two colours that appear nowhere on the map it is a legend for.
##
## A legend that disagrees with the picture is worse than no legend, and it is
## the first thing the chart primer points at. So there is one implementation
## and `star_colour` is a call to it: a key entry asks what an ORDINARY star of
## some type looks like, a real system asks about itself, and neither can drift
## from the other.
static func swatch(t: NodeType, star: Star = Star.ORDINARY) -> Color:
	if t == NodeType.CORE:
		return Color("#d4614f")
	# The pulsar keeps its own, which is the point of it: a neutron star is not
	# a colour of starlight, it is a lighthouse.
	if t == NodeType.PULSAR:
		return Color("#8fd2e0")
	match star:
		Star.RED: return Color("#c05046")
		Star.BLUE: return Color("#5b8fd4")
	return Color("#cbd6e3")

## What kind of place this is, in a word.
##
## FROM THE ENUM ITSELF, so it cannot drift from it. This was a hand-written
## array indexed by the enum value, and the collapse on 2026-08-27 renumbered
## every value without touching it: STATION read "FIGHT", CORE read "STATION",
## PULSAR read "EVENT" and SYSTEM read "DERELICT". Four of five node types named
## themselves wrong on the sector screen for a day.
##
## Nothing failed. The array was still seven entries long and every lookup was
## still in bounds, which is the whole hazard of a parallel array: it does not
## break when it stops corresponding, it just answers a different question.
##
## The warning was even written down, above the enum -- "type_label indexes this
## by value, and inserting in the middle would silently relabel every node type
## after it". It survived the edit it was warning about because it was a comment
## and comments do not run. `keys()` does.
static func type_label(t: NodeType) -> String:
	return NodeType.keys()[t]

## Title case rather than the enum's shouting, so it reads in a sentence.
const DEVELOPMENT_NAMES: Array[String] = ["Unclaimed", "Outpost", "Settlement",
	"City", "Capital"]

static func development_name(d: Development) -> String:
	return DEVELOPMENT_NAMES[d]

static func security_name(sec: int) -> String:
	return ["", "Lawless", "Minimal", "Moderate", "High", "Extreme"][clampi(sec, 1, 5)]

## The classification line: what kind of place, how policed, and who runs it.
static func place_line(n: MapNode) -> String:
	if n.type == NodeType.CORE:
		return "SUPERMASSIVE BLACK HOLE"
	if n.fauna:
		return "MIGRATION ROUTE - " + security_name(n.security).to_upper()
	var out := development_name(n.development).to_upper() \
		+ " - " + security_name(n.security).to_upper()
	if not n.berths.is_empty():
		var names: Array[String] = []
		for m in n.berths:
			names.append(DB.short_name(DB.manufacturer_name(m)).to_upper())
		out += " - " + " / ".join(names)
	return out

## One sentence on what being here means for you.
static func place_blurb(n: MapNode) -> String:
	if n.type == NodeType.CORE:
		return "Four million suns in a point, and the ruins of whatever came first still orbiting it. Nothing here was manufactured."
	if n.fauna:
		return "Megafauna. Exotic materials, no module salvage."
	if n.in_nebula:
		# Said in the sector blurb as well as drawn, because a player who has not
		# opened the chart lately should still know why the sky is moving.
		var gas := "Lit gas. Something inside this cloud is still burning." 			if n.nebula_emission else "Cold gas, thick enough to hide in."
		return gas + " Nothing else out here to see by."
	var who := ""
	match n.berths.size():
		0: who = "Nobody's space. Thin, random salvage."
		1: who = "One manufacturer dominates local salvage."
		_: who = "Contested. Broad stock, and nobody agrees on a price."
	var law := ""
	if n.security <= 2:
		law = " Contraband moves openly; fences carry good stock."
	elif n.security >= 4:
		law = " Inspections are thorough. Do not be carrying anything."
	return who + law

static func generate(canvas: Rect2) -> Array:
	var nodes: Array = []
	var idx := 0
	for layer in LAYERS:
		var count := ring_count(layer)
		# Across the POPULATED rings, not across all of them. Dividing by
		# LAYERS - 1 put the top tier on the Core alone — and the Core is a
		# hand-tuned boss that is never danger-scaled, so a whole run could end
		# without a single top-tier fight. The innermost ring you can actually
		# stop at is now the worst place in the galaxy.
		var ring_danger := 1 + int(round(layer * float(DANGER_MAX - 1)
			/ float(maxi(1, LAYERS - 2))))
		for row in count:
			var n := MapNode.new()
			n.index = idx
			idx += 1
			n.layer = layer
			n.row = row
			n.rows_in_layer = count
			# Jittered per system, not flat per ring. Eight rings cannot land on
			# ten tiers evenly, and more to the point a ring where every system
			# is equally bad is a ring with no decision in it.
			n.danger = clampi(ring_danger + Rng.world.randi_range(-1, 1), 1, DANGER_MAX)
			var depth := float(layer) / float(maxi(1, LAYERS - 1))
			if layer == 0 and row == 0:
				n.type = NodeType.START
			elif layer == LAYERS - 1:
				n.type = NodeType.CORE
			else:
				n.type = _pick_type()
			_roll_axes(n, depth)
			n.region = _derive_region(n)
			nodes.append(n)

	_layout(nodes, canvas)
	for n in nodes:
		# REACH IS APPLIED HERE, once, on the finished position. It scales how
		# far apart systems sit, and `fuel_cost_to` prices raw distance, so this
		# is the dial that makes a galaxy expensive or cheap to cross -- the
		# half of the old `squash` leak that was worth keeping, now authored.
		(n as MapNode).gal = galaxy_pos(n) * float(Run.galaxy.get("reach", 1.0))
	for n in nodes:
		var nn: MapNode = n
		var cloud := NebulaField.at(nn.gal)
		nn.in_nebula = cloud != null
		if cloud != null:
			nn.nebula_emission = cloud.emission
	_seed_pulsars(nodes)
	_mark_pulsar_neighbours(nodes)

	_link(nodes)
	nodes[0].visited = true
	nodes[0].cleared = true
	# And say so in the same vocabulary as everything else that finishes a
	# system. The start is consumed at generation rather than through
	# RunState.take_whole(), so without this it is the one node in the galaxy
	# whose `cleared` and `taken` disagree — and SaveGame infers the missing
	# entry when it reads an old save, which makes it disagree only AFTER a
	# round trip. That is exactly the shape of bug savetest exists to catch.
	nodes[0].taken.append(OPTION_WHOLE)
	return nodes

## WHICH SYSTEMS HAVE A PULSAR FOR A NEIGHBOUR.
##
## After `_seed_pulsars`, because it decides the types -- and before anything
## reads it, because `admits` will ask this of every system for every option and
## measuring a distance each time is a scan repeated for an answer that cannot
## change once the map exists.
##
## THE RADIUS IS THE ONE SIGHT USES. A beam that sweeps your arc every eleven
## seconds is a thing you can see from where you are standing, so "close" here
## means the same as "close" everywhere else on this map rather than a second
## number nobody can reconcile with the first.
static func _mark_pulsar_neighbours(nodes: Array) -> void:
	var beacons: Array = []
	for raw in nodes:
		if (raw as MapNode).type == NodeType.PULSAR:
			beacons.append(raw)
	if beacons.is_empty():
		return
	for raw2 in nodes:
		var n: MapNode = raw2
		if n.type != NodeType.SYSTEM:
			continue
		for b in beacons:
			if hop_distance(n, b as MapNode) <= RING_SPACING * 2.0:
				n.near_pulsar = true
				break


## The rim is unclaimed and the core is built up - that is the whole shape of
## the journey, so development tracks depth directly. The variance is what stops
## it being a readout of the ring number: a city out on the frontier is worth the
## detour, and an unclaimed pocket deep in is worth the risk.
static func _roll_axes(n: MapNode, depth: float) -> void:
	if n.type == NodeType.CORE:
		# Nobody develops a black hole and nobody polices it. The social axes
		# do not apply to the thing at the centre of a galaxy.
		n.development = Development.UNCLAIMED
		n.security = 1
		return
	if n.type == NodeType.PULSAR:
		# Nothing is established beside a neutron star. The beam sterilises
		# whatever it sweeps and the wind strips the rest, so there is no
		# outpost to police, no manufacturer with a claim on it, and nothing living
		# that migrates through — a pulsar is weather, not territory.
		#
		# Re-run rather than rolled in place: _seed_pulsars sets the type long
		# after the axes have been rolled, so it calls back into here to undo
		# them. The depth argument is ignored on this path.
		n.development = Development.UNCLAIMED
		n.security = 1
		n.berths.clear()
		n.manufacturer = &""
		n.fauna = false
		return
	if n.type == NodeType.START:
		n.development = Development.OUTPOST
		n.security = 3
		return

	n.development = clampi(int(round(depth * 4.0 + Rng.world.randf_range(-1.1, 1.1))),
		0, 4) as Development
	# Security follows development loosely, skewed low so lawless space stays
	# common enough to matter - it is where the contraband economy lives.
	n.security = clampi(1 + int(n.development) + Rng.world.randi_range(-2, 1), 1, 5)

	# Nobody claims empty space; the deeper and richer it gets the more manufacturers
	# want a piece, and two or more competing is what a crossroads actually is.
	var want := 0
	match n.development:
		Development.UNCLAIMED: want = 1 if Rng.world.randf() < 0.2 else 0
		Development.OUTPOST: want = 1 if Rng.world.randf() < 0.7 else 0
		Development.SETTLEMENT: want = 2 if Rng.world.randf() < 0.4 else 1
		Development.CITY: want = 3 if Rng.world.randf() < 0.35 else 2
		Development.CAPITAL: want = 3 if Rng.world.randf() < 0.6 else 2
	var pool: Array = DB.manufacturers.keys()
	Rng.shuffle(Rng.world, pool)
	for i in mini(want, pool.size()):
		n.berths.append(pool[i])
	if not n.berths.is_empty():
		n.manufacturer = n.berths[0]

	# Megafauna keep to the thin places.
	n.fauna = n.berths.is_empty() and int(n.development) <= 1 and Rng.world.randf() < 0.3

	# THE SKY, rolled here for the reason fauna is: it is a property of the
	# place, decided once off `Rng.world`, so four machines agree about it and a
	# save carries it without anything having to recompute.
	#
	# A flare star is rarer than a gas giant and does not care where it is --
	# stars do not respect development. A giant is common because most systems
	# have one; it is furniture, and the option that wants it is about being
	# caught in the well rather than about the planet being unusual.
	# Rare on purpose, and rarer than the eighteen per cent the single FLARE
	# kind had: a sky worth remarking on has to be a minority of the sky. Twelve
	# and eight leaves four systems in five ordinary, which is what makes the
	# other one worth crossing the chart to look at.
	var sky := Rng.world.randf()
	n.star = Star.RED if sky < 0.12 else (Star.BLUE if sky < 0.20 else Star.ORDINARY)
	n.gas_giant = Rng.world.randf() < 0.45

## Collapse the three axes back onto the old label, once, here. Order matters:
## the most specific claim about a place wins.
## What is wrong with a place, as short shouted words.
##
## Kept here rather than in the panel that happens to draw it, because a hazard
## is a fact about the sector and more than one screen wants to say it — the
## chart warns you before you commit the fuel, the sector screen reminds you
## once you are standing in it.
##
## Deliberately a LIST. Somewhere can be both inside a nebula and on top of a
## neutron star, and the honest answer then is both lines, not whichever one
## the code happened to test first. New hazards get added here and appear
## everywhere that asks, with no screen needing to learn about them.
static func hazards(n: MapNode) -> PackedStringArray:
	var out := PackedStringArray()
	if n.type == NodeType.PULSAR:
		out.append("PULSAR")
	if n.in_nebula:
		out.append("NEBULA")
	if n.type == NodeType.CORE:
		out.append("EVENT HORIZON")
	return out

## HOW DEEP IS DEEP. The last four shells of fifteen -- far enough in that a
## run reaching them has committed to the ending rather than wandered into it.
const DEEP_FROM := LAYERS - 4

static func _derive_region(n: MapNode) -> Region:
	if n.type == NodeType.CORE:
		return Region.DEEP
	# MEGAFAUNA FIRST, because a herd is a thing IN a place and outranks where
	# the place is -- the fauna encounters are about the animals and would read
	# the same on the rim.
	if n.fauna:
		return Region.FAUNA
	# THEN DEPTH, over everything else. This first took the slot FRONTIER would
	# have had, on the reasoning that a deep system somebody still works is a
	# Territory first -- and that excluded the one encounter of the four that
	# needs a dock. "The last berth" is a lit counter with a clerk behind it and
	# no traffic since before her posting: a berth in the deep is not a
	# contradiction, it is the whole point of the piece.
	#
	# So depth wins. Down here the claims have run out, and which manufacturer
	# nominally holds the paperwork stops being the thing worth knowing about a
	# system -- which is also why `roll_module` opens the unbranded pool for it,
	# the same treatment fauna space already gets.
	if n.layer >= DEEP_FROM:
		return Region.DEEP
	if n.fauna:
		return Region.FAUNA
	if n.security <= 2 and not n.berths.is_empty():
		return Region.LAWLESS
	if n.berths.size() >= 2:
		return Region.COSMOPOLITAN
	if n.berths.size() == 1:
		return Region.TERRITORY
	return Region.FRONTIER

## The spiral, in one place. The chart draws its stars with this and the map
## places its systems with it, so a system lands in an arm rather than beside one.
static func shape_angle(r_norm: float, arm: int, along: float) -> float:
	var g := Run.galaxy
	var n := maxi(1, int(g.arms))
	# Includes the run's spin, so the arms turn with the systems rather than
	# the systems sliding around a fixed galaxy.
	var base := float(arm) * TAU / float(n) + Run.galaxy_spin
	var bar: float = g.bar
	if bar > 0.0 and r_norm < bar:
		# Inside the bar the arms have not started: it is a straight spine
		# through the core, so angle barely varies with radius.
		return base + along * 0.22
	var t: float = r_norm
	if bar > 0.0:
		t = (r_norm - bar) / maxf(0.001, 1.0 - bar)
	return base + t * float(g.twist) + along

static func _hash2(i: int, j: int, salt: int) -> int:
	var h := (i * 374761393 + j * 668265263 + salt * 144665) & 0x7fffffff
	h = (h ^ (h >> 13)) & 0x7fffffff
	h = (h * 1274126177) & 0x7fffffff
	return (h ^ (h >> 16)) & 0x7fffffff

static func _frac(h: int) -> float:
	return float(h % 10000) / 10000.0

## Where a system sits, in units of the disc radius. The map owns this because
## links and fuel costs are derived from it - two copies would mean pricing a
## jump for a position nobody draws.
static func galaxy_pos(n: MapNode) -> Vector2:
	if n.type == NodeType.CORE:
		return Vector2.ZERO
	var g := Run.galaxy
	# The hole is inside ring_radius now -- applying it again here is what made
	# the counted ring and the drawn ring two different circles.
	var rn := ring_radius(n.layer)

	var rows := maxi(1, n.rows_in_layer)
	# Alternate rings are offset half a step so they interleave rather than
	# lining up into spokes.
	var half: float = 0.5 if n.layer % 2 == 1 else 0.0
	var astep := TAU / float(rows)

	# Exact rings at exact angles read as a lattice, not a galaxy. These offsets
	# are hashed from the node rather than rolled, so nothing shifts between
	# frames, and each is a fraction of one ring step so a neighbour stays one.
	# Seeded per run as well, or every galaxy scatters its systems in exactly
	# the same pattern — the same ring would always have the same wobble.
	var salt := (Run.galaxy_seed % 100003) * 31
	var jr := _frac(_hash2(n.index, n.layer, 101 + salt)) - 0.5
	var ja := _frac(_hash2(n.index, n.layer, 211 + salt)) - 0.5
	var rot := (_frac(_hash2(n.layer, 7, 307 + salt)) - 0.5) * astep * 0.55
	var r := rn + jr * 0.026
	var a := (float(n.row) + half) * astep + rot + ja * astep * 0.42 + Run.galaxy_spin

	# Drawn toward the nearest arm so systems sit in the bright lanes -- and far
	# enough to ACTUALLY GATHER, which the old cap of 0.6 could not.
	#
	# THE CAP IS COUNTED IN NEIGHBOUR WIDTHS. `astep` is the angle between
	# adjacent systems in the ring, so below 1.0 a system cannot overtake one and
	# the ring keeps even spacing BY ARITHMETIC, however bright the arm is. The
	# old value was not a weak setting, it was a disabled one: the starfield
	# gathered into lanes and the systems drifted evenly through them, so the
	# map's density said nothing about the galaxy drawn behind it. Everything
	# already agreed WHERE the arms are -- `shape_angle` is the one definition,
	# and the stars, the gas and the systems all read it -- they disagreed about
	# how much to believe it.
	#
	# THE OLD CAP'S REASON HAS EXPIRED. It read "an uncapped pull sends adjacent
	# rows to opposite arms, which is how one-fuel jumps once crossed the whole
	# galaxy", which was about `links` built by ROW INDEX. Links are a suggestion
	# now, and the lateral pass was rebuilt in angular order.
	#
	# Measured on a Grand-Design Spiral, widest void in ring 8 against an even
	# spacing of 15 degrees, with `-- maptest` asserting the core stays FLYABLE:
	#
	#     0.6   34 deg,  2 of 24 gaps bunched   flyable 6.1 mean   ok
	#     2.0   76 deg, 10 of 24                        6.2        ok
	#     3.0  106 deg, 15 of 24                        7.4        ok
	#     4.0  136 deg, 21 of 24                        7.9        FAILS
	#     6.0  139 deg, 22 of 24                        9.9        ok
	#
	# TWO THINGS THAT TABLE SAYS. It saturates: the real pull is `best * 0.75`,
	# so past about 4 nothing is being clipped and 5, 6 and uncapped draw the
	# same galaxy. And 4.0 FAILS the flyability gate -- one Grand-Design Spiral
	# in 120 ends up with no route to its core -- while 6.0, which draws a nearly
	# identical galaxy, passes. That pass is luck rather than safety, and the
	# honest fix is for generation to GUARANTEE a route the way MIN_DOORS
	# guarantees a ring has an exit. Until it does, staying well below 4 is not
	# a preference, it is the margin.
	#
	# 2.0 chosen for how it LOOKS. It buys the lanes and almost no detour --
	# routing barely moves, 6.2 against 6.1 -- and that is the right trade here,
	# because run length is meant to be handled by sector difficulty rather than
	# by walls.
	if int(g.arms) > 0:
		var arms := maxi(1, int(g.arms))
		var best := 0.0
		var closest := TAU
		for arm in arms:
			var d := wrapf(shape_angle(rn, arm, 0.0) - a, -PI, PI)
			if absf(d) < closest:
				closest = absf(d)
				best = d
		a += clampf(best * 0.75, -astep * 2.0, astep * 2.0)

	return Vector2(cos(a), sin(a) * float(g.squash)) * r

## How far apart two systems are, as the chart draws them, in disc radii.
## How far apart two systems are, for pricing a jump.
##
## MEASURED UN-SQUASHED. Ruled 2026-08-25 (D1). `galaxy_pos` foreshortens the
## disc for drawing -- `sin(a) * squash` -- and this used to measure in that
## same space, so a north-south jump cost 1.5x to 3.6x less than an east-west
## one at the same apparent separation. Optimal routes hugged the minor axis,
## invisibly, and nothing on screen said so.
##
## Undoing the foreshortening restores the disc to the circle it actually is, so
## a jump costs what it costs whichever way it points. THE COST OF THE RULING is
## that the chart no longer promises "distance as drawn": on a strongly tilted
## galaxy two systems that look equally far apart are not, because one pair is
## further apart in the plane and only looks close from this angle.
static func hop_distance(a: MapNode, b: MapNode) -> float:
	var sq := maxf(0.05, float(Run.galaxy.squash))
	var pa := Vector2(a.gal.x, a.gal.y / sq)
	var pb := Vector2(b.gal.x, b.gal.y / sq)
	return pa.distance_to(pb)

## Put a neutron star at the heart of every shell that has a system in it.
##
## Pulsars used to be rolled like any other node type, which put them wherever
## the dice fell — including out in clean space, where nothing had ever
## exploded. The object and its cause were unrelated.
##
## Now the cloud comes first and the pulsar is derived from it: a supernova
## remnant or a planetary nebula is a star's corpse, so if a system sits inside
## one, THAT is the system with the corpse in it. The consequence is that
## pulsars are properly scarce and unevenly spread — a galaxy can roll none,
## and one that rolls three has three shells to show for them — and that the
## ring you can see on the chart is the REASON the place is dangerous rather
## than decoration sitting next to it.
##
## Membership is NebulaField's own test at its own reach: the same one the
## sector screen asks to decide whether you are standing in gas. Two answers to
## "is this system inside that cloud" would agree exactly until one was edited.
static func _seed_pulsars(nodes: Array) -> void:
	for raw in NebulaField.clouds():
		var cl: NebulaField.Cloud = raw
		# REMNANTS ONLY. A planetary nebula is the envelope of a low-mass star
		# gently shrugging off its outer layers, and what it leaves behind is a
		# white dwarf — no collapse, no neutron star, no beam. Only a
		# core-collapse supernova leaves the thing this node is about.
		if cl.kind != NebulaField.Kind.REMNANT:
			continue
		# How far a system may be dragged to become this shell's pulsar.
		#
		# The test used to be "inside the cloud", which was the right question
		# when the pulsar stayed where it was. Now that it MOVES to the centre,
		# the only thing that matters is whether hauling it there wrecks the
		# layout — and a shell with no system quite inside it is a ring drawn
		# around nothing, which is worse than a system nudged half a cloud.
		#
		# Floored, because a planetary is small enough that a radius-relative
		# reach alone would almost never catch anything.
		var reach: float = clampf(cl.radius * 2.2, 0.14, 0.20)
		# Nearest to the middle, because the middle is where the star was.
		var best: MapNode = null
		var closest := INF
		for n in nodes:
			var nn: MapNode = n
			if nn.type == NodeType.START or nn.type == NodeType.CORE:
				continue
			if nn.type == NodeType.PULSAR:
				continue
			if nn.gal.distance_to(cl.pos) > reach:
				continue
			var d: float = nn.gal.distance_to(cl.pos)
			if d < closest:
				closest = d
				best = nn
		if best == null:
			continue
		best.type = NodeType.PULSAR
		# And it MOVES to the middle of the shell. Picking the nearest system
		# and leaving it where the layout happened to put it meant the neutron
		# star sat somewhere on the ring it had supposedly thrown off — usually
		# right in the wall of it. The shell is gas expanding away from a point,
		# and the point is the pulsar; anywhere else and the picture argues with
		# itself.
		#
		# Safe to do here because gal is what everything downstream reads: _link
		# has not run yet, so the jump distances are measured from the new
		# position, and the chart draws from it too. The node keeps its layer,
		# so its depth and danger are untouched.
		best.gal = cl.pos
		# Strip whatever civilisation the axes gave it when it was still an
		# ordinary system. Depth is ignored for a pulsar, so the value passed
		# here does not matter.
		_roll_axes(best, 0.0)
		best.region = _derive_region(best)
		# Whatever else was true of the place, standing next to a neutron star
		# is the dangerous part.
		best.danger = maxi(best.danger, DANGER_MAX - 1)

static func _pick_type() -> NodeType:
	# No PULSAR here. A neutron star is not scattered at random across the
	# galaxy: it is what a big star leaves when it goes, and the only places
	# that happened are the shells still hanging where it stood. They are placed
	# by _seed_pulsars, against the clouds, once positions exist.
	#
	# The other weights are left exactly as they were, so removing pulsars from
	# the draw did not quietly change the mix of fights, stations, events and
	# wrecks along with it.
	var weights := [
		NodeType.SYSTEM, NodeType.SYSTEM, NodeType.SYSTEM, NodeType.SYSTEM,
		NodeType.SYSTEM, NodeType.SYSTEM, NodeType.SYSTEM, NodeType.SYSTEM,
		NodeType.SYSTEM, NodeType.SYSTEM, NodeType.SYSTEM, NodeType.SYSTEM,
		NodeType.SYSTEM, NodeType.SYSTEM, NodeType.SYSTEM, NodeType.SYSTEM,
		NodeType.STATION, NodeType.STATION, NodeType.STATION, NodeType.STATION,
		NodeType.STATION, NodeType.STATION, NodeType.STATION, NodeType.STATION,
		NodeType.SYSTEM, NodeType.SYSTEM, NodeType.SYSTEM, NodeType.SYSTEM,
		NodeType.SYSTEM, NodeType.SYSTEM, NodeType.SYSTEM, NodeType.SYSTEM,
		NodeType.SYSTEM, NodeType.SYSTEM, NodeType.SYSTEM, NodeType.SYSTEM,
	]
	return Rng.pick(Rng.world, weights)

static func _layout(nodes: Array, canvas: Rect2) -> void:
	for n in nodes:
		var nn: MapNode = n
		var fx := float(nn.layer) / float(LAYERS - 1)
		nn.pos.x = canvas.position.x + fx * canvas.size.x
		if nn.rows_in_layer == 1:
			nn.pos.y = canvas.position.y + canvas.size.y * 0.5
		else:
			var fy := (float(nn.row) + 0.5) / float(nn.rows_in_layer)
			nn.pos.y = canvas.position.y + fy * canvas.size.y

static func _link(nodes: Array) -> void:
	for layer in LAYERS - 1:
		var here: Array = nodes.filter(func(n): return n.layer == layer)
		var next: Array = nodes.filter(func(n): return n.layer == layer + 1)
		# Coreward links go to whatever is actually nearest, not to whatever
		# shares a row index. Rings hold different numbers of systems and are
		# rotated and jittered against each other, so matching by index drew
		# routes that crossed other routes and skipped the neighbour in front.
		# NOT EVERY SYSTEM HAS A WAY INWARD. This used to connect unconditionally,
		# so the shortest path to the core was one hop per ring and nothing could
		# make it longer -- measured at exactly 14 in all 120 galaxies `--
		# maptest` rolls, with no variance at all.
		#
		# Rolled from `Rng.world` so it is POSITIONAL: the galaxy is a property
		# of the seed, and four machines in a co-op session must agree about
		# which systems have doors. A roll off any other stream would give each
		# peer its own map.
		var doors := 0
		for i in here.size():
			var n: MapNode = here[i]
			var ranked := _by_distance(n, next)
			if Rng.world.randf() >= DOOR_SHARE:
				continue
			_connect(n, ranked[0])
			doors += 1
			# A second route, but only if it is not much further than the first:
			# the point is a choice between comparable options, not a detour.
			if ranked.size() > 1 and Rng.world.randf() < 0.62:
				var d0 := hop_distance(n, ranked[0])
				var d1 := hop_distance(n, ranked[1])
				if d1 < d0 * 1.8:
					_connect(n, ranked[1])

		# THE RING NEEDS DOORS. Each SYSTEM IN IT DOES NOT.
		#
		# This used to guarantee that every forward system had an incoming link,
		# which orphaned nothing and also made thinning impossible: it restored
		# roughly one door per forward system, so doors per ring sat near 15
		# whether DOOR_SHARE was 0.55 or 0.15, and the forced path stayed at 14.
		#
		# It is safe to relax because the lateral pass below builds a COMPLETE
		# CYCLE inside every ring -- every adjacent row pair, plus the closure
		# from last row to first -- so arriving anywhere in a ring means being
		# able to walk to everywhere in it. A ring with MIN_DOORS ways in is a
		# ring with every system reachable.
		#
		# What it costs is that arriving no longer means arriving where you want
		# to be, which is the entire point of the phase.
		while doors < MIN_DOORS and doors < here.size():
			var spare: Array = here.filter(func(x): return not _descends(x, next))
			if spare.is_empty():
				break
			var extra: MapNode = spare[Rng.world.randi() % spare.size()]
			_connect(extra, _by_distance(extra, next)[0])
			doors += 1
		# LATERAL LINKS GO TO ACTUAL NEIGHBOURS. This used to connect systems
		# whose ROW INDEX differed by one, plus a closure from the first row to
		# the last, on the assumption that row order tracks position around the
		# ring. It does not: a stranded ship probed here had lateral links of
		# length 1.60 and 1.09 on a disc of radius 0.92 -- straight across the
		# galaxy.
		#
		# That was survivable only because every system also had a short forward
		# link, so `can_jump_to` filtered the long ones out and nobody noticed.
		# With sparse doors a system can have nothing BUT those links, and then
		# it strands on a full tank. Two nearest neighbours each still walks the
		# whole ring, which is what the row version was reaching for.
		# BY ANGLE AROUND THE RING, which is the only construction that closes.
		#
		# Two earlier versions did not. Connecting by ROW INDEX assumed row order
		# tracks position, and it does not -- a stranded ship probed here had
		# lateral links of length 1.60 on a disc of radius 0.92, straight across
		# the galaxy. Connecting each system to its two NEAREST neighbours makes
		# short links but not necessarily one cycle: it can settle into separate
		# clusters, and `-- maptest` found 6 galaxies in 120 where the core was
		# unreachable because of it.
		#
		# Sorting by angle and joining consecutive systems gives exactly one
		# cycle, every link short, every system reachable from every other. The
		# angle is taken from the drawn position, and the foreshortening does not
		# matter: scaling y by a positive constant preserves the ORDER of points
		# around a circle even though it changes the angles themselves.
		var ring: Array = here.duplicate()
		ring.sort_custom(func(x, y) -> bool:
			return atan2((x as MapNode).gal.y, (x as MapNode).gal.x) 				< atan2((y as MapNode).gal.y, (y as MapNode).gal.x))
		for i in ring.size():
			if ring.size() < 2:
				break
			_connect(ring[i], ring[(i + 1) % ring.size()])

## Does this system already carry a link into the next ring?
static func _descends(n: MapNode, next: Array) -> bool:
	for t in next:
		if n.links.has((t as MapNode).index):
			return true
	return false


## Candidates sorted by how far they are from `from`, nearest first.
static func _by_distance(from: MapNode, pool: Array) -> Array:
	var out := pool.duplicate()
	out.sort_custom(func(x, y):
		return hop_distance(from, x) < hop_distance(from, y))
	return out

static func _connect(a: MapNode, b: MapNode) -> void:
	if not a.links.has(b.index):
		a.links.append(b.index)
	if not b.links.has(a.index):
		b.links.append(a.index)
