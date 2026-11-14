#!/usr/bin/env python3
"""Per-frame ratchet for game code (tkg/scripts, not sim): work that belongs in `_ready` or on first
use, found inside a function the engine calls every frame (`_process`, `_physics_process`, `_draw`) or
one that such a function calls in the same file: a `load(`, an Image or texture built, a colour parsed
from a string literal, a tree search, a file opened, JSON parsed, a deep copy, a material built.
What predates the rule is in tools/frame_check_baseline.txt; a recorded count may not grow.
Run: python3 tools/frame_check.py [--update] [--report] [--selftest]
Why the rule, the call list and what it cannot see: docs/why/frame_check.md."""
import re
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from code_check import function_spans, indent_of, lex  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
BASELINE = ROOT / "tools" / "frame_check_baseline.txt"
HEADER = (
    "# Per-frame work that predates tools/frame_check.py. The gate ignores these and fails on anything\n"
    "# new, or a count that grew. Shrink it by moving the work out of the frame, then: python3 tools/frame_check.py --update\n"
    "# frame <file>::<func> <call> <times it appears in that function>\n"
)

PER_FRAME = ("_process", "_physics_process", "_draw")

# (label, regex on a line whose string contents are masked, kind). The label is what the key and the report show.
# `(?<![\w.])` keeps `preload(` and `cfg.load(` out; a string literal is the quote left standing by the mask.
CALLS = [
    ("load(", r"(?<![\w.])load\(", "load"),
    ("ResourceLoader.load(", r"\bResourceLoader\.load\(", "load"),
    ("Image.create(", r"\bImage\.create\(", "image"),
    ("Image.create_empty(", r"\bImage\.create_empty\(", "image"),
    ("Image.create_from_data(", r"\bImage\.create_from_data\(", "image"),
    ("Image.load_from_file(", r"\bImage\.load_from_file\(", "image"),
    (".get_image(", r"\.get_image\(", "image"),
    ("ImageTexture.create_from_image(", r"\bImageTexture\.create_from_image\(", "image"),
    ("ImageTexture.new(", r"\bImageTexture\.new\(", "image"),
    ('Color("', r"(?<![\w.])Color\(\s*[\"']", "color"),
    ("Color.html(", r"\bColor\.html\(\s*[\"']", "color"),
    ("Color.from_string(", r"\bColor\.from_string\(\s*[\"']", "color"),
    ("find_child(", r"(?<![\w])find_child\(", "tree"),
    ("find_children(", r"(?<![\w])find_children\(", "tree"),
    ("get_nodes_in_group(", r"(?<![\w])get_nodes_in_group\(", "tree"),
    ("FileAccess.open(", r"\bFileAccess\.open\(", "file"),
    ("FileAccess.file_exists(", r"\bFileAccess\.file_exists\(", "file"),
    ("DirAccess.", r"\bDirAccess\.", "file"),
    ("JSON.parse_string(", r"\bJSON\.parse_string\(", "json"),
    ("JSON.stringify(", r"\bJSON\.stringify\(", "json"),
    ("str_to_var(", r"(?<![\w.])str_to_var\(", "json"),
    ("var_to_str(", r"(?<![\w.])var_to_str\(", "json"),
    (".duplicate(true)", r"\.duplicate\(\s*true\s*\)", "copy"),
    ("ShaderMaterial.new(", r"\bShaderMaterial\.new\(", "material"),
    ("Shader.new(", r"\bShader\.new\(", "material"),
    ("StyleBoxFlat.new(", r"\bStyleBoxFlat\.new\(", "material"),
]
COMPILED = [(label, re.compile(rx), kind) for label, rx, kind in CALLS]

# What each kind of call costs, and the one-line fix. A frame is 16 ms (60 per second).
KIND = {
    "load": ("looks a resource up by path (the resource cache makes a repeat cheap, but it still hashes the path and can hit the disk the first time)",
             "load it once into a member in `_ready` (or on first use), or use `preload(...)` in a `const`"),
    "image": ("builds or copies pixel data (an Image or a texture) on the CPU, and may stall the GPU",
              "build it once in `_ready` or on first use, keep it in a member, and only rebuild when its inputs change"),
    "color": ("parses a colour out of a text string, which never changes",
              "make it a `const NAME := Color(\"#rrggbb\")` at the top of the file (a const is parsed once, at load)"),
    "tree": ("walks the scene tree looking for nodes, which costs more the bigger the scene",
             "look the node up once in `_ready` (or on first use) and keep it in a member; for groups, keep your own list"),
    "file": ("touches the disk, which can take milliseconds and blocks the frame",
             "read it once when it is needed (not per frame) and keep the result in a member"),
    "json": ("converts between text and data, allocating every time",
             "do the conversion once when the data changes, and keep the result in a member"),
    "copy": ("copies a whole nested Array or Dictionary, allocating every time",
             "copy only when you will change it, or keep the copy in a member and refresh it when its source changes"),
    "material": ("creates an engine object (material, shader or style box) that the renderer then has to register",
                 "create it once in `_ready` or on first use, keep it in a member, and change its parameters instead"),
}
KIND_OF = {label: kind for label, _, kind in CALLS}

IF_HEAD = re.compile(r"(?:el)?if\s+(.*?)\s*:\s*$")
GUARDS = [
    re.compile(r"^(?:self\.)?([A-Za-z_]\w*)(?:\[.*?\])?(?:\.\w+)*\s*==\s*null\b"),
    re.compile(r"^not\s+(?:self\.)?([A-Za-z_]\w*)\b(?!\s*\()"),
    re.compile(r"^(?:self\.)?([A-Za-z_]\w*)(?:\.\w+)*\.is_empty\(\)"),
    re.compile(r"^not\s+(?:self\.)?([A-Za-z_]\w*)(?:\.\w+)*\.has\("),
    re.compile(r"^(?:self\.)?(_[A-Za-z]\w*)\s*!="),  # `if _built != size:` a rebuild when its key changed
]


def guard_base(cond):
    """The member a condition tests as a cache or once-flag, from any `and`/`or` term of it, or None."""
    for term in re.split(r"\s+(?:and|or)\s+", cond.strip()):
        term = term.strip()
        while term.startswith("(") and term.count("(") > term.count(")"):
            term = term[1:].strip()
        while term.endswith(")") and term.count(")") > term.count("("):
            term = term[:-1].strip()
        for g in GUARDS:
            gm = g.match(term)
            if gm:
                return gm.group(1)
    return None
RETURN_GUARD = re.compile(r"^(?:if|elif)\s+(.*?)\s*:\s*(return\b.*)?$")


def mask(codes):
    """The lines with the inside of every string literal replaced by `_`, so a call named in text is not a call.
    The quotes stay, so `Color("` can still tell a literal from a variable."""
    out, state = [], None
    for line in codes:
        buf, i, n = [], 0, len(line)
        while i < n:
            if state:
                j = line.find(state, i)
                end = n if j < 0 else j
                buf.append("_" * (end - i))
                if j < 0:
                    i = n
                else:
                    buf.append(state)
                    i, state = j + 3, None
                continue
            c = line[i]
            if line.startswith('"""', i) or line.startswith("'''", i):
                state = line[i:i + 3]
                buf.append(state)
                i += 3
            elif c in "\"'":
                j = i + 1
                while j < n and line[j] != c:
                    j += 2 if line[j] == "\\" else 1
                buf.append(c + "_" * max(0, j - i - 1) + (c if j < n else ""))
                i = j + 1
            else:
                buf.append(c)
                i += 1
        out.append("".join(buf))
    return out


def assigns(base, lines):
    """True if some line assigns to `base` (`base = `, `base[k] = `, `base.x = `, `base.append(`)."""
    pat = re.compile(r"^\s*(?:self\.)?%s(?:\[[^\]]*\]|\.\w+)*\s*(?::?=|\.(?:append|push_back|merge|assign|set)\()" % re.escape(base))
    return any(pat.match(ln) for ln in lines)


def lazy_init(raws, codes, s, j, e_fn):
    """True when the call on line j (in the function that starts at line s) sits in the common cache idiom:
    inside `if X == null:` / `if not X:` / `if X.is_empty():` / `if not C.has(k):` whose block assigns to X (or C),
    or after an early-return guard on a member that the function fills in afterwards."""
    ind = indent_of(raws[j])
    # 1. an enclosing `if` whose block assigns to the thing it tested
    k, want = j, ind
    while k > s:
        k -= 1
        if not codes[k].strip():
            continue
        ik = indent_of(raws[k])
        if ik < want:
            want = ik
            m = IF_HEAD.match(codes[k].strip())
            if m and not codes[k].strip().startswith("elif"):
                base = guard_base(m.group(1))
                if base:
                    end = j
                    for e in range(k + 1, len(raws)):
                        if codes[e].strip() and indent_of(raws[e]) <= ik:
                            break
                        end = e
                    if assigns(base, codes[k + 1:end + 1]):
                        return True
    # 2. `if cache.has(k): return cache[k]` (or `if X != null: return X`) above, and the function fills it in below
    for k in range(s + 1, j):
        line = codes[k].strip()
        m = RETURN_GUARD.match(line)
        if not m or indent_of(raws[k]) > ind:
            continue
        if not m.group(2):
            nxt = next((x for x in range(k + 1, j) if codes[x].strip()), None)
            if nxt is None or not codes[nxt].strip().startswith("return") or indent_of(raws[nxt]) <= indent_of(raws[k]):
                continue
        ids = [i for i in re.findall(r"[A-Za-z_]\w*", m.group(1)) if i not in ("not", "and", "or", "null", "true", "false", "has", "is_empty", "self")]
        end = e_fn
        for i in ids:
            if (i.startswith("_") or i.isupper()) and assigns(i, codes[j:end]):
                return True
    return False


def engine_signature(name, line):
    """The engine's `_draw()` takes nothing and `_process(delta)` one value; a project function that reuses
    the name with other parameters (`_draw(vp, shader, n)`) is not called every frame by the engine."""
    params = line[line.index("(") + 1:].split(")")[0].strip()
    n = 0 if not params else params.count(",") + 1
    return n == 0 if name == "_draw" else n <= 1


def lazy_callee(raws, codes, s, j, callee):
    """True when line j (a call to the `callee` body) sits in `if X == null:` / `if not X:` and the callee fills X in:
    `if _vp == null: _runtime()`, where `_runtime` sets `_vp`. That is lazy initialisation done one call away."""
    k, want = j, indent_of(raws[j])
    while k > s:
        k -= 1
        if codes[k].strip() and indent_of(raws[k]) < want:
            want = indent_of(raws[k])
            m = IF_HEAD.match(codes[k].strip())
            if m and not codes[k].strip().startswith("elif"):
                base = guard_base(m.group(1))
                if base and assigns(base, callee):
                    return True
    return False


def class_of(codes, raws, s):
    """Index of the nearest `class` line above a function that is indented less than it, or -1 (the file's own class)."""
    ind = indent_of(raws[s])
    for k in range(s - 1, -1, -1):
        if codes[k].lstrip().startswith("class ") and indent_of(raws[k]) < ind:
            return k
    return -1


def scan_file(raws):
    """[(func key, label, count, via)] for one file. `via` is the per-frame function that reached it, or ''."""
    codes = lex(raws)
    spans = list(function_spans(raws, codes))
    if not spans:
        return []
    masked = mask(codes)
    by_name = {}
    for key, s, e, m in spans:
        by_name.setdefault(m.group(1), []).append((key, s, e))
    roots = [(key, s, e) for key, s, e, m in spans if m.group(1) in PER_FRAME and engine_signature(m.group(1), codes[s])]
    steps = {}  # key -> (s, e, caller key)
    for rkey, rs, re_ in roots:
        rcls = class_of(codes, raws, rs)
        for j in range(rs + 1, re_):
            for cm in re.finditer(r"(?<![\w.])(?:self\.)?([A-Za-z_]\w*)\(", masked[j]):
                for ckey, cs, ce in by_name.get(cm.group(1), []):
                    if cm.group(1) in PER_FRAME or cs == rs:
                        continue
                    if class_of(codes, raws, cs) == rcls and ckey not in steps:
                        if not lazy_callee(raws, codes, rs, j, codes[cs:ce]):
                            steps[ckey] = (cs, ce, rkey)
    todo = [(k, s, e, "") for k, s, e in roots] + [(k, s, e, v) for k, (s, e, v) in steps.items()]
    out, done = [], set()
    for key, s, e, via in todo:
        if key in done:
            continue
        done.add(key)
        counts = {}
        for j in range(s + 1, e):
            if not masked[j].strip():
                continue
            for label, rx, _ in COMPILED:
                n = len(rx.findall(masked[j]))
                if n and not lazy_init(raws, codes, s, j, e):
                    counts[label] = counts.get(label, 0) + n
        for label, n in counts.items():
            out.append((key, label, n, via))
    return out


def game_files(root):
    for gd in sorted((root / "tkg" / "scripts").rglob("*.gd")):
        rel = gd.relative_to(root / "tkg").as_posix()
        if not rel.startswith("scripts/sim/"):
            yield rel, gd


def measure(root=ROOT):
    """({key: count}, {key: via}) for every call in a per-frame function in the tree."""
    found, via = {}, {}
    for rel, gd in game_files(root):
        if "func" not in (text := gd.read_text(encoding="utf-8", errors="replace")):
            continue
        for fkey, label, n, v in scan_file(text.splitlines()):
            k = f"frame {rel}::{fkey} {label}"
            found[k] = n
            if v:
                via[k] = v
    return found, via


def read_baseline():
    out = {}
    if BASELINE.is_file():
        for line in BASELINE.read_text(encoding="utf-8").splitlines():
            if line.strip() and not line.startswith("#"):
                key, _, n = line.rpartition(" ")
                out[key] = int(n)
    return out


def write_baseline(found):
    BASELINE.write_text(HEADER + "".join(f"{k} {v}\n" for k, v in sorted(found.items())), encoding="utf-8")


def explain(key, n, via):
    _, where, label = key.split(" ", 2)
    func = where.split("::")[1].split("#")[0]
    kind = KIND[KIND_OF[label]]
    runs = f"`{func}` runs every frame" if func in PER_FRAME else f"`{func}` is called from `{via}` every frame"
    return (f"NEW {key}" + (f"  ({n} times)" if n > 1 else "") + "\n"
            f"    {runs} (in {where.split('::')[0]}), and it calls `{label}`: that {kind[0]}.\n"
            f"    A frame is 16 ms; doing this 60 times a second is how a game hitches.\n"
            f"    Fix: {kind[1]}.\n"
            f"    (If it is already inside `if X == null:` or `if not cache.has(k):` that fills X, the work happens once and the\n"
            f"    detector missed it: say so in the PR and record it with --update.)")


def report(found, via):
    files = {}
    for k, v in found.items():
        _, where, label = k.split(" ", 2)
        f, fn = where.split("::")
        files.setdefault(f, []).append((fn, label, v, via.get(k, "")))
    order = sorted(files, key=lambda f: (-sum(x[2] for x in files[f]), f))
    print(f"per-frame work: {sum(found.values())} calls in {len(found)} places across {len(files)} files, worst first\n")
    for f in order:
        print(f"{f}  ({sum(x[2] for x in files[f])})")
        for fn, label, v, vi in sorted(files[f], key=lambda x: (-x[2], x[0], x[1])):
            print(f"    {fn:<28} {label:<32} x{v}" + (f"   (from {vi})" if vi else ""))
    return 0


def check(update):
    found, via = measure()
    old = read_baseline()
    if update:
        for k, v in sorted(found.items()):
            if k not in old or v > old[k]:
                print(f"ADDED {k} {v}")
        write_baseline(found)
        print(f"frame check: recorded {len(found)} entries (was {len(old)})")
        return 0
    problems, fixed = [], []
    for k, v in sorted(found.items()):
        if k not in old:
            problems.append(explain(k, v, via.get(k, "")))
        elif v > old[k]:
            problems.append(f"GREW {k}: {old[k]} times, now {v}\n"
                            f"    Same fix as for a new one: move this work out of the frame instead of adding another.")
    for k, v in sorted(old.items()):
        if k not in found:
            fixed.append(f"FIXED {k}")
        elif found[k] < v:
            fixed.append(f"SHRANK {k}: {v} times, now {found[k]}")
    for line in problems + fixed:
        print(line)
    if fixed:
        print("run python3 tools/frame_check.py --update to shrink the baseline")
    print(f"frame check: {'FAIL' if problems else 'PASS'} ({len(problems)} new, "
          f"{len(found) - len(problems)} baselined, {len(fixed)} fixed)")
    return 1 if problems else 0


# ---------------------------------------------------------------- self-test

SYNTH = '''extends Node2D

const GOOD := Color("#ff0000")
var _tex: ImageTexture
var _font
var _cache := {}
var _items: Array = []
var _node
var _built := Vector2.ZERO
var _done := false

func _ready() -> void:
	var a := load("res://a.tres")
	var c := Color("#00ff00")
	_node = find_child("x")

func _process(delta: float) -> void:
	var r := load("res://r.tres")
	var p := preload("res://p.tres")
	var c := Color("#123456")
	var d := Color(some_string)
	var h := Color.html("#fff")
	var s := "this text says load(\\"x\\") and find_child(\\"y\\")"  # find_child("z") in a comment
	var cfg := ConfigFile.new()
	cfg.load("user://x.cfg")
	_tick(delta)
	_tex = ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8))
	var j = JSON.parse_string("{}")
	var n = get_tree().get_nodes_in_group("g")
	var n2 = get_tree().get_nodes_in_group("g")
	var f := FileAccess.open("user://f", FileAccess.READ)
	var dd := _cache.duplicate(true)
	var dsh := _cache.duplicate()
	var sm := ShaderMaterial.new()
	var sb := StyleBoxFlat.new()
	var t := tex.get_image()

func _tick(dt: float) -> void:
	var l := load("res://t.tres")
	_helper()

func _helper() -> void:
	var never := load("res://two_levels_away.tres")

func _draw() -> void:
	if _font == null:
		_font = load("res://font.tres")
	if not _tex:
		_tex = Image.create(2, 2, false, Image.FORMAT_RGBA8)
	if _items.is_empty():
		var made := find_children("*")
		_items = made
	if not _cache.has("k"):
		var im := Image.create_from_data(1, 1, false, Image.FORMAT_RGBA8, PackedByteArray())
		_cache["k"] = im
	if _font == null:
		print("no assignment here")
		var oops := load("res://font2.tres")
	var again := _memo("k")
	if _built != size:
		_rebuild()
	if visible and not _done:
		_done = true
		var once := load("res://once.tres")
	if _node == null:
		_make()

func _rebuild() -> void:
	_built = size
	var w := load("res://w.tres")

func _make() -> void:
	_node = load("res://made.tscn").instantiate()

func _memo(k: String):
	if _cache.has(k):
		return _cache[k]
	var v := Color.from_string("red", Color.WHITE)
	_cache[k] = v
	return v

func _unrelated() -> void:
	var u := load("res://not_per_frame.tres")

class Inner:
	func _process(d: float) -> void:
		_inner_step()

	func _inner_step() -> void:
		var q := DirAccess.open("user://")
'''
EXPECTED = {
    "frame scripts/x/Synth.gd::_process load(": 1,
    'frame scripts/x/Synth.gd::_process Color("': 1,
    "frame scripts/x/Synth.gd::_process Color.html(": 1,
    "frame scripts/x/Synth.gd::_process Image.create(": 1,
    "frame scripts/x/Synth.gd::_process ImageTexture.create_from_image(": 1,
    "frame scripts/x/Synth.gd::_process JSON.parse_string(": 1,
    "frame scripts/x/Synth.gd::_process get_nodes_in_group(": 2,
    "frame scripts/x/Synth.gd::_process FileAccess.open(": 1,
    "frame scripts/x/Synth.gd::_process .duplicate(true)": 1,
    "frame scripts/x/Synth.gd::_process ShaderMaterial.new(": 1,
    "frame scripts/x/Synth.gd::_process StyleBoxFlat.new(": 1,
    "frame scripts/x/Synth.gd::_process .get_image(": 1,
    "frame scripts/x/Synth.gd::_tick load(": 1,
    "frame scripts/x/Synth.gd::_draw load(": 1,
    "frame scripts/x/Synth.gd::_inner_step DirAccess.": 1,
}
# Not in EXPECTED on purpose: `preload(`, `Color(some_string)`, text and comment mentions, `cfg.load(`, `.duplicate()`,
# the call in `_ready`, in `_helper` (two levels from a frame), in `_unrelated`, in `_memo` (early-return cache),
# the four lazy-init blocks in `_draw`, its changed-key rebuild, its once-flag, and a lazy-init one call away (`_make`).


def selftest():
    bad = []
    with tempfile.TemporaryDirectory(prefix="frame_check_selftest_") as tmp:
        root = Path(tmp)
        (root / "tkg" / "scripts" / "x").mkdir(parents=True)
        (root / "tkg" / "scripts" / "x" / "Synth.gd").write_text(SYNTH)
        (root / "tkg" / "scripts" / "sim").mkdir()
        (root / "tkg" / "scripts" / "sim" / "Skipped.gd").write_text("extends Node\nfunc _process(d):\n\tload('x')\n")
        got, _ = measure(root)
    for k in sorted(set(EXPECTED) | set(got)):
        if k not in got:
            bad.append(f"missed {k}")
        elif k not in EXPECTED:
            bad.append(f"false {k} x{got[k]}")
        elif got[k] != EXPECTED[k]:
            bad.append(f"count {k}: want {EXPECTED[k]}, got {got[k]}")
    return bad


def main(argv):
    if "--selftest" in argv:
        bad = selftest()
        for b in bad:
            print(b)
        print("frame check selftest: %s" % ("FAIL (%d)" % len(bad) if bad else "PASS"))
        return 1 if bad else 0
    if "--report" in argv:
        return report(*measure())
    return check("--update" in argv)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
