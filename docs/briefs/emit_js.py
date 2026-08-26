# -*- coding: utf-8 -*-
import json
exec(open('batch03.py').read())

# pack the 20 into themed systems for the prototype
SYS = [
 ("Vane Drift","FAUNA",3,1,[], "Something is moving through, and it is not weather.",
   ["the_braid","silt","ice"]),
 ("Cygnet Reach","COSMOPOLITAN",5,4,["Cygnet","Probate"], "Four years of nobody, still running the lights.",
   ["refinery_still_lit","the_sweep","counterweight"]),
 ("Halvard Yards","COSMOPOLITAN",6,4,["Probate","Calyx","Korvan"], "Nine ships deep and everybody in a hurry.",
   ["tug_work","the_queue","the_auction","quarantine_flag"]),
 ("Skene Verge","LAWLESS",4,2,["Redline"], "No law out here, and a great deal of work.",
   ["cold_labour","escort","nine_tonnes","the_runner"]),
 ("Ordell Shelf","FRONTIER",3,1,[], "The star is about to do something.",
   ["flare_shelter","the_memorial"]),
 ("Bracken Fall","TERRITORY",5,3,["Korvan"], "A yard that stopped being paid for a decade ago.",
   ["deadfall","the_long_tow"]),
 ("Anselm Station","COSMOPOLITAN",4,4,["Verity","Cygnet"], "Two arrivals here have been waiting on you.",
   ["paid_in_full","what_she_was_carrying"]),
]
by = {o['id']:o for o in O}

def jsopt(o):
    d = {"id":o['id'], "body":o['teaser'], "label":o['label'], "full":o['full']}
    if o['group']: d["group"]=o['group']
    chs=[]
    for ch in o['choices']:
        c={"label":ch['label']}
        if 'check' in ch:
            c["check"]={"attr":ch['check'][0],"need":ch['check'][1]}
            c["bands"]={b:[ch['bands'][b][0], ch['bands'][b][1]] + ([ch['bands'][b][2]] if len(ch['bands'][b])>2 else []) for b in ["MET","CLEAN","PARTIAL","BOTCHED"]}
        else:
            c["flat"]=ch['flat']
            if ch.get('gain'): c["gain"]=ch['gain']
            if ch.get('gate_credits'): c["gate"]={"credits":ch['gate_credits']}
            if ch.get('fight'): c["fight"]=True
            if ch.get('decline'): c["decline"]=True
        chs.append(c)
    d["choices"]=chs
    return d

out=[]
for name,region,danger,sec,berths,flav,ids in SYS:
    out.append({"name":name,"region":region,"danger":danger,"security":sec,
                "berths":berths,"flavour":flav,
                "options":[jsopt(by[i]) for i in ids]})
js = json.dumps(out, ensure_ascii=False, indent=1)
open('/home/claude/gen/batch03.json','w').write(js)
print("systems:",len(out),"options:",sum(len(s['options']) for s in out))
