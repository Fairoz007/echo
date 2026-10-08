"""Resume-safe bounded chapter batches, using provider premade voices only."""
import csv
import json
import time
from elevenlabs_client import ElevenLabsClient, ElevenLabsError, ROOT
from produce_prologue_audio import process

# Provider IDs are resolved from a read-only capability request and pinned in the batch evidence.
VOICES={}

def main():
    client=ElevenLabsClient()
    available=client.read('/v1/voices')['voices']
    by_name={v['name'].split(' - ')[0]:v['voice_id'] for v in available if v.get('category')=='premade'}
    for character,name in [('MARA','Sarah'),('ELIAS','George'),('NADIYA','Matilda'),('TOMAS','Chris'),('ADRIAN','Eric'),('DRAKE','Daniel'),('MERIDIAN','Roger')]:
        if name not in by_name:raise RuntimeError(f'Required premade voice unavailable: {name}')
        VOICES[character]=by_name[name]
    rows=list(csv.DictReader((ROOT/'DIALOGUE_PRODUCTION.csv').open(encoding='utf-8')))
    manifest_path=ROOT/'audio/dialogue_manifest.json'
    manifest=json.loads(manifest_path.read_text())
    batch={'started_utc':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),'generated':0,'reused':0,'errors':[],
        'voice_identities':VOICES,'qa':'PENDING_LISTENING','license':'noncommercial_prototype','chapters':[]}
    reserved_characters=0
    # Account usage reads can lag; cap this additional run independently below supplied remaining quota.
    max_additional_characters=6500
    for chapter in ['PRO']+[f'C{i:02d}' for i in range(1,11)]+['FIN','EPI']:
        start=len(batch.get('assets',[]))
        for row in [r for r in rows if r['Chapter']==chapter]:
            dialogue_id=row['Dialogue ID'];asset_id='VO_'+dialogue_id
            # Prologue revision removes retired Mateo continuity without losing the original source.
            suffix='_V2' if dialogue_id=='PRO_MARA_001' else ''
            source=ROOT/'production/audio_masters'/f'{asset_id}{suffix}.mp3'
            target=ROOT/row['Generated File'].removeprefix('res://')
            if not source.exists():
                if reserved_characters+len(row['Text'])>max_additional_characters:
                    raise RuntimeError('Conservative campaign generation cap reached')
                reserved_characters+=len(row['Text'])
                try:
                    client.generate_dialogue(asset_id+suffix,row['Text'],VOICES[row['Character']],source,
                        settings={'stability':0.55,'similarity_boost':0.85,'style':0.1,'use_speaker_boost':True})
                    batch['generated']+=1
                except ElevenLabsError as error:
                    batch['errors'].append({'asset_id':asset_id,'reason':str(error)})
                    (ROOT/'production/campaign_dialogue_batch.json').write_text(json.dumps(batch,indent=2))
                    raise
            else:batch['reused']+=1
            details=process(source,target,row['Radio?']=='Yes')
            manifest[dialogue_id]={'path':row['Generated File'],'text':row['Text'],'speaker':row['Character'].title(),
                'radio':row['Radio?']=='Yes','voice_id':VOICES[row['Character']],'qa':'PENDING_LISTENING',**details}
            row['Status']='PROCESSED'
            batch.setdefault('assets',[]).append({'asset_id':asset_id,'dialogue_id':dialogue_id,'chapter':chapter,
                'text':row['Text'],'path':row['Generated File'],'voice_id':VOICES[row['Character']],
                'radio':row['Radio?']=='Yes',**details})
        manifest_path.write_text(json.dumps(manifest,indent=2),encoding='utf-8')
        with (ROOT/'DIALOGUE_PRODUCTION.csv').open('w',newline='',encoding='utf-8') as handle:
            writer=csv.DictWriter(handle,fieldnames=rows[0].keys());writer.writeheader();writer.writerows(rows)
        subscription=client.read('/v1/user/subscription')
        batch['chapters'].append({'chapter':chapter,'assets':len(batch.get('assets',[]))-start,
            'reported_used':subscription['character_count'],'reported_limit':subscription['character_limit']})
        batch['reserved_additional_characters']=reserved_characters
        (ROOT/'production/campaign_dialogue_batch.json').write_text(json.dumps(batch,indent=2),encoding='utf-8')
        print(json.dumps({'chapter':chapter,'assets':len(batch.get('assets',[]))-start,'generated_total':batch['generated'],
            'reported_remaining':subscription['character_limit']-subscription['character_count']}),flush=True)
    print('Campaign dialogue production complete; listening approval remains pending.',flush=True)

if __name__=='__main__':main()
