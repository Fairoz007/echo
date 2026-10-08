"""Bounded, resumable Tripo production jobs. Secrets never enter provenance."""
import argparse
import json
from pathlib import Path
import urllib.request
import urllib.error
import tripo_client as api

REGISTRY = Path('assets/production/tripo_jobs.json')
COMMON = 'Photorealistic grounded archaeological adventure game asset, earth-toned PBR materials, isolated object, no base platform, no text or logos. '
ASSETS = {
 'PROP_SURVEY_FIELDDESK_001': ('assets/props/camp/survey_fielddesk.glb', [2.4,0.9,1.4], 6000, 'Single complete folding archaeology expedition field desk, horizontal weathered olive canvas and aluminium tabletop with spread parchment topographic contour map weighted by small stones, compact compass and pencil, four coherent folding dark metal legs. Grounded realistic rugged outdoor archaeological survey equipment. Desk width2.4 meters height0.9 meters depth1.4 meters. No chairs, no people, no terrain, no text, no buildings. Upright functional table, table surface faces upwards.'),
 'PROP_EXPEDITION_SIDEARM_001': ('assets/props/equipment/expedition_sidearm.glb', [0.22,0.14,0.035], 4000, 'Compact original modern expedition semiautomatic sidearm, matte dark steel and textured charcoal grip, coherent realistic functional proportions, complete isolated handgun laid horizontal with muzzle forward, no ammunition, no hands, no branding.'),
 'PROP_CLIMB_PICK_001': ('assets/props/equipment/climbing_pick.glb', [0.35,0.5,0.05], 3000, 'Single modern compact curved climbing rock ice pick tool, weathered dark steel head and orange rubberized shaft grip with wrist loop, realistic mountaineering equipment, isolated complete object, no hands, no rock.'),
 'ENV_JUNGLE_TREE_001': ('assets/environment/jungle/jungle_tree.glb', [6,10,6], 15000, 'Single realistic tropical rainforest tree, mature irregular branching trunk and dense broad green leaf canopy, visible roots, brown bark moss, cohesive natural leaf clusters with gaps, isolated complete tree, no terrain, no pot.'),
 'ENV_JUNGLE_FERN_001': ('assets/environment/jungle/jungle_fern.glb', [1.5,1.2,1.5], 5000, 'Single lush tropical fern clump, several gracefully arched green fronds and detailed leaflet silhouettes, coherent rainforest understory plant, isolated complete plant, no pot, no terrain, no rocks.'),
 'ENV_CAVE_WALL_001': ('assets/environment/cave/cave_wall_limestone.glb', [4,4,0.9], 10000, 'Natural irregular wet limestone cave wall module, 4 meters wide 4 meters tall, layered sedimentary strata and erosion pockets, rough scalloped front face, nearly flat back and modular edges, no masonry, no ancient carvings, no arches.'),
 'ENV_CAVE_CEILING_001': ('assets/environment/cave/cave_ceiling_limestone.glb', [4,1,4], 10000, 'Natural limestone cave ceiling module, broad horizontal 4 by 4 meter slab with downward hanging short stalactites and irregular scalloped underside, eroded mineral seams, damp grey brown stone, rough edges, no buildings, no cave floor.'),
 'ENV_CAVE_FLOOR_001': ('assets/environment/cave/cave_floor_sediment.glb', [4,0.2,4], 8000, 'Natural cave floor module, broad horizontal square 4 by 4 meter flat walkable surface, shallow uneven sediment and gravel, embedded stones, damp dark limestone, thin slab with shallow relief, no walls, no tall rocks, no vegetation, no pedestal.'),
 'CHR_ELIAS_001': ('assets/characters/elias/source/CHR_Elias_Base.glb', [0.7,1.8,0.45], 20000, 'Full body original male archaeology expedition mentor age 58, grey short hair and beard, weathered tan field shirt grey utility vest linen trousers hiking boots, individual simple tools, realistic human proportions. Symmetrical neutral A pose, arms apart, legs separated, five fingers, no weapon.'),
 'CHR_NADIYA_001': ('assets/characters/nadiya/source/CHR_Nadiya_Base.glb', [0.65,1.67,0.4], 20000, 'Full body original female communications engineer age 32, dark hair tied back, slate navy field jacket with small orange trim, utility trousers rugged hiking boots, small belt radio, realistic human proportions. Symmetrical neutral A pose, arms apart, legs separated, five fingers, no weapon.'),
 'CHR_TOMAS_001': ('assets/characters/tomas/source/CHR_Tomas_Base.glb', [0.75,1.84,0.45], 20000, 'Full body original male expedition climber medic age 35, short dark hair, forest green field shirt khaki climbing trousers weathered leather climbing harness and hiking boots, realistic human proportions. Symmetrical neutral A pose, arms apart, legs separated, five fingers, no weapon.'),
 'CHR_ADRIAN_001': ('assets/characters/adrian/source/CHR_Adrian_Base.glb', [0.7,1.78,0.45], 20000, 'Full body original male expedition logistics coordinator age 40, short neat brown hair clean shaven, neutral grey technical field shirt black utility trousers gunmetal belt and hiking boots, realistic human proportions. Symmetrical neutral A pose, arms apart, legs separated, five fingers, no weapon.'),
 'CHR_DRAKE_001': ('assets/characters/drake/source/CHR_Drake_Base.glb', [0.75,1.86,0.45], 20000, 'Full body original male private archaeological security director age 48, silver temples short dark hair, stern face, premium dark graphite expedition jacket black industrial tactical trousers understated titanium hardware and boots, no insignia, realistic human proportions. Symmetrical neutral A pose, arms apart, legs separated, five fingers, no weapon.'),
 'CHR_MERIDIAN_BASE_001': ('assets/characters/meridian/base/source/CHR_Meridian_Base.glb', [0.75,1.82,0.45], 20000, 'Full body original professional archaeological security mercenary, dark charcoal field uniform matte black ballistic vest khaki drab tactical trousers boots, bare face short hair, standardized industrial equipment, no insignia, realistic human proportions. Symmetrical neutral A pose, arms apart, legs separated, five fingers, no held weapon.'),
}

def save(records):
    REGISTRY.parent.mkdir(parents=True, exist_ok=True)
    temporary = REGISTRY.with_suffix('.tmp')
    temporary.write_text(json.dumps(records, indent=2) + '\n', encoding='utf-8')
    temporary.replace(REGISTRY)

def submit(records, identifier):
    if identifier in records and records[identifier]['status'] != 'REQUESTED':
        print(identifier, 'already registered', records[identifier]['status'])
        return
    path, dimensions, faces, prompt = ASSETS[identifier]
    if Path(path).exists():
        raise RuntimeError(f'{identifier}: existing file must be registered, not regenerated')
    payload = {'type':'text_to_model', 'model_version':'P1-20260311', 'prompt':COMMON + prompt, 'face_limit':faces, 'texture':True, 'pbr':True, 'texture_quality':'standard'}
    if identifier == 'PROP_SURVEY_FIELDDESK_001':
        wallet = api.make_request('/user/balance', 'GET')
        available = wallet.get('data', {}).get('balance', 0)
        frozen = wallet.get('data', {}).get('frozen', 0)
        if wallet.get('code') != 0 or available - frozen < 40:
            raise RuntimeError('Survey desk requires 40 available credits; no task submitted')
        print('SURVEY_DESK_BUDGET expected_cost=40 wallet_slot=', api.current_key_idx+1, 'balance=',available,'frozen=',frozen)
    records[identifier] = {'asset_id':identifier,'path':path,'target_dimensions_m':dimensions,'requester':'Lead / Environment and Character Production','payload':payload,'status':'SUBMITTING','key_slot':api.current_key_idx+1,'approval':'unreviewed'}
    save(records)
    try:
        response = api.make_request('/task', 'POST', payload)
    except urllib.error.HTTPError as error:
        records[identifier]['status']='REQUESTED' if error.code == 429 else 'REJECTED'
        records[identifier]['error']={'http_status':error.code,'reason':'explicit HTTP rejection; no task ID created'}
        save(records)
        raise
    if response.get('code') != 0:
        records[identifier]['status']='REJECTED'
        records[identifier]['error']=response
        save(records)
        raise RuntimeError(f'Task rejected: {response}')
    records[identifier].update(task_id=response['data']['task_id'],status='GENERATING',key_slot=api.current_key_idx+1)
    save(records)
    print(identifier, 'submitted', records[identifier]['task_id'])

def poll(records):
    for identifier, record in records.items():
        if record['status'] != 'GENERATING':
            continue
        api.current_key_idx = record['key_slot']-1
        response = api.make_request('/task/' + record['task_id'])
        data = response.get('data', {})
        record['remote_status'] = data.get('status')
        record['progress'] = data.get('progress')
        record['consumed_credit'] = data.get('consumed_credit')
        if data.get('status') == 'success':
            output = data.get('output', {})
            if record['payload']['type'] == 'animate_prerigcheck':
                record.update(status='QA', check_result=output, generation_result={k:v for k,v in data.items() if k != 'output'})
                save(records)
                print(identifier, 'QA', output)
                continue
            link = output.get('pbr_model') or output.get('model') or output.get('model_url')
            if isinstance(link, dict):
                link = link.get('url')
            if not link:
                record['error']='Successful task returned no model URL'
                record['status']='QA'
            else:
                path = Path(record['path'])
                path.parent.mkdir(parents=True,exist_ok=True)
                urllib.request.urlretrieve(link, path)
                record['status']='GENERATED'
                record['bytes']=path.stat().st_size
                record['generation_result']={k:v for k,v in data.items() if k != 'output'}
        elif data.get('status') in ('failed','cancelled','banned'):
            record['status']='REJECTED'
            record['error']={k:v for k,v in data.items() if k != 'output'}
        save(records)
        print(identifier,record['status'],record.get('progress'), 'credits=', record.get('consumed_credit'))

def process_character(records, identifier, phase):
    suffix={'check':'_CHECK','rig':'_RIG','rig_legacy':'_RIG_LEGACY','idle_legacy':'_IDLE_LEGACY','idle':'_IDLE','idle_retry':'_IDLE_RETRY'}[phase]
    job_id=identifier+suffix
    if job_id in records and records[job_id]['status'] != 'REQUESTED':
        print(job_id,'already registered',records[job_id]['status'])
        return
    source=records[identifier + '_RIG_LEGACY'] if phase=='idle_legacy' else records[identifier + '_RIG'] if phase in ('idle','idle_retry') else records[identifier]
    api.current_key_idx=source['key_slot']-1
    payload={'type':{'check':'animate_prerigcheck','rig':'animate_rig','rig_legacy':'animate_rig','idle_legacy':'animate_retarget','idle':'animate_retarget','idle_retry':'animate_retarget'}[phase], 'original_model_task_id':source['task_id']}
    if phase=='rig':
        check=records.get(identifier+'_CHECK',{}).get('check_result',{})
        if not check.get('riggable'):
            raise RuntimeError(f'{identifier}: positive pre-rig check required: {check}')
        payload.update(model_version='v2.5-20260210',rig_type='biped',spec='tripo',out_format='glb')
    if phase=='idle':
        payload.update(animation='preset:idle',animate_in_place=True,out_format='glb')
    if phase=='idle_retry':
        payload.update(animation='preset:biped:idle',bake_animation=True,export_with_geometry=True,out_format='glb')
    if phase=='rig_legacy':
        payload.update(model_version='v1.0-20240301',out_format='glb',spec='tripo')
    if phase=='idle_legacy':
        payload.update(animation='preset:idle',animate_in_place=True,out_format='glb')
    base=Path(records[identifier]['path'])
    path=str(base.with_name(base.stem.replace('_Base','')+suffix.title()+'.glb')).replace('\\','/')
    records[job_id]={'asset_id':job_id,'path':path,'target_dimensions_m':source['target_dimensions_m'],'requester':'Character Production','payload':payload,'status':'SUBMITTING','key_slot':api.current_key_idx+1,'approval':'unreviewed'}
    save(records)
    try:
        response=api.make_request('/task','POST',payload)
    except urllib.error.HTTPError as error:
        records[job_id].update(status='REQUESTED' if error.code==429 else 'REJECTED',error={'http_status':error.code})
        save(records)
        raise
    if response.get('code') != 0:
        records[job_id].update(status='REJECTED',error=response)
        save(records)
        raise RuntimeError(str(response))
    records[job_id].update(task_id=response['data']['task_id'],status='GENERATING',key_slot=api.current_key_idx+1)
    save(records)
    print(job_id,'submitted',records[job_id]['task_id'])

if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode',choices=('submit','poll','check','rig','idle','idle_retry','rig_legacy','idle_legacy'))
    parser.add_argument('ids',nargs='*')
    parser.add_argument('--key-slot',type=int,default=2)
    args=parser.parse_args()
    api.current_key_idx=args.key_slot-1
    records=json.loads(REGISTRY.read_text()) if REGISTRY.exists() else {}
    if args.mode=='submit':
        for identifier in args.ids:
            submit(records,identifier)
    elif args.mode=='poll':
        poll(records)
    else:
        for identifier in args.ids:
            process_character(records,identifier,args.mode)
