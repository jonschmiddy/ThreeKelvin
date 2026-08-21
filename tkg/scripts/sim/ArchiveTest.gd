extends RefCounted

## The archive, checked from outside:  godot --headless --path . -- archivetest
##
## Two halves, and the second is the one that will actually catch something.
##
## The MACHINERY half is ordinary: a node holds the same page every time it is
## asked, nothing deeper than the shell is offered, the file round-trips, and a
## page already read is not found twice.
##
## The CONTENT half is a style gate, and it exists because `docs/lore.md` §5's
## rules are prose and prose rots. "It fits on one screen" is a convention that
## nobody will remember in eight months, and the failure mode is not a crash —
## it is an archive that has quietly become a wiki. A test is the only thing that
## reads every entry on every commit.

## `docs/lore.md` §5: "A hundred and fifty words is a long entry." Enforced at
## two hundred, because the rule is a target and this is a backstop — an entry
## at 180 is a long entry and an entry at 400 is a different kind of thing.
const WORD_CAP := 200

var _fails: int = 0


func run() -> void:
	Archive.wipe()
	_machinery()
	_content()
	print("")
	print("archivetest: %s" % ("PASS" if _fails == 0 else "%d FAILURES" % _fails))
	Archive.wipe()


func _machinery() -> void:
	Rng.reseed(4242, 0)
	Run.map = MapGen.generate(Rect2(0, 0, 1000, 700))

	# The same system holds the same page however often it is asked. Idempotent
	# rather than merely seeded: a second visit to a wreck must not re-roll, or
	# the only content gated on DEPTH is farmable by patience.
	var stable := true
	var holding := 0
	for n in Run.map:
		var node: MapGen.MapNode = n
		var a := Archive.at_node(node)
		if a != Archive.at_node(node):
			stable = false
		if a != &"":
			holding += 1
			# The depth gate, checked against the node that offered it rather
			# than against the table. A page from layer eight turning up at the
			# rim is the one failure that would go unnoticed in play.
			var d: DocumentData = DB.documents[a]
			if d.depth > node.layer:
				_ok("a layer %d system offered a depth %d page" % [
					node.layer, d.depth], false)
				break
	_ok("a system holds the same page every time it is asked", stable)
	_ok("and some systems hold one at all", holding > 0)
	# Not so many that the archive fills in one run. Sixteen entries against a
	# 150-system galaxy: this is the number that decides whether the deep pages
	# are ever actually deep.
	print("  %d of %d systems are holding something" % [holding, Run.map.size()])

	# Recovering, and refusing to recover twice.
	var id: StringName = DB.documents.keys()[0]
	_ok("a page recovers", Archive.recover(id, "a test"))
	_ok("and is not recovered a second time", not Archive.recover(id, "again"))
	_ok("and remembers where it came from", Archive.where(id) == "a test")
	_ok("and counts", Archive.count() == 1)

	# Round-trip through the file, which is the part `Unlocks` deliberately does
	# not have and therefore the part with somewhere to go wrong.
	Archive._loaded = false
	Archive._found = {}
	_ok("it survives a reload", Archive.has(id))
	_ok("with its place intact", Archive.where(id) == "a test")


func _content() -> void:
	var seen: Dictionary = {}
	var longest := 0
	var longest_id := ""
	for key in DB.documents:
		var d: DocumentData = DB.documents[key]
		if seen.has(d.title):
			_ok("two entries share the title %s" % d.title, false)
		seen[d.title] = true
		if d.title.strip_edges().is_empty() or d.body.strip_edges().is_empty():
			_ok("%s has a title and a body" % d.id, false)
		# Every document was written by somebody with a job. An entry with no
		# author is an entry written by the game, which is the one thing the
		# archive must never contain.
		if d.by.strip_edges().is_empty():
			_ok("%s names who held the pen" % d.id, false)
		if d.dated.strip_edges().is_empty():
			_ok("%s is dated in some epoch" % d.id, false)
		if d.depth < 0 or d.depth >= MapGen.LAYERS:
			_ok("%s sits at a reachable depth" % d.id, false)
		var words := d.body.split(" ", false).size()
		if words > longest:
			longest = words
			longest_id = String(d.id)
		if words > WORD_CAP:
			_ok("%s is %d words, over the %d cap" % [d.id, words, WORD_CAP], false)

	_ok("every entry has an author, a date, a depth and a body", true)
	_ok("and none of them has become an essay", longest <= WORD_CAP)
	print("  %d entries, longest is %s at %d words" % [
		DB.documents.size(), longest_id, longest])

	# The depth spread, because the gate is only interesting if it is used. An
	# archive whose entries all sit at zero is an archive with no reason to fly
	# inward, and that is a content bug no assertion above would catch.
	var deep := 0
	for key in DB.documents:
		if (DB.documents[key] as DocumentData).depth >= 5:
			deep += 1
	_ok("and some of it is only readable deep", deep >= 3)


func _ok(what: String, condition: bool) -> void:
	if condition:
		print("  ok   %s" % what)
	else:
		print("  FAIL %s" % what)
		_fails += 1
