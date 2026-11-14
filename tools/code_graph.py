#!/usr/bin/env python3
"""Code graph for GDScript: which file and function depends on which. The gate fails on a NEW
link that breaks the layering (game code reaching into sim, rules/data/net reaching into ui, data
reaching into rules/net) or a NEW call to another class's private `_method`. What predates the
rule is in tools/code_graph_baseline.txt. Run: python3 tools/code_graph.py [--update]
  --report [PATH]   the full markdown report: orphans, odd links, cycles, hubs (for planning a cleanup)
  --graphify PATH   the nodes and edges as graphify's extraction JSON
  --selftest        a tiny synthetic tree that must give exactly the expected facts (the gate runs it first)
Deterministic, no LLM, stdlib only. How it reads a call and what it cannot see: docs/why/code_graph.md."""
import json
import re
import shutil
import sys
import tempfile
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
import code_check  # noqa: E402  (its comment-stripping lexer and function finder)

TKG = ROOT / "tkg"
BASELINE = ROOT / "tools" / "code_graph_baseline.txt"
DISPATCHERS = ("scripts/DevFlags.gd", "scripts/Main.gd")  # their job is to load harnesses
HEADER = (
    "# Links that predate tools/code_graph.py. The gate ignores these and fails on any other.\n"
    "# Shrink it by fixing code, then: python3 tools/code_graph.py --update\n"
    "# layer <from-file> -> <to-file>    game code into sim; systems/data/net into ui; data into systems/net\n"
    "# private <def-file>::<_method> <- <caller-file>    a call to an unrelated class's private method\n"
    "# (files are paths under tkg/; never a line number, so an edit elsewhere does not churn this file)\n"
)

# Engine callbacks and virtuals: an underscore name that is the engine's, not a class's private.
VIRTUAL = set("""_ready _process _physics_process _draw _input _gui_input _unhandled_input _unhandled_key_input
_notification _init _enter_tree _exit_tree _to_string _get_minimum_size _make_custom_tooltip _get_drag_data
_can_drop_data _drop_data _has_point _get _set _get_property_list _shortcut_input _static_init _get_tooltip
_validate_property _property_can_revert _property_get_revert _iter_init _iter_next _iter_get
_put_packet_script _get_packet_script _get_available_packet_count _get_packet_peer _get_packet_mode
_get_packet_channel _get_max_packet_size _get_unique_id _is_server _is_server_relay_supported
_get_connection_status _set_target_peer _set_transfer_channel _get_transfer_channel _set_transfer_mode
_get_transfer_mode _poll _close _disconnect_peer _is_refusing_new_connections _set_refuse_new_connections""".split())
IDENT = re.compile(r"[A-Za-z_]\w*")
STR = re.compile(r'"(?:[^"\\]|\\.)*"|\'(?:[^\'\\]|\\.)*\'')
TRIPLE = re.compile(r'"""[\s\S]*?"""|\'\'\'[\s\S]*?\'\'\'')
TOKEN = re.compile(r"(?<![\w.])[A-Za-z_]\w*")           # an identifier that is not a member access
NODEPATH = re.compile(r"(?<![\w)\]])[$%][A-Za-z_][\w/]*")  # $Board/Ring, %Hints
CALL_ALL = re.compile(r"(?<!\w)([A-Za-z_]\w*)\s*\(")
CALL_PRIVATE = re.compile(r"(?<!\w)(_[A-Za-z0-9_]*)\s*\(")
FUNC_LINE = re.compile(r"\s*(?:static\s+)?func\s")
LAMBDA = re.compile(r"\bfunc\s*\(")
RES_PATH = re.compile(r"res://scripts/[\w/]+\.gd")
DECLNAME = re.compile(r"\b(?:var|const|func|signal|enum|class)\s+([A-Za-z_]\w*)")
FORVAR = re.compile(r"\bfor\s+([A-Za-z_]\w*)")
ENUMBODY = re.compile(r"\benum\b[^{;]*\{([^}]*)\}")
PARAM = re.compile(r"\s*(\w+)\s*(?::\s*([A-Z]\w*))?")
# type annotations, only in declaration positions
VAR_TYPED = re.compile(r"\b(?:var|const)\s+(\w+)\s*:\s*([A-Z]\w*)")
VAR_ANY = re.compile(r"\b(?:var|const)\s+(\w+)")
FOR_TYPED = re.compile(r"\bfor\s+(\w+)\s*:\s*([A-Z]\w*)\s+in\b")
ASSIGN_NEW = re.compile(r"\b(\w+)\s*:?=(?!=)\s*([A-Z]\w*)\.new\(")
ASSIGN_AS = re.compile(r"\b(\w+)\s*(?::\s*\w+\s*)?:?=(?!=)\s*.*?\bas\s+([A-Z]\w*)\s*\)?\s*$")
AS_TAIL = re.compile(r"\bas\s+([A-Z]\w*)\s*$")


def paren_text(lines):
    """The text inside the first (...) of these lines joined, or ''."""
    s = " ".join(lines)
    i = s.find("(")
    if i < 0:
        return ""
    d = 0
    for j in range(i, len(s)):
        ch = s[j]
        if ch in "([{":
            d += 1
        elif ch in ")]}":
            d -= 1
            if d == 0:
                return s[i + 1:j]
    return s[i + 1:]


def split_top(s):
    out, d, cur = [], 0, []
    for ch in s:
        if ch in "([{":
            d += 1
        elif ch in ")]}":
            d -= 1
        if ch == "," and d == 0:
            out.append("".join(cur))
            cur = []
        else:
            cur.append(ch)
    out.append("".join(cur))
    return out


def params_of(text):
    """[(name, Class or None)] from the text inside a parameter list."""
    out = []
    for part in split_top(text):
        m = PARAM.match(part)
        if m:
            out.append((m.group(1), m.group(2)))
    return out


class Script:
    """One .gd file: its text with comments dropped (`codes`) and strings blanked (`bare`)."""

    def __init__(self, path, tkg):
        self.rel = path.relative_to(tkg).as_posix()
        self.stem = path.stem
        parts = self.rel.split("/")
        self.top = parts[1] if len(parts) > 2 else "root"
        self.sim = self.top == "sim"
        text = path.read_text(encoding="utf-8", errors="replace")
        self.raws = text.splitlines()
        if '"""' in text or "'''" in text:
            # lex() carries the triple-quote state across lines; then the whole block is blanked
            joined = "\n".join(code_check.lex(self.raws))
            joined = TRIPLE.sub(lambda m: '""' + "\n" * m.group(0).count("\n"), joined)
            self.codes = joined.split("\n")
        else:
            self.codes = [c if not ("#" in c or '"' in c or "'" in c) else code_check.lex([c])[0] for c in self.raws]
        self.bare = [STR.sub('""', c) if ('"' in c or "'" in c) else c for c in self.codes]
        self.class_name = None
        self.extends = None
        for c in self.bare[:40]:
            m = re.match(r"\s*class_name\s+(\w+)", c)
            if m:
                self.class_name = m.group(1)
        for c in self.codes[:40]:
            m = re.match(r"\s*extends\s+(\"[^\"]+\"|[\w.]+)", c)
            if m:
                self.extends = m.group(1).strip('"')
                break
        self.find_funcs()

    def find_funcs(self):
        """Every func by position: funcs[key] = (first line index, one past last), key as
        code_check.function_spans names it."""
        self.funcs = {}
        self.names = set()       # the plain names, for finding a method
        self.params = {}         # key -> [(name, Class or None)]
        self.span_of = [None] * len(self.codes)
        for key, s, end, m in code_check.function_spans(self.raws, self.codes):
            self.funcs[key] = (s, end)
            self.names.add(m.group(1))
            self.params[key] = params_of(paren_text(self.bare[s:s + 12]))
            for j in range(s, end):
                self.span_of[j] = key


class Graph:
    pass


def read_text(p):
    return p.read_text(encoding="utf-8", errors="replace")


def build(deep=False, tkg=None):
    """The scripts, their file-to-file links and the private calls. deep adds the function-level
    calls and the name census the report and the graphify JSON need. Both modes find the same
    ratchet facts (the self-test asserts it)."""
    tkg = tkg or TKG
    g = Graph()
    g.files = {}
    for gd in sorted((tkg / "scripts").rglob("*.gd")):
        s = Script(gd, tkg)
        g.files[s.rel] = s
    files = g.files
    g.by_class = {f.class_name: f for f in files.values() if f.class_name}
    g.by_path = {"res://" + f.rel: f for f in files.values()}
    g.project = read_text(tkg / "project.godot")
    g.autoload = {}
    for m in re.finditer(r'^(\w+)="\*?(res://[^"]+)"', g.project, re.M):
        if m.group(2) in g.by_path:
            g.autoload[m.group(1)] = g.by_path[m.group(2)]
    g.autoload_files = set(f.rel for f in g.autoload.values())
    g.name_to_file = dict(g.by_class)
    g.name_to_file.update(g.autoload)
    g.func_homes = defaultdict(list)       # every file, sim too: the report's census
    g.game_homes = defaultdict(list)       # game code only: what "defined in exactly one file" means
    for f in files.values():
        for n in sorted(f.names):
            g.func_homes[n].append(f)
            if not f.sim:
                g.game_homes[n].append(f)
    chains = {}

    def base_chain(f):
        if f.rel in chains:
            return chains[f.rel]
        out, seen, cur = [], set(), f
        while cur and cur.rel not in seen:
            seen.add(cur.rel)
            out.append(cur)
            e = cur.extends
            cur = (g.by_class.get(e) or g.by_path.get(e)) if e else None
        chains[f.rel] = out
        return out

    def find_method(f, name):
        for b in base_chain(f):
            if name in b.names:
                return b
        return None

    g.base_chain = base_chain
    g.find_method = find_method
    g.file_edges = defaultdict(Counter)   # (src rel, dst rel) -> Counter of kind: references, loads, extends
    g.call_edges = Counter()              # (src rel, src func, dst rel, dst func, confidence) -> n
    g.private_calls = defaultdict(list)   # (def rel, method) -> [(caller rel, line, how)]
    g.mentions = defaultdict(list)        # identifier -> [(rel, line)] in code
    g.str_mentions = defaultdict(list)    # identifier -> [(rel, line)] in strings
    nm = g.name_to_file
    edges = g.file_edges
    for f in files.values():
        src = f.rel
        toks = [w for w in TOKEN.findall(NODEPATH.sub(" ", "\n".join(f.bare))) if w in nm]
        if toks:
            shadow = _declared(f) & set(toks)
            for w in toks:
                t = nm[w]
                if t is not f and w not in shadow:
                    edges[(src, t.rel)]["references"] += 1
        for c in f.codes:
            if "res://" in c:
                for p in RES_PATH.findall(c):
                    t = g.by_path.get(p)
                    if t is not None and t is not f:
                        edges[(src, t.rel)]["loads"] += 1
        if f.extends:
            b = g.by_class.get(f.extends) or g.by_path.get(f.extends)
            if b is not None and b is not f:
                edges[(src, b.rel)]["extends"] += 1
        _calls(g, f, deep)
    return g


def _declared(f):
    """Every name this file declares itself (var, const, func, signal, enum and its members, inner
    class, loop variable, parameter): such a name shadows a global class of the same name here."""
    text = "\n".join(f.bare)
    out = set(DECLNAME.findall(text)) | set(FORVAR.findall(text))
    for body in ENUMBODY.findall(text):
        for item in body.split(","):
            m = IDENT.match(item.strip())
            if m:
                out.add(m.group(0))
    for plist in f.params.values():
        out.update(n for n, _t in plist)
    for c in f.bare:
        if "func" in c:
            for m in LAMBDA.finditer(c):
                out.update(n for n, _t in params_of(paren_text([c[m.end() - 1:]])))
    return out


def _put(into, name, cls):
    """Record that `name` is declared with class `cls` ('' for none or unknown). Two answers: ''."""
    old = into.get(name)
    if old is None:
        into[name] = cls
    elif old != cls:
        into[name] = ""


def _scan_decls(c, nm, into):
    """Variable types from one line of code, in declaration positions only."""
    if "var" not in c and "const" not in c and "for" not in c and "new(" not in c and " as " not in c:
        return
    typed = set()
    for rx in (VAR_TYPED, FOR_TYPED, ASSIGN_NEW, ASSIGN_AS):
        for m in rx.finditer(c):
            if m.group(2) in nm:
                _put(into, m.group(1), m.group(2))
                typed.add(m.group(1))
    for m in VAR_ANY.finditer(c):
        if m.group(1) not in typed:
            _put(into, m.group(1), "")


def _scopes(g, f):
    """(member scope, scope per function key). Member scope: declarations outside any function.
    A parameter belongs to its own function only."""
    nm = g.name_to_file
    member, local = {}, {}
    for i, c in enumerate(f.bare):
        if f.span_of[i] is None:
            _scan_decls(c, nm, member)
    for key, (s, e) in f.funcs.items():
        d = {}
        for pname, ptype in f.params[key]:
            _put(d, pname, ptype if ptype in nm else "")
        for c in f.bare[s:e]:
            _scan_decls(c, nm, d)
        local[key] = d
    return member, local


def _receiver(g, f, pre, local, member):
    """What stands before a `.method(`: (kind, file or None). kind: 'self', 'class' (a class,
    autoload or cast: exact), 'typed' (a variable with a declared class), 'unknown' (an expression,
    or an untyped variable)."""
    nm = g.name_to_file
    pre = pre.rstrip()
    m = re.search(r"([A-Za-z_]\w*)$", pre)
    if m:
        name = m.group(1)
        if pre[:m.start()].rstrip().endswith("."):
            return "unknown", None
        if name in ("self", "super"):
            return "self", None
        if name in nm:
            return "class", nm[name]
        t = local[name] if name in local else member.get(name)
        if t:
            return "typed", nm[t]
        return "unknown", None
    if pre.endswith(")"):
        d, k = 0, len(pre) - 1
        while k >= 0:
            if pre[k] == ")":
                d += 1
            elif pre[k] == "(":
                d -= 1
                if d == 0:
                    break
            k -= 1
        if k >= 0:
            inner, before = pre[k + 1:-1], pre[:k].rstrip()
            ma = AS_TAIL.search(inner)
            if ma and ma.group(1) in nm:
                return "typed", nm[ma.group(1)]
            mn = re.search(r"([A-Za-z_]\w*)\s*\.\s*new$", before)
            if mn and mn.group(1) in nm and not before[:mn.start()].rstrip().endswith("."):
                return "typed", nm[mn.group(1)]
    return "unknown", None


def _calls(g, f, deep):
    """Resolve calls in one file. Honest rule: a call resolves only when the receiver is self/bare,
    a class_name or autoload, a variable or cast with a declared class, a `Class.new()`, or a
    private `_x` defined in exactly one game file (the last resort, marked UNIQUE). A public method on
    an untyped receiver is never guessed (Array.resize, Node.add_child); a receiver that is any
    other expression (`a[i]._m()`, `f()._m()`) is not `self`."""
    member, local = _scopes(g, f)
    rx = CALL_ALL if deep else CALL_PRIVATE
    for i, c in enumerate(f.bare):
        if deep:
            for w in IDENT.findall(c):
                g.mentions[w].append((f.rel, i + 1))
            if '"' in f.codes[i] or "'" in f.codes[i]:
                for w in IDENT.findall(" ".join(STR.findall(f.codes[i]))):
                    g.str_mentions[w].append((f.rel, i + 1))
        if "(" not in c:
            continue
        cur = f.span_of[i]
        loc = local[cur] if cur else {}
        is_def = FUNC_LINE.match(c) is not None
        for m in rx.finditer(c):
            meth = m.group(1)
            pre = c[:m.start()].rstrip()
            if is_def and cur and meth == cur.split("#")[0] and not pre.endswith("."):
                continue
            if pre.endswith("."):
                kind, tgt = _receiver(g, f, pre[:-1], loc, member)
            else:
                kind, tgt = "self", None
            dst, how = None, "EXTRACTED"
            if kind == "self":
                dst = g.find_method(f, meth)
            elif kind in ("class", "typed"):
                dst = g.find_method(tgt, meth)
                how = "EXTRACTED" if kind == "class" else "TYPED"
            if dst is None and kind in ("unknown",) and meth.startswith("_") and meth not in VIRTUAL \
                    and len(g.game_homes.get(meth, ())) == 1:
                dst, how = g.game_homes[meth][0], "UNIQUE"
            if dst is None:
                continue
            if deep and cur:
                g.call_edges[(f.rel, cur, dst.rel, meth, how)] += 1
            if dst is not f and meth.startswith("_") and meth not in VIRTUAL \
                    and dst not in g.base_chain(f) and f not in g.base_chain(dst):
                g.private_calls[(dst.rel, meth)].append((f.rel, i + 1, how))


# ---- the ratcheted facts

def facts(g):
    """The set of ratcheted keys. Stable across unrelated edits: file and function names only."""
    out = set()
    for (a, b) in g.file_edges:
        fa, fb = g.files[a], g.files[b]
        if fa.sim:
            continue
        if fb.sim and a not in DISPATCHERS:
            out.add("layer %s -> %s" % (a, b))
        elif fa.top in ("systems", "data", "net") and fb.top == "ui" and b not in g.autoload_files:
            out.add("layer %s -> %s" % (a, b))
        elif fa.top == "data" and fb.top in ("systems", "net"):
            out.add("layer %s -> %s" % (a, b))
    for (d, m), calls in g.private_calls.items():
        if g.files[d].sim:
            continue
        for caller in set(c[0] for c in calls):
            if not g.files[caller].sim:
                out.add("private %s::%s <- %s" % (d, m, caller))
    return out


def fallback_keys(g):
    """The private keys every call of which rests on the unique-name guess (no declared type)."""
    out = set()
    for (d, m), calls in g.private_calls.items():
        for caller in set(c[0] for c in calls):
            if all(c[2] == "UNIQUE" for c in calls if c[0] == caller):
                out.add("private %s::%s <- %s" % (d, m, caller))
    return out


def read_baseline():
    if not BASELINE.is_file():
        return set()
    return set(l for l in BASELINE.read_text(encoding="utf-8").splitlines() if l.strip() and not l.startswith("#"))


def write_baseline(keys):
    BASELINE.write_text(HEADER + "\n".join(sorted(keys)) + "\n", encoding="utf-8")


def check(update):
    g = build()
    now, old = facts(g), read_baseline()
    if update:
        for k in sorted(now - old):
            print("ADDED " + k)
        write_baseline(now)
        print("code graph: recorded %d entries (was %d), from %d scripts" % (len(now), len(old), len(g.files)))
        return 0
    guess = fallback_keys(g)
    new, fixed = sorted(now - old), sorted(old - now)
    for k in new:
        print("NEW " + k + ("   <- game code may not depend on test code" if k.startswith("layer") and "/sim/" in k.split(" -> ")[1]
                            else "   <- breaks the layering (tkg/CLAUDE.md)" if k.startswith("layer")
                            else "   <- private to its class: make it public, or ask through the class's own API"
                            + (" (found by name alone: if another game file just gained or lost a method of "
                               "this name, --update with a note)" if k in guess else "")))
    for k in fixed:
        print("FIXED " + k)
    if fixed:
        print("run python3 tools/code_graph.py --update to shrink the baseline")
    print("code graph: %s (%d new, %d baselined, %d fixed)" % (
        "FAIL" if new else "PASS", len(new), len(now) - len(new), len(fixed)))
    return 1 if new else 0


# ---- the graphify extraction

def node_id(rel, func=None):
    """Unique and exact: a leading underscore and the case survive, so `foo` and `_foo` differ."""
    base = rel[:-3].replace("/", "__")
    return base if func is None else base + "::" + func.replace("#", "_n")


def graphify_data(g):
    nodes, edges = [], []
    for f in g.files.values():
        nodes.append({"id": node_id(f.rel), "label": f.stem, "file_type": "code", "source_file": "tkg/" + f.rel,
                      "source_location": "L1", "metadata": {"language": "gdscript", "kind": "file", "layer": f.top,
                                                            "lines": len(f.raws)}})
        for n, (s, _e) in f.funcs.items():
            nodes.append({"id": node_id(f.rel, n), "label": "%s.%s" % (f.stem, n), "file_type": "code",
                          "source_file": "tkg/" + f.rel, "source_location": "L%d" % (s + 1),
                          "metadata": {"language": "gdscript", "kind": "function"}})
            edges.append({"source": node_id(f.rel), "target": node_id(f.rel, n), "relation": "contains",
                          "confidence": "EXTRACTED", "confidence_score": 1.0, "source_file": "tkg/" + f.rel, "weight": 1.0})
    for (a, b), kinds in g.file_edges.items():
        for k, w in sorted(kinds.items()):
            edges.append({"source": node_id(a), "target": node_id(b), "relation": {"loads": "imports"}.get(k, k),
                          "confidence": "EXTRACTED", "confidence_score": 1.0, "source_file": "tkg/" + a,
                          "weight": float(min(w, 10))})
    for (a, fa, b, fb, how), w in g.call_edges.items():
        s, t = node_id(a, fa), node_id(b, fb)
        if s == t:
            continue
        edges.append({"source": s, "target": t, "relation": "calls",
                      "confidence": "EXTRACTED" if how == "EXTRACTED" else "INFERRED",
                      "confidence_score": 1.0 if how == "EXTRACTED" else 0.7, "source_file": "tkg/" + a,
                      "weight": float(min(w, 10))})
    ids = set(n["id"] for n in nodes)
    edges = [e for e in edges if e["source"] in ids and e["target"] in ids]
    return {"nodes": nodes, "edges": edges, "hyperedges": [], "input_tokens": 0, "output_tokens": 0}


def graphify(g, path):
    data = graphify_data(g)
    Path(path).write_text(json.dumps(data), encoding="utf-8")
    print("wrote %s (%d nodes, %d edges)" % (path, len(data["nodes"]), len(data["edges"])))


# ---- the self-test

SELFTEST_FILES = {
    "project.godot": '[autoload]\nHints="*res://scripts/ui/Hints.gd"\n',
    "scripts/Main.gd": "extends Node\nfunc _ready():\n\tvar p := Probe.new()\n",
    "scripts/sim/Probe.gd": "class_name Probe\nextends Node\nfunc _uq():\n\tpass\n",
    "scripts/ui/Hints.gd": "extends Node\nfunc tip():\n\tpass\n",
    "scripts/ui/Board.gd": (
        "class_name Board\nextends Node\n"
        "func show_it():\n\tpass\n"
        "func _priv():\n\tpass\n"
        "func _setter_target():\n\tpass\n"
        "func _dup():\n\tpass\n"
        "func _uq():\n\tpass\n"),
    "scripts/ui/CardView.gd": "class_name CardView\nextends Node\nconst Z := 1\nfunc _z():\n\tpass\n",
    "scripts/ui/Screen.gd": (
        "class_name Screen\nextends Node\n"
        "func _keep():\n\tpass\n"
        "func _nw():\n\tpass\n"
        "func _foo():\n\tpass\n"
        "func foo():\n\t_foo()\n"),
    "scripts/ui/Other.gd": "class_name Other\nextends Node\nfunc _keep():\n\tpass\nfunc _nw():\n\tpass\nfunc _dup():\n\tpass\n",
    "scripts/data/Tbl.gd": "class_name Tbl\nextends Resource\nfunc x():\n\treturn Rules.new()\n",
    "scripts/systems/Rules.gd": (
        "class_name Rules\nextends Node\n"
        "var b: Board\n"
        "func a(v: CardView):\n\tpass\n"
        "func b2(v):\n\tv._z(CardView.Z)\n"            # an untyped v: not typed by a()'s parameter
        "func c(arr):\n"
        "\t(Router.current as Screen)._keep()\n"        # a cast
        "\tScreen.new()._nw()\n"                        # a fresh instance
        "\tarr[0]._keep()\n"                            # an expression: not self, and not unique
        "\t_make()._nw()\n"
        "func d(ok):\n\tif ok: Board.show_it()\n\tok._dup()\n"   # ok is not typed Board
        "func _make():\n\treturn 1\n"),
    "scripts/systems/Doc.gd": 'extends Node\nvar t = """\nScreen._keep() and Hints and Board\n"""\nfunc f():\n\tpass\n',
    "scripts/systems/Nodes.gd": "extends Node\nfunc f():\n\tvar n = $Screen\n\tvar m = %Screen\n\treturn $Board/Other\n",
    "scripts/systems/Enums.gd": "extends Node\nenum Kind { Screen, Board }\nfunc f(k):\n\treturn Kind.Screen\n",
    "scripts/systems/Shadow.gd": "extends Node\nfunc f(Screen):\n\tvar Board = 3\n\treturn Screen + Board\n",
    "scripts/systems/Inner.gd": (
        "extends Node\n"
        "class A:\n\tfunc go():\n\t\tpass\n"
        "class B:\n\tfunc go():\n\t\tBoard._priv()\n"
        "var prop: int:\n\tset(v):\n\t\tBoard._setter_target()\n"),
    "scripts/systems/Uniq.gd": "extends Node\nfunc f(x):\n\tx._uq()\n\tHints.tip()\n",
    "scripts/systems/UsesSim.gd": "extends Node\nfunc f():\n\treturn Probe.new()\n",
    "scripts/net/Dup.gd": "extends Node\nfunc foo():\n\tpass\nfunc _foo():\n\tfoo()\n",
}
SELFTEST_EXPECT = set("""
layer scripts/data/Tbl.gd -> scripts/systems/Rules.gd
layer scripts/systems/Rules.gd -> scripts/ui/Board.gd
layer scripts/systems/Rules.gd -> scripts/ui/CardView.gd
layer scripts/systems/Rules.gd -> scripts/ui/Screen.gd
layer scripts/systems/Inner.gd -> scripts/ui/Board.gd
layer scripts/systems/UsesSim.gd -> scripts/sim/Probe.gd
private scripts/ui/CardView.gd::_z <- scripts/systems/Rules.gd
private scripts/ui/Screen.gd::_keep <- scripts/systems/Rules.gd
private scripts/ui/Screen.gd::_nw <- scripts/systems/Rules.gd
private scripts/ui/Board.gd::_priv <- scripts/systems/Inner.gd
private scripts/ui/Board.gd::_setter_target <- scripts/systems/Inner.gd
private scripts/ui/Board.gd::_uq <- scripts/systems/Uniq.gd
""".split("\n"))
SELFTEST_EXPECT.discard("")


def selftest():
    """Build a tiny tree, assert the exact facts. Returns the list of mismatches (empty = pass)."""
    tmp = Path(tempfile.mkdtemp(prefix="code_graph_selftest_"))
    bad = []
    try:
        tkg = tmp / "tkg"
        for rel, text in SELFTEST_FILES.items():
            p = tkg / rel
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text(text, encoding="utf-8")
        quick, deep = build(False, tkg), build(True, tkg)
        got = facts(quick)
        for k in sorted(SELFTEST_EXPECT - got):
            bad.append("missing " + k)
        for k in sorted(got - SELFTEST_EXPECT):
            bad.append("unexpected " + k)
        if facts(deep) != got:
            bad.append("check and report modes disagree: " + ", ".join(sorted(facts(deep) ^ got)))
        data = graphify_data(deep)
        ids = [n["id"] for n in data["nodes"]]
        if len(ids) != len(set(ids)):
            bad.append("graphify node ids collide")
        by = dict((n["id"], n["label"]) for n in data["nodes"])
        loops = [e for e in data["edges"] if e["source"] == e["target"]]
        if loops:
            bad.append("graphify self-loop")
        call = [(by[e["source"]], by[e["target"]]) for e in data["edges"] if e["relation"] == "calls"]
        if ("Screen.foo", "Screen._foo") not in call:
            bad.append("graphify lost the edge Screen.foo -> Screen._foo")
        if ("Dup.foo", "Dup._foo") in call or ("Dup._foo", "Dup.foo") not in call:
            bad.append("graphify edge direction for Dup._foo -> Dup.foo wrong")
        inner = deep.files["scripts/systems/Inner.gd"].funcs
        if sorted(inner) != ["go", "go#2"]:
            bad.append("same-named funcs not kept apart: %s" % sorted(inner))
    finally:
        shutil.rmtree(str(tmp), ignore_errors=True)
    return bad


def _tokens(paths):
    out = set()
    for p in paths:
        if p.is_file() and "__pycache__" not in p.parts:
            out.update(IDENT.findall(read_text(p)))
    return out


def report(g):
    files, fe, autoload = g.files, g.file_edges, g.autoload
    scene_text = "\n".join(read_text(p) for pat in ("*.tscn", "*.tres") for p in sorted(TKG.rglob(pat))
                           if ".godot" not in p.parts)
    scene_scripts = set(RES_PATH.findall(scene_text)) | set(RES_PATH.findall(g.project))
    scene_tok = set(IDENT.findall(scene_text))
    outside = _tokens(sorted((ROOT / ".github").rglob("*.sh")) + sorted((ROOT / "tools").rglob("*.sh")) +
                      sorted((ROOT / "tools").rglob("*.py")) + [ROOT / "docs" / "tests.md"])
    inbound = defaultdict(set)
    for (a, b) in fe:
        inbound[b].add(a)
    auto = lambda f: f.rel in g.autoload_files
    R = ["# Code graph: orphaned and oddly linked code", "",
         "Built from %d scripts by a deterministic extractor (no LLM): comments stripped, class_name / autoload / "
         "res:// path references, extends, and calls resolved by receiver (EXTRACTED when the receiver is self, a class or an "
         "autoload; INFERRED when it is a typed variable, or a private `_name` that exists in exactly one file; a public "
         "method on an untyped receiver gets no edge, because it cannot be told from an engine method). "
         "GDScript is dynamic, so every row is a lead to confirm, not a verdict." % len(files), ""]

    # 1 orphan files
    R += ["## 1. Orphan files: nothing references them", "",
          "No other script names the class, loads the path or extends it; not an autoload, not in a scene. "
          "For sim files 'named outside' means validate.sh, run_battery.sh, tools/ or docs/tests.md mention the stem or its flag.", ""]
    game_orph, sim_orph = [], []
    for f in files.values():
        if inbound[f.rel] or ("res://" + f.rel) in scene_scripts or auto(f):
            continue
        if f.sim:
            if f.stem not in outside and f.stem.lower() not in outside:
                sim_orph.append(f)
        else:
            game_orph.append(f)
    R.append("**Game code (%d):**" % len(game_orph))
    R += ["- `%s` (%d lines)" % (f.rel, len(f.raws)) for f in sorted(game_orph, key=lambda f: (-len(f.raws), f.rel))] or ["- none"]
    R += ["", "**Sim, also named nowhere outside (%d, %d lines):** " % (len(sim_orph), sum(len(f.raws) for f in sim_orph))
          + ", ".join("%s (%d)" % (f.stem, len(f.raws)) for f in sorted(sim_orph, key=lambda f: (-len(f.raws), f.rel))), ""]

    # 2 game files only tests reference
    only_sim = [f for f in files.values() if not f.sim and inbound[f.rel] and all(files[a].sim for a in inbound[f.rel])
                and ("res://" + f.rel) not in scene_scripts and not auto(f)]
    R += ["## 2. Game files only test code references", ""]
    R += ["- `%s` (%d lines): only %s" % (f.rel, len(f.raws), ", ".join(sorted(files[a].stem for a in inbound[f.rel])[:6]))
          for f in sorted(only_sim, key=lambda f: (-len(f.raws), f.rel))] or ["- none"]
    R.append("")

    # 3-5 orphan functions, test-only functions, orphan declarations
    dead_f, test_only_f, dead_d = [], [], []
    def_lines = set((f.rel, s + 1) for f in files.values() for (s, _e) in f.funcs.values())
    for f in files.values():
        decls = _decls(f)
        for key, (s, _e) in f.funcs.items():
            n = key.split("#")[0]
            if n in VIRTUAL or (f.sim and n in ("run", "main")):
                continue
            code = [x for x in g.mentions.get(n, ()) if x not in def_lines]
            strs = g.str_mentions.get(n)
            if not code and not strs and n not in scene_tok:
                dead_f.append((f, key, s + 1))
            elif not f.sim and code and all(files[r].sim for r, _ in code) and not strs and n not in scene_tok \
                    and len(g.func_homes[n]) == 1:
                test_only_f.append((f, key, s + 1, sorted(set(files[r].stem for r, _ in code))))
        for n, (kind, line, exported) in decls.items():
            if exported:
                continue
            code = [(r, l) for (r, l) in g.mentions.get(n, ()) if not (r == f.rel and l == line)]
            if not code and not g.str_mentions.get(n) and n not in scene_tok:
                dead_d.append((f, kind, n, line))
    R += ["## 3. Orphan functions: defined, never named again", "",
          "No call, no Callable, no string (call/connect by name), no scene. Engine callbacks excluded. "
          "A same-named function in another class would hide a dead one, so this list is conservative.", "",
          "**Game code (%d):**" % sum(1 for x in dead_f if not x[0].sim)]
    key3 = lambda x: (x[0].rel, x[2])
    R += ["- `%s:%d` `%s`" % (f.rel, line, n) for f, n, line in sorted(dead_f, key=key3) if not f.sim]
    simd = [x for x in sorted(dead_f, key=key3) if x[0].sim]
    R += ["", "**Sim (%d):** " % len(simd) + ", ".join("`%s.%s`:%d" % (f.stem, n, line) for f, n, line in simd), ""]
    R += ["## 4. Game functions only tests call", "",
          "Defined in game code, named only from scripts/sim. Either a test hook (fine, but say so in its name or comment) "
          "or game code that lost its last caller and is kept alive by its test.", ""]
    R += ["- `%s:%d` `%s` <- %s" % (f.rel, line, n, ", ".join(who[:4]))
          for f, n, line, who in sorted(test_only_f, key=lambda x: (x[0].rel, x[2]))]
    R += ["", "## 5. Orphan constants, variables, signals and enums (top level, never named again)", ""]
    R += ["- `%s:%d` %s `%s`" % (f.rel, line, kind, n) for f, kind, n, line in sorted(dead_d, key=lambda x: (x[0].sim, x[0].rel, x[3]))]
    R.append("")

    # 6 signals on the bus
    sig = g.by_class.get("Sig") or autoload.get("Sig")
    if sig:
        rows, alltext = [], dict((f.rel, "\n".join(f.codes)) for f in files.values())
        for n, (kind, line, _x) in sorted(_decls(sig).items(), key=lambda kv: kv[1][1]):
            if kind != "signal":
                continue
            em_rx = re.compile(r"\b" + n + r"\.emit\(|emit_signal\(\s*&?\"" + n + r"\"")
            co_rx = re.compile(r"\b" + n + r"\.(connect|disconnect)\(|&?\"" + n + r"\"\s*,\s*Callable|await\s+\w+\." + n
                               + r"\b|\b" + n + r"\.is_connected")
            em = [r for r, t in alltext.items() if n in t and em_rx.search(t)]
            co = [r for r, t in alltext.items() if n in t and co_rx.search(t)]
            em_g, co_g = [r for r in em if not files[r].sim], [r for r in co if not files[r].sim]
            if not em_g or not co_g:
                rows.append("- `Sig.%s` (Sig.gd:%d): emitted by %d game / %d sim files, listened to by %d game / %d sim files"
                            % (n, line, len(em_g), len(em) - len(em_g), len(co_g), len(co) - len(co_g)))
        R += ["## 6. Bus signals with a missing end (in game code)", "",
              "A signal on `Sig` that game code never emits, or that no game code listens to.", ""] + (rows or ["- none"]) + [""]

    # 7 layering
    R += ["## 7. Links against the layering", "",
          "tkg/CLAUDE.md: systems are rules with no UI and never reach across scenes (they emit on Sig, UI listens); "
          "data is plain resources; sim is test code. Counted in references, loads and extends. The first three are ratcheted "
          "by the gate (the dispatchers DevFlags and Main, and the autoloads Hints and Ash, are exempt); "
          "autoloads into ui/ is only reported (Router opens screens).", ""]

    def cross(src_ok, dst_ok, title, limit=60):
        rows = [(sum(k.values()), a, b, k) for (a, b), k in fe.items() if src_ok(files[a]) and dst_ok(files[b])]
        R.append("**%s (%d file pairs):**" % (title, len(rows)))
        for w, a, b, k in sorted(rows, key=lambda r: (-r[0], r[1], r[2]))[:limit]:
            R.append("- `%s` -> `%s` (%s)" % (a, b, ", ".join("%d %s" % (n, x) for x, n in sorted(k.items()))))
        if len(rows) > limit:
            R.append("- ... %d more" % (len(rows) - limit))
        R.append("")
    cross(lambda f: not f.sim and f.rel not in DISPATCHERS, lambda f: f.sim, "Game code depending on sim/ (test code)")
    cross(lambda f: f.top == "systems", lambda f: f.top == "ui" and not auto(f), "systems/ reaching into ui/")
    cross(lambda f: f.top == "data", lambda f: (f.top == "ui" and not auto(f)) or f.top in ("systems", "net"),
          "data/ reaching into systems, net or ui")
    cross(lambda f: f.top == "autoload", lambda f: f.top == "ui" and not auto(f), "autoloads reaching into ui/ (reported only)")
    cross(lambda f: f.top == "net", lambda f: f.top == "ui" and not auto(f), "net/ reaching into ui/")

    # 8 private leaks
    R += ["## 8. Private methods called from another file", "",
          "`other._method(...)` where the method is defined in a different, unrelated class. The underscore says private; "
          "the call says it is part of that class's real interface (rename it) or the caller is doing the class's job. "
          "The gate ratchets game-to-game calls; calls from sim are only counted.", ""]
    game_leaks = []
    for (d, m), v in g.private_calls.items():
        v2 = [x for x in v if not files[x[0]].sim]
        if v2 and not files[d].sim:
            game_leaks.append(((d, m), v2))
    by_target = Counter()
    for (d, m), v in game_leaks:
        by_target[d] += len(v)
    R.append("Game-to-game: %d call sites on %d private methods. Worst targets: %s" % (
        sum(len(v) for _, v in game_leaks), len(game_leaks),
        ", ".join("%s %d" % (Path(d).stem, n) for d, n in sorted(by_target.items(), key=lambda kv: (-kv[1], kv[0]))[:15])))
    R.append("")
    R.append("Ratcheted keys that rest on the unique-name guess alone (no declared type): %d of %d."
             % (len(fallback_keys(g) & facts(g)), sum(1 for k in facts(g) if k.startswith("private"))))
    R.append("")
    for (d, m), v in sorted(game_leaks, key=lambda kv: (-len(kv[1]), kv[0]))[:70]:
        callers = Counter(Path(x[0]).stem for x in v)
        hows = set(x[2] for x in v)
        conf = "EXTRACTED" if hows == set(["EXTRACTED"]) else "by name alone" if hows == set(["UNIQUE"]) else "TYPED"
        R.append("- `%s.%s` <- %s [%s]" % (Path(d).stem, m, ", ".join(
            "%s x%d" % (c, n) for c, n in sorted(callers.items(), key=lambda kv: (-kv[1], kv[0]))[:5]), conf))
    sim_leaks = Counter()
    for (d, m), v in g.private_calls.items():
        if not files[d].sim:
            sim_leaks[Path(d).stem] += sum(1 for x in v if files[x[0]].sim)
    R += ["", "Tests reaching into private methods of game classes (call sites per class): " + ", ".join(
        "%s %d" % (k, n) for k, n in sorted(sim_leaks.items(), key=lambda kv: (-kv[1], kv[0]))[:25] if n), ""]

    # 9 cycles
    keep = lambda r: not files[r].sim and not auto(files[r])
    adj = defaultdict(list)
    for (a, b) in fe:
        if keep(a) and keep(b):
            adj[a].append(b)
    sccs = _sccs(adj)
    R += ["## 9. Dependency cycles between game files (autoloads left out)", "",
          "%d groups of files that all reach each other. A big group cannot be read or tested one file at a time." % len(sccs), ""]
    for comp in sccs[:12]:
        R.append("- **%d files:** %s" % (len(comp), ", ".join(sorted(Path(c).stem for c in comp))[:1500]))
    pairs = sorted(set(tuple(sorted((a, b))) for (a, b) in fe if (b, a) in fe and a != b and keep(a) and keep(b)))
    wt = lambda p: sum(fe[(p[0], p[1])].values()) + sum(fe[(p[1], p[0])].values())
    R += ["", "Direct two-way pairs (%d), heaviest first:" % len(pairs)]
    R += ["- `%s` <-> `%s` (%d / %d)" % (Path(a).stem, Path(b).stem, sum(fe[(a, b)].values()), sum(fe[(b, a)].values()))
          for a, b in sorted(pairs, key=lambda p: (-wt(p), p))[:40]]
    R.append("")

    # 10 hubs
    fan_in, fan_out = Counter(), Counter()
    for (a, b) in fe:
        if not files[a].sim:
            fan_out[a] += 1
            fan_in[b] += 1
    top = lambda c: ", ".join("%s %d" % (Path(k).stem, n) for k, n in sorted(c.items(), key=lambda kv: (-kv[1], kv[0]))[:20])
    R += ["## 10. Hubs (game code only)", "", "Most depended on: " + top(fan_in), "",
          "Depends on the most files: " + top(fan_out), ""]
    return "\n".join(R) + "\n"


def _decls(f):
    """Top-level const/var/signal/enum: name -> (kind, line, exported)."""
    out = {}
    for i, c in enumerate(f.bare):
        if c[:1] in (" ", "\t", ""):
            continue
        m = re.match(r"(?:@\w+(?:\([^)]*\))?\s+)*(?:static\s+)?(const|var|signal|enum)\s+([A-Za-z_]\w*)", c)
        if m:
            out[m.group(2)] = (m.group(1), i + 1, "@export" in c or "@onready" in c)
    return out


def _sccs(adj):
    """Strongly connected groups of more than one file, biggest first, in a fixed order."""
    sys.setrecursionlimit(10000)
    index, low, on, stack, out, counter = {}, {}, set(), [], [], [0]

    def strong(v):
        index[v] = low[v] = counter[0]
        counter[0] += 1
        stack.append(v)
        on.add(v)
        for w in sorted(adj[v]):
            if w not in index:
                strong(w)
                low[v] = min(low[v], low[w])
            elif w in on:
                low[v] = min(low[v], index[w])
        if low[v] == index[v]:
            comp = []
            while True:
                w = stack.pop()
                on.discard(w)
                comp.append(w)
                if w == v:
                    break
            if len(comp) > 1:
                out.append(sorted(comp))
    for v in sorted(adj):
        if v not in index:
            strong(v)
    return sorted(out, key=lambda c: (-len(c), c))


def main(argv):
    if "--selftest" in argv:
        bad = selftest()
        for b in bad:
            print("SELFTEST " + b)
        print("code graph selftest: %s" % ("FAIL (%d)" % len(bad) if bad else "PASS"))
        return 1 if bad else 0
    if "--update" in argv:
        return check(True)
    for flag in ("--report", "--graphify"):
        if flag in argv:
            i = argv.index(flag)
            nxt = argv[i + 1] if i + 1 < len(argv) and not argv[i + 1].startswith("--") else None
            if flag == "--graphify" and not nxt:
                print("usage: code_graph.py --graphify PATH")
                return 2
            g = build(deep=True)
            if flag == "--graphify":
                graphify(g, nxt)
            else:
                path = nxt or str(Path(tempfile.gettempdir()) / "three_kelvin_code_graph.md")
                Path(path).write_text(report(g), encoding="utf-8")
                print("wrote " + path)
            return 0
    return check(False)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
