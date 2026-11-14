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
import os
import re
import sys
import tempfile
import textwrap
from collections import Counter, defaultdict, namedtuple
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
CALL = re.compile(r"(?<!\w)([A-Za-z_]\w*)\s*\(")
IDENT_TAIL = re.compile(r"([A-Za-z_]\w*)$")
NEW_TAIL = re.compile(r"([A-Za-z_]\w*)\s*\.\s*new$")
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
CLASS_NAME = re.compile(r"\s*class_name\s+(\w+)")
EXTENDS = re.compile(r"\s*extends\s+(\"[^\"]+\"|[\w.]+)")
AS_TAIL = re.compile(r"\bas\s+([A-Z]\w*)\s*$")


PrivateCall = namedtuple("PrivateCall", "caller line how")   # one call of a private method, how it was resolved
Span = namedtuple("Span", "start end")                       # a func: first line index, one past the last


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
        self.autoload = False    # set by Graph when project.godot lists this file
        self.class_name = None
        self.extends = None
        for bare, code in zip(self.bare[:40], self.codes[:40]):
            m = CLASS_NAME.match(bare)
            if m:
                self.class_name = m.group(1)
            m = None if self.extends else EXTENDS.match(code)
            if m:
                self.extends = m.group(1).strip('"')
        self.find_funcs()

    def find_funcs(self):
        """Every func by position: funcs[key] = Span(first line index, one past last), key as
        code_check.function_spans names it."""
        self.funcs = {}
        self.names = set()       # the plain names, for finding a method
        self.params = {}         # key -> [(name, Class or None)]
        self.span_of = [None] * len(self.codes)
        for key, s, end, m in code_check.function_spans(self.raws, self.codes):
            self.funcs[key] = Span(s, end)
            self.names.add(m.group(1))
            self.params[key] = params_of(paren_text(self.bare[s:s + 12]))
            for j in range(s, end):
                self.span_of[j] = key


def read_text(p):
    return p.read_text(encoding="utf-8", errors="replace")


class Graph:
    """Every script under tkg/scripts, the names that point at them, and what build() finds between them."""

    def __init__(self, tkg):
        self.files = {}
        for gd in sorted((tkg / "scripts").rglob("*.gd")):
            s = Script(gd, tkg)
            self.files[s.rel] = s
        self.by_class = {f.class_name: f for f in self.files.values() if f.class_name}
        self.by_path = {"res://" + f.rel: f for f in self.files.values()}
        self.project = read_text(tkg / "project.godot")
        self.autoload = {}
        for m in re.finditer(r'^(\w+)="\*?(res://[^"]+)"', self.project, re.M):
            if m.group(2) in self.by_path:
                self.autoload[m.group(1)] = self.by_path[m.group(2)]
        for f in self.autoload.values():
            f.autoload = True
        self.name_to_file = dict(self.by_class)
        self.name_to_file.update(self.autoload)
        self.func_homes = defaultdict(list)       # every file, sim too: the report's census
        self.game_homes = defaultdict(list)       # game code only: what "defined in exactly one file" means
        for f in self.files.values():
            for n in sorted(f.names):
                self.func_homes[n].append(f)
                if not f.sim:
                    self.game_homes[n].append(f)
        self._chains = {}
        self.file_edges = defaultdict(Counter)   # (src rel, dst rel) -> Counter of kind: references, loads, extends
        self.call_edges = Counter()              # (src rel, src func, dst rel, dst func, confidence) -> n
        self.private_calls = defaultdict(list)   # (def rel, method) -> [PrivateCall]
        self.mentions = defaultdict(list)        # identifier -> [(rel, line)] in code
        self.str_mentions = defaultdict(list)    # identifier -> [(rel, line)] in strings

    def base_class(self, f):
        """The file f extends, or None."""
        e = f.extends
        return (self.by_class.get(e) or self.by_path.get(e)) if e else None

    def base_chain(self, f):
        """f, then the file it extends, and so on up."""
        if f.rel not in self._chains:
            out, seen, cur = [], set(), f
            while cur and cur.rel not in seen:
                seen.add(cur.rel)
                out.append(cur)
                cur = self.base_class(cur)
            self._chains[f.rel] = out
        return self._chains[f.rel]

    def find_method(self, f, name):
        """The file in f's base chain that defines `name`, or None."""
        for b in self.base_chain(f):
            if name in b.names:
                return b
        return None

    def game_private(self):
        """{(def rel, method): [PrivateCall]} for private methods of game code, the calls made from game code."""
        out = {}
        for (d, m), calls in self.private_calls.items():
            game = [c for c in calls if not self.files[c.caller].sim]
            if game and not self.files[d].sim:
                out[(d, m)] = game
        return out


def build(deep=False, tkg=None):
    """The scripts, their file-to-file links and the private calls. deep adds the function-level
    calls and the name census the report and the graphify JSON need; the ratchet facts come from one
    path either way."""
    g = Graph(tkg or TKG)
    for f in g.files.values():
        src = f.rel
        toks = [w for w in TOKEN.findall(NODEPATH.sub(" ", "\n".join(f.bare))) if w in g.name_to_file]
        if toks:
            shadow = _declared(f) & set(toks)
            for w in toks:
                t = g.name_to_file[w]
                if t is not f and w not in shadow:
                    g.file_edges[(src, t.rel)]["references"] += 1
        for c in f.codes:
            if "res://" in c:
                for p in RES_PATH.findall(c):
                    t = g.by_path.get(p)
                    if t is not None and t is not f:
                        g.file_edges[(src, t.rel)]["loads"] += 1
        b = g.base_class(f)
        if b is not None and b is not f:
            g.file_edges[(src, b.rel)]["extends"] += 1
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


class Scopes:
    """The declared class of a name in one file, by function. Member scope: declarations outside any
    function. A function's scope: its parameters and its own declarations. Each is built on first
    use, since only a call on another object asks."""

    def __init__(self, g, f):
        self.nm, self.f = g.name_to_file, f
        self._member = None
        self._local = {}

    def member(self):
        if self._member is None:
            self._member = {}
            for i, c in enumerate(self.f.bare):
                if self.f.span_of[i] is None:
                    _scan_decls(c, self.nm, self._member)
        return self._member

    def local(self, key):
        d = self._local.get(key)
        if d is None:
            d = self._local[key] = {}
            s, e = self.f.funcs[key]   # a Span
            for pname, ptype in self.f.params[key]:
                _put(d, pname, ptype if ptype in self.nm else "")
            for c in self.f.bare[s:e]:
                _scan_decls(c, self.nm, d)
        return d

    def class_of(self, key, name):
        """The declared class name of `name` inside function `key` (None for no function), or ''/None."""
        loc = self.local(key) if key else {}
        return loc[name] if name in loc else self.member().get(name)


def _receiver(g, pre, scopes, key):
    """What stands before a call: (kind, file or None). `pre` is the text before the method name, with
    its `.` if there is one. kind: 'self' (no receiver, self or super), 'class' (a class, autoload or
    cast: exact), 'typed' (a variable with a declared class), 'unknown' (an expression, or an untyped
    variable)."""
    pre = pre.rstrip()
    if not pre.endswith("."):
        return "self", None
    nm = g.name_to_file
    pre = pre[:-1].rstrip()
    m = IDENT_TAIL.search(pre)
    if m:
        name = m.group(1)
        if pre[:m.start()].rstrip().endswith("."):
            return "unknown", None
        if name in ("self", "super"):
            return "self", None
        if name in nm:
            return "class", nm[name]
        t = scopes.class_of(key, name)
        return ("typed", nm[t]) if t else ("unknown", None)
    k = _open_paren(pre) if pre.endswith(")") else -1
    if k >= 0:
        inner, before = pre[k + 1:-1], pre[:k].rstrip()
        ma = AS_TAIL.search(inner)
        if ma and ma.group(1) in nm:
            return "typed", nm[ma.group(1)]
        mn = NEW_TAIL.search(before)
        if mn and mn.group(1) in nm and not before[:mn.start()].rstrip().endswith("."):
            return "typed", nm[mn.group(1)]
    return "unknown", None


def _open_paren(s):
    """The index of the `(` that closes the `)` ending s, or -1."""
    d = 0
    for k in range(len(s) - 1, -1, -1):
        if s[k] == ")":
            d += 1
        elif s[k] == "(":
            d -= 1
            if d == 0:
                return k
    return -1


def _resolve(g, f, meth, pre, scopes, key):
    """(file that defines the method, how found) for a call, or (None, None). how: EXTRACTED (self, a
    class, an autoload), TYPED (a variable or cast with a declared class), UNIQUE (the last resort: a
    private `_x` defined in exactly one game file, for a receiver that is an expression or untyped)."""
    kind, tgt = _receiver(g, pre, scopes, key)
    how = {"self": "EXTRACTED", "class": "EXTRACTED", "typed": "TYPED"}.get(kind)
    if how:
        return g.find_method(tgt or f, meth), how
    if meth.startswith("_") and meth not in VIRTUAL and len(g.game_homes.get(meth, ())) == 1:
        return g.game_homes[meth][0], "UNIQUE"
    return None, None


def _calls(g, f, deep):
    """Resolve calls in one file. Honest rule: a call resolves only when the receiver is self/bare,
    a class_name or autoload, a variable or cast with a declared class, a `Class.new()`, or a
    private `_x` defined in exactly one game file (the last resort, marked UNIQUE). A public method on
    an untyped receiver is never guessed (Array.resize, Node.add_child); a receiver that is any
    other expression (`a[i]._m()`, `f()._m()`) is not `self`. deep also records the per-word census and
    the public call edges, which only the report and the graph read."""
    scopes = Scopes(g, f)
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
        is_def = FUNC_LINE.match(c) is not None
        for m in CALL.finditer(c):
            meth = m.group(1)
            private = meth.startswith("_")
            if not (private or deep):
                continue
            pre = c[:m.start()].rstrip()
            if is_def and cur and meth == cur.split("#")[0] and not pre.endswith("."):
                continue
            dst, how = _resolve(g, f, meth, pre, scopes, cur)
            if dst is None:
                continue
            if deep and cur:
                g.call_edges[(f.rel, cur, dst.rel, meth, how)] += 1
            if dst is not f and private and meth not in VIRTUAL \
                    and dst not in g.base_chain(f) and f not in g.base_chain(dst):
                g.private_calls[(dst.rel, meth)].append(PrivateCall(f.rel, i + 1, how))


# ---- the layering rules and the ratcheted facts

LayerRule = namedtuple("LayerRule", "title src dst hint ratcheted")


def is_screen(f):
    """A file under ui/ that is not an autoload: Hints and Ash sit there but are singletons anyone may use."""
    return f.top == "ui" and not f.autoload


# One row per rule, in the report's order. A row is a dependency from a file where `src` holds to a file
# where `dst` holds; `hint` is what a NEW break says; a row not `ratcheted` is only reported (Router opens screens).
LAYER_RULES = (
    LayerRule("Game code depending on sim/ (test code)",
              lambda a: not a.sim and a.rel not in DISPATCHERS, lambda b: b.sim,
              "game code may not depend on test code", True),
    LayerRule("systems/ reaching into ui/", lambda a: a.top == "systems", is_screen,
              "breaks the layering (tkg/CLAUDE.md)", True),
    LayerRule("data/ reaching into systems, net or ui", lambda a: a.top == "data",
              lambda b: is_screen(b) or b.top in ("systems", "net"),
              "breaks the layering (tkg/CLAUDE.md)", True),
    LayerRule("autoloads reaching into ui/ (reported only)", lambda a: a.top == "autoload", is_screen,
              None, False),
    LayerRule("net/ reaching into ui/", lambda a: a.top == "net", is_screen,
              "breaks the layering (tkg/CLAUDE.md)", True),
)


def layer_breaks(g):
    """{key: the ratcheted rule it breaks} for every file link that breaks one. Stable across
    unrelated edits: file names only."""
    out = {}
    for (a, b) in g.file_edges:
        fa, fb = g.files[a], g.files[b]
        for rule in LAYER_RULES:
            if rule.ratcheted and rule.src(fa) and rule.dst(fb):
                out["layer %s -> %s" % (a, b)] = rule
                break
    return out


def private_keys(g):
    """{key: True when every call of it rests on the unique-name guess (no declared type)} for the
    private reach-ins of game code into game code."""
    out = {}
    for (d, m), calls in g.game_private().items():
        for caller in set(c.caller for c in calls):
            out["private %s::%s <- %s" % (d, m, caller)] = all(c.how == "UNIQUE" for c in calls if c.caller == caller)
    return out


def facts(g):
    """The set of ratcheted keys."""
    return set(layer_breaks(g)) | set(private_keys(g))


def fallback_keys(g):
    """The private keys every call of which rests on the unique-name guess."""
    return set(k for k, guessed in private_keys(g).items() if guessed)


def read_baseline():
    if not BASELINE.is_file():
        return set()
    return set(l for l in BASELINE.read_text(encoding="utf-8").splitlines() if l.strip() and not l.startswith("#"))


def write_baseline(keys):
    BASELINE.write_text(HEADER + "\n".join(sorted(keys)) + "\n", encoding="utf-8")


def _hint(key, breaks, guess):
    if key in breaks:
        return "   <- " + breaks[key].hint
    hint = "   <- private to its class: make it public, or ask through the class's own API"
    if key in guess:
        hint += " (found by name alone: if another game file just gained or lost a method of this name, --update with a note)"
    return hint


def check(update):
    g = build()
    now, old = facts(g), read_baseline()
    if update:
        for k in sorted(now - old):
            print("ADDED " + k)
        write_baseline(now)
        print("code graph: recorded %d entries (was %d), from %d scripts" % (len(now), len(old), len(g.files)))
        return 0
    breaks, guess = layer_breaks(g), fallback_keys(g)
    new, fixed = sorted(now - old), sorted(old - now)
    for k in new:
        print("NEW " + k + _hint(k, breaks, guess))
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


def _node(nid, label, rel, line, metadata):
    return {"id": nid, "label": label, "file_type": "code", "source_file": "tkg/" + rel,
            "source_location": "L%d" % line, "metadata": {"language": "gdscript", **metadata}}


def _edge(source, target, relation, rel, weight, extracted=True):
    """One edge of the JSON: key order is part of the file's bytes."""
    return {"source": source, "target": target, "relation": relation,
            "confidence": "EXTRACTED" if extracted else "INFERRED", "confidence_score": 1.0 if extracted else 0.7,
            "source_file": "tkg/" + rel, "weight": float(weight)}


def graphify_data(g):
    nodes, edges = [], []
    for f in g.files.values():
        fid = node_id(f.rel)
        nodes.append(_node(fid, f.stem, f.rel, 1, {"kind": "file", "layer": f.top, "lines": len(f.raws)}))
        for n, span in f.funcs.items():
            nodes.append(_node(node_id(f.rel, n), "%s.%s" % (f.stem, n), f.rel, span.start + 1, {"kind": "function"}))
            edges.append(_edge(fid, node_id(f.rel, n), "contains", f.rel, 1))
    for (a, b), kinds in g.file_edges.items():
        for k, w in sorted(kinds.items()):
            edges.append(_edge(node_id(a), node_id(b), {"loads": "imports"}.get(k, k), a, min(w, 10)))
    for (a, fa, b, fb, how), w in g.call_edges.items():
        s, t = node_id(a, fa), node_id(b, fb)
        if s != t:
            edges.append(_edge(s, t, "calls", a, min(w, 10), how == "EXTRACTED"))
    ids = set(n["id"] for n in nodes)
    edges = [e for e in edges if e["source"] in ids and e["target"] in ids]
    return {"nodes": nodes, "edges": edges, "hyperedges": [], "input_tokens": 0, "output_tokens": 0}


def graphify(g, path):
    data = graphify_data(g)
    Path(path).write_text(json.dumps(data), encoding="utf-8")
    print("wrote %s (%d nodes, %d edges)" % (path, len(data["nodes"]), len(data["edges"])))


# ---- the self-test

SELFTEST_PROJECT = '[autoload]\nHints="*res://scripts/ui/Hints.gd"\n'

Case = namedtuple("Case", "path source layer private")   # layer and private: the facts the file must produce


def gd(text):
    """GDScript written with four spaces per level, dedented and turned into the tabs it needs."""
    lines = textwrap.dedent(text).strip("\n").split("\n")
    return "\n".join(re.sub(r"^((?:    )+)", lambda m: "\t" * (len(m.group(1)) // 4), l) for l in lines) + "\n"


# Paths are under scripts/. layer=("ui/Board.gd",) means "layer <this file> -> scripts/ui/Board.gd" is expected;
# private=("ui/Screen.gd::_keep",) means "private scripts/ui/Screen.gd::_keep <- <this file>".
SELFTEST_CASES = (
    Case("Main.gd", gd("""
        extends Node
        func _ready():
            var p := Probe.new()    # a dispatcher: loading a harness is its job
        """), (), ()),
    Case("sim/Probe.gd", gd("""
        class_name Probe
        extends Node
        func _uq():
            pass
        """), (), ()),
    Case("ui/Hints.gd", gd("""
        extends Node
        func tip():
            pass
        """), (), ()),
    Case("ui/Board.gd", gd("""
        class_name Board
        extends Node
        func show_it():
            pass
        func _priv():
            pass
        func _setter_target():
            pass
        func _dup():
            pass
        func _uq():
            pass
        """), (), ()),
    Case("ui/CardView.gd", gd("""
        class_name CardView
        extends Node
        const Z := 1
        func _z():
            pass
        """), (), ()),
    Case("ui/Screen.gd", gd("""
        class_name Screen
        extends Node
        func _keep():
            pass
        func _nw():
            pass
        func _foo():
            pass
        func foo():
            _foo()
        """), (), ()),
    Case("ui/Other.gd", gd("""
        class_name Other
        extends Node
        func _keep():
            pass
        func _nw():
            pass
        func _dup():
            pass
        """), (), ()),
    Case("data/Tbl.gd", gd("""
        class_name Tbl
        extends Resource
        func x():
            return Rules.new()
        """), ("systems/Rules.gd",), ()),
    Case("systems/Rules.gd", gd("""
        class_name Rules
        extends Node
        var b: Board
        func a(v: CardView):
            pass
        func b2(v):
            v._z(CardView.Z)             # an untyped v: not typed by a()'s parameter, found by name alone
        func c(arr):
            (Router.current as Screen)._keep()   # a cast
            Screen.new()._nw()                   # a fresh instance
            arr[0]._keep()                       # an expression: not self, and not unique
            _make()._nw()
        func d(ok):
            if ok: Board.show_it()
            ok._dup()                    # ok is not typed Board
        func _make():
            return 1
        """), ("ui/Board.gd", "ui/CardView.gd", "ui/Screen.gd"),
         ("ui/CardView.gd::_z", "ui/Screen.gd::_keep", "ui/Screen.gd::_nw")),
    Case("systems/Doc.gd", gd('''
        extends Node
        var t = """
        Screen._keep() and Hints and Board
        """
        func f():
            pass
        '''), (), ()),
    Case("systems/Nodes.gd", gd("""
        extends Node
        func f():
            var n = $Screen
            var m = %Screen
            return $Board/Other
        """), (), ()),
    Case("systems/Enums.gd", gd("""
        extends Node
        enum Kind { Screen, Board }
        func f(k):
            return Kind.Screen
        """), (), ()),
    Case("systems/Shadow.gd", gd("""
        extends Node
        func f(Screen):
            var Board = 3
            return Screen + Board
        """), (), ()),
    Case("systems/Inner.gd", gd("""
        extends Node
        class A:
            func go():
                pass
        class B:
            func go():
                Board._priv()
        var prop: int:
            set(v):
                Board._setter_target()
        """), ("ui/Board.gd",), ("ui/Board.gd::_priv", "ui/Board.gd::_setter_target")),
    Case("systems/Uniq.gd", gd("""
        extends Node
        func f(x):
            x._uq()
            Hints.tip()
        """), (), ("ui/Board.gd::_uq",)),
    Case("systems/UsesSim.gd", gd("""
        extends Node
        func f():
            return Probe.new()
        """), ("sim/Probe.gd",), ()),
    Case("net/Dup.gd", gd("""
        extends Node
        func foo():
            pass
        func _foo():
            foo()
        """), (), ()),
)


def expected_facts():
    out = set()
    for c in SELFTEST_CASES:
        me = "scripts/" + c.path
        out.update("layer %s -> scripts/%s" % (me, t) for t in c.layer)
        for p in c.private:
            definer, method = p.split("::")
            out.add("private scripts/%s::%s <- %s" % (definer, method, me))
    return out


def selftest():
    """Build a tiny tree, assert the exact facts. Returns the list of mismatches (empty = pass)."""
    bad = []
    with tempfile.TemporaryDirectory(prefix="code_graph_selftest_") as tmp:
        tkg = Path(tmp) / "tkg"
        tkg.mkdir()
        (tkg / "project.godot").write_text(SELFTEST_PROJECT, encoding="utf-8")
        for c in SELFTEST_CASES:
            p = tkg / "scripts" / c.path
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text(c.source, encoding="utf-8")
        g = build(True, tkg)
    expect, got = expected_facts(), facts(g)
    bad += ["missing " + k for k in sorted(expect - got)]
    bad += ["unexpected " + k for k in sorted(got - expect)]
    data = graphify_data(g)
    ids = [n["id"] for n in data["nodes"]]
    if len(ids) != len(set(ids)):
        bad.append("graphify node ids collide")
    by = dict((n["id"], n["label"]) for n in data["nodes"])
    if any(e["source"] == e["target"] for e in data["edges"]):
        bad.append("graphify self-loop")
    call = [(by[e["source"]], by[e["target"]]) for e in data["edges"] if e["relation"] == "calls"]
    if ("Screen.foo", "Screen._foo") not in call:
        bad.append("graphify lost the edge Screen.foo -> Screen._foo")
    if ("Dup.foo", "Dup._foo") in call or ("Dup._foo", "Dup.foo") not in call:
        bad.append("graphify edge direction for Dup._foo -> Dup.foo wrong")
    inner = sorted(g.files["scripts/systems/Inner.gd"].funcs)
    if inner != ["go", "go#2"]:
        bad.append("same-named funcs not kept apart: %s" % inner)
    return bad


def _tokens(paths):
    out = set()
    for p in paths:
        if p.is_file() and "__pycache__" not in p.parts:
            out.update(IDENT.findall(read_text(p)))
    return out


def ranked(counts, n):
    """The n biggest (key, count) pairs of a Counter, ties by key."""
    return sorted(counts.items(), key=lambda kv: (-kv[1], kv[0]))[:n]


def by_size(f):
    """Sort key: longest file first, then by path."""
    return (-len(f.raws), f.rel)


DeadFunc = namedtuple("DeadFunc", "file key line")
TestOnlyFunc = namedtuple("TestOnlyFunc", "file key line callers")
DeadDecl = namedtuple("DeadDecl", "file kind name line")


class Report:
    """The markdown report: one method per section, each returning its lines. The inputs every
    section reads are gathered once, in __init__."""

    def __init__(self, g):
        self.g = g
        self.files, self.fe = g.files, g.file_edges
        scene_text = "\n".join(read_text(p) for pat in ("*.tscn", "*.tres") for p in sorted(TKG.rglob(pat))
                               if ".godot" not in p.parts)
        self.scene_scripts = set(RES_PATH.findall(scene_text)) | set(RES_PATH.findall(g.project))
        self.scene_tok = set(IDENT.findall(scene_text))
        self.outside = _tokens(sorted((ROOT / ".github").rglob("*.sh")) + sorted((ROOT / "tools").rglob("*.sh")) +
                               sorted((ROOT / "tools").rglob("*.py")) + [ROOT / "docs" / "tests.md"])
        self.inbound = defaultdict(set)
        for (a, b) in self.fe:
            self.inbound[b].add(a)
        self.dead_funcs, self.test_only, self.dead_decls = self._find_dead()

    def lines(self):
        out = self.intro()
        for section in (self.orphan_files, self.test_kept_files, self.orphan_funcs, self.test_only_funcs,
                        self.orphan_decls, self.bus_signals, self.layering, self.private_leaks, self.cycles, self.hubs):
            out += section()
        return "\n".join(out) + "\n"

    def _named_in_a_scene(self, f):
        return ("res://" + f.rel) in self.scene_scripts

    def _find_dead(self):
        """(functions never named again, game functions only tests name, top-level declarations never named again)."""
        g, files = self.g, self.files
        dead_f, test_only, dead_d = [], [], []
        def_lines = set((f.rel, span.start + 1) for f in files.values() for span in f.funcs.values())
        for f in files.values():
            for key, span in f.funcs.items():
                n = key.split("#")[0]
                if n in VIRTUAL or (f.sim and n in ("run", "main")):
                    continue
                code = [x for x in g.mentions.get(n, ()) if x not in def_lines]
                strs = g.str_mentions.get(n)
                if not code and not strs and n not in self.scene_tok:
                    dead_f.append(DeadFunc(f, key, span.start + 1))
                elif not f.sim and code and all(files[r].sim for r, _ in code) and not strs and n not in self.scene_tok \
                        and len(g.func_homes[n]) == 1:
                    test_only.append(TestOnlyFunc(f, key, span.start + 1, sorted(set(files[r].stem for r, _ in code))))
            for n, (kind, line, exported) in _decls(f).items():
                if exported:
                    continue
                code = [(r, l) for (r, l) in g.mentions.get(n, ()) if not (r == f.rel and l == line)]
                if not code and not g.str_mentions.get(n) and n not in self.scene_tok:
                    dead_d.append(DeadDecl(f, kind, n, line))
        return dead_f, test_only, dead_d

    def intro(self):
        return ["# Code graph: orphaned and oddly linked code", "",
                "Built from %d scripts by a deterministic extractor (no LLM): comments stripped, class_name / autoload / "
                "res:// path references, extends, and calls resolved by receiver (EXTRACTED when the receiver is self, a class or an "
                "autoload; INFERRED when it is a typed variable, or a private `_name` that exists in exactly one file; a public "
                "method on an untyped receiver gets no edge, because it cannot be told from an engine method). "
                "GDScript is dynamic, so every row is a lead to confirm, not a verdict." % len(self.files), ""]

    def orphan_files(self):
        out = ["## 1. Orphan files: nothing references them", "",
               "No other script names the class, loads the path or extends it; not an autoload, not in a scene. "
               "For sim files 'named outside' means validate.sh, run_battery.sh, tools/ or docs/tests.md mention the stem or its flag.", ""]
        game_orph, sim_orph = [], []
        for f in self.files.values():
            if self.inbound[f.rel] or self._named_in_a_scene(f) or f.autoload:
                continue
            if not f.sim:
                game_orph.append(f)
            elif f.stem not in self.outside and f.stem.lower() not in self.outside:
                sim_orph.append(f)
        out.append("**Game code (%d):**" % len(game_orph))
        out += ["- `%s` (%d lines)" % (f.rel, len(f.raws)) for f in sorted(game_orph, key=by_size)] or ["- none"]
        out += ["", "**Sim, also named nowhere outside (%d, %d lines):** " % (len(sim_orph), sum(len(f.raws) for f in sim_orph))
                + ", ".join("%s (%d)" % (f.stem, len(f.raws)) for f in sorted(sim_orph, key=by_size)), ""]
        return out

    def test_kept_files(self):
        files = self.files
        only_sim = [f for f in files.values() if not f.sim and self.inbound[f.rel]
                    and all(files[a].sim for a in self.inbound[f.rel])
                    and not self._named_in_a_scene(f) and not f.autoload]
        out = ["## 2. Game files only test code references", ""]
        out += ["- `%s` (%d lines): only %s" % (f.rel, len(f.raws), ", ".join(sorted(files[a].stem for a in self.inbound[f.rel])[:6]))
                for f in sorted(only_sim, key=by_size)] or ["- none"]
        return out + [""]

    def orphan_funcs(self):
        dead = sorted(self.dead_funcs, key=lambda d: (d.file.rel, d.line))
        game = [d for d in dead if not d.file.sim]
        sim = [d for d in dead if d.file.sim]
        return (["## 3. Orphan functions: defined, never named again", "",
                 "No call, no Callable, no string (call/connect by name), no scene. Engine callbacks excluded. "
                 "A same-named function in another class would hide a dead one, so this list is conservative.", "",
                 "**Game code (%d):**" % len(game)]
                + ["- `%s:%d` `%s`" % (d.file.rel, d.line, d.key) for d in game]
                + ["", "**Sim (%d):** " % len(sim) + ", ".join("`%s.%s`:%d" % (d.file.stem, d.key, d.line) for d in sim), ""])

    def test_only_funcs(self):
        return (["## 4. Game functions only tests call", "",
                 "Defined in game code, named only from scripts/sim. Either a test hook (fine, but say so in its name or comment) "
                 "or game code that lost its last caller and is kept alive by its test.", ""]
                + ["- `%s:%d` `%s` <- %s" % (d.file.rel, d.line, d.key, ", ".join(d.callers[:4]))
                   for d in sorted(self.test_only, key=lambda d: (d.file.rel, d.line))])

    def orphan_decls(self):
        return (["", "## 5. Orphan constants, variables, signals and enums (top level, never named again)", ""]
                + ["- `%s:%d` %s `%s`" % (d.file.rel, d.line, d.kind, d.name)
                   for d in sorted(self.dead_decls, key=lambda d: (d.file.sim, d.file.rel, d.line))]
                + [""])

    def bus_signals(self):
        g, files = self.g, self.files
        sig = g.by_class.get("Sig") or g.autoload.get("Sig")
        if not sig:
            return []
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
        return ["## 6. Bus signals with a missing end (in game code)", "",
                "A signal on `Sig` that game code never emits, or that no game code listens to.", ""] + (rows or ["- none"]) + [""]

    def layering(self):
        out = ["## 7. Links against the layering", "",
               "tkg/CLAUDE.md: systems are rules with no UI and never reach across scenes (they emit on Sig, UI listens); "
               "data is plain resources; sim is test code. Counted in references, loads and extends. The first three are ratcheted "
               "by the gate (the dispatchers DevFlags and Main, and the autoloads Hints and Ash, are exempt); "
               "autoloads into ui/ is only reported (Router opens screens).", ""]
        for rule in LAYER_RULES:
            out += self._cross(rule)
        return out

    def _cross(self, rule, limit=60):
        files = self.files
        rows = [(sum(k.values()), a, b, k) for (a, b), k in self.fe.items() if rule.src(files[a]) and rule.dst(files[b])]
        out = ["**%s (%d file pairs):**" % (rule.title, len(rows))]
        for _w, a, b, k in sorted(rows, key=lambda r: (-r[0], r[1], r[2]))[:limit]:
            out.append("- `%s` -> `%s` (%s)" % (a, b, ", ".join("%d %s" % (n, x) for x, n in sorted(k.items()))))
        if len(rows) > limit:
            out.append("- ... %d more" % (len(rows) - limit))
        return out + [""]

    def private_leaks(self):
        g, files = self.g, self.files
        out = ["## 8. Private methods called from another file", "",
               "`other._method(...)` where the method is defined in a different, unrelated class. The underscore says private; "
               "the call says it is part of that class's real interface (rename it) or the caller is doing the class's job. "
               "The gate ratchets game-to-game calls; calls from sim are only counted.", ""]
        game_leaks = g.game_private()
        by_target = Counter()
        for (d, _m), v in game_leaks.items():
            by_target[d] += len(v)
        keys = private_keys(g)
        out.append("Game-to-game: %d call sites on %d private methods. Worst targets: %s" % (
            sum(len(v) for v in game_leaks.values()), len(game_leaks),
            ", ".join("%s %d" % (Path(d).stem, n) for d, n in ranked(by_target, 15))))
        out.append("")
        out.append("Ratcheted keys that rest on the unique-name guess alone (no declared type): %d of %d."
                   % (sum(keys.values()), len(keys)))
        out.append("")
        for (d, m), v in sorted(game_leaks.items(), key=lambda kv: (-len(kv[1]), kv[0]))[:70]:
            callers = Counter(Path(c.caller).stem for c in v)
            hows = set(c.how for c in v)
            conf = "EXTRACTED" if hows == set(["EXTRACTED"]) else "by name alone" if hows == set(["UNIQUE"]) else "TYPED"
            out.append("- `%s.%s` <- %s [%s]" % (Path(d).stem, m, ", ".join(
                "%s x%d" % (c, n) for c, n in ranked(callers, 5)), conf))
        sim_leaks = Counter()
        for (d, _m), v in g.private_calls.items():
            if not files[d].sim:
                sim_leaks[Path(d).stem] += sum(1 for c in v if files[c.caller].sim)
        return out + ["", "Tests reaching into private methods of game classes (call sites per class): " + ", ".join(
            "%s %d" % (k, n) for k, n in ranked(sim_leaks, 25) if n), ""]

    def _is_game_file(self, rel):
        """A game file that is not an autoload: the files whose cycles are worth reading."""
        return not self.files[rel].sim and not self.files[rel].autoload

    def cycles(self):
        fe = self.fe
        adj = defaultdict(list)
        for (a, b) in fe:
            if self._is_game_file(a) and self._is_game_file(b):
                adj[a].append(b)
        sccs = _sccs(adj)
        out = ["## 9. Dependency cycles between game files (autoloads left out)", "",
               "%d groups of files that all reach each other. A big group cannot be read or tested one file at a time." % len(sccs), ""]
        for comp in sccs[:12]:
            out.append("- **%d files:** %s" % (len(comp), ", ".join(sorted(Path(c).stem for c in comp))[:1500]))
        pairs = sorted(set(tuple(sorted((a, b))) for (a, b) in fe
                           if (b, a) in fe and a != b and self._is_game_file(a) and self._is_game_file(b)))
        weight = lambda p: sum(fe[(p[0], p[1])].values()) + sum(fe[(p[1], p[0])].values())
        out += ["", "Direct two-way pairs (%d), heaviest first:" % len(pairs)]
        out += ["- `%s` <-> `%s` (%d / %d)" % (Path(a).stem, Path(b).stem, sum(fe[(a, b)].values()), sum(fe[(b, a)].values()))
                for a, b in sorted(pairs, key=lambda p: (-weight(p), p))[:40]]
        return out + [""]

    def hubs(self):
        fan_in, fan_out = Counter(), Counter()
        for (a, b) in self.fe:
            if not self.files[a].sim:
                fan_out[a] += 1
                fan_in[b] += 1
        top = lambda c: ", ".join("%s %d" % (Path(k).stem, n) for k, n in ranked(c, 20))
        return ["## 10. Hubs (game code only)", "", "Most depended on: " + top(fan_in), "",
                "Depends on the most files: " + top(fan_out), ""]


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
                if nxt:
                    path = nxt
                else:
                    # A fresh name each time: a fixed name in a shared temp folder can be pre-made by someone else.
                    fd, path = tempfile.mkstemp(prefix="three_kelvin_code_graph_", suffix=".md")
                    os.close(fd)
                Path(path).write_text(Report(g).lines(), encoding="utf-8")
                print("wrote " + path)
            return 0
    return check(False)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
