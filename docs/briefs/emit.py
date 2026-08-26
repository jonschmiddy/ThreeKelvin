# -*- coding: utf-8 -*-
exec(open('batch03.py').read())

def ledger(g):
    if not g: return "**nothing.**"
    parts=[]
    names={"credits":"credits","fuel":"fuel","hull":"hull","heat":"heat",
           "exotic":"exotic","module":"module","fight":"fight"}
    for k,v in g.items():
        if k=="fight": parts.append("**fight**"); continue
        if k=="module": parts.append(f"**+{v} module**"); continue
        parts.append(f"**{'+' if v>0 else ''}{v} {names.get(k,k)}**")
    return " · ".join(parts)

md=["# batch-03 — twenty options",
"",
"*Written 2026-08-26, offline. Aimed at the gaps `batch-02-draft.md` left: Maneuver",
"and Thermal had one option each, LAWLESS and COSMOPOLITAN carry 78% of the galaxy,",
"and continuity had exactly one instance.*",
"",
"**Every option here is written against `ENCOUNTER_FLOW.md` Ruling 9** — *an obstacle",
"guards a reward, never a door.* Walking away always costs something specific.",
"",
"**Fuel figures are placeholders** pending S3/S3a.",
"",
"---",""]
for o in O:
    md.append(f"## {o['label']}")
    md.append("")
    md.append("```")
    md.append(f"id       {o['id']}")
    md.append(f"tags     {o['tags']}")
    md.append(f"gate     {o['gate']}")
    md.append(f"group    {o['group'] or '—'}")
    md.append(f"weight   {o['weight'] if not o.get('placed') else '— (placed)'}")
    if o.get('places'): md.append(f"places   {o['places']}")
    md.append("```")
    md.append("")
    md.append(f"*Row teaser:* {o['teaser']}")
    md.append("")
    for para in o['full'].split("\n\n"): md.append(f"> {para}"); md.append(">")
    md.append("")
    for ch in o['choices']:
        head=f"**{ch['label']}**"
        if 'check' in ch: head+=f" — *{ch['check'][0].title()} {ch['check'][1]}*"
        elif ch.get('gate_credits'): head+=f" — *hard gate: {ch['gate_credits']} credits*"
        elif ch.get('fight'): head+=" — *fight*"
        elif ch.get('decline'): head+=" — *decline*"
        else: head+=" — *no check*"
        md.append(head)
        md.append("")
        if 'bands' in ch:
            for b in ["MET","CLEAN","PARTIAL","BOTCHED"]:
                t=ch['bands'][b]; txt,g=t[0],t[1]
                md.append(f"- **{b}** — {txt} {ledger(g)}")
        else:
            g=ch.get('gain',{})
            extra=" *(archive entry, if this system holds one)*" if ch.get('archive') else ""
            md.append(f"- {ch['flat']} {ledger(g)}{extra}")
        md.append("")
    md.append("---"); md.append("")

open('/home/claude/handoff_build/batch-03.md','w').write("\n".join(md))
print("md written")
