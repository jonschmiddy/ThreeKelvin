# Orchestrator notes, Oct 31 (merged tree 8f257a76)

## First windowed run (stills1/, 17:57-18:03)
- All four edited shaders compiled: no SHADER ERROR / Compile Error in 8 windowed runs
  (map in 4 styles, a nebula twin in RADIANT, LOCAL at world B in SIMPLIFIED and PAINTED, the chart).
  Only exit-time lines: leaks and "RenderingServer::get_singleton() is null" (~ImageTexture at exit).
- SystemShot hangs the map over the title (menu + logo show through the keyed sky); pre-existing
  (Oct 27 shot the same). For Jon's stills use the real screen: MapShipShot.gd (uncommitted, in
  tk-wt/map-own-ship) goes through Router.show_system. Needs twin support (twin / park=wb / look=).

## To check after wave 3
- Panel: star B reads YELLOW DWARF, G2, 5,700 K like star A, but it is drawn warmer and smaller.
  MASS 0.55 / 0.45 SOL beside class G2 and RADIUS 1.0 / 0.85 SOL: a G2 star is about 1 sol.
  Does the class/temperature of B follow its own look? (it must make sense where it stands)
- Labels: "IN ORBIT · <world>" at fit zoom sits on star A's glow in twins (world at 83 px round A).
- orbitworldtest took 323 s wall in the battery vs its 300 s gate limit, but that includes waiting
  for the lock behind wave-3 agents. Check its own time in the log.

## Oct 31: battery on 8f257a76 (merged/logs/summary.txt)
- Everything PASS except:
  - flighttest FAIL: twin found 98.78% < 99% from game starts; 75 put-there of 3856 plans. The chain agent's job.
  - scrollcheck + scrollcheck_twin: PASS then exit 134 (signal 11 in malloc at cleanup). NEW on the branch: main (tk-wt/enemy-x2 @ a6ed7f5e) exits 0 twice; branch crashes 3/3.
    Cause: a FlightSolve worker task never waited for at quit (ShipFlight._reap, filled by PREDELETE after the map stops stepping). Its lambda is freed in WorkerThreadPool::finish after GDScript is gone.
    Fix: ShipFlight.drain() from Router's NOTIFICATION_PREDELETE (autoloads are deleted after screens). Probe: 1 task waited at quit, 3/3 clean. Patch: twin-build/exitfix.patch (test copy twin-build/exitfix). Apply on twin-fix after wave 3.
- orbitworldtest: 310 s run alone (onesun reviewer), over the gate's 300 s. Real, not lock wait.
- dockflytest 1389 s = lock wait behind the stills; its first run 149 s.
