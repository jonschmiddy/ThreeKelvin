extends Harness

## Does the first flight keep its promise?
##   godot --headless --path . -- tutorialtest
##
## A GATE over two different things that fail two different ways:
##
## **The curated seed.** TutorialOverlay.SEED is a number somebody verified
## once, against an option table and a map generator that both keep moving.
## The overlay degrades politely when the seed rots -- "jump anywhere in
## reach" -- which is exactly why nothing in a played run would ever say so.
## This asserts the CHART step found a real recommendation.
##
## **The step machine.** Every transition rides the signal bus, and a bus
## connection fails silently: the panel just stops advancing, and the only
## symptom is a player who has done the thing the panel still asks for. So
## this drives the real Router through the real lesson -- chart, jump, resolve
## an encounter, fight the fight -- and asserts the overlay walked its five
## steps alongside.
##
## `_process` is called by hand where a played run would tick it, because this
## harness runs inside one frame and the SETTLE step polls by design.

func run() -> void:
	var ov: TutorialOverlay = TutorialOverlay._live
	if ov == null:
		_fail("no overlay in the tree -- Main stopped building it")
		verdict("tutorialtest")
		return

	Router.new_tutorial()
	_ok("tutorial opens on WELCOME, on the sector",
		ov._step == TutorialOverlay.Step.WELCOME
		and Router.current is SectorScreen)
	_ok("the curated run flies the korvan medium",
		Run.hull != null and Run.hull.manufacturer == &"korvan")

	Router.show_starchart()
	if not _ok("opening the chart advances to CHART",
			ov._step == TutorialOverlay.Step.CHART):
		verdict("tutorialtest")
		return
	# The seed's whole job. -1 here means SEED no longer carries the lesson
	# and the constant needs re-picking: godot --headless --path . -- tutseed
	if not _ok("the curated seed offers a recommendation one jump out",
			ov._target >= 0):
		verdict("tutorialtest")
		return

	Router.jump_to(ov._target)
	_ok("arrival is quiet -- no ambush on the first jump",
		not Router.in_combat())
	_ok("the jump advances to SETTLE",
		ov._step == TutorialOverlay.Step.SETTLE)

	# Resolve the first peaceful encounter the way the sector's in-place path
	# does. The overlay must notice on its next tick, because this path swaps
	# no screen and fires no signal.
	var n: MapGen.MapNode = Run.node_at()
	var calm := -1
	var fight := -1
	for i in n.options.size():
		if TutorialOverlay._fights(OptionTable.by_id(n.options[i])):
			fight = i
		elif calm < 0:
			calm = i
	if not _ok("the recommended system holds both halves of the lesson",
			calm >= 0 and fight >= 0):
		verdict("tutorialtest")
		return
	Router.option_resolved(calm)
	ov._process(0.016)
	_ok("a resolved encounter is noticed by the poll", ov._did_calm)
	_ok("half a lesson does not finish it",
		ov._step == TutorialOverlay.Step.SETTLE)

	# The fight the contact's Engage outcome opens, played by the sim's pilot.
	Router.start_ambush()
	if not _ok("a fight advances to FIGHT",
			ov._step == TutorialOverlay.Step.FIGHT):
		verdict("tutorialtest")
		return
	var cb: Combat = Router.combat
	var pilot := Policy.new()
	var turns := 0
	while not cb.finished and turns < 60:
		turns += 1
		var acted := true
		while acted and not cb.finished:
			acted = false
			while cb.choosing > 0:
				cb.choose(cb.best_choice())
				acted = true
			var best := pilot.best_card(cb)
			if best >= 0:
				cb.play(best)
				acted = true
		if not cb.finished:
			cb.end_turn()
	_ok("the pilot survived its own tutorial", not Run.dead)
	_ok("the fight's end lands on WRAP",
		ov._step == TutorialOverlay.Step.WRAP)

	# And the way out: FINISH is _end, and a dead panel stays dead.
	ov._end()
	_ok("finishing puts the panel away",
		ov._step == TutorialOverlay.Step.OFF and not ov.visible)

	# The screen swaps above autosaved a throwaway run over whatever was on
	# disk before the harness ran. Nothing can put that back, but a tutorial
	# bookmark left behind would resume as a half-spent system.
	SaveGame.clear()
	verdict("tutorialtest")
