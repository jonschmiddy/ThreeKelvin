The reasoning behind the science desk (`tkg/scripts/ui/DeskScene.gd`, not yet written); each heading will be referenced from the code by a `Why:` line.

## The plan

Status, Nov 19: plan only. Nothing below is built. The port is larger than one builder pass, and three
things in it are Jon's to decide (the last section).

**What is being ported.** Jon's approved science desk rooms page (the deskpower prototype, Nov 17 to 19):
picking science on LOCAL zooms into your ship, fades to one of four rooms (DESK 1, DESK 2, BUNK, NOOK),
and the room powers on (lamp, string lights, CRT warm-up, title card), then idles. Leaving runs the same
timeline backwards to LOCAL. The page's code is the source of truth: `index.html` (the shell: timeline
ZOOM_S 2.9, SPEED 1.25, KNEE 10; leaving OFF_SPEED 2.2, ZOOM_OUT_S 2.4; act 1; the tube; the title
card), `scenes/roomfx.js` (the C lighting engine `makeLit`, keyboards, dust, porthole sky, tired bulb),
the four room scripts and `scenes/audio.js`.

**Where science lives now.**
- A science event is an `OptionTable` entry tagged `&"science"` (`OptionsPart11`, `OptionsPart12`),
  at most one per system (`OptionTable._science_pass`, `Rng.derive(&"science", index)`). A reading
  burns fuel (`SCIENCE_FUEL`) and pays DATA (`SCIENCE_PAY`).
- On LOCAL it is taken like any event: `LocalEventDrawer.choose(j)` calls `OptionResolve.take`, the one
  rule, which `Policy` also flies in the sim.
- The Lab is a station deck (`LabScene`, lit by `shaders/lab_light.gdshader` from the
  `tools/lab_install.py` bakes; `LabZoom` moves the camera into the glass for RESEARCH, AUGMENT and
  RECIPES; `Science.gd` sells them for DATA).
- Materials from mini games (Jon and Tyler, Nov 16 to 18) are designed, not built. No mini game is in
  the game, so the desk's glass has nothing of its own to show yet.

**The hook.** `LocalEventDrawer.choose(j)` on a science event's choice: the desk plays before
`OptionResolve.take`, and the take runs when the player leaves. The rule stays where it is, so the sim
(which never draws) is untouched. A move is a `ZoomLadder` beat (UI out, the move, UI in), like
`LabZoom`'s. Act 1 is a camera push into your ship on LOCAL's own picture, not a still, then a fade.

**Architecture: bake once, light on the GPU.**
1. `tools/desk/` holds a copy of the page's code, as `tools/dev/badge/` does, and `dump_desk.py`
   runs it in the installed Chrome and writes each room's bake. The bake holds:
   - the art with the keyboard drawn and the settled dust (`A2c`);
   - every light's field (lamp, screen, porthole, the scope and the bunk's extra washes);
   - the string bulbs and LEDs as up to four (index, value) pairs a pixel, since their boxes overlap;
   - the per-pixel `TG`, `AO`, room vignette and skip mask;
   - the emitter pixel sets (bulb, filament, strings, LEDs, porthole glass, iron tip).

   Fields are float32, gzipped (`PackedByteArray.decompress_dynamic`). Running the page's own code
   keeps the look exact, where a second implementation in Python (what `lab_install.py` did) can drift.
2. `shaders/desk_light.gdshader` is `makeLit.compose` and `frame` per pixel: the overlap rule, the C
   ramp (C_LV, the Bayer seam, cool-violet shadow, warm light, the knee) and the flicker multipliers
   after the stepping. Composing every frame on the GPU removes the page's compose cache. The steady
   weights (power-on) and the flicker (`tiredBulb`, twinkle, the tube's life) arrive as uniforms.
3. Each room's script ports its timeline from JS to GDScript, scalar maths only: lamp strike and
   warm-up, string chase, LEDs, screen level, glitch slots, brown-outs. Its per-pixel overlays go in
   that room's shader, with the common part in a `.gdshaderinc`: bulb and string pixels, LED glows,
   steam, smoke, dust, the screen lips. Particles (dust, steam, smoke, the porthole sky) are worked out
   on the CPU into small textures, and the shader blends them against the room's light as the page does.
4. `shaders/desk_glass.gdshader` covers the CRT at glass resolution: phases dot, line, raster, boot
   text, title card and picture; the phosphor bleed; the shade. `desk_tube.gdshader` draws the barrel
   curve, rim, bezel glow and scanlines at screen resolution, so 1 art px is 5 px at 1080p.
5. Everything runs on `GameClock`, never the wall clock (films). Reduced motion keeps the power-on and
   holds the idle clocks still: no dust, no twinkle, no glitches.

**Sound** (`audio.js`):
- The cabin bed is `bed_bunk_1_A` in every room, and the lamp click is `lamp_A`.
- The power-on is `poweron_K` (Jon's "G alone").
- The CRT hum (`crt_hum_A`) loops from `HUM_AT` 0.83 s after G. It warms up: gain to 1.25 by 1.6 s,
  then 1 by 2.4 s; pitch 0.9 to 1 over 2 s; a low-pass from 160 Hz to 20 kHz over 2.2 s. It plays
  +14 dB over the file, follows the room fade and stops on leave.
- Leaving (coordinator, Nov 19):
  - The game's own `&"power_off"` (the GameShell quit sound) plays, not a copy. Its cut, 1.47 s into
    the file, lands as the leaving timeline crosses the CRT time; with less time left, it starts
    part way in.
  - The hum coasts down as `Audio.power_down` does (pitch to 0.3, quad ease-in) and is cut 60 ms
    before the click, with a 40 ms fade.
  - The lamp clicks again as leaving crosses the lamp time.
  - The page plays power_off 22 dB under the file. In the game it is levelled to its peers in the SFX
    mix, and the change says which level was chosen.
- Players go to the SFX and Ambient buses, so the volume settings apply. The low-pass and pitch
  warm-up are an `AudioEffectLowPassFilter` on a desk bus plus `pitch_scale`.

**Tests.**
- `DeskTest` (headless, gated): the timeline maps real time to scene time both ways, the sound
  triggers fire once each at their times forward and on leave, a mid-power-on leave goes back from
  where it stands, and the reading resolves exactly once.
- `-- sheet=DeskRooms` (windowed, `render.sh`): each room lit at 2x, plus act 1 and power-on frames.
- `tools/desk/diff_desk.py` sets the game's stills beside the page's own captures at the same t,
  counts the pixels that differ, and writes a contact sheet. The look is judged on that.

**Size.**
- About 4,600 lines of page JS. About 2,300 of it is bespoke per-frame drawing, and the four rooms do
  not share a structure: the bunk has extra washes, LED lights and a jukebox screen; the nook has a
  scope panel and its own CRT.
- Expect about 3,500 lines of GDScript and shader code, plus the bake tool, the tests and the hook.
- Staged:
  1. The bake tool, the shared light shader, the glass and tube, sound, the LOCAL hook and DESK 1
     whole.
  2. DESK 2.
  3. BUNK.
  4. NOOK, from the current `nook_1.js` (the shelf-lamp shadow fix is in it, Nov 19).

  Each stage has its own diff against the page.

**For Jon.**
1. Which room you get. Recommendation: one room per hull class, fixed, so a ship is a home:
   - light hulls get the BUNK;
   - medium hulls DESK 1;
   - heavy hulls DESK 2;
   - salvage frames the NOOK.

   The fallback is a pick from the run seed (`Rng.derive(&"desk", 0)`), which is cosmetic and the same
   all run.
2. What the glass shows before the mini games exist. The page's title card is CULTURE DISH's ("TAP TO
   BEGIN"). Recommendation: the card names the reading (its title from the event), the tap takes the
   reading through `OptionResolve` and shows its outcome on the glass, and LEAVE runs back.
3. Whether the desk plays for every science reading, or only once mini games exist. Recommendation:
   build it now behind a switch, on for readings.
