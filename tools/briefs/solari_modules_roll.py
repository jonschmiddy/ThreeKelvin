import base64, json, os, sys, urllib.request
D = os.path.dirname(os.path.abspath(__file__))
API = "https://api.pixellab.ai/v1/generate-image-pixflux"
SUF = (", strictly side-on with no perspective and no angle, a flat side profile. Dark gunmetal steel with brass "
       "bands, one small glowing orange point, dark outline, a single ship part, pixel art game sprite")
NEG = "perspective, three-quarter view, top face, text, letters, numbers, background, floor, ground shadow, white, cream"
P = {
 "emberlance": ((120, 40), "A short stubby ship-mounted plasma lance with two brass bands and a glowing orange tip",
                "A compact ship-mounted emitter tube, thick at the back and narrowing to a short glowing orange muzzle, two brass rings"),
 "plasma": ((120, 40), "A long thin ship-mounted lance wound with brass coil along its whole length, glowing orange tip",
            "A long slender rail of dark steel with a tight brass coil spiralling along it, a heavy breech block at the back"),
 "ventcan": ((120, 40), "A thick ship-mounted housing with radiator fins along the top, ending in a wide flared vent mouth glowing orange inside",
             "A heavy finned projector body with a big trumpet-shaped vent mouth at the front"),
 "overpressure": ((120, 40), "A riveted steel pressure drum behind a short fat emitter nozzle, pipes looping over the top",
                  "A squat ship-mounted emitter with a big round pressure tank at the back and thick brass pipes curving over it"),
 "heliostat": ((160, 40), "A very long slim boom ending in a round concave mirror dish at the front",
               "A long thin lance boom with brass rings along it and a polished brass reflector dish on its tip"),
 "sparkthrower": ((80, 40), "A small steel tank with three stubby nozzles fanned out at the front, sparks at the tips",
                  "A compact spark emitter: a ribbed steel canister with a three-pronged nozzle head"),
 "sunspot": ((80, 80), "A short wide brass-ringed mortar tube angled upward on a heavy turret base",
             "A squat stubby launch tube pointing up at an angle from a heavy round mounting block"),
 "overdrive": ((80, 40), "A horizontal cylinder tightly wound with brass coils, glowing orange between the windings",
               "A bank of three brass induction coils side by side on a steel frame, glowing between them"),
 "shroud": ((80, 40), "A low dome of overlapping pale ceramic tiles on a dark steel rim, glowing amber at the seams",
            "A curved heat cowl of overlapping armour scales on a steel base, faint glow in the gaps"),
 "cautery": ((80, 40), "A small steel fuel tank with a short torch nozzle on one end, white-hot tip",
             "A welding torch unit: a round brass-banded tank and a bent nozzle arm with a glowing tip"),
 "foundrybus": ((80, 40), "Thick brass bus bars running between two dark insulator blocks, glowing where they join",
                "A heavy power coupling: two steel junction boxes joined by three thick brass bars"),
 "firebrick": ((80, 40), "A brass-framed block of thick firebricks, the mortar lines glowing orange",
               "A heavy steel box lined with dark firebricks, glowing faintly through the joints"),
 "bellows": ((80, 40), "A pleated bellows between two steel end plates, with a nozzle on one end",
             "A ribbed accordion pump of dark steel with a brass outlet nozzle"),
 "heathaze": ((80, 40), "A shallow dish emitter on a short steel stand, shimmering with heat",
              "A small projector dish mounted on a pivot arm, its face glowing faint orange"),
 "heatbank": ((80, 80), "A squat insulated tank with brass bands and a valve on top, glowing orange at a seam",
              "A round-shouldered steel heat tank with two brass hoops and a pressure valve"),
 "starfurnace": ((80, 80), "A heavy steel firebox with a round white-hot port in its face",
                 "A compact furnace block with a thick round door glowing white-hot around its rim"),
 "sunheart": ((80, 80), "A glowing orange core held inside a brass cage on a steel base",
              "A small reactor: a bright orange orb gripped by brass struts on a heavy mount"),
 "crucible": ((80, 80), "A heavy pot hung on trunnions in a U-shaped steel frame, glowing inside",
              "A tilting brass crucible on a steel cradle, molten orange at its lip"),
 "flare": ((80, 40), "A rail of upright flare canisters, one with a lit orange tip",
           "A short launch rack holding five upright brass-capped canisters"),
 "radiatorsail": ((80, 40), "A fan of tall thin radiator fins on a hinge rail, glowing orange at their roots",
                  "A row of tall copper radiator fins standing up from a steel base, warm at the bottom"),
 "annealer": ((80, 40), "A hooded lamp head on a bent jointed steel arm, glowing orange",
              "An articulated arm with a domed heat lamp on the end, its lens glowing"),
 "mirrorarray": ((80, 40), "A row of small hexagonal brass mirrors along a steel beam",
                 "A slim steel rail carrying four small round reflector mirrors"),
 "heliograph": ((40, 40), "A small round brass mirror on a gimbal stand",
                "A tiny signal mirror in a brass ring, on a short pivot post"),
 "incinerator": ((40, 40), "A heavy round steel hatch with a glowing orange opening",
                 "A small furnace hatch: a thick ring door ajar, orange glow inside"),
 "bleedvalve": ((40, 40), "A brass spring relief valve on a short steel pipe stub",
                "A small steel valve body with a brass cap and a vent spout"),
}
def roll(mid, idea):
    (w, h), a, b = P[mid]
    out = os.path.join(D, "raw", "%s_%d.png" % (mid, idea))
    if os.path.exists(out): return "skip"
    # Ideas 3 and 4 are 1 and 2 again AT SCALE (Jon: "they might need to be
    # regenerated at scale"): told to fill the frame, over a full-box silhouette.
    base = a if idea in (1, 3) else b
    fill = ", large and close, the part filling the whole frame from edge to edge" if idea > 2 else ""
    body = {"description": base + fill + SUF, "negative_description": NEG,
            "image_size": {"width": w, "height": h}, "no_background": True,
            "view": "side", "text_guidance_scale": 9, "seed": 6200 + idea * 17}
    if idea > 2:
        sil = os.path.join(D, "sil", mid + ".png")
        body["init_image"] = {"type": "base64", "base64": base64.b64encode(open(sil, "rb").read()).decode()}
        body["init_image_strength"] = 60
    req = urllib.request.Request(API, data=json.dumps(body).encode(), headers={"Content-Type": "application/json"})
    err = ""
    for _ in range(4):
        try:
            with urllib.request.urlopen(req, timeout=300) as r:
                res = json.loads(r.read().decode())
            open(out, "wb").write(base64.b64decode(res["image"]["base64"]))
            json.dump({k: v for k, v in body.items() if k != "init_image"}, open(out[:-4] + ".json", "w"))
            return "ok"
        except Exception as e:
            err = str(e)
    return "FAIL " + err
if __name__ == "__main__":
    print(sys.argv[1], sys.argv[2], roll(sys.argv[1], int(sys.argv[2])), flush=True)
