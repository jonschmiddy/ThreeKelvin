"""Build a pick page of pictures or films from a small JSON spec.

usage: python tools/dev/pages/make_pick_page.py SPEC.json OUTDIR

SPEC:
{
  "title": "Quest Log",                 two to four words, the browser tab's name
  "intro": "One paragraph: what Jon is deciding and why.",
  "store": "questlog-picks",            localStorage key, unique per page
  "reply": "Quest log",                 the reply line's prefix
  "sections": [
    {"heading": "A · a QUESTS tab", "text": "...",
     "media": [{"src": "C:/.../a.png", "caption": "Four quests"},
               {"src": ".../a.mp4", "caption": "...", "poster": ".../a.png"}],
     "question": "log",                 optional: a question asked in this section
     "options": [{"v": "A", "label": "A · a tab", "note": "one line"}]}
  ]
}

Media are copied into OUTDIR/m/ (MP4 for anything that moves: phones do not
play WebP). Prints the `files` map to pass to the Artifact tool with
root=<OUTDIR's parent>. Decision pages hold three or so options and a reply
letter, not working notes.
"""
import json
import shutil
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import pickpage as P  # noqa: E402


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    spec = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    out = Path(sys.argv[2])
    (out / "m").mkdir(parents=True, exist_ok=True)
    files, order, body = {}, [], []
    body.append(f"<header><h1>{P.esc(spec['title'])}</h1><p>{P.esc(spec.get('intro', ''))}</p></header>")
    for s in spec["sections"]:
        figs = []
        for m in s.get("media", []):
            src = Path(m["src"])
            name = src.name
            shutil.copy(src, out / "m" / name)
            files[f"m/{name}"] = f"{out.name}/m/{name}"
            cap = f"<figcaption>{P.esc(m.get('caption', ''))}</figcaption>" if m.get("caption") else ""
            if src.suffix.lower() in (".mp4", ".webm", ".mov"):
                poster = ""
                if m.get("poster"):
                    pn = Path(m["poster"]).name
                    shutil.copy(m["poster"], out / "m" / pn)
                    files[f"m/{pn}"] = f"{out.name}/m/{pn}"
                    poster = f' poster="m/{P.esc(pn)}"'
                el = f'<video controls playsinline muted loop preload="metadata"{poster} src="m/{P.esc(name)}"></video>'
            else:
                el = f'<img src="m/{P.esc(name)}" alt="{P.esc(m.get("caption", name))}">'
            figs.append(f"<figure>{el}{cap}</figure>")
        q = ""
        if s.get("question"):
            order.append(s["question"])
            q = P.options(s["question"], s["options"])
        text = f"<p>{P.esc(s['text'])}</p>" if s.get("text") else ""
        grid = f'<div class="grid">{"".join(figs)}</div>' if figs else ""
        body.append(f"<section><h2>{P.esc(s['heading'])}</h2>{text}{grid}{q}</section>")
    (out / "index.html").write_text(P.page(spec["title"], "".join(body), spec["store"], spec["reply"], order),
                                    encoding="utf-8")
    print(json.dumps(files))


if __name__ == "__main__":
    main()
