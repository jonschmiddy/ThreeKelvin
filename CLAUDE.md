# Three Kelvin

Start here, in this order:

1. [`tools/dev/README.md`](tools/dev/README.md): the scripts for running, testing, landing,
   releasing, rendering and recording on Windows or the Mac; how Jon and Claude work; and
   the latest handoff (where the work stands).
2. [`HANDOFF.md`](HANDOFF.md): the project for a new person or session.
3. [`docs/DEVELOPMENT_PLAN.md`](docs/DEVELOPMENT_PLAN.md): the build order and the post-alpha roadmap.
4. [`tkg/CLAUDE.md`](tkg/CLAUDE.md): the game's code, its tests and which test covers what.

Two rules before anything else: every Godot run goes through `tools/dev/godot.sh` or
`tools/dev/render.sh`, never straight to Godot, so Jon's real profile is never touched;
and nothing reaches `main` except through `tools/dev/gate_land.sh`, one gate at a time.
