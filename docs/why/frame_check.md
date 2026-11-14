The reasoning behind `tools/frame_check.py`, the gate's per-frame ratchet.

## What it catches

The game draws 60 times a second, so a frame has 16 ms. Some work is cheap once and a hitch when
it is done every frame: parsing a colour out of a hex string (`Color("#10161f")`), loading a
resource, building an Image or a texture, searching the scene tree, opening a file, parsing JSON,
copying a nested Array, building a material or a style box. Reviews kept finding these inside
`_draw` and `_process`, a few at a time, months after they went in. Each one is small. Together
they are the hitches a player feels and nobody can point to.

The tool reads `tkg/scripts` (not `sim`, whose harnesses are not the game) and finds, in the body
of a per-frame function, any call from a short fixed list:

- `load(` and `ResourceLoader.load(` (not `preload(`, which is done when the script loads, and not
  `cfg.load(`, a method of another object)
- `Image.create(`, `Image.create_empty(`, `Image.create_from_data(`, `Image.load_from_file(`,
  `.get_image(`, `ImageTexture.create_from_image(`, `ImageTexture.new(`
- `Color("`, `Color.html(`, `Color.from_string(` with a string literal as the argument: a
  constant colour parsed again every frame. `Color(some_variable)` is not flagged.
- `find_child(`, `find_children(`, `get_nodes_in_group(`
- `FileAccess.open(`, `FileAccess.file_exists(`, any `DirAccess.`
- `JSON.parse_string(`, `JSON.stringify(`, `str_to_var(`, `var_to_str(`
- `.duplicate(true)`, `ShaderMaterial.new(`, `Shader.new(`, `StyleBoxFlat.new(`

The list is short on purpose: every entry is a call that is nearly always wrong in a frame. A
broader list would be noisy and the noise would teach people to ignore the check.

## Which functions are per-frame

`_process`, `_physics_process` and `_draw`, written with the engine's own parameters (`_draw()`
takes none, `_process(delta)` one; a project function that reuses the name with more parameters,
like `_draw(vp, shader, n)`, is not the engine's). `_input` and the rest of the `_input` family
are per event, not per frame, and are left out.

Plus one level of calls in the same file: if `_process` calls `_tick(delta)` or `_draw` calls
`_cell(...)`, then `_tick` and `_cell` count too, because the project splits its per-frame work
into helpers. The call must be bare (`_tick()` or `self._tick()`), the helper must be in the same
class (an inner class's `_draw` does not reach the outer class's helper of the same name), and it
stops there: a helper's helper is not followed. **Calls across files are not followed in this
version.** `_draw` in one file calling `Widgets.paint(...)` in another is not seen, so the real
count is higher than the baseline.

## What is not flagged: lazy initialisation

Guarded code still counts (an `if` inside `_process` does not make a call free) except the common
cache idiom, which does the work once:

- the call is inside `if X == null:`, `if not X:`, `if X.is_empty():`, `if not cache.has(k):`,
  or `if _built != size:` (a rebuild when its key changed), and that block assigns to X (or to the
  cache). A condition joined with `and`/`or` counts if any term is one of these, so
  `if visible and not _done:` with `_done = true` inside is a once-flag.
- the call is after an early return on a member the function then fills, and the return is a genuine cache
  guard: `if _cache.has(k): return _cache[k]` ... `_cache[k] = v`; also `if X != null: return`, `if X: return X`,
  `if not X.is_empty(): return`, `if _built == size: return`. Any other comparison is a throttle
  (`if _acc < 0.1: return`, then a load, then `_acc = 0.0`), which still loads on every pass that gets
  through, so the call stays counted.
- the helper is called from a frame function inside such a guard and fills the guarded member
  itself: `if _vp == null: _runtime()` where `_runtime` sets `_vp`. The helper is then not
  treated as per-frame at all.

## How a key is formed

`frame <file>::<function> <call>`, for example `frame scripts/ui/BoxGauge.gd::_cell Color("`. One
entry per distinct call per function. A function that appears twice in a file (an inner class's)
is `name#2`, as in `tools/code_check.py`. Never a line number, so an unrelated edit does not churn
`tools/frame_check_baseline.txt`.

The baseline records how many times the call appears in that function, and the count may not
grow. A second `load(` in a function that already has one is `GREW`, not silently fine: a count
that could grow freely would let a function pile on. A count that falls is reported (`SHRANK`) and
does not fail, so two branches never fight over the file.

## `--update`: when it is legitimate, and when it is cheating

Legitimate: you fixed some of the debt (the entry is gone or smaller) and want the baseline to
say so. Or the detector was wrong about a call that is truly once-only and you cannot restructure
it: say why in the PR. `--update` prints every entry it ADDED or grew, so that shows in the diff.

Cheating: the check failed on code you just wrote and you re-record it to make the gate green. The
fix is nearly always one line: build it once in `_ready` or on first use and keep it in a member;
for a colour, a `const`. If the work really must happen in the frame, say so in the PR.

## `--report`

`python3 tools/frame_check.py --report` lists everything found, by file, worst first. It is the
to-do list for paying the debt down; it never fails.

## What it deliberately does not catch

- Calls across files, and helpers more than one call away.
- Per-frame code that is not named `_process`, `_physics_process` or `_draw`: a `Timer` callback,
  a signal handler fired every frame, a `Tween` step, a loop in `await get_tree().process_frame`.
- Work that is expensive but not in the list (building a `PackedVector2Array` of thousands of
  points, `instantiate()`, `Time.get_datetime_dict_from_system()`). Add it here when a review finds
  it in a frame, with a hand-check that it is rarely right.
- A `_draw` runs when the node asks to be redrawn, which may be every frame or only when
  something changed. The check cannot tell, so it treats every `_draw` as per-frame.
- Calls that sit in a frame function but run rarely: a helper reached only when a timer fires
  (`Audio._deal_pa`), or a warm-up queue that is meant to do one load per frame
  (`ShaderWarm._process`). They are baselined, not fixed; the rule is a lead, not a verdict.
