extends Node

## FIRST-RUN HINTS, so a friend playing alone is not lost (alpha; scratchpad
## `alpha/onboarding.md`). There is NO TOUR (tutorial direction B, "learn by
## doing", Jon Oct 17): the controls are yours when the ship stops, the goal and
## the next step sit under the HUD (`GoalLine`), and each of these teaches one
## thing at the moment it first matters, never as a wall:
##
##   chart    the chart's in-range list, and its two bars (danger, fuel)
##   events   the sector map's events: click one to read it, GO flies you there
##   drawer   the event band's choices, and the odds printed on them
##   hand     a fight's hand: drag a card onto an enemy; the cost corner
##   intent   after your first card: the words over an enemy are its next move
##   endturn  nothing left to play: END TURN, and what it does
##   brace    brace held over an end of turn: it stays up, and costs heat
##   heat     heat has risen: the cap, and the hull it burns past it
##   salvage  a wreck's window: drag a part into your hold, or double-click it
##   cutaway  inside your ship: drag parts onto rings, R turns, F flips
##   wreck    a wreck is clicked to loot it
##   loot     SECTOR LOOT, beside SCAN SECTOR
##   dock     the first station: what it does, and its decks
##   shipyard, promenade, exchange, hiring_board, laboratory
##            the first time each deck is open: what it is for and the one
##            thing to do there, on its main thing (`DECK_HINTS`)
##   fuel     a third of the tank left: running dry ends the run, and the
##            nearest dock in reach by name (or what to do with none)
##   ship     click your ship (LOCAL or the shipyard) to open it up
##
## THE DEEP TUTORIAL (Jon, Oct 22: "Tutorial: scope:all voice:record bugs:fix",
## after Kevin's playtest: he clicked the tutorial away and did not know the
## energy meter or when to loot a dead ship). The audit's 35 rows, each a
## lesson with its trigger, subject, end and pacing (`docs/ash.md`):
##
##   in a fight   energy (after the first card), heat_corner, keywords,
##                discard_pick, malfunction, flee_hail, piles; intent moved to
##                the start of turn 2; heat, brace and intent end on their
##                action (a card or END TURN), not on a reading time
##   the band     odds (a choice with a check), result (REWARD, CONTINUE)
##   LOCAL        hull; the wreck, salvage and loot lines say more
##   the map      fuel_first (the first arrival), map_fly (flying by hand)
##   the chart    layers, contract_track, quest, jump_blocked
##   the cutaway  mounts, cards_from_parts, attributes (the flip key dropped)
##   the station  faults, hull_sale, undock
##   the menu     save (over the escape menu: the one lesson said there)
##   the title    chassis_card (a card only: she has not introduced herself)
##
## PACING (the audit's, binding). One lesson at a time; each starts only when its
## screen has held still (SETTLE_S) and ends when the player does what it
## teaches. IN A FIGHT (`_pace_ok`) a lesson starts only while the hand is
## settled and no card is held; only the hand's, energy, discard_pick and END
## TURN's start after a card this turn (`MID_TURN`), the rest at a turn's start.
## Turn 1 of the first fight teaches the hand, energy and END TURN alone
## (`TURN_ONE`); flee_hail, malfunction and piles are one a fight
## (`ONE_A_FIGHT`), piles not in the first. OUTSIDE A FIGHT the gap after a
## lesson is GAP_S (3 s; 1.2 in a fight, `GAP_FIGHT_S`), and a screen as it
## stands (`_front`: the screen, its station deck, an open cutaway, window or
## event) teaches one new lesson, but for the chains (`CHAINS`). The goal
## steps still yield to lessons.
##
## ONE AT A TIME, a `HintCard` beside its subject. Its subject has to hold still
## for SETTLE_S first, so nothing shows mid-transition.
##
## A CLICK NEVER DISMISSES ONE (Jon, Oct 22, after the first outside playtest:
## "Kevin also clicked away the tutorial and subsequently had no idea what he
## was doing. Can we soft lock the screen so A.S.H. can't be dismissed?"). It
## used to go on any click (his earlier "let's have them advance with a click").
## Now each stays until the player has DONE what it teaches (`_done`, the table
## at `DONE`): the chart's until a star is picked or a jump made, the hand's
## until a card is played, END TURN's until it is pressed, and so on. The few
## that only tell you something (`INFO`: the intent, brace, heat, fuel) stay for
## their reading time after her voice ends and go by themselves, spent. If its
## subject goes first, it hides unspent and shows again the next time (but the
## six Jon ruled are said once, `SPENT_ONCE_HEARD`). NEVER STUCK: one that has
## been said whole and stood YIELD_S while another line is waiting here (a hint,
## or a goal step) gives way unspent and rests REST_S, so no line holds the goal
## or another hint for good; a line whose action cannot be done here has no
## subject (`probe`) and hides. Seen is per hint in
## settings.cfg `[hints] <id>` (`DisplaySettings.hints_path`), beside the welcome
## note's and the goal line's steps. Under a harness that is the harness
## settings file, never the player's. Settings' REPLAY TUTORIAL (`reset`) brings
## all of them back, and the goal line's steps.
##
## TUTORIAL ON / OFF (Jon, Oct 20: "Have a setting in the options for tutorial
## on or tutorial off"): Settings' TUTORIAL row, `[hints] tutorial` in the
## settings file, on by default (`set_tutorial`). Off: no hint, no goal step and
## nothing of A.S.H.'s teaching; the goal line's GOAL stays, and her introduction
## and her other lines are hers, not the tutorial's. Turned off mid-run, what is
## up goes at once, unspent; turned on, the hints pick up where the player is
## (what was seen stays seen; REPLAY TUTORIAL works either way).
##
## OFF UNDER HARNESSES (`TestRun.active`) unless the run asks with `-- hints`;
## `-- hinttest` turns it on by hand (`forced`). OFF IN A PARTY too (Jon, Oct 17:
## "coop:B"): a networked run shows no hints and no goal-line steps. They still
## show on a seeded solo run. Not off under reduced motion: those players need
## hints too; only the fade goes.
##
## It finds its subjects by looking at the screens as they are each frame, so no
## screen has to call it.
##
## A.S.H. SAYS THEM (Jon picked how A for the tutorial, Oct 17: "A.S.H. replaces
## the hint cards"). While she is on (`Ash.teaches`), a hint that is due is said
## in her corner in her words (`AshTutorLines`) with its subject outlined,
## instead of a card: the same trigger, the same order, the same subject, the
## same action to spend it, the same hiding unspent when the subject goes. Where
## she has nowhere clear to stand it is the card after all, so a lesson never
## waits for room. With her off, the cards, exactly as before. She also says
## each goal step (`GoalLine`) once as it starts (`said_<step>`), after any hint
## due on that screen; the goal line itself does not change. All of it is off in
## a party with the hints (`enabled`).
##
## SHE NEVER SAYS THE SAME LINE ALOUD TWICE (Jeremy, a playtester, Oct 23: "it
## doesn't need to repeat everything when I jump out of a menu after it has
## already said it"; Jon's log of 0.4.1-alpha.1 had the hull's line five times,
## heat's four times in one fight, the ship for sale's and SAVE & EXIT's twice).
## The come-back rules above (a line left unspent shows again, a line that gave
## way returns) said the whole line again each time, in her voice. Now a line
## she has said whole is HEARD (`heard_<line>` beside `seen`, cleared by REPLAY
## TUTORIAL), and if it is still unspent because its action has not been done it
## comes back QUIETLY: her box with the words already out, no chirp, no voice
## (`AshPortrait`'s quiet), held as before until its action. A line cut off while
## she was saying it may be said aloud once more, on a later visit or fight
## (`_visit`), never on the one it was cut on; after that it is text only too. An
## information line (`INFO`) is spent as it shows: said once, ever. The lines
## stay undismissable: a quiet line still ends only by its action.

const SECTION := "hints"
## Highest first: when two could show, this one does.
const ORDER: Array[StringName] = [&"hand", &"energy", &"discard_pick", &"endturn", &"intent",
	&"heat_corner", &"heat", &"brace", &"keywords", &"malfunction", &"flee_hail", &"piles",
	&"drawer", &"odds", &"result", &"fuel_first", &"events", &"map_fly", &"chart", &"jump_blocked",
	&"layers", &"contract_track", &"quest", &"salvage", &"cutaway", &"mounts", &"cards_from_parts",
	&"attributes", &"wreck", &"loot", &"hull", &"dock", &"shipyard", &"faults", &"hull_sale",
	&"promenade", &"exchange", &"hiring_board", &"laboratory", &"undock", &"fuel", &"ship", &"save",
	&"chassis_card"]
## THE FIGHT'S LESSONS, paced by the turn (`_pace_ok`).
const FIGHT: Array[StringName] = [&"hand", &"energy", &"discard_pick", &"endturn", &"intent",
	&"heat_corner", &"heat", &"brace", &"keywords", &"malfunction", &"flee_hail", &"piles"]
## The only ones turn 1 of the first fight teaches (the audit: "Turn 1: hand,
## energy, endturn"; a discard asked for is a thing to do now).
const TURN_ONE: Array[StringName] = [&"hand", &"energy", &"endturn", &"discard_pick"]
## The only ones that start after a card this turn: the rest wait for a turn's
## start, so nothing new comes up between two cards.
const MID_TURN: Array[StringName] = [&"hand", &"energy", &"endturn", &"discard_pick"]
## One of these a fight, at most.
const ONE_A_FIGHT: Array[StringName] = [&"malfunction", &"flee_hail", &"piles"]
## A screen as it stands teaches one new lesson; a chain's next follows it there.
const CHAINS: Array = [[&"wreck", &"salvage", &"loot"], [&"shipyard", &"ship", &"cutaway", &"mounts", &"cards_from_parts"],
	[&"drawer", &"odds", &"result"], [&"fuel_first", &"events"], [&"chart", &"jump_blocked"],
	[&"layers", &"jump_blocked"]]
## A CARD ONLY: the chassis select, before her introduction.
const CARD_ONLY: Array[StringName] = [&"chassis_card"]
## THE DEEP TUTORIAL'S NEW LESSONS (Oct 22), for the harnesses that hold the
## first set alone (`-- hinttest` parks these).
const DEEP: Array[StringName] = [&"energy", &"discard_pick", &"heat_corner", &"keywords",
	&"malfunction", &"flee_hail", &"piles", &"odds", &"result", &"fuel_first", &"map_fly", &"layers",
	&"contract_track", &"quest", &"jump_blocked", &"mounts", &"cards_from_parts", &"attributes",
	&"hull", &"faults", &"hull_sale", &"undock", &"save", &"chassis_card"]
## ONE HINT A DECK, the first time it is open (Jon, Oct 20, playing the alpha:
## "There is no tutorial tip for the promenade, exchange, shipyard, laboratory,
## or hiring board"): hint id -> the station's page (`StationScreen.DECKS`). Each
## points at the deck's main thing (`StationScreen.deck_subject`): the yard's
## drones, the shelf, the sell counter, the notes on the board, the fabricator's
## screen. After `dock`, which still comes first on arrival.
const DECK_HINTS := {&"shipyard": &"services", &"promenade": &"stock", &"exchange": &"hold",
	&"hiring_board": &"work", &"laboratory": &"bench"}
## The goal line's steps (`GoalLine`), done once: kept beside the hints, and
## cleared with them.
const STEPS: Array[StringName] = [&"step_jump", &"step_event"]
## The lines A.S.H. says as a goal step starts, each once (`said_<id>`), cleared
## with the hints.
const STEP_LINES: Array[StringName] = [&"step_jump", &"step_jump_chart", &"step_event", &"step_event_map"]
## SAID ONCE, HEARD WHOLE (Jon, Oct 20: "when I enter the ship editor, A.S.H.
## keeps saying the tutorial line every time I enter. It should only be the
## first time"; the decks' the same day: people leave a deck by clicking another).
## Each still stays up until its action (`DONE`), but leaving its screen after
## she has said it whole spends it too, so it is said once however the player
## goes. Left while she is still saying it, it is unspent and comes again. (They
## were spent as they showed while a click was what spent the rest.) A card is
## read whole as it shows. SHOW HINTS AGAIN brings them back.
const SPENT_ONCE_HEARD: Array[StringName] = [&"cutaway", &"shipyard", &"promenade", &"exchange",
	&"hiring_board", &"laboratory", &"energy", &"hull", &"map_fly", &"layers", &"contract_track", &"mounts",
	&"quest", &"jump_blocked", &"cards_from_parts", &"attributes", &"faults", &"hull_sale", &"undock",
	&"chassis_card"]
## THE LINES THAT ONLY TELL YOU SOMETHING: no action to wait for, so each stays
## its reading time after her voice ends (`AshPortrait`'s own hold) and goes by
## itself; as a card, `info_s`. Spent as it shows (Oct 23): said once, ever,
## however it goes.
const INFO: Array[StringName] = [&"fuel", &"fuel_first"]
## EVERY OTHER HINT'S ACTION, what spends it (`_done`; `-- sheet=AshTutorTest`
## holds every hint in ORDER to being in one of these two lists):
const DONE := {
	&"chart": "a star picked on the chart, or a jump made",
	&"events": "an event opened from the map's list (its page, or GO)",
	&"drawer": "a choice taken in the event band, or NOT NOW",
	&"odds": "a choice taken in the event band, or NOT NOW",
	&"result": "REWARD opened, or CONTINUE pressed",
	&"hand": "a card played",
	&"energy": "the next card played, or END TURN pressed",
	&"discard_pick": "a card picked from the hand",
	&"endturn": "END TURN pressed",
	&"intent": "a card played, or END TURN pressed",
	&"heat_corner": "a card played, or END TURN pressed",
	&"heat": "END TURN pressed",
	&"brace": "END TURN pressed",
	&"keywords": "a card's readout opened (the pointer rested on a card)",
	&"malfunction": "the malfunction played (purged), or END TURN pressed",
	&"flee_hail": "a card played, END TURN, FLEE or HAIL pressed",
	&"piles": "a card played, or END TURN pressed",
	&"map_fly": "the ship flown: a key held, or a world flown to",
	&"layers": "a star picked on the chart",
	&"contract_track": "a star picked on the chart; or said whole and the chart left",
	&"quest": "a star picked on the chart",
	&"jump_blocked": "another star picked",
	&"mounts": "the part put down; or said whole and the cutaway left",
	&"cards_from_parts": "a part pointed at; or said whole and the cutaway left",
	&"attributes": "a module moved; or said whole and the cutaway left",
	&"hull": "said whole and the screen left",
	&"faults": "the FAULTS drone clicked; or said whole and the deck left",
	&"hull_sale": "the ship taken; or said whole and the deck left",
	&"undock": "UNDOCK pressed or another deck picked",
	&"save": "the escape menu shut, or SAVE & EXIT (or ABANDON) pressed: its question up",
	&"chassis_card": "LAUNCH pressed",
	&"salvage": "a part or a chit taken aboard from the window",
	&"cutaway": "a module moved: installed, removed or moved on the ship",
	&"wreck": "a wreck opened",
	&"loot": "SECTOR LOOT pressed: the pile's window open",
	&"dock": "a deck picked on the left",
	&"shipyard": "the yard used: a drone's job paid, or a hull taken",
	&"promenade": "a part bought",
	&"exchange": "a part sold",
	&"hiring_board": "a job signed",
	&"laboratory": "something made at the fabricator",
	&"ship": "your ship opened up",
}
## How long a subject must hold before its hint shows, s.
const SETTLE_S := 0.6
## Quiet after one hint before the next may show, s: outside a fight (raised from
## 1.2 by the deep tutorial's pacing), and in one.
const GAP_S := 3.0
const GAP_FIGHT_S := 1.2
## NEVER STUCK: a line said whole and up this long while another line is waiting
## here gives way to it, unspent, s; and rests this long before it may come
## again, so the one waiting goes first, s (the hints' own clock).
const YIELD_S := 20.0
const REST_S := 45.0
## SOFT LOCK, option (b) of Jon's "soft lock the screen" (Oct 22): while she is
## SPEAKING a hint's line (not after), a click anywhere but the thing she points
## at does nothing (`ClickGate`). Off: blocking the game reads as a bug, and the
## player must be free to do the step; on to try it. `soft_lock` is the live
## switch (a harness flips it).
const SOFT_LOCK := false
var soft_lock := SOFT_LOCK

## On for a harness that drives it by hand (`-- hinttest`).
var forced := false
## The hint on screen, if any.
var card: HintCard = null
## The hint A.S.H. is saying instead of a card, if any (`Ash.teach`).
var lesson: StringName = &""
## The goal step's line she is saying, if any.
var step_up: StringName = &""
## The hints that came as a card although she was on: nowhere clear for her.
var fallback_log: Array[StringName] = []
## Every hint that has shown since launch, in order (for the harnesses).
var shown_log: Array[StringName] = []

var _seen := {}
var _loaded := false
var _cand: StringName = &""
var _cand_t := 0.0
var _up_t := 0.0
var _gone_t := 0.0
var _quiet := 0.0
## The fight a card has been played in (`Sig.card_played`): the intent hint's
## "after the first card".
var _played_in: Combat = null
var _step_cand: StringName = &""
var _step_t := 0.0
## The hints' own clock (the deltas `poll` is given), s.
var _clock := 0.0
## WHAT IS UP: the line id she says for it (`AshTutorLines.line_id`), the state
## its action is measured from (`_snapshot`), whether it has been said whole and
## when (her words all out; a card as it shows), and the last look at whether
## another line is waiting (`_waiting_other`).
var _lesson_lid: StringName = &""
var _base := {}
var _said := false
var _said_at := 0.0
var _wait_look := 0.0
## Hints that gave way to another line: id -> the clock they rest until.
var _rest := {}
## Counted off the game's own signal, for the hand's action: cards played.
var _cards_played := 0
## FIGHT PACING: the fight and turn the count below is for, cards played this
## turn, fights seen since launch, the fight the hand was taught in (its turn 1
## is the hand's, energy's and END TURN's), and the fight one of `ONE_A_FIGHT`
## was taught in.
var _turn_of: Array = []
var _turn_cards := 0
var _fights_seen := 0
var _last_fight: Object = null
var _first_fight: Object = null
var _extra_fight: Object = null
## A SCREEN AS IT STANDS (`_front`) and the lesson last taught there.
var _front_key := ""
var _front_last: StringName = &""
## The chart the chart's own line was taught on (layers waits for another).
var _chart_taught_on := 0
## The cutaway first seen open since launch, and the fit it opened on
## (cards_from_parts waits for a part fitted since).
var _cut_seen := 0
var _cut_fit: Array = []
## The soft lock's gate, while one is up (`soft_lock`).
var _gate: ClickGate = null
## SAID ALOUD ONCE: line id -> the times she started saying it aloud and was cut
## off before the end, and the visit (`_visit_n`) of the last of those. Heard
## whole is `heard()`, kept in the hints file.
var _tries := {}
var _tried_in := {}
## A VISIT, for "never again on the same one": the screen as it stands
## (`_visit_key`, `_front` without the escape menu, and the fight), counted.
var _visit_key := ""
var _visit_n := 0
## The line up came back quietly (no voice: heard, or cut off once already), and
## the visit it was shown on.
var _lesson_quiet := false
var _lesson_visit := 0


func _ready() -> void:
	Sig.card_played.connect(func(_c: CardData) -> void:
		_played_in = Router.combat
		_cards_played += 1
		_sync_turn(Router.combat)
		_turn_cards += 1)


## The two lines of each hint. Graded with `tools/prose_grade.py` (grade 7.0 or
## under, ruled 2026-10-13; the ones added Oct 17 are held to 5.2). The
## cutaway's names the keys as bound; the heat and END TURN ones read the live
## cap and hand size, never a number written here.
func lines(id: StringName) -> Array:
	match id:
		&"chart":
			return ["Stars you can reach are listed here.", "Left bar is danger. Right bar is fuel."]
		&"events":
			return ["Click an event to read it.", "GO flies you to it."]
		&"drawer":
			return ["Pick what to do. Some choices show your odds.", "NOT NOW saves it for later."]
		&"hand":
			return ["Drag a card onto an enemy to fire it.", "Cards that help you go on your own ship."]
		&"energy":
			return ["That card cost energy. This box counts what you have left.", "It fills back up every turn."]
		&"discard_pick":
			return ["That card wants a discard.", "Click a card in your hand to discard it."]
		&"heat_corner":
			return ["Top right is heat: playing it adds that much.", "A green minus cools you down."]
		&"keywords":
			return ["Underlined words have rules.", "Rest the pointer on a card to read them."]
		&"malfunction":
			return ["A malfunction. Play it to clear it for this fight.", "A shipyard clears it for good."]
		&"flee_hail":
			return ["FLEE and HAIL end a fight early.", "Each is a check, and a miss costs you."]
		&"piles":
			return ["Played cards go to the discard.", "When the draw pile runs out, they shuffle back in."]
		&"odds":
			return ["This choice tests your ship.", "Meet the number and it cannot fail."]
		&"result":
			return ["What it cost and what you got.", "REWARD opens what you found. Then CONTINUE."]
		&"fuel_first":
			return ["Each jump burns fuel. Run dry and the run ends.", "Stations sell more."]
		&"hull":
			return ["Your hull. At zero, the ship is lost.", "A shipyard can patch it."]
		&"map_fly":
			return ["Click a world twice to fly there.", "%s pushes. %s and %s turn." % [Keys.describe(&"ship_thrust"),
				Keys.describe(&"ship_left"), Keys.describe(&"ship_right")]]
		&"layers":
			return ["This strip is how deep you are.", "Deeper means more danger and better pay."]
		&"contract_track":
			return ["The ring on the chart is the job. Do it there.", "Then press DELIVER at any of their docks."]
		&"quest":
			return ["Something is marked on the chart now.", "Fly there to follow it up."]
		&"jump_blocked":
			return ["You cannot jump there yet.", "The button says why."]
		&"mounts":
			return ["Each slot takes one kind of part.", "The slots that light up will take this one."]
		&"cards_from_parts":
			return ["Every part brings its own cards to the deck.", "Point at a part to see them."]
		&"attributes":
			return ["These are your ship's stats.", "Event checks test them. Parts move them."]
		&"faults":
			return ["FAULTS clears a malfunction from your deck.", "Each one costs credits."]
		&"hull_sale":
			return ["That ship is for sale. TAKE IT trades yours in.", "It comes empty, so move everything over."]
		&"undock":
			return ["UNDOCK takes you back out.", "Press it when you are done here."]
		&"save":
			return ["SAVE & EXIT keeps the run.", "CONTINUE on the title picks it back up."]
		&"chassis_card":
			return ["Pick a ship, then press LAUNCH.", "Point at a line or a card to read more."]
		&"intent":
			return ["This is what it will do", "when you press END TURN."]
		&"endturn":
			return ["Out of energy. Press END TURN.",
				"They act, then you draw %d new cards." % _hand_size()]
		&"brace":
			return ["Brace stops damage until it is used up.", "Holding it costs 1 heat a turn."]
		&"heat":
			return ["Heat. Past %d you lose 1 hull" % _heat_cap(), "for each point over, at end of turn."]
		&"salvage":
			return ["Drag parts into your hold, or double-click them.", "What you leave stays. DONE closes it."]
		&"cutaway":
			# (her words, Jon's of Oct 20, "merge:A": the card says what she says)
			return ["Drag a module onto an empty slot to install it.",
				"Drag it off the ship into the hold to remove it.",
				"%s turns it." % Keys.describe(&"hold_turn")]
		&"wreck":
			return ["Click a wreck to see what you can take.", "It stays here if you leave."]
		&"loot":
			return ["SECTOR LOOT is everything loose here.", "It waits for you. Click it to look."]
		&"dock":
			# ON THE LEFT, not "at the top" as the brief had it: the decks are the
			# station's section, a column down the left side (`StationScreen.DECKS`)
			return ["Stations repair, refuel and trade.", "Pick a deck on the left."]
		# THE DECKS' (drafts, Oct 20: Jon picks the words)
		&"shipyard":
			return ["The drones over your ship repair and refuel it.", "Click one to pay for its job."]
		&"promenade":
			return ["Buy parts here. Point at one to read it.", "Drag it to the till to buy it."]
		&"exchange":
			return ["Sell what you carry here.", "Drag a part from your hold to the counter."]
		&"hiring_board":
			return ["Manufacturers post paid work here.", "Press SIGN on a note to take the job."]
		&"laboratory":
			return ["The fabricator turns a relic into a part.", "Press MAKE when you can pay for it."]
		&"fuel":
			return ["Fuel is low. Run dry and the run ends.", fuel_dock_line()]
		&"ship":
			return ["Click your ship to open it up.", "Fit and swap parts there."]
	return []


## `Run.nearest_dock`, worked out once per place and tank: the chart's probe
## asks every frame the card is up.
var _dock_key := Vector2i(-1, -1)
var _dock := {}

func _dock_cached() -> Dictionary:
	var k := Vector2i(Run.at, Run.fuel)
	if k != _dock_key:
		_dock_key = k
		_dock = Run.nearest_dock()
	return _dock


## WHERE TO GET FUEL, named (Jon: "warn:A"): the nearest dock the tank can
## still reach, by its name on the chart and the jumps to it; with none in
## reach, what to do instead. Read when the card shows, never a stale name.
func fuel_dock_line() -> String:
	var d := _dock_cached()
	if d.is_empty():
		return "No dock in reach. Make short jumps and look for one."
	var j := int(d.jumps)
	if j == 0:
		# (a dock in this system: here only at the station itself, dock:A)
		return "Refuel here before you leave." if Router.at_station() else "Fly to the station here to refuel."
	return "Nearest dock: %s, %d jump%s." % [MapGen.star_name(d.node), j, "" if j == 1 else "s"]


## THE LIVE VALUES her lines' fields are filled from (`AshTutorLines.fill`):
## the hand, the heat cap, the dock in reach and the jumps to it, the keys.
func values(id: StringName = &"") -> Dictionary:
	var out := {hand = _hand_size(), cap = _heat_cap(),
		turn = Keys.describe(&"hold_turn"), flip = Keys.describe(&"part_flip"),
		thrust = Keys.describe(&"ship_thrust"), left = Keys.describe(&"ship_left"),
		right = Keys.describe(&"ship_right")}
	if id == &"fuel" and _fuel_low():
		var d := _dock_cached()
		if not d.is_empty():
			out["jumps"] = int(d.jumps)
			out["name"] = MapGen.star_name(d.node)
	return out


## Whether she says the hints (her switch, a harness that asked); else cards.
func by_ash() -> bool:
	return Ash.teaches()


## Whether hint `id` is said by her now: a card-only one never is.
func _ash_for(id: StringName) -> bool:
	return by_ash() and not CARD_ONLY.has(id)


func _hand_size() -> int:
	return Run.hand_size() if Run.hull != null else 5


func _heat_cap() -> int:
	return Run.heat_cap() if Run.hull != null else 0


func enabled() -> bool:
	# (a party first: not even a harness that forces the hints on gets them
	# there, so `-- sheet=AshTutorTest` can hold her teaching to it)
	if Net.is_networked():
		return false
	# (and the player's TUTORIAL OFF, over a harness's forcing too, so the
	# harnesses can hold the switch to it)
	if not tutorial_on():
		return false
	if forced:
		return true
	return "hints" in OS.get_cmdline_user_args() or not TestRun.active()


# ------------------------------------------------------------------ seen

func store_path() -> String:
	return DisplaySettings.hints_path()


## THE TUTORIAL SWITCH (Settings' TUTORIAL), read once: `[hints] tutorial` in the
## settings file (`DisplaySettings.path`, the harness's scratch file under one).
const TUTORIAL_KEY := "tutorial"
var _tutorial := true
var _tutorial_read := false


func tutorial_on() -> bool:
	if not _tutorial_read:
		var cfg := ConfigFile.new()
		_tutorial = true
		if cfg.load(DisplaySettings.path) == OK:
			_tutorial = bool(cfg.get_value(SECTION, TUTORIAL_KEY, true))
		_tutorial_read = true
	return _tutorial


## On or off, kept in the settings file. Off takes down at once, unspent, a
## card, her teaching line and a goal step's line that are up.
func set_tutorial(v: bool) -> void:
	_tutorial = v
	_tutorial_read = true
	var cfg := ConfigFile.new()
	cfg.load(DisplaySettings.path)
	cfg.set_value(SECTION, TUTORIAL_KEY, v)
	cfg.save(DisplaySettings.path)
	if not v:
		_close(false)
		_close_lesson(false)
		_end_step()
		_cand = &""
		_step_cand = &""
		_rest.clear()
	_quiet = 0.0


func _load() -> void:
	_seen.clear()
	var cfg := ConfigFile.new()
	if cfg.load(store_path()) == OK:
		for id in ORDER + STEPS:
			_seen[id] = bool(cfg.get_value(SECTION, String(id), false))
		for id in STEP_LINES:
			_seen[_said_key(id)] = bool(cfg.get_value(SECTION, String(_said_key(id)), false))
		for lid in AshTutorLines.all_ids():
			_seen[_heard_key(lid)] = bool(cfg.get_value(SECTION, String(_heard_key(lid)), false))
	_loaded = true


func seen(id: StringName) -> bool:
	if not _loaded:
		_load()
	return bool(_seen.get(id, false))


func mark_seen(id: StringName, v: bool = true) -> void:
	var cfg := ConfigFile.new()
	cfg.load(store_path())
	cfg.set_value(SECTION, String(id), v)
	cfg.save(store_path())
	if not _loaded:
		_load()
	_seen[id] = v


## Whether A.S.H. has said goal step `id`'s line (`STEP_LINES`).
func said(id: StringName) -> bool:
	return seen(_said_key(id))


func _said_key(id: StringName) -> StringName:
	return StringName("said_" + String(id))


## Whether she has said teaching line `lid` (`AshTutorLines`) aloud to its end,
## ever (until REPLAY TUTORIAL). Then it is never said aloud again.
func heard(lid: StringName) -> bool:
	return seen(_heard_key(lid))


func _heard_key(lid: StringName) -> StringName:
	return StringName("heard_" + String(lid))


## Whether line `lid` may be said in her voice now: never once heard whole; once
## more after she was cut off saying it, but not on the visit (or fight) it was
## cut on; never after two.
func may_say_aloud(lid: StringName) -> bool:
	if heard(lid):
		return false
	var n := int(_tries.get(lid, 0))
	return n == 0 or (n == 1 and int(_tried_in.get(lid, -1)) != _visit_n)


## FOR THE HARNESSES that set a line up again to hear it again (as REPLAY
## TUTORIAL does for all of them): line `lid` unheard and never cut off.
func forget_heard(lid: StringName) -> void:
	mark_seen(_heard_key(lid), false)
	_tries.erase(lid)
	_tried_in.erase(lid)


## REPLAY TUTORIAL: every hint and the goal line's steps, unseen, her steps'
## lines unsaid, and every line of hers unheard.
func reset() -> void:
	var cfg := ConfigFile.new()
	cfg.load(store_path())
	for id in ORDER + STEPS:
		cfg.set_value(SECTION, String(id), false)
	for id in STEP_LINES:
		cfg.set_value(SECTION, String(_said_key(id)), false)
	for lid in AshTutorLines.all_ids():
		cfg.set_value(SECTION, String(_heard_key(lid)), false)
	cfg.save(store_path())
	_tries.clear()
	_tried_in.clear()
	_load()
	_close(false)
	_close_lesson(false)
	_end_step()
	_quiet = 0.0
	_cand = &""
	_step_cand = &""
	_rest.clear()


## Re-read the file (a harness that wrote it behind our back).
func reload() -> void:
	_load()
	_tutorial_read = false


# ------------------------------------------------------------------ the clock

func _process(delta: float) -> void:
	poll(delta)


## One step: keep the card on its subject, or look for the next hint. Public so
## `-- hinttest` can step it on its own clock.
func poll(delta: float) -> void:
	_clock += delta
	if not enabled():
		if card != null:
			_close(false)
		if lesson != &"":
			_close_lesson(false)
		_end_step()
		_gate_to(false)
		return
	_quiet = maxf(0.0, _quiet - delta)
	# A NEW VISIT (or fight): what "never on the same one" counts in
	var vk := _visit()
	if vk != _visit_key:
		_visit_key = vk
		_visit_n += 1
	# HER LESSON: kept on its subject until the player has done what it teaches
	# (`_done`), never by a click
	if lesson != &"":
		_up_t += delta
		_poll_lesson(delta)
		_gate_to(lesson != &"" and soft_lock and Ash.lesson_speaking())
		return
	_gate_to(false)
	# a goal step's line up: the hints wait for it
	if step_up != &"":
		if Ash.lesson_up() and Ash.lesson == step_up:
			return
		step_up = &""
	if card != null:
		if not is_instance_valid(card):
			card = null
		else:
			_up_t += delta
			_poll_card(delta)
			return
	# HER INTRODUCTION FIRST (Jon, Oct 18, "intro:A"): up, or next and able to
	# start, no hint or step starts and none cuts it; the step follows it
	if Ash.intro_holds():
		_cand = &""
		_step_cand = &""
		return
	# A NEW VISIT when the screen as it stands changes (`_front`)
	var fk := _front()
	if fk != _front_key:
		_front_key = fk
		_front_last = &""
	if _quiet > 0.0 or _blocked(&"save"):
		_cand = &""
		return
	for id in ORDER:
		if seen(id) or resting(id) or _blocked(id) or not _pace_ok(id):
			continue
		var p := probe(id)
		if p.is_empty():
			continue
		if _cand != id:
			_cand = id
			_cand_t = 0.0
		_cand_t += delta
		# A LINE OF HERS PLAYS OUT (Jon, Oct 22: "a click doesn't cut a quip
		# short. It plays out and ends on its own"): a hint that comes due while
		# she is saying one waits for it to end, settled, rather than cutting it
		if _cand_t >= SETTLE_S and not Ash.bark_up():
			_show(id, p)
		return
	_cand = &""
	_poll_step(delta)


## HER LESSON, one step: spent the moment its action is done; an information
## line spent when she has said it to its end; gone unspent when she went for
## anything else (her switch, the screen changed, something came into her box),
## or its subject did, but spent if it is one said once and she had said it
## whole; or given way to a line waiting here (`_yield`).
func _poll_lesson(delta: float) -> void:
	if _done(lesson):
		_close_lesson(true)
		return
	var p := Ash.portrait
	if not _said and p != null and is_instance_valid(p) and Ash.lesson_up() \
			and p.phase == AshPortrait.Phase.HOLDING:
		_said = true
		_said_at = _clock
		# SAID WHOLE, ALOUD: heard, and never said aloud again
		if not _lesson_quiet:
			mark_seen(_heard_key(_lesson_lid))
	if not by_ash() or not Ash.lesson_up() or Ash.lesson_hint != lesson:
		var read := (INFO.has(lesson) and Ash.ended_of_itself(_lesson_lid)) or _left_heard()
		if not read:
			print("[hints] %s: she went (%s), unspent" % [lesson, Ash.held_by if Ash.held_by != "" else "off"])
		_close_lesson(read)
		return
	var lp := probe(lesson, true) if not _blocked(lesson) else {}
	if lp.is_empty():
		_gone_t += delta
		if _gone_t > 0.25:
			var read := _left_heard()
			if not read:
				print("[hints] %s: its subject went, unspent" % lesson)
			_close_lesson(read)
		return
	_gone_t = 0.0
	Ash.aim_lesson(lp.subject)
	if _yield_due():
		_yield(lesson)


## A CARD, one step: as her lesson, and an information card spent after its
## reading time (`info_s`).
func _poll_card(delta: float) -> void:
	if _done(card.id) or (INFO.has(card.id) and _up_t >= info_s(card.id)):
		_close(true)
		return
	var p := probe(card.id, true) if not _blocked(card.id) else {}
	if p.is_empty():
		_gone_t += delta
		if _gone_t > 0.25:
			_close(_left_heard(card.id))
		return
	_gone_t = 0.0
	card.visible = true
	card.aim(p.subject, _with_goal(p.get("avoid", [])))
	if _yield_due():
		_yield(card.id)


## An information card's reading time, s: her own floor and allowance a letter
## (`AshPortrait`), over its words.
func info_s(id: StringName) -> float:
	return AshPortrait.HOLD_MIN_S + AshPortrait.HOLD_PER_CHAR_S * float(" ".join(lines(id)).length())


## The line up was left (its subject or its screen gone) after it was said whole,
## and it is one of those said once (`SPENT_ONCE_HEARD`); or it is information
## (`INFO`), said once, ever, however it went.
func _left_heard(id: StringName = &"") -> bool:
	if id == &"":
		id = lesson
	return INFO.has(id) or (SPENT_ONCE_HEARD.has(id) and _said)


## NEVER STUCK: said whole, up YIELD_S since, and another line waiting here.
## Looked at twice a second, not every frame (every hint's subject is asked).
func _yield_due() -> bool:
	if not _said or _clock - _said_at < YIELD_S or _clock < _wait_look:
		return false
	_wait_look = _clock + 0.5
	return _waiting_other(card.id if card != null and is_instance_valid(card) else lesson)


## Another line could go here now: an unseen hint with its subject up (not
## resting, not `than`), or a goal step she has yet to say.
func _waiting_other(than: StringName) -> bool:
	if _step_now() != &"":
		return true
	for id in ORDER:
		if id == than or seen(id) or resting(id):
			continue
		# (a fight's lesson the turn holds back is not waiting; one a visit has
		# held back is: giving way lets it start, `_yield`)
		if FIGHT.has(id) and not _pace_ok(id):
			continue
		if not probe(id).is_empty():
			return true
	return false


## `id` gives way: goes unspent, and rests REST_S so what was waiting goes first.
func _yield(id: StringName) -> void:
	print("[hints] %s: up %.0f s with another line waiting; it gives way, unspent, for %.0f s" % [id, _clock - _said_at, REST_S])
	_rest[id] = _clock + REST_S
	# (the one it gives way to may start on this same visit: `_pace_ok`)
	_front_last = &""
	if card != null and is_instance_valid(card) and card.id == id:
		_close(false)
	else:
		_close_lesson(false)


## Whether hint `id` is resting after giving way to another line.
func resting(id: StringName) -> bool:
	return float(_rest.get(id, -1.0)) > _clock


# ------------------------------------------------------------------ pacing

## The quiet after a lesson: GAP_S outside a fight, GAP_FIGHT_S in one.
func _gap() -> float:
	var sc := Router.current as SectorScreen
	return GAP_FIGHT_S if sc != null and is_instance_valid(sc) and sc.fighting() else GAP_S


## Keep the turn's count on the fight and turn up now.
func _sync_turn(cb: Combat) -> void:
	if cb == null:
		return
	if cb != _last_fight:
		_last_fight = cb
		_fights_seen += 1
	var k := [cb.get_instance_id(), cb.turn]
	if k != _turn_of:
		_turn_of = k
		_turn_cards = 0


## Lesson `id` shows: what pacing remembers of it.
func _taught(id: StringName) -> void:
	var cb: Combat = Router.combat
	if FIGHT.has(id):
		if id == &"hand":
			_first_fight = cb
		if ONE_A_FIGHT.has(id):
			_extra_fight = cb
		return
	_front_key = _front()
	_front_last = id
	if id == &"chart" and Router.current != null:
		_chart_taught_on = Router.current.get_instance_id()
	if id == &"cutaway":
		_cut_seen = 1
		_cut_fit = _fit_sig()


## THE AUDIT'S PACING: whether lesson `id` may START now (not whether it may
## stay: that is its subject's). In a fight: no card held; after a card this
## turn only `MID_TURN`; turn 1 of the first fight only `TURN_ONE`; one of
## `ONE_A_FIGHT` a fight, and piles not in the first fight nor on turn 1.
## Outside one: a screen as it stands teaches one new lesson, or the next of a
## chain.
func _pace_ok(id: StringName) -> bool:
	if FIGHT.has(id):
		var sc := Router.current as SectorScreen
		var cb: Combat = Router.combat
		if sc == null or cb == null or not sc.fighting():
			return true
		_sync_turn(cb)
		if sc._grab_view != null or sc._aim_view != null:
			return false
		if not MID_TURN.has(id) and _turn_cards > 0:
			return false
		if not TURN_ONE.has(id) and cb.turn < 2 and (cb == _first_fight
				or not (seen(&"hand") and seen(&"energy") and seen(&"endturn"))):
			return false
		if ONE_A_FIGHT.has(id) and cb == _extra_fight:
			return false
		if id == &"piles" and (cb.turn < 2 or cb == _first_fight or not seen(&"hand")):
			return false
		return true
	if _front() != _front_key or _front_last == &"" or _front_last == id:
		return true
	for ch: Array in CHAINS:
		if ch.has(_front_last) and ch.has(id) and ch.find(id) > ch.find(_front_last):
			return true
	return false


## A SCREEN AS IT STANDS: the screen, the fights seen, and what is open on it
## (the station's deck, the cutaway, a window, an event in the band, the menu).
## A new one is a new visit.
func _front(for_voice: bool = false) -> String:
	var cur = Router.current
	if cur == null or not is_instance_valid(cur):
		return ""
	var k := "%d|%d" % [cur.get_instance_id(), _fights_seen]
	var sc := cur as SectorScreen
	# (for her voice, `_visit`: the fight itself, not the count of them, which
	# moves on a poll after a fight starts; and not the escape menu)
	if for_voice:
		k = str(cur.get_instance_id())
		if sc != null and sc.fighting() and Router.combat != null:
			k += "|fight%d" % Router.combat.get_instance_id()
	if sc != null:
		if sc._cutaway != null and is_instance_valid(sc._cutaway):
			k += "|cut%d" % sc._cutaway.get_instance_id()
		var tv := _transfer(sc)
		if tv != null:
			k += "|tv%d" % tv.get_instance_id()
		var d := sc._events
		if d != null and is_instance_valid(d) and d.page != &"":
			k += "|ev%d" % d.opt
	var st := cur as StationScreen
	if st != null:
		k += "|" + String(st._tab)
		if st._cutaway != null and is_instance_valid(st._cutaway):
			k += "|cut%d" % st._cutaway.get_instance_id()
	if menu_up() and not for_voice:
		k += "|menu"
	return k


## A VISIT, for her voice (`may_say_aloud`): the screen as it stands (`_front`)
## less the escape menu, so a line the menu took her off is not said aloud again
## when it shuts, and the fight up, so a fight is one visit from its first turn
## to its last.
func _visit() -> String:
	return _front(true)


## Her words for teaching line `lid` had started (her voice, or the typing of a
## line with no take) when she went.
func _spoke_some(lid: StringName) -> bool:
	var p := Ash.portrait
	return p != null and is_instance_valid(p) and p.kind == StringName("tut_" + String(lid)) and p.typed_at >= 0.0


## Malfunctions in this fight's deck, hand and discard (a purge takes one out).
func _junk(cb: Combat) -> int:
	if cb == null:
		return 0
	var k := 0
	for pile: Array in [cb.hand, cb.deck, cb.discard]:
		for c in pile:
			if (c as CardData).unplayable:
				k += 1
	return k


# ------------------------------------------------------------------ the actions

## THE STATE AN ACTION IS MEASURED FROM, taken as hint `id` shows.
func _snapshot(id: StringName) -> Dictionary:
	var cb: Combat = Router.combat
	var sc := Router.current as SectorScreen
	match id:
		&"hand":
			return {played = _cards_played}
		&"endturn", &"heat", &"brace":
			return {combat = cb, turn = cb.turn if cb != null else 0}
		&"intent", &"energy", &"heat_corner", &"piles", &"flee_hail", &"keywords":
			return {combat = cb, turn = cb.turn if cb != null else 0, played = _cards_played}
		&"malfunction":
			return {combat = cb, turn = cb.turn if cb != null else 0, junk = _junk(cb)}
		&"discard_pick":
			return {combat = cb, turn = cb.turn if cb != null else 0, choosing = cb.choosing if cb != null else 0}
		&"drawer", &"odds":
			return {fight = sc != null and sc.fighting()}
		&"map_fly":
			return {flights = SystemMapScreen.flights}
		&"layers", &"contract_track", &"quest", &"jump_blocked":
			var chs := Router.current as StarchartScreen
			return {sel = chs._selected if chs != null else -1, jumps = Run.jumps}
		&"attributes":
			return {fit = _fit_sig()}
		&"hull_sale":
			return {hull = Run.hull}
		&"undock":
			var stu := Router.current as StationScreen
			return {tab = stu._tab if stu != null else &""}
		&"events":
			return {pending = LocalEventDrawer.pending.duplicate()}
		&"chart":
			var ch := Router.current as StarchartScreen
			return {sel = ch._selected if ch != null else -1, jumps = Run.jumps}
		&"salvage":
			return {hauls = Run.hauls}
		&"cutaway":
			return {fit = _fit_sig()}
		&"wreck":
			return {opened = _opened_here()}
		&"dock":
			var st := Router.current as StationScreen
			return {tab = st._tab if st != null else &""}
		&"shipyard", &"promenade", &"exchange", &"hiring_board", &"laboratory":
			return {sig = _deck_sig()}
	return {}


## WHETHER THE PLAYER HAS DONE WHAT HINT `id` TEACHES since it showed (`DONE`).
## Read off the screens and the run as they are, like the subjects: no screen
## calls it. Asked before the subject, since doing it often takes the subject
## away (an event opened is no longer in the list).
func _done(id: StringName) -> bool:
	var cur = Router.current
	if cur == null or not is_instance_valid(cur):
		return false
	var sc := cur as SectorScreen
	match id:
		&"hand":
			return _cards_played > int(_base.get("played", 1 << 30))
		&"intent", &"energy", &"heat_corner", &"piles", &"flee_hail":
			# A CARD PLAYED OR END TURN (and FLEE or HAIL pressed, for theirs)
			if _cards_played > int(_base.get("played", 1 << 30)):
				return true
			if id == &"flee_hail" and sc != null and sc._exit_ask != null:
				return true
			return _turn_over(sc)
		&"keywords":
			return sc != null and sc.fighting() and sc._readout != null and is_instance_valid(sc._readout) \
				and sc._readout_for != null
		&"malfunction":
			return _junk(Router.combat) < int(_base.get("junk", -1)) or _turn_over(sc)
		&"discard_pick":
			var cbp: Combat = Router.combat
			return cbp == null or cbp != _base.get("combat") or cbp.choosing < int(_base.get("choosing", 0)) \
				or _turn_over(sc)
		&"odds":
			if sc == null or sc._events == null or not is_instance_valid(sc._events):
				return false
			var od := sc._events
			return od.page != &"event" or od._busy or (sc.fighting() and not bool(_base.get("fight", true)))
		&"result":
			if sc == null or sc._events == null or not is_instance_valid(sc._events):
				return false
			var rd := sc._events
			return rd.page != &"result" or (rd._transfer != null and is_instance_valid(rd._transfer))
		&"map_fly":
			var mf := cur as SystemMapScreen
			if SystemMapScreen.flights > int(_base.get("flights", 1 << 30)):
				return true
			return mf != null and (mf._wasd as Dictionary).values().has(true)
		&"layers", &"contract_track", &"quest", &"jump_blocked":
			if Run.jumps > int(_base.get("jumps", 1 << 30)):
				return true
			var chd := cur as StarchartScreen
			return chd != null and chd._selected >= 0 and chd._selected != int(_base.get("sel", -1))
		&"mounts":
			var mc := _cut_of(cur)
			return mc != null and mc._mounts != null and mc._mounts._lit == null
		&"cards_from_parts":
			var cc := _cut_of(cur)
			return cc != null and cc._shown is ModuleData and cc._panel != null and cc._panel.visible
		&"attributes":
			return _base.has("fit") and _fit_sig() != _base.fit
		&"hull":
			# (no action: said whole and the screen left, `SPENT_ONCE_HEARD`)
			return false
		&"faults":
			var sf := cur as StationScreen
			return sf != null and sf._purge_prompt != null
		&"hull_sale":
			return (Router.dock != null and is_instance_valid(Router.dock)) or Run.hull != _base.get("hull")
		&"undock":
			var su := cur as StationScreen
			return not Router.docked or (su != null and su._tab != StringName(_base.get("tab", &"")))
		&"save":
			# THE MENU SHUT, OR A WAY OUT PRESSED: its question ("SAVE AND LEAVE?")
			# takes the plates' place, so the line's subject went with it and it
			# came back in full at the next menu (Jon's 0.4.1 log, twice)
			return not menu_up() or _exit_asked()
		&"chassis_card":
			return not (cur is ChassisSelect)
		&"endturn", &"heat", &"brace":
			# (the intent's line is about END TURN: pressed, it has been read)
			var cb: Combat = Router.combat
			if cb == null or cb != _base.get("combat"):
				return false
			return cb.turn > int(_base.get("turn", 0)) or (sc != null and (sc._hold or sc._playing))
		&"drawer":
			if sc == null or sc._events == null or not is_instance_valid(sc._events):
				return false
			var d := sc._events
			# (a choice, or NOT NOW: the band down with the event still open)
			return d.page == &"result" or d.page == &"" or d._busy \
				or (sc.fighting() and not bool(_base.get("fight", true)))
		&"events":
			var map := cur as SystemMapScreen
			if map != null and map.panel != null and is_instance_valid(map.panel) and map.panel.mode == &"event":
				return true
			# (GO: the flight to it under way, its band waiting on LOCAL)
			return not LocalEventDrawer.pending.is_empty() and LocalEventDrawer.pending != _base.get("pending", [])
		&"chart":
			if Run.jumps > int(_base.get("jumps", 1 << 30)):
				return true
			var ch := cur as StarchartScreen
			if ch == null:
				return false
			return ch._selected >= 0 and ch._selected != int(_base.get("sel", -1))
		&"salvage":
			# a part taken, or DONE: the window shut
			return Run.hauls > int(_base.get("hauls", 1 << 30)) or _transfer(sc) == null
		&"cutaway":
			# (not while a part is in the hand: picked up and put back where it
			# was is nothing moved)
			for cut in [sc._cutaway if sc != null else null, (cur as StationScreen)._cutaway if cur is StationScreen else null]:
				if cut != null and is_instance_valid(cut) and (cut as CutawayView)._lifted != null:
					return false
			return _base.has("fit") and _fit_sig() != _base.fit
		&"wreck":
			return _opened_here() > int(_base.get("opened", 1 << 30))
		&"loot":
			var tv: TransferView = sc._transfer if sc != null else null
			return tv != null and is_instance_valid(tv) and tv._jetsam != null and not tv._jetsam.is_wreck()
		&"dock":
			var st := cur as StationScreen
			return st != null and st._tab != StringName(_base.get("tab", &""))
		&"shipyard", &"promenade", &"exchange", &"hiring_board", &"laboratory":
			return _base.has("sig") and _deck_sig() != _base.sig
		&"ship":
			if sc != null:
				return sc._cutaway != null and is_instance_valid(sc._cutaway)
			var st := cur as StationScreen
			return st != null and st._cutaway != null and is_instance_valid(st._cutaway)
	return false


## The escape menu asks its question in place of the two ways out: SAVE & EXIT
## (or ABANDON) pressed.
func _exit_asked() -> bool:
	var m := _menu()
	if m == null or m._exits == null or m._exits.get_child_count() == 0:
		return false
	return not (m._exits.get_child(0) is DrawerPlate)


## END TURN pressed since the line showed: the turn on, or its playback under way.
func _turn_over(sc: SectorScreen) -> bool:
	var cb: Combat = Router.combat
	if cb == null or cb != _base.get("combat"):
		return false
	return cb.turn > int(_base.get("turn", 0)) or (sc != null and (sc._hold or sc._playing))


## The cutaway open on `cur` (LOCAL's or the station's), or null.
func _cut_of(cur) -> CutawayView:
	var cut: CutawayView = null
	if cur is SectorScreen:
		cut = (cur as SectorScreen)._cutaway
	elif cur is StationScreen:
		cut = (cur as StationScreen)._cutaway
	if cut == null or not is_instance_valid(cut) or not cut.is_open():
		return null
	return cut


## What is fitted and where: each module on the ship, its mount and its flip, in
## no order (a part put back goes to the end of the list). A module installed,
## removed, moved to another mount or flipped changes it.
func _fit_sig() -> Array:
	var out: Array = []
	# (not its flip: drawing only, `ModuleData.flipped`, and not what the
	# cutaway's line teaches since Oct 22)
	for m in Run.installed:
		out.append([m.get_instance_id(), m.mount])
	out.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) < int(b[0]))
	return out


## A deck used: anything it sells, buys, mends, fills or signs moved.
func _deck_sig() -> Array:
	return [Run.credits, Run.hp, Run.fuel, Run.hauls, Run.cargo.size(), Run.installed.size(),
		Run.contracts.size(), Run.hull]


## The wrecks here opened so far.
func _opened_here() -> int:
	var n := Run.node_at()
	if n == null:
		return 0
	var k := 0
	for raw in Run.wrecks_here(n):
		var h: MapGen.Jetsam = raw
		if h.is_wreck() and h.opened:
			k += 1
	return k


## THE GOAL STEPS IN HER VOICE: once a step is up on the goal line and has held
## SETTLE_S, and no hint is due, she says its line, once ever (until SHOW HINTS
## AGAIN). No outline of her own: the goal line outlines the tab it names.
func _poll_step(delta: float) -> void:
	if menu_up():
		_step_cand = &""
		return
	var id := _step_now()
	if id == &"":
		_step_cand = &""
		return
	if _step_cand != id:
		_step_cand = id
		_step_t = 0.0
	_step_t += delta
	# (and, as a hint, after a line of hers already under way: it plays out)
	if _step_t < SETTLE_S or Ash.bark_up():
		return
	var vals := values()
	if Ash.teach(id, AshTutorLines.fill(id, vals), &"", Rect2(),
			{voice = AshTutorLines.voice_path(id), spoken = AshTutorLines.spoken(id)}):
		mark_seen(_said_key(id))
		step_up = id
		shown_log.append(id)
		_step_cand = &""


## The goal step whose line she has yet to say, up on the goal line now; &"".
func _step_now() -> StringName:
	if not by_ash() or Router.hud == null or not is_instance_valid(Router.hud):
		return &""
	# (whether the goal line is up this frame, not whether it has drawn yet: a
	# bark asked first on the frame the ship stopped, the line not yet faded in,
	# so the launch bark started and the step cut it 0.6 s later)
	if not GoalLine.shows_on(Router.current):
		return &""
	var st := GoalLine.step()
	var id := StringName(st.get("id", &""))
	if id == &"" or said(id):
		return &""
	return id


## A goal step's line is due here or being said (her barks wait for it).
func step_due() -> bool:
	if not enabled() or _blocked():
		return false
	if step_up == &"" and Ash.intro_holds():
		return false
	return step_up != &"" or _step_now() != &""


func _end_step() -> void:
	if step_up != &"" and Ash.lesson == step_up:
		Ash.end_lesson(true)
	step_up = &""


## NO CLICK DISMISSES ANYTHING HERE (Jon, Oct 22): there is no `_input`. A
## goal step's line goes after its reading time, a hint when its action is done
## (`_done`). For the harnesses that walk a run without doing every step (the
## films and shots), `spend` stands in for the player having done it: what is up
## is spent and goes. Nothing in the game calls it. True if something was up.
func spend() -> bool:
	if lesson != &"":
		_close_lesson(true)
		return true
	if card != null and is_instance_valid(card):
		_close(true)
		return true
	if step_up != &"":
		_end_step()
		return true
	return false


func _show(id: StringName, p: Dictionary) -> void:
	var host := _host()
	if host == null:
		return
	_base = _snapshot(id)
	_said = false
	_wait_look = 0.0
	_taught(id)
	if _ash_for(id):
		var lid := AshTutorLines.line_id(id, _dock_cached() if id == &"fuel" else {})
		var vals := values(id)
		var text := AshTutorLines.fill(lid, vals)
		# (an information line goes by itself after its reading time: not held)
		# SAID ALOUD ONCE: heard already, or cut off once already on this visit or
		# twice ever, it comes back quietly, text only
		var aloud := may_say_aloud(lid)
		var opts := {voice = AshTutorLines.voice_path(lid), spoken = AshTutorLines.spoken(lid),
			held = not INFO.has(id), quiet = not aloud}
		# OVER THE ESCAPE MENU: on the menu's own layer, clear of its drawer
		if id == &"save":
			var m := _menu()
			if m != null:
				opts["host"] = m.get_parent()
				opts["spot"] = Ash.menu_spot(text, m._drawer.get_global_rect(), p.subject,
					m.get_viewport_rect().size)
		if Ash.teach(lid, text, id, p.subject, opts):
			lesson = id
			_lesson_lid = lid
			_lesson_quiet = not aloud
			_lesson_visit = _visit_n
			_up_t = 0.0
			_gone_t = 0.0
			_cand = &""
			shown_log.append(id)
			# (quiet, the words are out as it shows: read whole, as a card is)
			if not aloud:
				_said = true
				_said_at = _clock
			# INFORMATION IS SAID ONCE, EVER: spent as it shows
			if INFO.has(id):
				mark_seen(id)
			return
		# NOWHERE CLEAR FOR HER on this screen: the card, so the lesson is never
		# held back waiting for room
		fallback_log.append(id)
		print("[hints] %s: no clear spot for A.S.H. (%s), as a card" % [id, Ash.held_by])
	card = HintCard.new(id, lines(id))
	card.theme = _theme()
	# (over the escape menu: on its layer, above it)
	var mh := _menu()
	if id == &"save" and mh != null:
		mh.get_parent().add_child(card)
	else:
		host.add_child(card)
	card.aim(p.subject, _with_goal(p.get("avoid", [])))
	_up_t = 0.0
	_gone_t = 0.0
	_cand = &""
	# (a card is read whole as it shows)
	_said = true
	_said_at = _clock
	shown_log.append(id)
	if INFO.has(id):
		mark_seen(id)


## A card keeps off the goal line too (`GoalLine`), and the step's line under
## it, so the one thing that is always on screen is never covered by the thing
## that comes and goes.
func _with_goal(avoid: Array) -> Array:
	var g := goal_rect()
	if g.size == Vector2.ZERO:
		return avoid
	var out := avoid.duplicate()
	out.append(g)
	var gl: Variant = Router.hud.get("goal")
	if gl is GoalLine and is_instance_valid(gl):
		out.append((gl as GoalLine).step_rect())
	return out


func goal_rect() -> Rect2:
	if Router.hud == null or not is_instance_valid(Router.hud):
		return Rect2()
	return Router.hud.goal_rect()


func _close(read: bool) -> void:
	if card != null and is_instance_valid(card):
		if read:
			mark_seen(card.id)
		card.queue_free()
		if card.get_parent() != null:
			card.get_parent().remove_child(card)
	card = null
	_quiet = _gap()


## Her lesson goes: spent (`read`: its action done, read to its end, or said
## whole and left), or unspent.
func _close_lesson(read: bool) -> void:
	if lesson == &"":
		return
	if read:
		mark_seen(lesson)
	# CUT OFF WHILE SHE WAS SAYING IT (her words had started, not all out): one
	# more time aloud, on another visit (`may_say_aloud`)
	if not _lesson_quiet and not heard(_lesson_lid) and _spoke_some(_lesson_lid):
		_tries[_lesson_lid] = int(_tries.get(_lesson_lid, 0)) + 1
		_tried_in[_lesson_lid] = _lesson_visit
	_lesson_quiet = false
	if Ash.lesson_hint == lesson:
		Ash.end_lesson(true)
	lesson = &""
	_lesson_lid = &""
	_quiet = _gap()
	_gate_to(false)


# ------------------------------------------------------------------ the soft lock

## Up or down: the gate over the game while she speaks (`soft_lock`), with a
## hole where she points.
func _gate_to(on: bool) -> void:
	if not on:
		if _gate != null and is_instance_valid(_gate):
			_gate.queue_free()
			if _gate.get_parent() != null:
				_gate.get_parent().remove_child(_gate)
		_gate = null
		return
	var host := Ash._host()
	if host == null:
		return
	if _gate == null or not is_instance_valid(_gate):
		_gate = ClickGate.new()
	if _gate.get_parent() != host:
		if _gate.get_parent() != null:
			_gate.get_parent().remove_child(_gate)
		host.add_child(_gate)
	# (last of its column: picked before the screens and the HUD, under the
	# escape menu's own layer)
	if _gate.get_index() != host.get_child_count() - 1:
		host.move_child(_gate, -1)
	_gate.hole = Ash.outline_rect()


## THE SOFT LOCK'S GATE: the whole picture, taking every click but those inside
## `hole` (global), which go through to what is under. Draws nothing.
class ClickGate extends Control:
	var hole := Rect2()
	## Presses it has taken (for the harness).
	var taken := 0

	func _init() -> void:
		name = "AshClickGate"
		top_level = true
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE
		position = Vector2.ZERO

	func _process(_d: float) -> void:
		var vs := get_viewport_rect().size
		if size != vs:
			size = vs

	func _has_point(p: Vector2) -> bool:
		return not (hole.has_area() and hole.has_point(get_global_transform() * p))

	func _gui_input(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb != null and mb.pressed:
			taken += 1
		accept_event()


## The root of the game's picture.
func _host() -> Node:
	if Router.content == null or not Router.content.is_inside_tree():
		return null
	return Router.content.get_viewport()


## The game's theme (its pixel font), which lives on an ancestor of the screens.
func _theme() -> Theme:
	var n: Node = Router.content
	while n != null:
		if n is Control and (n as Control).theme != null:
			return (n as Control).theme
		n = n.get_parent()
	return null


## Nothing shows in a run that has ended, nor over the escape menu but its own
## lesson (`save`, the one asked for there: Oct 22).
func _blocked(id: StringName = &"") -> bool:
	if Run.dead or Run.hull == null:
		return true
	return menu_up() and id != &"save"


## The escape menu, if it is up.
func _menu() -> PauseMenu:
	var n: Node = Router.content
	while n != null:
		if n.get_script() != null and "_menu" in n:
			var m = n.get("_menu")
			return m as PauseMenu if m != null and is_instance_valid(m) else null
		n = n.get_parent()
	return null


## The escape menu is up. It is Main's (`Main.toggle_menu`), and Main sits above
## the screens inside the game's picture, not at the scene's root.
func menu_up() -> bool:
	var n: Node = Router.content
	while n != null:
		if n.get_script() != null and "_menu" in n:
			return n.get("_menu") != null
		n = n.get_parent()
	return false


# ------------------------------------------------------------------ subjects

## Where hint `id`'s subject is now, if it is on screen and ready:
## {subject: Rect2, avoid: Array of Rect2}, global in the game's picture; or {}.
## `staying`: asked of the line already up, not of one about to start (heat's
## stays through the heat vented to nothing, below).
func probe(id: StringName, staying: bool = false) -> Dictionary:
	var cur = Router.current
	if cur == null or not is_instance_valid(cur) or not (cur as Node).is_inside_tree():
		return {}
	var hud := _hud_rect()
	var sc := cur as SectorScreen
	match id:
		&"chart":
			# the in-range list, once the camera has landed on the chart
			var ch := cur as StarchartScreen
			if ch == null or ZoomLadder.busy() or ch._neigh == null or not ch._neigh.is_visible_in_tree():
				return {}
			var rows := _union(ch._neigh.get_children())
			if rows.size == Vector2.ZERO:
				return {}
			var avoid: Array = [hud]
			var side := ch.ladder_side()
			if side != null and side.is_visible_in_tree():
				avoid.append(side.get_global_rect())
			return {subject = rows, avoid = avoid}
		&"events":
			# the map's list of events, while one is open to pick
			var map := cur as SystemMapScreen
			if map == null or ZoomLadder.busy() or map.panel == null or not is_instance_valid(map.panel):
				return {}
			if map.panel.mode != &"list" or not (map.panel as Control).is_visible_in_tree():
				return {}
			var open: Array = []
			for c in (map.panel as Node).find_children("*", "", true, false):
				if c is Control and c.has_method("set_doomed") and not c.get("finished") \
						and (c.get("press") as Callable).is_valid() and (c as Control).is_visible_in_tree():
					open.append(c)
			var r := _union(open)
			if r.size == Vector2.ZERO:
				return {}
			var avoid: Array = [hud]
			var side := map.ladder_side()
			if side != null and side.is_visible_in_tree():
				avoid.append(side.get_global_rect())
			return {subject = r, avoid = avoid}
		&"drawer":
			if sc == null or sc._events == null or not is_instance_valid(sc._events):
				return {}
			var d := sc._events
			if d.page != &"event" or d._choices == null or not d._choices.is_visible_in_tree() \
					or d._choices.modulate.a < 0.99 or (d.text != null and not d.text.done):
				return {}
			return {subject = d._choices.get_global_rect(), avoid = [d.get_global_rect(), hud]}
		&"hand":
			if not _hand_settled(sc):
				return {}
			# A CARD YOU CAN PLAY: its action is playing one, so with none it
			# would stand there until the turn ends (and END TURN's line, the one
			# that applies, behind it)
			var hcb: Combat = Router.combat
			if hcb == null or not hcb.hand.any(func(c: CardData) -> bool: return hcb.can_play(c)):
				return {}
			var r := Rect2()
			for v in sc._hand._views:
				if v != null and is_instance_valid(v) and v.is_visible_in_tree():
					r = v.get_global_rect() if r.size == Vector2.ZERO else r.merge(v.get_global_rect())
			if r.size == Vector2.ZERO:
				return {}
			return {subject = r, avoid = _fight_avoid(sc, hud)}
		&"intent":
			# THE WORDS OVER AN ENEMY, what it does when you end the turn: at the
			# start of turn 2 (the deep tutorial's pacing, `_pace_ok`; it came
			# after the first card, in the hand's turn)
			if not _hand_settled(sc):
				return {}
			for i in 8:
				var sl := sc._view.slot(i)
				if sl == null or not sl.is_visible_in_tree() or sl.intent_hushed():
					continue
				var ir := sl.intent_rect_global()
				if ir.size.x > 2.0:
					return {subject = ir, avoid = _fight_avoid(sc, hud)}
			return {}
		&"endturn":
			# NOTHING LEFT YOU CAN PLAY: END TURN, and what it does
			if not _hand_settled(sc):
				return {}
			var cb: Combat = Router.combat
			# (nor while a discard is being picked: nothing is playable then, and
			# the pick is the thing to do)
			if cb == null or cb.choosing > 0:
				return {}
			for c in cb.hand:
				if cb.can_play(c as CardData):
					return {}
			return {subject = sc._end_button.get_global_rect(), avoid = _fight_avoid(sc, hud)}
		&"brace":
			# BRACE CARRIED OVER AN END OF TURN (and charged its heat), still up
			var cb: Combat = Router.combat
			if not _hand_settled(sc) or cb == null or cb.brace_held <= 0 or cb.brace <= 0:
				return {}
			if sc._player_chips == null or sc._player_chips.get_child_count() == 0:
				return {}
			var chip := sc._player_chips.get_child(0) as Control
			if chip == null or not chip.is_visible_in_tree() or chip.size.x < 2.0:
				return {}
			# and off the hand under it: the card went over the first two cards' costs
			var bav := _fight_avoid(sc, hud)
			bav.append(sc._hand.get_global_rect())
			return {subject = chip.get_global_rect(), avoid = bav}
		&"heat":
			# HEAT HAS RISEN, in a fight: the gauge, the cap and its price. Up,
			# it stays when the heat is vented to nothing (Bleed Heat is in every
			# starting deck): the gauge is still there and its action is END TURN.
			# It went, unspent, and came back at the next turn's start in full,
			# four times in one fight in Jon's 0.4.1 log.
			if not _hand_settled(sc) or (Run.heat <= 0 and not staying) or Router.hud == null:
				return {}
			var hr: Rect2 = Router.hud.heat_rect()
			if hr.size == Vector2.ZERO:
				return {}
			var hav := _fight_avoid(sc, hud)
			hav.append_array(GoalLine.avoid_rects(cur))
			return {subject = hr, avoid = hav}
		&"salvage":
			# A WRECK'S window open with something in it (its words say "the
			# wreck": not an event's REWARD window)
			var tv := _transfer(sc)
			if tv == null or tv._loose == null or not tv._loose.is_visible_in_tree():
				return {}
			if tv._jetsam == null or not tv._jetsam.is_wreck():
				return {}
			if tv._loose.find_children("*", "ItemIcon", true, false).is_empty():
				return {}
			var avoid: Array = [hud]
			if tv._hold != null and tv._hold.is_visible_in_tree():
				avoid.append(tv._hold.get_global_rect())
			for l: Control in [tv._title, tv._loose_label]:
				if l != null and l.is_visible_in_tree():
					avoid.append(l.get_global_rect())
			return {subject = tv._loose.get_global_rect(), avoid = avoid}
		&"cutaway":
			var cut: CutawayView = null
			if sc != null:
				cut = sc._cutaway
			elif cur is StationScreen:
				cut = (cur as StationScreen)._cutaway
			if cut == null or not is_instance_valid(cut) or not cut.is_open() or cut.popup_open():
				return {}
			var pic: Rect2 = cut.get_global_transform() * cut._pic
			if pic.size.x < 4.0:
				return {}
			var avoid: Array = [hud]
			if cut._panel != null and cut._panel.is_visible_in_tree():
				avoid.append(cut._panel.get_global_rect())
			return {subject = pic, avoid = avoid}
		&"wreck":
			if not _local_idle(sc):
				return {}
			var n := Run.node_at()
			if n == null:
				return {}
			# A REAL WRECK, ONE A CLICK OPENS: the slot's own hull ink (its
			# picture's canvas is far taller than the hull), and the card kept off
			# an event's subject drawn here, which is scenery and opens nothing
			var avoid: Array = [hud]
			var subj := LocalSubject.of(sc._view)
			if subj != null:
				avoid.append_array(subj.drawn_rects())
			var k := 0
			for raw in Run.wrecks_here(n):
				var h: MapGen.Jetsam = raw
				if Run.jetsam_left(n, h) > 0:
					var sl := sc._view.slot(k)
					if sl != null and sl.is_visible_in_tree() and sl.opened.is_valid():
						return {subject = sl.get_global_transform() * sl.ink_rect(), avoid = avoid}
				k += 1
			return {}
		&"loot":
			if not _local_idle(sc):
				return {}
			var b := sc.find_child("SectorLoot", true, false) as Button
			if b == null or not b.is_visible_in_tree() or b.disabled:
				return {}
			return {subject = b.get_global_rect(), avoid = [hud]}
		&"dock":
			# THE FIRST STATION, once the dock has landed: its decks
			var st := cur as StationScreen
			if st == null or ZoomLadder.busy() or st._cutaway != null:
				return {}
			var cells: Array = []
			for v in st._tabs.values():
				if v is Control and (v as Control).is_visible_in_tree():
					cells.append(v)
			var r := _union(cells)
			if r.size == Vector2.ZERO:
				return {}
			return {subject = r, avoid = [hud]}
		&"fuel":
			# A THIRD OF THE TANK LEFT (`Run.fuel_low`), out of a fight on a screen
			# that is still. It waited for "under two of the dearest jump" (about
			# 12 of 279) and in every stranded run the sim flew, that was one to
			# three jumps from the end.
			if Router.hud == null or ZoomLadder.busy() or not _fuel_low():
				return {}
			if not (cur is StarchartScreen or cur is SystemMapScreen or _local_idle(sc)):
				return {}
			# ON THE CHART IT POINTS AT THE DOCK IT NAMES, in the in-range list, or
			# at the list when the dock is further: the readout is in the bar's
			# corner and on the chart the only room near it is the bar itself (the
			# side bar under it, the toolbar and the picture's frame beside it), so
			# the card stood on the HUD. Kept off the HUD and the side bar, as the
			# chart's own hint is, which puts it on the picture beside the list.
			if cur is StarchartScreen:
				var ch := cur as StarchartScreen
				if ch._neigh == null or not ch._neigh.is_visible_in_tree():
					return {}
				var to := -1
				var d := _dock_cached()
				if not d.is_empty():
					to = (d.node as MapGen.MapNode).index
				var row := Rect2()
				for c in ch._neigh.get_children():
					var cc := c as Control
					if cc != null and cc.is_visible_in_tree() and int(cc.get_meta(&"node", -2)) == to:
						row = cc.get_global_rect()
				if row.size == Vector2.ZERO:
					row = _union(ch._neigh.get_children())
				if row.size == Vector2.ZERO:
					return {}
				var cav: Array = [hud]
				var cside := ch.ladder_side()
				if cside != null and cside.is_visible_in_tree():
					cav.append(cside.get_global_rect())
				return {subject = row, avoid = cav}
			var fr: Rect2 = Router.hud.fuel_rect()
			if fr.size == Vector2.ZERO:
				return {}
			# and off the side bar, the toolbar and the scene's own pieces: the
			# readout is in the corner, so the card lands among them
			return {subject = fr, avoid = GoalLine.avoid_rects(cur)}
		&"shipyard", &"promenade", &"exchange", &"hiring_board", &"laboratory":
			# THE DECK OPEN FOR THE FIRST TIME: its main thing
			return _deck_probe(cur as StationScreen, id)
		&"energy", &"discard_pick", &"heat_corner", &"keywords", &"malfunction", &"flee_hail", &"piles":
			return _fight_probe(sc, id, hud)
		&"odds", &"result":
			return _band_probe(sc, id, hud)
		&"fuel_first":
			# THE FIRST ARRIVAL AFTER A JUMP (the map it lands on, or LOCAL): the
			# tank on the HUD, before the event step
			if Router.hud == null or ZoomLadder.busy() or Run.jumps < 1:
				return {}
			if not (cur is SystemMapScreen or _local_idle(sc)):
				return {}
			var ffr: Rect2 = Router.hud.fuel_rect()
			if ffr.size == Vector2.ZERO:
				return {}
			return {subject = ffr, avoid = GoalLine.avoid_rects(cur)}
		&"hull":
			# LOCAL, still, the hull short of full
			if not _local_idle(sc) or Run.hp >= Run.max_hp() or Router.hud == null:
				return {}
			var hhr: Rect2 = Router.hud.hull_rect()
			if hhr.size == Vector2.ZERO:
				return {}
			return {subject = hhr, avoid = GoalLine.avoid_rects(cur)}
		&"map_fly":
			return _map_fly_probe(cur as SystemMapScreen, hud)
		&"layers", &"contract_track", &"quest", &"jump_blocked":
			return _chart_probe(cur as StarchartScreen, id, hud)
		&"mounts", &"cards_from_parts", &"attributes":
			return _cut_probe(_cut_of(cur), id, hud)
		&"faults", &"hull_sale", &"undock":
			return _station_probe(cur as StationScreen, id, hud)
		&"save":
			# THE ESCAPE MENU, its SAVE & EXIT plate (not Settings, not the confirm)
			var m := _menu()
			if m == null or m._closing or m._exits == null or not m._exits.is_visible_in_tree():
				return {}
			if m._settings != null and is_instance_valid(m._settings) and m._settings.visible:
				return {}
			var plate := m._exits.get_child(0) as DrawerPlate if m._exits.get_child_count() > 0 else null
			if plate == null or not plate.is_visible_in_tree() or not plate.title.begins_with("SAVE"):
				return {}
			return {subject = plate.get_global_rect(), avoid = [m._drawer.get_global_rect()]}
		&"chassis_card":
			# THE CHASSIS SELECT, its LAUNCH (a card only)
			if not (cur is ChassisSelect) or ZoomLadder.busy():
				return {}
			for b in (cur as Node).find_children("*", "Button", true, false):
				var lb := b as Button
				if lb.text == "LAUNCH" and lb.is_visible_in_tree():
					return {subject = lb.get_global_rect(), avoid = [hud]}
			return {}
		&"ship":
			if cur is StationScreen:
				var st := cur as StationScreen
				# (after the yard's own hint, which says what the deck is for: it
				# is spent as it shows, so this follows it)
				if not st.cutaway_ready() or not seen(&"shipyard"):
					return {}
				# with its name sign over it (`YardScene._names`, 16 px type at the
				# yard's 2x), so the card never stands on the name
				var box := _ship_box(st._mine_view)
				return {subject = box.grow_side(SIDE_TOP, 44.0), avoid = [hud]}
			# NOT BEFORE THE FIRST JUMP: the first screen of a run says one thing,
			# the goal line's (open STARCHART), and there is nothing to fit yet
			if not _local_idle(sc) or Run.jumps < 1:
				return {}
			var ship := sc._view.ship_view()
			if ship == null or not ship.is_visible_in_tree():
				return {}
			return {subject = _ship_box(ship), avoid = [hud]}
	return {}


## THE FIGHT'S NEW LESSONS (the deep tutorial), each on a settled hand.
func _fight_probe(sc: SectorScreen, id: StringName, hud: Rect2) -> Dictionary:
	if not _hand_settled(sc):
		return {}
	var cb: Combat = Router.combat
	if cb == null:
		return {}
	var av := _fight_avoid(sc, hud)
	match id:
		&"energy":
			# RIGHT AFTER THE FIRST CARD of a fight (the hand's lesson taught), with
			# a card still to play: the ENERGY box
			if _played_in != cb or not seen(&"hand") or cb.choosing > 0:
				return {}
			if not cb.hand.any(func(c: CardData) -> bool: return cb.can_play(c)):
				return {}
			var box := sc._energy.get_parent().get_parent() as Control if sc._energy != null else null
			if box == null or not box.is_visible_in_tree():
				return {}
			return {subject = box.get_global_rect(), avoid = av}
		&"discard_pick":
			# A CARD ASKED FOR A DISCARD: the hand, to pick from
			if cb.choosing <= 0 or cb.choose_kind != &"discard":
				return {}
			var hr := _hand_rect(sc)
			return {} if hr.size == Vector2.ZERO else {subject = hr, avoid = av}
		&"heat_corner":
			# A CARD THAT ADDS HEAT in the hand: its top right corner
			for v in sc._hand._views:
				if v != null and is_instance_valid(v) and v.is_visible_in_tree() and not v.card.unplayable \
						and v.card.net_heat() > 0:
					return {subject = v.get_global_transform() * v._z(CardView.Z_HEAT), avoid = av}
			return {}
		&"keywords":
			# A CARD WITH AN UNDERLINED WORD (`CardData.describe_rich`) in the hand
			for v in sc._hand._views:
				if v != null and is_instance_valid(v) and v.is_visible_in_tree() and v._body != null \
						and v._body.text.contains("[u]"):
					return {subject = v.get_global_rect(), avoid = av}
			return {}
		&"malfunction":
			for v in sc._hand._views:
				if v != null and is_instance_valid(v) and v.is_visible_in_tree() and v.card.unplayable:
					return {subject = v.get_global_rect(), avoid = av}
			return {}
		&"flee_hail":
			# HALF THE HULL GONE, and a way out to take
			if Run.hp * 2 > Run.max_hp():
				return {}
			var outs: Array = []
			for b: Button in [sc._flee_button, sc._hail_button]:
				if b != null and b.is_visible_in_tree() and not b.disabled:
					outs.append(b)
			var r := _union(outs)
			return {} if r.size == Vector2.ZERO else {subject = r, avoid = av}
		&"piles":
			# THE DISCARD, where played cards go
			if sc._discard_pile == null or not sc._discard_pile.is_visible_in_tree():
				return {}
			return {subject = sc._discard_pile.get_global_rect(), avoid = av}
	return {}


func _hand_rect(sc: SectorScreen) -> Rect2:
	var r := Rect2()
	for v in sc._hand._views:
		if v != null and is_instance_valid(v) and v.is_visible_in_tree():
			r = v.get_global_rect() if r.size == Vector2.ZERO else r.merge(v.get_global_rect())
	return r


## THE EVENT BAND'S: a choice that tests the ship (its plate), and the result
## with a REWARD to open (its buttons and table).
func _band_probe(sc: SectorScreen, id: StringName, hud: Rect2) -> Dictionary:
	if sc == null or sc._events == null or not is_instance_valid(sc._events) or sc.fighting():
		return {}
	var d := sc._events
	if d._choices == null or not is_instance_valid(d._choices) or not d._choices.is_visible_in_tree() \
			or d._choices.modulate.a < 0.99 or (d.text != null and not d.text.done) or d._busy:
		return {}
	if id == &"odds":
		if d.page != &"event" or d.node == null:
			return {}
		var choices: Array = OptionTable.by_id(d.node.options[d.opt]).get("choices", [])
		for j in choices.size():
			if (choices[j] as Dictionary).has("check"):
				var c := d._choices.find_child("Choice%d" % j, true, false) as Control
				if c != null and c.is_visible_in_tree():
					return {subject = c.get_global_rect(), avoid = [d.get_global_rect(), hud]}
		return {}
	if d.page != &"result" or (d._transfer != null and is_instance_valid(d._transfer)):
		return {}
	var reward := d.find_child("Reward", true, false) as Button
	if reward == null or not reward.is_visible_in_tree() or reward.disabled:
		return {}
	var parts: Array = [reward]
	for nm in ["Continue", "OutcomeTable"]:
		var c := d.find_child(nm, true, false) as Control
		if c != null:
			parts.append(c)
	return {subject = _union(parts), avoid = [hud]}


## THE MAP, the ship not in an orbit: flying it by hand.
func _map_fly_probe(map: SystemMapScreen, hud: Rect2) -> Dictionary:
	if map == null or ZoomLadder.busy() or map.flight == null or map.overlay == null or map._box == null:
		return {}
	if int(map.flight.reached()) != -9:
		return {}
	var at: Vector2 = map.overlay._ship_at
	var r := map._box.get_global_transform() * Rect2(at - Vector2(12, 12), Vector2(24, 24))
	if not map._box.get_global_rect().encloses(r):
		return {}
	var avoid: Array = [hud]
	var side := map.ladder_side()
	if side != null and side.is_visible_in_tree():
		avoid.append(side.get_global_rect())
	return {subject = r, avoid = avoid}


## THE CHART'S: its layer strip (from the second chart), a job's ring, a mark,
## a JUMP that cannot go.
func _chart_probe(ch: StarchartScreen, id: StringName, hud: Rect2) -> Dictionary:
	if ch == null or ZoomLadder.busy() or ch._chart == null or not ch._chart.is_visible_in_tree():
		return {}
	var avoid: Array = [hud]
	var side := ch.ladder_side()
	if side != null and side.is_visible_in_tree():
		avoid.append(side.get_global_rect())
	var view := ch._chart.get_global_rect()
	var g := ch._chart.get_global_transform()
	match id:
		&"layers":
			# (another chart than the one its own line was taught on)
			if not seen(&"chart") or ch.get_instance_id() == _chart_taught_on:
				return {}
			var parts: Array = [ch._layer_text, ch._layer_cells]
			if ch._strip_row != null and ch._strip_row.get_child_count() > 2:
				parts.append(ch._strip_row.get_child(2))
			var r := _union(parts)
			return {} if r.size == Vector2.ZERO else {subject = r, avoid = avoid}
		&"contract_track":
			if not ch._chart.show_icons:
				return {}
			for raw in Run.contracts:
				var job: ContractData = raw
				if job.state != ContractData.State.TAKEN or job.at < 0 or job.at >= Run.map.size():
					continue
				var c: Vector2 = ch._chart._screen_pos(Run.map[job.at])
				var r := g * Rect2(c - Vector2(10, 10), Vector2(20, 20))
				if view.encloses(r):
					return {subject = r, avoid = avoid}
			return {}
		&"quest":
			if not ch._chart.show_icons:
				return {}
			for raw in Run.map:
				var n: MapGen.MapNode = raw
				if not OptionTable.holds_quest(n):
					continue
				var c: Vector2 = ch._chart._screen_pos(n)
				var r := g * Rect2(c + Vector2(-46, -21), Vector2(92, 29))
				if view.encloses(r):
					return {subject = r, avoid = avoid}
			return {}
		&"jump_blocked":
			var j := ch._jump
			if j == null or not j.is_visible_in_tree() or ch._selected < 0 or not j.disabled or j.text == "JUMP":
				return {}
			return {subject = j.get_global_rect(), avoid = avoid}
	return {}


## INSIDE YOUR SHIP: the mounts that take the part in hand, the deck's line
## after a part is fitted, and the ship's stats.
func _cut_probe(cut: CutawayView, id: StringName, hud: Rect2) -> Dictionary:
	if cut == null or cut.popup_open() or cut.t < 0.98:
		return {}
	var avoid: Array = [hud]
	if cut._panel != null and cut._panel.is_visible_in_tree():
		avoid.append(cut._panel.get_global_rect())
	match id:
		&"mounts":
			var mp := cut._mounts
			if mp == null or mp._lit == null:
				return {}
			var rr := MountPoints.REACH * mp._mag()
			var gt := mp.get_global_transform()
			var r := Rect2()
			for sp: Dictionary in mp.spots():
				if not mp._takes_spot(sp):
					continue
				var at: Vector2 = sp.at
				var box := Rect2(gt * (at - Vector2.ONE * rr), Vector2.ONE * 2.0 * rr * gt.get_scale())
				r = box if r.size == Vector2.ZERO else r.merge(box)
			return {} if r.size == Vector2.ZERO else {subject = r, avoid = [hud]}
		&"cards_from_parts":
			# A PART FITTED (after the mounts' line) since the cutaway's own line
			# showed, or since your ship was first seen opened up this launch:
			# its fit changed since then
			if _cut_seen == 0:
				_cut_seen = cut.get_instance_id()
				_cut_fit = _fit_sig()
			if not seen(&"mounts"):
				return {}
			if _fit_sig() == _cut_fit or (cut._mounts != null and cut._mounts._lit != null):
				return {}
			var ml := cut._mount_line
			if ml == null or not ml.is_visible_in_tree():
				return {}
			return {subject = ml.get_global_rect(), avoid = avoid}
		&"attributes":
			# (after a check has been taught: what the checks test)
			if not seen(&"odds") or cut._attrs == null or not cut._attrs.is_visible_in_tree():
				return {}
			if cut._mounts != null and cut._mounts._lit != null:
				return {}
			return {subject = cut._attrs.get_global_rect(), avoid = avoid}
	return {}


## THE STATION'S: the FAULTS drone, a ship for sale, UNDOCK.
func _station_probe(st: StationScreen, id: StringName, hud: Rect2) -> Dictionary:
	if st == null or ZoomLadder.busy() or st._cutaway != null or st._purge_prompt != null:
		return {}
	if Router.dock != null and is_instance_valid(Router.dock):
		return {}
	var avoid := Ash.tut_avoid_rects(st)
	match id:
		&"faults":
			if st._tab != &"services" or Run.dross_count() <= 0 or st._scene == null or st._scene.drones == null:
				return {}
			var dr: Array = st._scene.drones.D
			if dr.size() < 4:
				return {}
			var d: Dictionary = dr[3]
			var mode := String(d.get("mode", ""))
			if d.get("away", false) or not (mode == "hover" or mode == "dip" or mode == "tell") or not d.has("r"):
				return {}
			var r: Dictionary = d["r"]
			var dx := float(d["x"]) - float(d["hx"])
			var dy := float(d["y"]) - float(d["hy"])
			var x0 := minf(float(r["fx0"]), float(r["sx"])) - dx
			var x1 := maxf(float(r["fx0"]) + float(r["fw"]), float(r["sx"]) + float(r["w"])) - dx
			var y0 := float(r["fy0"]) - dy
			var y1 := float(r["sy"]) + float(r["h"]) - dy
			var box := Rect2(x0, y0, x1 - x0, y1 - y0).grow_individual(3.0, 6.0, 3.0, 6.0)
			return {subject = st._scene.get_global_transform() * box, avoid = avoid}
		&"hull_sale":
			if st._tab != &"services" or st._yard_hull == null or st._scene == null or st._scene.deal.is_empty():
				return {}
			var dt: YardDeal = st._scene.deal_tv
			if dt == null or dt.reveal < 1.0:
				return {}
			var tv := Rect2(dt.X, dt.Y - YardDeal.LID, dt.IW, dt.IH + YardDeal.LID)
			return {subject = st._scene.get_global_transform() * tv, avoid = avoid}
		&"undock":
			# AFTER THE FIRST DECK'S LESSON, and not before this deck's own
			if not DECK_HINTS.keys().any(func(k: StringName) -> bool: return seen(k)):
				return {}
			for k: StringName in DECK_HINTS:
				if DECK_HINTS[k] == st._tab and not seen(k):
					return {}
			if st._undock == null or not st._undock.is_visible_in_tree() or st._undock.disabled:
				return {}
			return {subject = st._undock.get_global_rect(), avoid = [hud]}
	return {}


## A DECK'S FIRST-VISIT HINT: its deck the one open, the dock landed, nothing
## over it (your ship opened up, the faults picker), and its main thing up and
## still (`StationScreen.deck_subject`: the drones home, the lamp lit, the scan
## passed). A card keeps off everything she keeps off (`Ash.tut_avoid_rects`:
## the decks, UNDOCK, every button and word), so it never covers what you press.
func _deck_probe(st: StationScreen, id: StringName) -> Dictionary:
	if st == null or ZoomLadder.busy() or st._cutaway != null or st._purge_prompt != null:
		return {}
	var tab: StringName = DECK_HINTS[id]
	if st._tab != tab or not st._tabs_on.get(tab, true):
		return {}
	var r := st.deck_subject(tab)
	if r.size.x < 2.0 or r.size.y < 2.0:
		return {}
	return {subject = r, avoid = Ash.tut_avoid_rects(st)}


## The hull's own pixels, not the box it is drawn in (a third of it at most).
func _ship_box(v: ShipView) -> Rect2:
	return v.get_global_transform() * v.ship_rect()


## LOCAL out of a fight, nothing over it, and nothing on its way: no camera
## move, no event band up, going down, or waiting to come up (`deferred`,
## `LocalEventDrawer.pending`). The ship hint used to show in the 0.6 s between
## GO's landing and the band rising, and hide unread (tutorial audit, 0.44 s).
func _local_idle(sc: SectorScreen) -> bool:
	if sc == null or not sc.cutaway_ready() or ZoomLadder.busy():
		return false
	if not LocalEventDrawer.pending.is_empty():
		return false
	var d := sc._events
	if d != null and is_instance_valid(d) and (d.page != &"" or d.visible or not d.deferred.is_empty()):
		return false
	return true


## A fight's hand is up and yours to play: the band settled, END TURN live.
func _hand_settled(sc: SectorScreen) -> bool:
	if sc == null or not sc.fighting() or sc._hand == null or not sc._hand.is_visible_in_tree():
		return false
	if sc._hold or sc._opening:
		return false
	return sc._end_button != null and sc._end_button.is_visible_in_tree() and not sc._end_button.disabled


## What a card in a fight keeps off: the HUD, END TURN, the hand, the hulls and
## the words over them.
func _fight_avoid(sc: SectorScreen, hud: Rect2) -> Array:
	var avoid: Array = [hud, sc._end_button.get_global_rect()]
	# the fight log's LOG button, and the log while it is open (`FightLog`)
	avoid.append_array(FightLog.rects(sc))
	var ship := sc._view.ship_view()
	if ship != null:
		avoid.append(_ship_box(ship))
	# your name, hull and chips under it
	if sc._self_plate != null and sc._self_plate.is_visible_in_tree():
		avoid.append(sc._self_plate.get_global_rect())
	for i in 8:
		var sl := sc._view.slot(i)
		if sl == null or not sl.is_visible_in_tree():
			continue
		avoid.append(sl.get_global_transform() * sl.ink_rect())
		var ir := sl.intent_rect_global()
		if ir.size.x > 0.0:
			avoid.append(ir)
	return avoid


## The wreck's (or an event reward's) window, if one is open on LOCAL.
func _transfer(sc: SectorScreen) -> TransferView:
	if sc == null:
		return null
	if sc._transfer != null and is_instance_valid(sc._transfer) and sc._transfer.is_visible_in_tree():
		return sc._transfer
	var d := sc._events
	if d != null and is_instance_valid(d) and d._transfer != null and is_instance_valid(d._transfer) \
			and d._transfer.is_visible_in_tree():
		return d._transfer
	return null


## A third of the tank or less. See `RunState.fuel_low_at`.
func _fuel_low() -> bool:
	if Run.hull == null or Run.map.is_empty() or Run.node_at() == null:
		return false
	return Run.fuel_low()


func _hud_rect() -> Rect2:
	if Router.hud != null and is_instance_valid(Router.hud) and Router.hud.is_visible_in_tree():
		return Router.hud.get_global_rect()
	return Rect2()


## The global box round the visible ones of `nodes`.
func _union(nodes: Array) -> Rect2:
	var r := Rect2()
	for c in nodes:
		if c is Control and (c as Control).is_visible_in_tree() and (c as Control).size.x > 0.0:
			var g := (c as Control).get_global_rect()
			r = g if r.size == Vector2.ZERO else r.merge(g)
	return r
