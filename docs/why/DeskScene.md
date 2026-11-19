The reasoning behind the science desk (`tkg/scripts/ui/DeskScene.gd`, not yet written); each heading will be referenced from the code by a `Why:` line.

## The plan

Status, Nov 19: stage 1 (the shared parts and DESK 1) is being built; the hook onto LOCAL waits.

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

## The hook

`LocalEventDrawer.choose(j)` sends a reading (a science choice with `reads`) through `DeskScene.visit`
when the switch is on and there is a screen. The visit calls `OptionResolve.take` itself, once, on
the tap, and returns its result. `choose` then carries on as if it had called it: the result page
on LOCAL, a fight, a death. Leaving before the tap takes nothing, and the event stays open.

- **Act 1 is the page's.** LOCAL is held as a still taken at the click, pushed into your ship (it
  glides to the middle as it grows, so the picture's edge never shows), then faded to black. Leaving
  runs it back. Reduced motion holds the zoom.
- **The 749 ms first frame** (the room's shaders compiling) is drawn at the click, behind the still.
  The desk's clock moves at most 0.1 s a frame, so a long frame never skips the room's beats.
- **The card waits for the tap.** On the page it held 2.5 s. `DeskOne.roll` is where it wipes into
  the picture: endless until the tap, when the picture becomes the outcome. The room's own idle clocks
  keep the page's times.
- **A tap after the outcome, or Esc any time, leaves.** Before the tap, the card is what squeezes away.

## Window size

The game draws a 960x540 frame and the shell shows it at the biggest whole multiple that fits,
through its glass (`GameShell._fit`, `screen_filter`). The desk's room is the page's 1920x1080
canvas (5 px an art pixel), and 960x540 cannot hold it: an art pixel would be 2.5 px. So the shell
shows the desk's canvas in the game's place, through the same glass at the same size, the filter
told the canvas's own texels per screen pixel (`GameShell.cover`). The bands, the colour help, the
gamma and the screen look all apply as they do on every other screen. At each window size:

- **1920x1080 and 2560x1440 (2x):** the page's canvas 1:1, exact (bands round 2560x1440, as for the
  game).
- **960x540, 1280x720, 1600x900 (1x):** the canvas halved, each screen pixel the average of four.
  The art reads as on the page at half size; the CRT's scanlines, one dark row in five, soften to a
  faint stripe.
- **2880x1620 (3x):** 1.5 canvas pixels a screen pixel, through the filter's sharp bilinear, as the
  game takes any finer picture.
- **3840x2160 (4x):** each canvas pixel 2x2, exact.

## Porting a room

DESK 1 is done (`DeskOne`, `shaders/desk_1.gdshader`). A frame differs from the page's in 0 to 31
pixels of about 2 million, apart from two early power-on frames that differ in up to 2,770, none
off by more than 8. Each other room is a port of its own `tools/desk/page/scenes/<id>.js`. The
rooms share `makeLit` (the bake, `desk_room.gdshaderinc`), the tube, the timeline and the sound.
They do not share their per-frame drawing.

**For each room:**
1. Add its probe line to `tools/desk/dump.html`'s `PROBE`, listing the closure's names it needs.
2. Run `dump_desk.py bake <id>`.
3. Write `Desk<Name>.gd`, the scalar half: clocks, levels, weights, CPU layers.
4. Write `shaders/<id>.gdshader`, the per-pixel half, in the page's drawing order.
5. Add the room to `DeskRoom.SHADERS` and `DeskScene.BUILT`.
6. Dump the page's frames, render `-- sheet=DeskRooms`, and diff them.

**Traps found on DESK 1** (each cost a run):
- **`hash`.** An unqualified `hash()` inside a static class calls GDScript's own `hash`, so the
  page's hash is `DeskFx.rnd`. DESK 2 has its own hash: `sin(n * 127.1 + 311.7)`.
- **`floor`.** `floor()` returns a Variant, and `:=` cannot infer from it; use `floorf`. `wrap` is
  a global too.
- **Uniform arrays.** The compatibility renderer lays `float[]` and `vec3[]` uniforms out tight,
  so pass `vec4` arrays (`DeskRoom._quads`, `_v4`).
- **Byte stores.** Every store into the page's `Uint8ClampedArray` rounds halves to even (`st8`).
  A product that lands exactly on .5 rounds the way the page's double does (see `glass_px`).
- **Bytes on the glass.** A mean read back through 8 bits steps the bezel's glow, so it travels as
  two bytes. The page's sin-based noise must come from the CPU in doubles.
- **`aux`** is a device name on Windows; it cannot be a file.
- **Finding a node by class.** `find_children(type)` matches native classes only; test `is DeskScene`.

Each room's scalar half extends `DeskLife` (its times, its CPU layers, its frame's uniforms);
`DeskRoom._life` picks it. The dump inits each scene once, as the page's shell does: DESK 2's init
is not idempotent (its emitter lists grow on every call).

**DESK 2** (`DeskTwo`, `shaders/desk_2.gdshader`, done Nov 19): every frame within 0 to 138 of about
2 million pixels, at most 28 off by more than 8 (a dust mote or two). It differs from DESK 1:
- Up to six bulbs light one pixel, so the bake has a second four (`small_i2`, `small_v2`;
  `SMALL_8`), and each bulb has its own tint (`SMALL_TINTS`).
- Its scanline is a 0.3 fill Chrome truncates (`floor(v * 179 / 256)`), not rounds (`scan_mul.z`).
- The lamp's smudge on the glass shows on the dark tube too.
- The fifth slot in each round of glitches names no kind: it shows nothing but dims the screen's
  light 5% until the next (`GL_KINDS` has four).

What the page's script says about it:
- 33 string bulbs, each with its own tint, so the uniform arrays must reach 64.
- Dust is drawn before the emitters and lit by the stepped light alone.
- The LED glow is a box shape (`addGlow`).
- Its steam box is 36 x 48 at (252, 144) and fades within 4 px of the glass.
- The screen's light, `crtW`, follows the picture's mean brightness and a colour the page eases 30%
  a frame. That colour depends on the frame before it; the sheet runs the page's frames in order.
- Its CRT has its own phases (dot, line, open, boot, title, wipe, settle, on, and shrink when
  leaving), a 3x3 bloom of a bright-pass, and glitches from a fixed list of start times.
- One scanline row of 0.3.
- Its porthole's own stars and ship are drawn over by `drawSky`.

BUNK (1,016 lines) bakes extra fields (patch, pillow, ring, wash), LED lights and a jukebox
screen. NOOK (776 lines, the shelf-lamp fix of Nov 19 in) has an oscilloscope panel, the rack bulb
(its lamp time is `T.bulb`, 4.3) and its own CRT.

## Sound

The page's mix is kept as it is (`scenes/audio.js`, Jon's picks Nov 17 to 19). The bed, the lamp
click (`desk_lamp`, lamp A) and the power-on (`desk_poweron`, `poweron_K`, his "G alone") play at
their files' own level. The bed goes on Ambient and the clicks on SFX, so the volume settings scale
them. The files measure:
- the bed: -37 dB RMS;
- the hum: -44 dB RMS, played +14 dB (Jon, Nov 19: "The hum is too quiet."), so a little over the
  bed;
- the lamp and G: -39 and -40 dB RMS.

The hum has its own bus, `DeskHum`, which sends to Ambient and carries the low-pass for its warm-up.

Leaving reuses the game's own quit sound (`power_off`, GameShell's), not a copy. It plays 22 dB under
its file. The file is mastered hot (-11 dB RMS, a -6 dB whine), and the quit plays it alone at 0 dB.
Among the desk's sounds, -22 dB puts its whine near G's loudest moment, which is the level the page
chose by ear. Its click, 1.47 s into the file, lands where the leaving timeline crosses the CRT time.
With less time left than that, it starts part way in. The hum coasts down into the click as
`Audio.power_down` coasts the music (pitch to 0.3, quad ease-in) and is cut 60 ms before it with a
40 ms fade. The lamp clicks again as leaving crosses the lamp's time.

## Jon's rulings, Nov 19

1. **Which room: by hull class (his A).** Light hulls get the BUNK, medium hulls DESK 1, heavy hulls
   DESK 2, salvage frames the NOOK. A ship is a home: the same room every visit.
2. **What the glass shows (his A).** A title card naming the science site; a tap takes the reading
   (`OptionResolve`, the one rule) and shows its outcome on the glass; LEAVE runs back to LOCAL.
3. **When it plays.** Behind a switch, on for every science reading.
