# Documentation

Everything that is prose rather than code. It lives here, in one place, because
it used to live in seven — four files at the repo root, three beside the art
tools, five beside the audio generators, and a stray verification note in a
directory that held nothing else.

One rule decides what is here and what is not: **a README earns its place by
sitting next to the thing it explains.** So `tkg/audio/README.md` stays where it
is, because it tells you how to run the fifteen Python generators in that
directory and a reader who has just `cd`-ed there is exactly the reader it is
written for. Everything that describes the *game* rather than a *directory* is
here instead.

Still in place, deliberately:

| File | Why it stays |
| --- | --- |
| `tkg/CLAUDE.md` | Loaded automatically from that directory. Moving it would silently unload it. |
| `tkg/README.md` | How to run the game, next to the game. |
| `tkg/audio/README.md` | How to run the generators, next to the generators. |
| `tkg/art/ui/README.md` | What the UI assets in that folder are. |
| `relay/README.md` | How to deploy the worker, next to the worker. |
| `tkg/assets/fonts/LICENSE.md` | A licence belongs with what it licenses. |

## Design

| File | What it is |
| --- | --- |
| [design-doc.md](design-doc.md) | The game: what it is, the setting, what the run is shaped like. Start here. |
| [coop-design.md](coop-design.md) | Four ships in one galaxy — the design questions and the rulings that answered them. |
| [netcode.md](netcode.md) | How the party actually talks. Transports, the relay, and what crosses the wire. |
| [lore.md](lore.md) | Who is paying for all this, and why nobody will say what the heat is for. The archive's writing rules live here. |
| [catalogue.md](catalogue.md) | Every rule that decides what a module is, what cards it grants, and what they may be called. Read before writing a part. |
| [handbook.md](handbook.md) | The long half of `tkg/CLAUDE.md`: screen layout, art direction and generation, audio, the economy's internals, the two procedural engines. Reference, not context — you open it on the day you need it. |
| [DEVELOPMENT_PLAN.md](DEVELOPMENT_PLAN.md) | The build order, and how much of it is done. |

Code comments cite these by section — `docs/coop-design.md` §5, `docs/netcode.md`
§2 — and the section numbers are load-bearing. Renumbering one means fixing the
citations, so append rather than insert.

## Art

| File | What it is |
| --- | --- |
| [art/ART_CONTRACT.md](art/ART_CONTRACT.md) | The visual rules every generated asset has to satisfy. Read before generating anything. |
| [art/ASSET_PIPELINE.md](art/ASSET_PIPELINE.md) | How an asset gets from a prompt to a file the game loads. |
| [art/PIXELLAB_WORKFLOW.md](art/PIXELLAB_WORKFLOW.md) | Working the generator itself, with the pipelines that are known to come out right. |

## Audio

| File | What it is |
| --- | --- |
| [audio/DEVELOPMENT_NOTES.md](audio/DEVELOPMENT_NOTES.md) | How the score is built, and what was learned making it. |
| [audio/THEME_NOTES.md](audio/THEME_NOTES.md) | The themes and what they are doing. |
| [audio/DREAD_NOTES.md](audio/DREAD_NOTES.md) | The dread layer specifically. |
| [audio/CUE_NOTES.md](audio/CUE_NOTES.md) | Which cue fires when. |

## Archive

[archive/](archive/) holds session handoffs and one-off verification notes. They
are kept because they record why something is the way it is, and they are
separated because they describe a moment rather than the current state — a
handoff written three months ago is history, not documentation, and reading it
as though it were current is how a stale instruction gets followed.
