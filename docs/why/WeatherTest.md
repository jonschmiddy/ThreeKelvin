The reasoning behind `tkg/scripts/sim/WeatherTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Weather scheduler

Above `const SkyWeatherS := preload("res://scripts/ui/sysmap/SkyWeather.gd")`:

```text
THE SECTOR MAP'S WEATHER, ITS SCHEDULER ALONE (`SkyWeather`):
  godot --headless --path . -- weathertest
Two hours of every sky at every temperament, a quarter second a step, with
no picture at all: every event "places" (the scheduler's timing is what is
tested; where each one goes is the harness's `wclip`). Asserts:
  * one slot-A event at a time, and none starting within 6 s of the last's end;
  * showpieces at least 90 s apart and 40 s into the visit (Oct 5: rarer was never seen);
  * no event twice running in a slot;
  * no small event starting while a showpiece is live;
  * no slot-A start inside a 60 s busy hold (a page being read, a glide);
  * nothing starting with reduced motion, and a live event gone the step after;
  * temperament changes how often, never how long;
  * EVERY event in the table fires at least once in its sky (a dead entry
    fails: the lesson of a green gate that cannot see the feature).
Prints events a minute by tier, sky and temperament.
`-- weathertest rates` instead prints how often each event comes, sky by sky:
minutes between one and the next, steady systems and the calm-to-stormy
range, averaged over systems with each favourite (a measurement, no verdict).
```
