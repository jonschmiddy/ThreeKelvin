"""Pick page for recorded takes: one section per line, each take playable, a
suggestion (the first take with no cut-off flag) and a "fill the rest" button.

usage: python tools/dev/voice/make_page.py OUTDIR "Page Title"
  reads OUTDIR/index.json (voice/record.py fx), writes OUTDIR/page/index.html,
  copies the MP3 previews into OUTDIR/page/m/, prints the Artifact `files` map.
Jon replies "<Title> takes: id:take id:take ..." and voice/install.py installs them.
"""
import json
import re
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent / "pages"))
import pickpage as P  # noqa: E402


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    out = Path(sys.argv[1])
    title = sys.argv[2]
    doc = json.loads((out / "index.json").read_text(encoding="utf-8"))
    page = out / "page"
    (page / "m").mkdir(parents=True, exist_ok=True)
    files, order, secs = {}, [], []
    for e in doc["lines"]:
        i = e["id"]
        if not e["takes"]:
            continue
        order.append(i)
        sugg = next((t["take"] for t in e["takes"] if not t["flag"]), e["takes"][0]["take"])
        cards = []
        for t in e["takes"]:
            name = Path(t["mp3"]).name
            shutil.copy(out / t["mp3"], page / "m" / name)
            files[f"m/{name}"] = f"{page.name}/m/{name}"
            flag = f'<div class="flag">{P.esc(t["flag"])}</div>' if t["flag"] else ""
            cards.append(f'<div class="take{" sugg" if t["take"] == sugg else ""}">'
                         f'<div class="lab">TAKE {t["take"]} · {t["duration_s"]:.1f}s</div>'
                         f'<audio controls preload="none" src="m/{P.esc(name)}"></audio>{flag}'
                         + P.options(i, [{"v": str(t["take"]), "label": f"Pick {t['take']}"}]) + "</div>")
        spoken = "" if e["spoken"] == e["shown"] else f'<p class="sub">Spoken: {P.esc(e["spoken"])}</p>'
        secs.append(f'<section data-id="{P.esc(i)}" data-sugg="{sugg}"><h2>{P.esc(i)}</h2>'
                    f'<p class="said">{P.esc(e["shown"])}</p>{spoken}<div class="takes">{"".join(cards)}</div></section>')
    head = (f"<header><h1>{P.esc(title)}</h1><p>{len(order)} lines in A.S.H.'s voice at the game's level. Pick one take per line. "
            "The lighter-bordered take is the suggestion: the first with no flag. A flag means the ending may be "
            "clipped; listen to the last word.</p>"
            '<div class="bar2"><button type="button" id="fill">Fill the rest with the suggestions</button>'
            '<button type="button" id="clear">Clear picks</button></div></header>')
    extra = """
  document.getElementById("fill").addEventListener("click", function(){
    var p = window.tkPicks.get();
    document.querySelectorAll("section[data-id]").forEach(function(s){ if (!p[s.dataset.id]) window.tkPicks.set(s.dataset.id, s.dataset.sugg); });
  });
  document.getElementById("clear").addEventListener("click", function(){ window.tkPicks.clear(); });"""
    key = "voice-" + re.sub(r"[^a-z0-9]+", "-", title.lower()).strip("-")
    (page / "index.html").write_text(
        P.page(title, head + "".join(secs), key, f"{title} takes", order, empty="Pick a take for each line", extra_js=extra),
        encoding="utf-8")
    print(json.dumps(files))


if __name__ == "__main__":
    main()
