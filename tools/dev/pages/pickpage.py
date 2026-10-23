"""The pick page Jon decides on: sections of pictures, films or sounds, a row of
options per question, and a reply line at the bottom he copies back into chat
("Quest log: A", "Tutorial takes: energy:2 heat:1 ...").

Picks are kept in the browser (localStorage) per page, so a reload keeps them.
The look is the game's own dark, Silkscreen headings over IBM Plex.

Used by make_pick_page.py (pictures and films) and voice/make_page.py (takes).
Publish the folder with Claude's Artifact tool: the page is index.html, and every
file under m/ goes in the `files` map the builder prints.
"""
import html
import json

STYLE = """<style>
:root{
  color-scheme:dark;
  --void:#090c13; --panel:#0f141e; --line:#222c3b; --fg:#d9e1ec; --dim:#8e9bb0; --amber:#f0a043; --pick:#6fcf8f;
  --display:"Silkscreen",ui-monospace,monospace; --body:"IBM Plex Sans",system-ui,sans-serif; --mono:"IBM Plex Mono",ui-monospace,monospace;
}
html,body{background:var(--void);color:var(--fg)}
body{margin:0;font:15px/1.55 var(--body)}
main{max-width:1700px;margin:0 auto;padding-inline:16px;padding-block:28px 120px;display:grid;gap:32px}
h1{font:400 26px/1.2 var(--display);margin:0;text-wrap:balance}
h2{font:400 18px/1.3 var(--display);margin:0;color:var(--amber);text-wrap:balance}
p{margin:0;max-width:72ch}
.dim,.sub{color:var(--dim)} .sub{font-size:13px}
header,section{display:grid;gap:12px;min-width:0}
section{border-top:1px solid var(--line);padding-top:20px}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(min(100%,420px),1fr));gap:12px}
figure{margin:0;display:grid;gap:4px;min-width:0}
figcaption{font-size:13px;color:var(--dim)}
img,video{display:block;width:100%;height:auto;image-rendering:pixelated;border:1px solid var(--line);background:#000}
audio{width:100%;max-width:340px;display:block}
.takes{display:grid;grid-template-columns:repeat(auto-fill,minmax(240px,1fr));gap:12px}
.take{display:grid;gap:6px;padding:10px;border:1px solid var(--line);border-radius:3px;background:var(--panel)}
.take.sugg{border-color:#3a4a5f}
.flag{font-size:12px;color:var(--amber)}
.said{font:14px/1.5 var(--mono);max-width:80ch}
.lab{font:400 13px var(--display)}
.opts{display:flex;flex-wrap:wrap;gap:8px}
.opts button,.bar2 button{font:400 13px var(--display);text-align:left;padding:9px 12px;background:var(--panel);color:var(--fg);border:1px solid var(--line);border-radius:3px;cursor:pointer;max-width:100%}
.opts button span{display:block;font:13px/1.35 var(--body);color:var(--dim);margin-top:3px;max-width:40ch}
.opts button[aria-pressed="true"]{border-color:var(--pick);box-shadow:inset 0 0 0 1px var(--pick)}
.opts button:focus-visible,.reply button:focus-visible{outline:2px solid var(--amber);outline-offset:2px}
.bar2{display:flex;gap:8px;flex-wrap:wrap}
.reply{position:fixed;left:0;right:0;bottom:0;background:var(--panel);border-top:1px solid var(--line);padding:10px 16px calc(10px + env(safe-area-inset-bottom,0px));display:flex;gap:10px;align-items:center;flex-wrap:wrap}
.reply code{font:14px var(--mono);color:var(--pick);flex:1 1 200px;min-width:0}
.reply button{font:400 13px var(--display);padding:8px 14px;background:var(--amber);color:var(--void);border:0;border-radius:3px;cursor:pointer}
</style>"""

FONTS = ('<link rel="preconnect" href="https://fonts.googleapis.com">'
         '<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>'
         '<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Silkscreen'
         '&family=IBM+Plex+Sans:wght@400;600&family=IBM+Plex+Mono&display=swap">')


def esc(s):
    return html.escape(str(s))


def options(q, opts):
    """One question's buttons. opts: [{"v": "A", "label": "...", "note": "..."}]."""
    out = []
    for o in opts:
        note = f"<span>{esc(o['note'])}</span>" if o.get("note") else ""
        out.append(f'<button type="button" data-v="{esc(o["v"])}" aria-pressed="false">{esc(o["label"])}{note}</button>')
    return f'<div class="opts" data-q="{esc(q)}">{"".join(out)}</div>'


def page(title, body, store_key, reply_prefix, order, empty="Pick one", extra_js=""):
    """A whole page. `order` lists the question ids in the order the reply prints them.

    With one question the reply reads "<prefix>: <pick>"; with several,
    "<prefix>: q1:pick q2:pick", plus "(N unpicked)" while any are open.
    """
    js = f"""<script>
(function(){{
  var ORDER = {json.dumps(order)};
  var picks = {{}};
  try {{ picks = JSON.parse(localStorage.getItem({json.dumps(store_key)}) || "{{}}") || {{}}; }} catch (e) {{ picks = {{}}; }}
  var out = document.getElementById("reply");
  function save(){{ try {{ localStorage.setItem({json.dumps(store_key)}, JSON.stringify(picks)); }} catch (e) {{}} }}
  function render(){{
    document.querySelectorAll(".opts").forEach(function(g){{
      g.querySelectorAll("button").forEach(function(b){{ b.setAttribute("aria-pressed", picks[g.dataset.q] === b.dataset.v ? "true" : "false"); }});
    }});
    var got = ORDER.filter(function(k){{ return picks[k]; }});
    if (!got.length) {{ out.textContent = {json.dumps(empty)}; return; }}
    var s = ORDER.length === 1 ? picks[ORDER[0]] : got.map(function(k){{ return k + ":" + picks[k]; }}).join(" ");
    var left = ORDER.length - got.length;
    out.textContent = {json.dumps(reply_prefix)} + ": " + s + (left && ORDER.length > 1 ? "  (" + left + " unpicked)" : "");
  }}
  window.tkPicks = {{ get: function(){{ return picks; }}, set: function(q, v){{ picks[q] = v; save(); render(); }}, clear: function(){{ picks = {{}}; save(); render(); }} }};
  document.querySelectorAll(".opts").forEach(function(g){{
    g.addEventListener("click", function(ev){{
      var b = ev.target.closest("button"); if (!b) return;
      var q = g.dataset.q;
      if (picks[q] === b.dataset.v) delete picks[q]; else picks[q] = b.dataset.v;
      save(); render();
    }});
  }});
  document.querySelectorAll("audio,video").forEach(function(a){{
    a.addEventListener("play", function(){{ document.querySelectorAll("audio,video").forEach(function(o){{ if (o !== a) o.pause(); }}); }});
  }});
  document.getElementById("copy").addEventListener("click", function(){{
    var t = out.textContent, btn = this;
    function sel(){{ var r = document.createRange(); r.selectNodeContents(out); var s = getSelection(); s.removeAllRanges(); s.addRange(r); }}
    function done(){{ btn.textContent = "Copied"; setTimeout(function(){{ btn.textContent = "Copy"; }}, 1500); }}
    if (navigator.clipboard && navigator.clipboard.writeText) navigator.clipboard.writeText(t).then(done, sel); else sel();
  }});
  {extra_js}
  render();
}})();
</script>"""
    return (f"<title>{esc(title)}</title>\n{FONTS}\n{STYLE}\n<main>{body}</main>\n"
            f'<div class="reply" role="status"><code id="reply">{esc(empty)}</code>'
            f'<button type="button" id="copy">Copy</button></div>\n{js}\n')
