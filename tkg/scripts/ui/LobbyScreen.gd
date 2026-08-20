class_name LobbyScreen
extends Control

## The party, before the dive. Read a code out, type a code in, watch four
## names arrive.
##
## This is the first screen `NetSession` has ever had. Everything it shows was
## already working headless — `-- nettest` forms a party of four in one process
## — so nothing here decides anything. It reads `Net` and it calls four methods
## on it. That is deliberate: the session layer must not learn about screens,
## and a lobby that held state of its own would be a second roster to disagree
## with the first.
##
## **The address problem is on this screen and it cannot be solved on it.**
## `DirectTransport` folds the host's address into the code, and a machine
## behind a router cannot learn its own public address by looking inward. So the
## host gets a LAN address by default and a field to type a real one over. That
## is honest rather than good, and it is the whole argument for the relay
## transport in `docs/netcode.md` §2.

const READY_COLOUR := UITheme.GOOD

## The text, not the fields. `Widgets.clear()` frees the children it removes,
## so a LineEdit held across a rebuild is a freed object by the time the next
## build tries to re-add it — which is a crash on the one path that rebuilds
## the offline face twice: fail to join, then press TRY AGAIN. The fields are
## rebuilt every time and only their contents persist.
var _name_text: String = ""
var _code_text: String = ""
var _host_text: String = ""

var _name_field: LineEdit
var _code_field: LineEdit
var _host_field: LineEdit
var _body: VBoxContainer
var _status: Label
## Set by `-- lobby host` or `-- lobby join CODE`. Drives the screen from the
## command line and narrates it to stdout, which is the only way two instances
## of a lobby can be tested without two humans and two keyboards.
var _scripted: bool = false
var _pending: bool = false
## `-- lobby host auto` / `-- lobby join CODE auto`: press READY on arrival, and
## LAUNCH as soon as everyone has. It exists to prove the one claim that cannot
## be checked from a single window — that two machines given one seed build one
## galaxy — without two people clicking at the same time.
var _auto: bool = false
## `-- lobby host auto wait 4` holds the launch until four ships are in. Without
## it the scripted host dives the moment the first joiner is ready, which is the
## right default for a two-instance smoke test and useless for proving that four
## machines agree.
var _wait_for: int = 2


## How to leave. Empty means "this is a whole screen, go back to the title";
## the launcher sets it so the same class can be a panel ON the title instead.
var on_leave: Callable = Callable()

func setup() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Connected, and never disconnected. Leaving this screen is not leaving the
	# party — the dive starts from here and the peer has to survive the swap
	# into the sector — so there is nothing to tear down. Godot drops the
	# connections with the node.
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

	# Defaults live here rather than in _build_offline(), because the rebuild is
	# deferred by a frame and the command-line flags below fire before it. The
	# fields are a view of these strings; nothing reads a field to decide
	# anything, which is what makes the two orders equivalent.
	#
	# A different callsign per instance, so two windows on one machine are
	# telling each other apart before the player has typed anything. Testing
	# this screen means running it twice, and two rows both reading PILOT is
	# the first thing that makes the roster unreadable.
	_name_text = "PILOT-%d" % (randi() % 900 + 100)
	_host_text = DirectTransport.new().public_guess()

	_rebuild()
	_run_flags()


## Dev flags:
##   godot --path . -- lobby host          opens a party, prints the code
##   godot --path . -- lobby join CODE     joins that code
##
## They exist because testing a lobby means running it twice at once, and
## reading a code off one window to type into another is a slow loop to be in
## while the thing you are changing is the code itself. They also make the whole
## party path testable headless, which is how this screen was checked at all.
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


## Only under the dev flags. A lobby narrating itself to a terminal nobody is
## reading is noise; a lobby that cannot be watched from a terminal cannot be
## tested by a script.
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

## Coalesced to once a frame. Opening a party emits `party_state_changed` and
## `party_changed` back to back and `_host()` asks for a redraw on top of them,
## so the screen was rebuilding itself three times in one frame — which throws
## away the field the player is typing in and the focus with it.
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
	_body.add_child(Widgets.panel_with(_pad(mine)))

	_body.add_child(_host_box())

	var join_box := Widgets.section("JOIN")
	var jrow := HBoxContainer.new()
	jrow.add_theme_constant_override("separation", 6)
	jrow.add_child(UITheme.body("CODE", UITheme.COLD, UITheme.FS_SMALL))
	_code_field = _field(_code_text, 16)
	# Corrected as it is typed rather than on submit. Seeing O become 0 is how
	# a player learns the alphabet has no O in it, instead of finding out from
	# a refusal thirty seconds later.
	_code_field.text_changed.connect(_normalise_code)
	jrow.add_child(_code_field)
	if _can_clip():
		jrow.add_child(Widgets.button("PASTE", func() -> void:
			_code_text = LobbyCode.normalise(DisplayServer.clipboard_get())
			_rebuild()))
	jrow.add_child(Widgets.button("JOIN PARTY", _join))
	join_box.add_child(jrow)
	_body.add_child(join_box)


## Two ways to open a party, and the difference between them is the whole of
## `docs/netcode.md` §1 compressed into two buttons.
##
## The relay is offered first and reads as the ordinary choice, because it is:
## nobody opens a port and nobody types an address. Direct stays because it is
## the only one that works with no service behind it — on a LAN, on a plane, or
## on the day the relay is down.
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
		+ " this machine on the local network — friends in the house can use it"
		+ " as it stands. Anyone outside needs your public address typed over"
		+ " it, and the port forwarded here.") % DirectTransport.DEFAULT_PORT
	var note_label := UITheme.body(note, UITheme.QUOTE, UITheme.FS_SMALL)
	# The only long note on this screen that was not wrapping. Harmless while the
	# lobby was a full screen; as a panel it pushed the whole column wider than
	# its frame and the text ran off the right-hand edge.
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
	for slot in Net.slots():
		roster.add_child(_slot_row(slot))
	_body.add_child(roster)

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


## The code, big, with a button that puts it on the clipboard.
##
## COPY is not a convenience. A lobby code is shared by pasting it into a chat
## window, and a code that can only be READ off the screen makes the player
## transcribe fourteen characters by hand into the one place a typo is most
## likely — which is the exact failure the check character exists to catch, now
## caused by the interface rather than caught by it.
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

	box.add_child(UITheme.body(
		"Send this to your friends. They paste it into FLY TOGETHER > JOIN."
		+ " Dashes and capitals do not matter, and there is no letter O or I"
		+ " in it — anything that looks like one is a zero or a one.",
		UITheme.QUOTE, UITheme.FS_SMALL))
	return box


## Confirmed on the button itself, and put back after a beat. A copy that says
## nothing leaves the player pressing it again to be sure, and pasting twice is
## how you end up with half a code in the chat window.
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


## Not every display server has one. Headless has none at all, and calling
## clipboard_get() there pushes an engine error for something the player never
## asked for — so the buttons are absent rather than broken, and the code stays
## readable on screen either way.
func _can_clip() -> bool:
	return DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD)


func _find_button(named: String) -> Button:
	return _body.find_child(named, true, false) as Button


## The `auto` flag, one step at a time. Deferred and re-entered through the
## normal rebuild, so it walks the same path a player's clicks would rather
## than a shortcut around it — a scripted test that skips the real methods
## proves the script works, not the screen.
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
	return Widgets.panel_with(_pad(row))


# --- what the buttons do --------------------------------------------------

func _host(t: NetTransport) -> void:
	var code := Net.host_party(_callsign(), &"", t)
	if code.is_empty():
		_status.text = Net.last_error()
		return
	_rebuild()


## No transport choice on this side, ever. The code says which kind of party it
## is — see NetTransport.for_code() — so the only thing a joining player has to
## get right is the code itself.
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


## The seed the host rolled, made into a galaxy on this machine.
##
## This is the payoff and it is worth being precise about what it proves: both
## machines now run `MapGen` and `GalaxyGen` over the same master seed, so both
## sectors hold the same systems with the same names, the same danger and the
## same shelves. Nothing is being kept in step — there are no gameplay messages
## yet. The galaxy agrees because it was derived, not because it was sent.
##
## It goes through Router.new_run() rather than starting a run here, so the
## party lands on the chassis select exactly as a solo run does. Four players
## pick four different ships on one galaxy, which is the party composition rule
## rather than an oversight.
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


## The first text field in the game, so it is styled here rather than in
## UITheme — one screen is not a pattern, and putting it in the theme would say
## the rest of the UI is expected to grow input fields.
func _field(initial: String, chars: int) -> LineEdit:
	var e := LineEdit.new()
	e.text = initial
	e.custom_minimum_size = Vector2(chars * 10, 0)
	e.add_theme_stylebox_override("normal", UITheme.bevel_in(UITheme.VOID, 4, 6))
	e.add_theme_stylebox_override("focus", UITheme.bevel_in(UITheme.VOID, 4, 6))
	e.add_theme_color_override("font_color", UITheme.ICE)
	e.add_theme_color_override("font_placeholder_color", UITheme.COLD)
	e.add_theme_color_override("caret_color", UITheme.EMBER)
	e.add_theme_font_size_override("font_size", UITheme.FS_BODY)
	return e


func _pad(child: Control) -> MarginContainer:
	var pad := MarginContainer.new()
	for side in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + side, 8)
	for side in ["top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 5)
	pad.add_child(child)
	return pad
