class_name StarNumbers
extends RefCounted

## EACH SUN ITS OWN NUMBERS (Jon, Nov 23: "What about mass, temp, etc.?"): mass, surface
## temperature and size drawn per system off `Rng.derive(&"star_facts", index)`, inside each
## kind's real range; luminosity follows from size and temperature. Why: docs/why/StarNumbers.md#star-numbers
const SPREAD := {
	"ORDINARY": {m = [0.8, 1.2], t = [5300.0, 6000.0], step = 10.0},
	"RED": {m = [15.0, 30.0], t = [3400.0, 3800.0], r = [700.0, 1500.0], step = 10.0},
	"BLUE": {m = [30.0, 60.0], t = [20000.0, 30000.0], r = [25.0, 70.0], step = 100.0},
	"PULSAR": {m = [1.3, 1.6], t = [500000.0, 700000.0], r = [10.0, 13.0], step = 10000.0},
}
## The Sun's surface, the scale the luminosity is reckoned on.
const SUN_K := 5772.0
const SUN_KM := 696000.0


## `mass`, `temp`, `radius` and `lum` of system `index`'s sun of kind `kind_name`, as the panel words them.
static func of(kind_name: String, index: int) -> Dictionary[String, String]:
	var out: Dictionary[String, String] = {}
	if not SPREAD.has(kind_name):
		return out
	var g: Dictionary = SPREAD[kind_name]
	var rng := Rng.derive(&"star_facts", index)
	var u := rng.randf()
	var v := rng.randf()
	var w := rng.randf()
	var m := lerpf(g.m[0], g.m[1], u)
	# a dwarf's heat goes with its mass; the giants' and the pulsar's are their own draw
	var t := snappedf(lerpf(g.t[0], g.t[1], u if kind_name == "ORDINARY" else w), g.step)
	var r_sun := pow(m, 0.8) if kind_name == "ORDINARY" else lerpf(g.r[0], g.r[1], v)
	if kind_name == "PULSAR":
		out["radius"] = "%d KM" % roundi(r_sun)
		r_sun /= SUN_KM
	else:
		out["radius"] = "%s SOL" % sig2(r_sun)
	out["mass"] = "%s SOL" % sig2(m)
	out["temp"] = "%s K" % grouped(roundi(t))
	out["lum"] = "%s SOL" % sig2(r_sun * r_sun * pow(t / SUN_K, 4.0))
	return out


## `x` to two significant figures, grouped by thousands: 1.0, 0.93, 28, 180,000.
static func sig2(x: float) -> String:
	if x <= 0.0:
		return "0"
	var e := floori(log(x) / log(10.0))
	var q := snappedf(x, pow(10.0, e - 1))
	if e >= 1:
		return grouped(roundi(q))
	return ("%." + str(1 - e) + "f") % q


## 1234567 as "1,234,567".
static func grouped(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if n < 0 else "") + s + out
