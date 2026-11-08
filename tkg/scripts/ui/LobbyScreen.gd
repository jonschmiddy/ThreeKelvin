class_name LobbyScreen
extends Control

## Reads `Net` and holds no state of its own; the address problem is why a relay exists.
## Why: docs/why/LobbyScreen.md#lobby-design

const READY_COLOUR := UITheme.GOOD

## Keeps the text, not the fields: `Widgets.clear()` frees them, so a held LineEdit crashes.
var _name_text: String = ""
var _code_text: String = ""
var _host_text: String = ""

var _name_field: LineEdit
var _code_field: LineEdit
var _host_field: LineEdit
var _body: VBoxContainer
var _status: Label
## Set by `-- lobby host` or `-- lobby join CODE`, the only way to test two lobbies.
var _scripted: bool = false
var _pending: bool = false
## `auto` presses READY and LAUNCH to prove two machines build one galaxy from a seed.
var _auto: bool = false
## `wait N` holds the launch until N ships are in, to prove four machines agree.
var _crowd: int = 0
var _wait_for: int = 2


## How to leave. Empty means "this is a whole screen, go back to the title";
## the launcher sets it so the same class can be a panel ON the title instead.
var on_leave: Callable = Callable()

func setup() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Never disconnected: leaving this screen is not leaving the party, so nothing to tear down.
	# Why: docs/why/LobbyScreen.md#party-signals
	Sig.party_changed.connect(_rebuild)
	Sig.party_state_changed.connect(func(_s: int) -> void: _rebuild())
	Sig.party_failed.connect(func(_r: String) -> void: _rebuild())
	Sig.party_launched.connect(_on_launched)

	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 8)
	add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.add_child(UITheme.header("PARTY"))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(gap)
	head.add_child(Widgets.button("BACK", _leave))
	col.add_child(head)
	col.add_child(UITheme.hsep())

	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 8)
	col.add_child(_body)

	_status = UITheme.body("", UITheme.COLD, UITheme.FS_BODY)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_status)

	# Defaults live in `setup()`, as the rebuild is deferred; callsigns differ per window.
	# Why: docs/why/LobbyScreen.md#defaults
	_name_text = "PILOT-%d" % (randi() % 900 + 100)
	_host_text = DirectTransport.new().public_guess()

	_rebuild()
	_run_flags()


## Flags exist because testing a lobby means two instances, and make the party path headless.
## Why: docs/why/LobbyScreen.md#dev-flags
func _run_flags() -> void:
	var argv := OS.get_cmdline_user_args()
	if "lobby" not in argv:
		return
	_auto = "auto" in argv
	for i in argv.size():
		if argv[i] == "wait" and i + 1 < argv.size():
			_wait_for = maxi(2, int(argv[i + 1]))
	if "host" in argv:
		_scripted = true
		# `crowd N` fakes the roster to check READY and LAUNCH DIVE fit, without N real peers.
		# Why: docs/why/LobbyScreen.md#dev-flags
		for i in argv.size():
			if argv[i] == "crowd" and i + 1 < argv.size():
				_crowd = clampi(int(argv[i + 1]), 1, 7)
		# `-- lobby host relay ws://localhost:8787` for a local wrangler dev.
		if "relay" in argv:
			_host(RelayTransport.new())
		else:
			var t := DirectTransport.new()
			t.advertise = _host_text.strip_edges()
			_host(t)
		return
	for i in argv.size():
		if argv[i] == "join" and i + 1 < argv.size():
			_scripted = true
			_code_text = LobbyCode.normalise(argv[i + 1])
			_join()
			return


## Only under dev flags: a lobby that cannot be watched from a terminal cannot be scripted.
func _narrate() -> void:
	if not _scripted:
		return
	if Net.state == NetSession.State.FAILED:
		print("[lobby] failed: %s" % Net.last_error())
		return
	if Net.state == NetSession.State.JOINING:
		print("[lobby] connecting")
		return
	if Net.is_host() and Net.transport != null and not Net.transport.code.is_empty():
		print("[lobby] code %s" % LobbyCode.pretty(Net.transport.code))
	var who: PackedStringArray = []
	for slot in Net.slots():
		who.append("%s%s" % [slot.name, "*" if slot.ready else ""])
	print("[lobby] %d/%d  %s" % [
		Net.party_size(), NetSession.MAX_PLAYERS, " ".join(who)])


# --- the three faces ------------------------------------------------------

## Coalesced to once a frame: three rebuilds in one frame threw away the field and focus.
func _rebuild() -> void:
	if _body == null or _pending:
		return
	_pending = true
	_do_rebuild.call_deferred()


func _do_rebuild() -> void:
	_pending = false
	if _body == null:
		return
	Widgets.clear(_body)
	_narrate()
	match Net.state:
		NetSession.State.OFFLINE:
			_build_offline()
		NetSession.State.JOINING:
			_build_waiting()
		NetSession.State.FAILED:
			_build_failed()
		_:
			_build_party()


func _build_offline() -> void:
	_status.text = ""

	var mine := VBoxContainer.new()
	mine.add_theme_constant_override("separation", 4)
	mine.add_child(UITheme.body("CALLSIGN", UITheme.COLD, UITheme.FS_SMALL))
	_name_field = _field(_name_text, 14)
	_name_field.text_changed.connect(func(t: String) -> void: _name_text = t)
	mine.add_child(_name_field)
	_body.add_child(Widgets.panel_with(Widgets.pad(mine, 8, 5)))

	_body.add_child(_host_box())

	var join_box := Widgets.section("JOIN")
	var jrow := HBoxContainer.new()
	jrow.add_theme_constant_override("separation", 6)
	jrow.add_child(UITheme.body("CODE", UITheme.COLD, UITheme.FS_SMALL))
	_code_field = _field(_code_text, 16)
	# Corrected as typed, so seeing O become 0 teaches the alphabet before a refusal does.
	_code_field.text_changed.connect(_normalise_code)
	jrow.add_child(_code_field)
	if _can_clip():
		jrow.add_child(Widgets.button("PASTE", func() -> void:
			_code_text = LobbyCode.normalise(DisplayServer.clipboard_get())
			_rebuild()))
	jrow.add_child(Widgets.button("JOIN PARTY", _join))
	join_box.add_child(jrow)
	_body.add_child(join_box)


## Relay is offered first as the ordinary choice; Direct stays for LAN, planes and relay outages.
## Why: docs/why/LobbyScreen.md#host-options
func _host_box() -> Control:
	var box := Widgets.section("HOST")

	if RelayTransport.is_configured():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.add_child(Widgets.button("HOST PARTY", func() -> void: _host(RelayTransport.new())))
		row.add_child(UITheme.body("over the internet", UITheme.CHILL, UITheme.FS_SMALL))
		box.add_child(row)
		box.add_child(UITheme.body(
			"Gives you a code to send. Nobody opens a port and nobody types an"
			+ " address.", UITheme.QUOTE, UITheme.FS_SMALL))
		box.add_child(UITheme.hsep())
	else:
		box.add_child(UITheme.body(
			"No relay is configured in this build, so a party can only be opened"
			+ " directly. See relay/README.md.", UITheme.THEM, UITheme.FS_SMALL))

	var addr := HBoxContainer.new()
	addr.add_theme_constant_override("separation", 6)
	addr.add_child(UITheme.body("ADDRESS", UITheme.COLD, UITheme.FS_SMALL))
	_host_field = _field(_host_text, 16)
	_host_field.text_changed.connect(func(t: String) -> void: _host_text = t)
	addr.add_child(_host_field)
	addr.add_child(Widgets.button("HOST DIRECT", func() -> void:
		var t := DirectTransport.new()
		t.advertise = _host_text.strip_edges()
		_host(t)))
	box.add_child(addr)
	var note := ("Direct opens port %d on this machine. The address above is"
		+ " this machine on the local network; friends in the house can use it"
		+ " as it stands. Anyone outside needs your public address typed over"
		+ " it, and the port forwarded here.") % DirectTransport.DEFAULT_PORT
	var note_label := UITheme.body(note, UITheme.QUOTE, UITheme.FS_SMALL)
	# The one unwrapped long note: as a panel it widened the column and ran off the edge.
	note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note_label)
	return box


func _build_waiting() -> void:
	_body.add_child(UITheme.header("CONNECTING"))
	_body.add_child(UITheme.body("Reaching the host.", UITheme.CHILL, UITheme.FS_BODY))
	_status.text = ""


func _build_failed() -> void:
	_body.add_child(UITheme.header("NO PARTY"))
	var msg := UITheme.body(Net.last_error(), UITheme.THEM, UITheme.FS_BODY)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_child(msg)
	_body.add_child(Widgets.button("TRY AGAIN", func() -> void:
		Net.leave_party()
		_rebuild()))


func _build_party() -> void:
	if Net.is_host():
		_body.add_child(_code_box())

	var roster := Widgets.section("SHIPS (%d/%d)" % [
		Net.party_size(), NetSession.MAX_PLAYERS])
	# The list scrolls to protect READY and LAUNCH DIVE; at about six ships they leave the screen.
	# Why: docs/why/LobbyScreen.md#roster-scroll
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for slot in Net.slots():
		rows.add_child(_slot_row(slot))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Four rows' worth, then it scrolls; a party of two does not sit in a tall empty box.
	scroll.custom_minimum_size = Vector2(0, 0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	roster.add_child(scroll)
	_body.add_child(roster)
	# The roster is the one part that grows, so it gets the leftover height or the scroll is dead.
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	roster.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	var me: Dictionary = Net.roster.get(Net.local_id(), {})
	var ready := bool(me.get("ready", false))
	actions.add_child(Widgets.button("NOT READY" if ready else "READY",
		func() -> void: Net.set_ready(not ready)))
	if Net.is_host():
		actions.add_child(Widgets.button("LAUNCH DIVE", func() -> void:
			if not Net.launch_dive():
				_status.text = Net.last_error()))
	_body.add_child(actions)
	if _auto:
		_drive.call_deferred()

	if Net.is_host():
		_status.text = "" if Net.everyone_ready() \
			else "Waiting for everyone to be ready."
	else:
		_status.text = "The host starts the dive."


## COPY is not a convenience: hand-transcribing 14 characters defeats the check character.
## Why: docs/why/LobbyScreen.md#copy-button
func _code_box() -> Control:
	var box := Widgets.section("CODE")
	var pretty := LobbyCode.pretty(Net.transport.code)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(UITheme.header(pretty))
	if _can_clip():
		var copy := Widgets.button("COPY", func() -> void: _copy(pretty))
		copy.name = "Copy"
		row.add_child(copy)
	box.add_child(row)

	# Without autowrap the note claimed about 1200 px and pushed BACK and READY off screen.
	# Why: docs/why/LobbyScreen.md#note-wrapping
	var note := UITheme.body(
		"Send this to your friends. They paste it into FLY TOGETHER > JOIN."
		+ " Dashes and capitals do not matter, and there is no letter O or I"
		+ " in it: anything that looks like one is a zero or a one.",
		UITheme.QUOTE, UITheme.FS_SMALL)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)
	return box


## Confirmed on the button and restored after a beat, or the player copies twice.
func _copy(text: String) -> void:
	DisplayServer.clipboard_set(text)
	var b := _find_button("Copy")
	if b == null:
		return
	b.text = "COPIED"
	b.disabled = true
	await get_tree().create_timer(1.2).timeout
	# The screen rebuilds on every roster change, so by now the button may be
	# a different button, or gone.
	var still := _find_button("Copy")
	if still != null:
		still.text = "COPY"
		still.disabled = false


## Headless has no clipboard and `clipboard_get()` pushes an error, so the buttons are absent.
func _can_clip() -> bool:
	return DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD)


func _find_button(named: String) -> Button:
	return _body.find_child(named, true, false) as Button


## The `auto` flag runs through the normal rebuild, so a scripted test walks the real path.
func _drive() -> void:
	var me: Dictionary = Net.roster.get(Net.local_id(), {})
	if not bool(me.get("ready", false)):
		Net.set_ready(true)
		return
	if Net.is_host() and Net.party_size() >= _wait_for and Net.everyone_ready():
		Net.launch_dive()


func _slot_row(slot: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var who := String(slot.name)
	if int(slot.id) == 1:
		who += "  (host)"
	if int(slot.id) == Net.local_id():
		who += "  (you)"
	row.add_child(UITheme.body(who, UITheme.ICE, UITheme.FS_BODY))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gap)
	row.add_child(Widgets.chip("READY" if slot.ready else "STANDING BY",
		READY_COLOUR if slot.ready else UITheme.LINE))
	return Widgets.panel_with(Widgets.pad(row, 8, 5))


# --- what the buttons do --------------------------------------------------

func _host(t: NetTransport) -> void:
	var code := Net.host_party(_callsign(), &"", t)
	if code.is_empty():
		_status.text = Net.last_error()
		return
	if _crowd > 0:
		_fill_crowd()
	_rebuild()


## Dev only. See the `crowd` flag in _run_flags().
func _fill_crowd() -> void:
	for i in _crowd:
		var id := 2 + i
		Net.roster[id] = {"id": id, "name": "PILOT-%d" % (200 + i * 37),
			"hull": &"", "ready": i % 2 == 0, "order": 1 + i,
			"build": {}, "at": -1}
	Sig.party_changed.emit()


## No transport choice on joining: the code says which kind of party it is.
func _join() -> void:
	if not Net.join_party(_code_text, _callsign(), &"", NetTransport.for_code(_code_text)):
		_status.text = Net.last_error()
		return
	_rebuild()


func _leave() -> void:
	Net.leave_party()
	if on_leave.is_valid():
		on_leave.call()
		return
	Router.show_launcher()


## Both machines derive the same galaxy from the seed; the party lands on chassis select.
## Why: docs/why/LobbyScreen.md#launch-seed
func _on_launched(seed_value: int) -> void:
	if _scripted:
		print("[lobby] dive on seed %d" % seed_value)
	Router.new_run(seed_value)
	if _scripted:
		print("[lobby] galaxy %s (%s) — %d systems" % [
			Run.galaxy_name, Run.galaxy_title, Run.map.size()])


# --- bits -----------------------------------------------------------------

func _callsign() -> String:
	var n := _name_text.strip_edges()
	return n if not n.is_empty() else "PILOT"


func _normalise_code(_t: String) -> void:
	var at := _code_field.caret_column
	var clean := LobbyCode.normalise(_code_field.text)
	_code_text = clean
	if clean == _code_field.text:
		return
	_code_field.text = clean
	_code_field.caret_column = mini(at, clean.length())


## Moved to `UITheme.field` when the ship's rename box became the second user.
func _field(initial: String, chars: int) -> LineEdit:
	var e := UITheme.field(chars)
	e.text = initial
	return e
