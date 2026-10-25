from pathlib import Path
import csv,json,re,shutil
ROOT=Path(__file__).resolve().parents[1]
SOURCE=Path('G:/projects/game metal man')
legacy=json.loads((ROOT/'tools/legacy-source.json').read_text(encoding='utf8'))
def snake(k): return re.sub(r'(?<!^)(?=[A-Z])','_',k).lower()
parts={}
for table in sorted((SOURCE/'battle_math_tables_v0_4/json/02_parts').glob('*.json')):
    if table.stem=='programs': continue
    kind={'arms_and_weapons':'arm','controllers_modules':'controller','cpus':'cpu','power_cores':'power_core','sensors':'sensor','torsos':'torso','legs':'legs','cooling':'cooling'}[table.stem]
    for raw in json.loads(table.read_text(encoding='utf-8-sig')):
        d={snake(k):v for k,v in raw.items()}; ident=d.pop('part_id'); d['id']=ident
        d['type']=d.get('type',kind);d['max_durability']=d['durability'];d['name']=ident.replace('_',' ').title()
        if 'idle_peak_energy' in d:d['idle_energy'],d['peak_energy']=[float(x) for x in d.pop('idle_peak_energy').split('/')]
        for a,b in [('damage_type_1','damage_type'),('damage_type_2','secondary_damage_type'),('range_code','range_band')]:
            if a in d:d[b]=d.pop(a)
        d['source']='battle_math_v0.4/'+table.stem
        parts[ident]=d
for ident,raw in legacy['parts']['PART_TEMPLATES'].items():
    d={snake(k):v for k,v in raw.items()}
    if ident not in parts:parts[ident]={**d,'max_durability':d['durability'],'source':'legacy additional equipment'}
    else:
        for k,v in d.items():
            if k not in parts[ident] or k in ('name','attack_delivery','can_hold_weapon','built_in_weapon','is_shield_arm','is_hack_arm','is_tool_arm','ammo_type','magazine_size','burst_count','pellet_count'):
                parts[ident][k]=v
classes={x['class_id']:x['code'] for x in json.loads((SOURCE/'battle_math_tables_v0_4/json/01_reference/classes.json').read_text(encoding='utf-8-sig'))}
for d in parts.values():
    d['part_class']=classes.get(d.get('class_id'),d.get('part_class','domestic'))
    d.setdefault('name',d['id']);d.setdefault('repair_difficulty',1);d.setdefault('dismantle_difficulty',1)
    d.setdefault('idle_energy',0);d.setdefault('cpu_req',0);d.setdefault('heat',0)
    d.setdefault('armor',0);d.setdefault('mass',0);d.setdefault('attack_speed',50)
    d.setdefault('attack_delivery','melee');d.setdefault('damage_type','kinetic')
    d.setdefault('range_band',d.get('range','melee'));d.setdefault('can_hold_weapon',d['type']=='arm' and not d.get('built_in_weapon',False))
parts['CELL0_BATTERY']['power_gen']=14
aliases={'TITAN_GRIP':'TITAN_GRIP_L','PATROL_SECURITY_LEGS':'PATROL_RUNNER_LEGS','MULE_INDUSTRIAL_LEGS':'MULE_HEAVY_LEGS','SHADE_STEALTH_LEGS':'SHADE_SILENT_LEGS','VECTOR_EXPERIMENTAL_LEGS':'VECTOR_PREDATOR_LEGS','SILENTCELL':'SILENTCELL_H','SURGE_CORE':'SURGE_COMPACT_CORE','MEM0_BLACKBOX':'MEMORY_BLACKBOX'}
visuals=[]
maps={
 'arms':['B01_BASIC_ARM','R12_REPAIR_ARM','TITAN_GRIP_L','GUARD_L_SHIELD_ARM','S17_PISTOL_ARM','LONGSHOT_PRECISION_ARM','GHOST_PORT_LITE_L','PLASMA_CUT_ARM','VOLT3_IMPULSE_ARM','SHOTGUN_ARM','HYDRAULIC_CRUSHER_R','ARC_LANCE_ARM'],
 'torsos':['HOME_SHELL_S0','TECH_FRAME_T2','SENTINEL_LIGHT_ARMOR','SOFTFRAME_H2','VEKTOR_TACTICAL_FRAME','ATLAS_INDUSTRIAL_FRAME','07_military_torso','RIOT_CONTROL_FRAME','BLACKCORE_EXPERIMENTAL_FRAME','BULWARK_ARMOR_CORE','11_stealth_torso','12_prototype_torso'],
 'legs':['WALK0_DOMESTIC_LEGS','STABLE_SERVICE_LEGS','SCOUT_LIGHT_LEGS','PATROL_RUNNER_LEGS','MULE_HEAVY_LEGS','HEAVY_LOAD_LEGS','SHADE_SILENT_LEGS','AGILE_RECON_LEGS','HAMMER_ASSAULT_LEGS','ULTRA_CORPORATE_LEGS','LEAP_JUMP_LEGS','VECTOR_PREDATOR_LEGS'],
 'heads':['EYE0_HOMECAM','TECHEYE_DIAG','THREATMARK_S1','SIGNALTRACE_EYE','PREDATOR_OPTIC_MK2','BLACKCORE_OMNISIGHT']}
for group,ids in maps.items():
    base=SOURCE/f'android_{group}_alpha_prepared'/f'android_{group}_alpha_prepared'
    images=sorted((base/'01_source_clean_alpha_original_scale').glob('*.png'))
    for i,(ident,image) in enumerate(zip(ids,images),1):
        visual_id=f'{group}_{i:02d}'
        record={'id':visual_id,'type':parts[ident]['type'],'index':i,'part_id':ident,'name':image.stem,'source':str(image),'model':f'res://assets/models/parts/{visual_id}.glb'}
        visuals.append(record);parts[ident]['visual_id']=visual_id
        shutil.copy2(image,ROOT/'assets/references'/image.name)
default_by_class={'domestic':1,'service':2,'recon':2,'security':3,'industrial':6,'combat':3,'military':7,'police':8,'hacker':4,'corporate':5,'experimental':9,'data':1,'heavy':10,'stealth':11}
for ident,d in parts.items():
    if d.get('visual_id'):continue
    if ident in aliases and aliases[ident] in parts and 'visual_id' in parts[aliases[ident]]:d['visual_id']=parts[aliases[ident]]['visual_id'];continue
    kind=d['type'];cl=d['part_class']
    if kind=='torso':d['visual_id']='torsos_%02d'%default_by_class.get(cl,1)
    elif kind=='sensor':d['visual_id']='heads_%02d'%({'domestic':1,'service':2,'security':3,'combat':3,'police':3,'industrial':2,'recon':2,'hacker':4,'corporate':5,'experimental':6}.get(cl,1))
    elif kind=='legs':d['visual_id']='legs_%02d'%({'domestic':1,'service':2,'recon':3,'security':4,'industrial':5,'military':9,'police':4,'hacker':7,'corporate':10,'experimental':12}.get(cl,1))
    elif kind=='arm':d['visual_id']='arms_%02d'%({'M7_SURGICAL_ARM':2,'MICROWELD_R8':8,'GHOST_PORT_HACK_ARM':7,'NEEDLE_JACK_R':7,'STUN_BATON_ARM':9,'RIOT_SHIELD_ARM':4,'PHASE_SHIELD_ARM':4,'DRONE_GUNPOD_GP4':5}.get(ident,1))
    else:d['visual_id']='internal_'+kind
for ident,mass,hp,armor,idle,peak,heat,kind in [('LIGHT_DRONE_BODY',8,60,5,1,3,1,'drone_body'),('HOVER_ENGINE',5,40,2,5,20,8,'drone_engine'),('ARMORED_DRONE_BODY',18,110,20,2,5,3,'drone_body'),('VECTOR_ENGINE',10,70,8,8,35,14,'drone_engine'),('UNIVERSAL_DRONE_ADAPTER',2,40,2,1,4,1,'adapter')]:
    parts[ident]=dict(id=ident,name=ident.replace('_',' ').title(),type=kind,mass=mass,durability=hp,max_durability=hp,armor=armor,idle_energy=idle,peak_energy=peak,heat=heat,cpu_req=1,visual_id='internal_'+kind,source='source text drone tables' if kind!='adapter' else '3D adapter definition',repair_difficulty=2)
weapons={i:{snake(k):v for k,v in d.items()} for i,d in legacy['weapons']['WEAPONS'].items()}
for i,w in weapons.items():w['infinite_ammo_for_prototype']=False;w['model_index']=list(weapons).index(i)%20
programs={x['program_id']:{**x,'id':x['program_id']} for x in json.loads((SOURCE/'battle_math_tables_v0_4/json/02_parts/programs.json').read_text(encoding='utf-8-sig'))}
enemies=json.loads((SOURCE/'battle_math_tables_v0_4/json/05_enemies/enemy_builds.json').read_text(encoding='utf-8-sig'))
for e in enemies:
    e['assembly']={};ids=re.findall(r'\b[A-Z][A-Z0-9_]+\b',e['parts'])
    for ident in ids:
        kind=parts[ident]['type']
        if kind=='arm':
            slot='left_arm' if 'left_arm' not in e['assembly'] else 'right_arm'
            e['assembly'][slot]=ident
            if ident=='B01_BASIC_ARM':e['assembly']['right_arm']=ident
        else:e['assembly'][kind]=ident
    if e['enemy_id'] not in ('E05','E06'):
        e['assembly'].setdefault('cooling','COOL0_PASSIVE_RADIATOR')
    e['archetype']=e['enemy_id'];e['id']=e['enemy_id']
matrix=json.loads((SOURCE/'battle_math_tables_v0_4/json/03_combat_rules/damage_type_vs_part_matrix.json').read_text(encoding='utf-8-sig'))
data=dict(parts=parts,weapons=weapons,programs=programs,enemies={e['id']:e for e in enemies},visuals=visuals,aliases=aliases,damage_matrix={x['damage_type']:x for x in matrix},ammo=legacy['ammo']['AMMO'])
(ROOT/'data/catalog.json').write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf8')
(ROOT/'docs/CATALOG.md').write_text(f'# Equipment catalog\n\n{len(parts)} definitions including historical aliases, {len(visuals)} distinct external reference forms, {len(weapons)} held weapons, {len(programs)} programs, {len(enemies)} enemy builds.\n\nBaseline: v0.4 numeric tables. Additional definitions: browser prototype and supplied reference indexes. Drone body/engine definitions restored from source prose tables. Explicit 3D override: CELL0_BATTERY generation 14.\n',encoding='utf8')
print('CATALOG_READY',len(parts),len(visuals),len(weapons),len(programs),len(enemies))
