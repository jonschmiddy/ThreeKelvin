"""The science mini games' approved layouts (Jon, Nov 19-20): each prototype re-laid out (fit3, fit4),
dressed in the one UI kit (kit.js), then moved to status A on the whole 150x140 glass (a_swaps.py,
Nov 20), as string swaps on the prototype's own file. `page_js(id)` is the JS a page runs: kit.js, then the game with its swaps.
The swaps were made and judged on sheets in tk-scratch/science/games_in/fit (copied here Nov 20).
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import kit_swaps_a as _A  # noqa: E402
import kit_swaps_b as _B  # noqa: E402
import kit_swaps_c as _C  # noqa: E402
import a_swaps as _S  # noqa: E402


def page_js(gid: str) -> str:
    """kit.js, the game with its fit and kit swaps, then its status A swaps (a_swaps.py)."""
    if gid in _A.GAMES:
        js = _A.kit_patched(gid)
    elif gid in _B.GAMES:
        js = _B.kit_patched(gid)
    else:
        js = _C.kit_patched(gid)
    return _S.apply(gid, js)


IDS = list(_A.GAMES) + list(_B.GAMES) + list(_C.KITS)
