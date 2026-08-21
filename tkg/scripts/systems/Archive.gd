class_name Archive
extends RefCounted

## What you have read. Survives the ship.
##
## A dive ends and the hull is gone; what you read, you have read. That is the
## second crack in `CLAUDE.md`'s "the flight record is a record, not
## meta-progression", and it is safe for exactly the reason `Unlocks` was: **an
## entry grants no power.** It widens what you know and changes nothing about how
## hard the next run is. A player with the whole archive is not a stronger
## player, they are a player who has read more of somebody else's post.
##
## STORED, NOT DERIVED, and that is a deliberate departure from `Unlocks`.
##
## Unlocks folds over `RunHistory` because the question it asks — "which houses
## have you won with" — is answerable from the record. This one is not: a
## document is recovered at a node, in a galaxy that is gone the moment the run
## ends, and the record does not carry where you were standing when you read
## something. So there is a file. The cost is a file that can desync or be
## deleted, and the mitigation is that losing it costs nothing but rereading.
##
## Positional, like everything else that belongs to a place. Which document a
## system holds is drawn from `Rng.derive(&"doc", index)`, so four ships at one
## wreck find the SAME page — and unlike the loot bag, nobody has to race for it.
## Knowledge is the one thing in this game that is not a contested resource, and
## that is worth keeping: a party reading over each other's shoulders is the only
## warm thing in the setting.

const PATH := "user://archive.json"

## How often a system that could hold a document actually does.
##
## Low, and it is a floor rather than a rate: this fires only where the game is
## already handing you something — a stripped wreck, a scooped pulsar, a won
## fight — so a run's chances are the number of those you chose to do. Greed is
## still the clock; this just puts something at the bottom of it that is not a
## better gun.
const FIND_CHANCE := 0.22

## Cached across the session. The file is read once and written on change, which
## is the same shape `RunHistory` uses and for the same reason: this is touched
## on arrival at a node, and a disk read per jump is a disk read per jump.
static var _found: Dictionary = {}
static var _loaded: bool = false


## Everything read, by id.
static func found() -> Dictionary:
	if not _loaded:
		_load()
	return _found


static func has(id: StringName) -> bool:
	return found().has(id)


static func count() -> int:
	return found().size()


static func total() -> int:
	return DB.documents.size()


## Recovered, with the place it came from written into it.
##
## The place is the half that makes two copies of one manifest different
## documents — `docs/lore.md` §5 — so it is stored beside the id rather than
## thrown away. Returns false when it was already read, which is what stops a
## second visit reporting a find.
static func recover(id: StringName, where: String) -> bool:
	if not DB.documents.has(id) or has(id):
		return false
	found()[id] = where
	_save()
	return true


## Where a document was recovered, or empty for one you have not read.
static func where(id: StringName) -> String:
	return String(found().get(id, ""))


## Whether this system is holding a page, and which one.
##
## POSITIONAL AND IDEMPOTENT. Both halves are load-bearing: positional so a party
## at one wreck reads one page, idempotent so that leaving a system and coming
## back does not roll again — which would make re-visiting a wreck a way to farm
## the archive, and would put the only content gated on DEPTH behind patience
## instead.
##
## Returns an empty StringName when this system holds nothing, which is most of
## them.
static func at_node(n: MapGen.MapNode) -> StringName:
	if n == null:
		return &""
	var r := Rng.derive(&"doc", n.index)
	if r.randf() >= FIND_CHANCE:
		return &""
	var pool := DB.documents_by_depth(n.layer)
	if pool.is_empty():
		return &""
	# Weighted toward the deep end of what this system could hold, so that flying
	# inward changes what you find rather than only how much. Squaring a uniform
	# roll pulls the pick toward the end of a list sorted shallow-to-deep.
	var t := r.randf()
	var i := clampi(int(floor(t * t * float(pool.size()))), 0, pool.size() - 1)
	return (pool[pool.size() - 1 - i] as DocumentData).id


# --- disk -----------------------------------------------------------------

static func _load() -> void:
	_loaded = true
	_found = {}
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	# Filtered against the catalogue on the way in. An id that no longer exists
	# is a document that was cut between builds, and carrying it would show the
	# player a count they can never complete.
	for k in (parsed as Dictionary):
		var id := StringName(k)
		if DB.documents.has(id):
			_found[id] = String((parsed as Dictionary)[k])


static func _save() -> void:
	var out: Dictionary = {}
	for id in _found:
		out[String(id)] = _found[id]
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Archive: could not write %s (%d)" % [
			PATH, FileAccess.get_open_error()])
		return
	f.store_string(JSON.stringify(out, "\t"))
	f.close()


## For the tests, and for a player who wants the discovery back.
static func wipe() -> void:
	_found = {}
	_loaded = true
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


## THE ONE DOOR. Rolls, records, and says so in the log.
##
## Called from the three places the game already hands you something — the wreck
## you stripped, the pulsar you flew, the fight you won — rather than from
## arrival, because a page that turns up for being somewhere is a page you did
## not go and get. It returns quietly when this system holds nothing, which is
## most of them, so every call site is one line with no branch.
static func recover_at(n: MapGen.MapNode, from: String) -> StringName:
	var id := at_node(n)
	if id == &"" or has(id):
		return &""
	var d: DocumentData = DB.documents[id]
	if not recover(id, "%s · %s · layer %d" % [MapGen.star_name(n), from, n.layer]):
		return &""
	# Named but not quoted. The log says a thing was found; the archive is where
	# it is read. A log line that printed the document would put a hundred and
	# fifty words in the middle of a fight's aftermath.
	Run.log_line("Something aboard was still readable. %s recovered." % d.title, &"good")
	Sig.archive_changed.emit()
	return id
