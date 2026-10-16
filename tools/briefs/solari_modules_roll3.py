import base64, json, os, sys, urllib.request
D = os.path.dirname(os.path.abspath(__file__))
API = "https://api.pixellab.ai/v1/generate-image-pixflux"
SUF = (", strictly side-on with no perspective and no angle, a flat side profile. Dark gunmetal steel with brass "
       "bands, one small glowing orange point, dark outline, a single ship part, pixel art game sprite")
NEG = "perspective, three-quarter view, top face, text, letters, numbers, background, floor, ground shadow, white, cream"
P = {
 "annealer": ((80, 40), "A long low heat-lamp bar: a dark steel housing with a row of three glowing orange lamp lenses along its face",
              "A wide hooded heat lamp lying on its side, the hood a long dark steel shell with a glowing orange slot along its length"),
 "bleedvalve": ((40, 40), "A chunky square valve block of dark steel with a big brass hand wheel on its face and a short vent spout",
                "A fat round pressure valve with a brass dome cap and two thick pipe stubs left and right"),
 "crucible": ((80, 80), "A heavy round-bellied smelting pot of dark steel with a brass rim and pouring lip, glowing orange molten metal inside",
              "A big square furnace crucible block with a tilted spout and a glowing orange pour channel"),
 "flare": ((80, 40), "A long launcher box of dark steel with a row of four round launch holes, a flare glowing orange in one",
           "A long steel flare pod with brass bands and a glowing orange cap at one end"),
 "heathaze": ((80, 40), "A long low projector bar of dark steel with a wide glowing orange emitter strip along its face",
              "A wide heat emitter block framed in brass, rippling orange glow behind a steel grille"),
 "heliograph": ((40, 40), "A big round brass signal mirror in a heavy square steel mount, the mirror face catching a bright glint",
                "A square shuttered signal lamp of dark steel with a glowing round lens and brass louvres"),
 "heliostat": ((160, 40), "A very long heavy lance of dark steel, thick along its whole length, brass rings, a wide polished brass dish at the front",
               "A long thick mirror lance: brass-rimmed reflector rings stacked along a heavy steel spine, glowing at the tip"),
 "incinerator": ((40, 40), "A square heavy furnace block of dark steel with a round brass hatch in its face, glowing orange round the hatch rim",
                 "A chunky incinerator drum with a hinged grate door glowing orange"),
 "mirrorarray": ((80, 40), "A heavy steel frame holding six square brass mirrors in two rows of three",
                 "A wide fan of curved brass mirror panels on a thick steel base"),
 "plasma": ((120, 40), "A long thick plasma lance of dark steel, heavy along its whole length, wound with a fat brass coil, glowing orange muzzle",
            "A long heavy lance made of stacked brass coil rings on a thick steel core, glowing orange between the rings"),
 "radiatorsail": ((80, 40), "A thick slab of dark steel radiator with many deep fins, glowing orange in the gaps",
                  "A wide folding radiator wing of brass-edged fins on a heavy hinge block"),
 "starfurnace": ((80, 80), "A heavy round furnace of dark steel with a big round white-hot window in the middle and brass bolts round it",
                 "A squat stepped furnace block with a glowing orange grate at the bottom and a short brass chimney"),
 "sunheart": ((80, 80), "A heavy dark steel reactor housing with a big round porthole showing a glowing orange core, brass rim",
              "A thick brass ring frame standing on a steel base, a glowing orange core held in its centre"),
}
def roll(mid, idea):
    (w, h), a, b = P[mid]
    out = os.path.join(D, "raw", "%s_%d.png" % (mid, idea))
    if os.path.exists(out): return "skip"
    # Ideas 3 and 4 are 1 and 2 again AT SCALE (Jon: "they might need to be
    # regenerated at scale"): told to fill the frame, over a full-box silhouette.
    base = a if idea in (1, 3) else b
    fill = ", large and close, the part filling the whole frame from edge to edge"
    body = {"description": base + fill + SUF, "negative_description": NEG,
            "image_size": {"width": w, "height": h}, "no_background": True,
            "view": "side", "text_guidance_scale": 9, "seed": 7300 + idea * 17}
    if True:
        sil = os.path.join(D, "sil", mid + ".png")
        body["init_image"] = {"type": "base64", "base64": base64.b64encode(open(sil, "rb").read()).decode()}
        body["init_image_strength"] = 70 if idea < 3 else 40  # 70 drew grey boxes
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
