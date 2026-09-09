# -*- coding: utf-8 -*-
"""Flag nautical vocabulary in a generation prompt.

Korvan ships are meant to read as industrial machines, not boats. When the
prompt says boat words the generator draws boat things -- the "working vessel"
prompt in round 9 produced a red antifouling waterline on two hulls of three,
and negating a word does not help: a model told "a bunker rather than a boat"
still draws toward boat.

Run:  python tools/nautical.py "<prompt>"   or pipe the prompt on stdin.
"""
import re
import sys

# Why each is out. Bare hull/deck/ship words plus anything that only exists
# because water does.
NAUTICAL = {
    "vessel": "boat word; use machine, ship, hulk",
    "boat": "boat word, even when negated",
    "ship": None,             # allowed -- spaceship is the subject
    "nautical": "says it outright",
    "naval": "says it outright",
    "maritime": "says it outright",
    "prow": "boat word; use front",
    "bow": "boat word; use front",
    "bows": "boat word; use front",
    "stern": "boat word; use rear, back",
    "aft": "boat word; use rear",
    "fore": "boat word; use front",
    "forecastle": "boat word",
    "beam": "boat word for width -- 'across the beam' reads as boat",
    "waterline": "draws an antifouling stripe",
    "keel": "only exists because of water",
    "rudder": "only exists because of water",
    "helm": "boat word",
    "bilge": "boat word",
    "gunwale": "boat word",
    "hold": "boat word in this sense",
    "port": "boat word; 'lit ports' is fine, this is a false positive risk",
    "starboard": "boat word",
    "deck": "boat word; use platform, level",
    "superstructure": "boat word; use upper works, blocks",
    "bridge": "boat word; use control block",
    "mast": "boat word; use antenna, spar",
    "conning": "submarine word",
    "hull": None,             # allowed -- standard for spacecraft too
    "tug": "boat word",
    "barge": "boat word",
    "frigate": "boat word",
    "destroyer": "boat word",
    "battleship": "boat word",
    "dreadnought": "boat word",
    "submarine": "boat word",
    "trawler": "boat word",
    "freighter": "boat word",
    "tanker": "boat word",
    "sail": "boat word",
    "anchor": "boat word",
    "moor": "boat word",
    "berth": "boat word, and retired from player-facing text",
    "dock": "boat word",
    "harbour": "boat word",
    "harbor": "boat word",
    "afloat": "boat word",
    "seagoing": "boat word",
    "hulk": None,             # allowed -- reads as wreck more than boat
}

BANNED = dict((k, v) for k, v in NAUTICAL.items() if v)


def scan(text):
    """Every banned word in text, as (word, position, reason), in order."""
    hits = []
    for word, reason in BANNED.items():
        for m in re.finditer(r"\b%s\b" % re.escape(word), text, re.I):
            hits.append((m.group(0), m.start(), reason))
    return sorted(hits, key=lambda h: h[1])


def context(text, at, span=34):
    lo = max(0, at - span)
    hi = min(len(text), at + span)
    return ("..." if lo else "") + text[lo:hi].replace("\n", " ") + ("..." if hi < len(text) else "")


if __name__ == "__main__":
    prompt = " ".join(sys.argv[1:]) if len(sys.argv) > 1 else sys.stdin.read()
    hits = scan(prompt)
    if not hits:
        print("  clean -- no nautical vocabulary in %d words" % len(prompt.split()))
    else:
        for word, at, reason in hits:
            print("  %-16s %s" % (word, reason))
            print("  %-16s %s" % ("", context(prompt, at)))
    sys.exit(1 if hits else 0)
