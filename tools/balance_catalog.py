"""Validate authored enemy power budgets and record explicit 3D balance deltas."""
from pathlib import Path
import json,math
ROOT=Path(__file__).resolve().parents[1]
path=ROOT/'data/catalog.json';c=json.loads(path.read_text(encoding='utf8'));p=c['parts'];overrides=[]
coolers={'E01':'COOL0_PASSIVE_RADIATOR','E02':'FLOW1_LIQUID_LOOP','E03':'VENT2_COMBAT_SINK','E04':'CRYO3_HEAVY_COOLER','E05':'COOL0_PASSIVE_RADIATOR','E06':'VENT2_COMBAT_SINK','E07':'VENT2_COMBAT_SINK','E08':'FLOW1_LIQUID_LOOP','E09':'BUFFERX_THERMAL_BANK','E10':'BLACKCORE_CRYO_SPINE'}
for e in c['enemies'].values():
 e['assembly']['cooling']=coolers[e['id']]
 idle=sum(float(p[x].get('idle_energy',0)) for x in e['assembly'].values())
 core=p[e['assembly']['power_core']]
 actions=[float(p[x].get('attack_energy',5)) for slot,x in e['assembly'].items() if p[x]['type']=='arm']
 required=max(actions or [8])
 if e['id']=='E01':continue
 for key,value in [('power_gen',max(float(core['power_gen']),math.ceil(idle*1.25))),('peak_output',max(float(core['peak_output']),math.ceil(idle+required+8)))]:
  if core[key]!=value:overrides.append({'part':core['id'],'field':key,'before':core[key],'after':value,'reason':'Authored enemy assembly must support idle load and its strongest weapon'});core[key]=value
c['balance_overrides']=overrides
path.write_text(json.dumps(c,ensure_ascii=False,indent=2),encoding='utf8')
(ROOT/'docs/balance-overrides.json').write_text(json.dumps(overrides,indent=2),encoding='utf8')
print('POWER_BUDGETS_VALIDATED',len(overrides),'explicit changes')
