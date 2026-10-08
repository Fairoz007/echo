"""Generate distinct bounded scene families; spatial sources remain scene-owned."""
import array
import json
import wave
from elevenlabs_client import ElevenLabsClient, ElevenLabsError, ROOT
from produce_prologue_audio import process

ASSETS=[
 ('AMB_JUNGLE_CANOPY','ambience/jungle',20,'Quiet misty mountain jungle canopy, gentle moving leaves, sparse distant birds and soft insects, continuous natural wind, no music, voices, repetitive loud bird calls or dramatic events. Seamless understated background.'),
 ('AMB_RUIN_DRAFT','ambience/ruins',16,'A faint natural draft through ancient stone chambers, distant water behind a thick wall, airy stone reflections, restrained archaeological ruin interior, continuous quiet texture, no voices, music or monster sounds. Seamless loop.'),
 ('AMB_BRIDGE_GORGE','ambience/ruins',16,'Wind moving through a deep mountain gorge beneath an ancient high stone bridge, soft air and very distant rushing water, broad outdoor acoustic space, restrained continuous texture, no voices or music. Seamless loop.'),
 ('AMB_MERIDIAN_POWER','ambience/meridian',12,'Distant industrial survey generator and ventilation equipment in a stone tunnel, steady muted mechanical motor, dry modern metallic vibration, no alarm, voices or music, quiet continuous seamless loop.'),
 ('AMB_DROWNED_TEMPLE','ambience/temple',20,'Quiet submerged stone temple water surface, subtle continuous trickling channels and watery reflections in a large chamber, natural restrained wet ambience, no voices, monster sounds or music. Seamless loop.'),
 ('AMB_LOST_CITY_AIRFLOW','ambience/lost_city',20,'Vast abandoned subterranean city air movement with very distant aqueduct waterfalls, enormous open stone reflections, still quiet foreground, natural geological space, no voices or music. Seamless restrained continuous texture.'),
 ('AMB_HEART_ROAD_RUMBLE','ambience/heart_vault',16,'Distant restrained geological low rumble transmitted through old stone conduits, subtle air movement, continuous natural mountain vibration, no distinct repeated impacts, explosions, voices or music. Seamless loop.'),
 ('AMB_HEART_VAULT_RESONANCE','ambience/heart_vault',20,'Ancient cavern mineral resonance, quiet continuous low stone harmonic with gentle upper overtones and huge geode reflections, grounded acoustic mineral vibration, no melody, electronic beeps, monster voices or music. Seamless loop.'),
 ('AMB_DAYLIGHT_RIDGE_WIND','ambience/jungle',18,'Gentle open mountain ridge breeze at dawn, light distant birds far below, calm continuous high altitude air, natural broad outdoor space, no voices, music or loud repeated calls. Seamless quiet loop.')]

def smooth_boundary(path):
    with wave.open(str(path),'rb') as audio:
        params=audio.getparams();samples=array.array('h',audio.readframes(audio.getnframes()))
    width=min(512,len(samples)//4)
    for index in range(width):
        gain=index/max(1,width-1)
        samples[index]=round(samples[index]*gain)
        samples[-index-1]=round(samples[-index-1]*gain)
    with wave.open(str(path),'wb') as audio:audio.setparams(params);audio.writeframes(samples.tobytes())

def main():
    client=ElevenLabsClient();assets=[];errors=[]
    for asset_id,folder,duration,prompt in ASSETS:
        source=ROOT/'production/audio_masters'/f'{asset_id}.mp3';target=ROOT/'audio'/folder/f'{asset_id}.wav'
        if not source.exists():
            try:client.generate_ambience(asset_id,prompt,source,duration)
            except ElevenLabsError as error:
                errors.append({'asset_id':asset_id,'reason':str(error)});break
        details=process(source,target);smooth_boundary(target)
        assets.append({'asset_id':asset_id,'path':'res://'+target.relative_to(ROOT).as_posix(),
            'prompt':prompt,'loop':True,'spatial':True,'qa':'PENDING_LISTENING',**details})
        print(asset_id+' ready',flush=True)
    by_id={a['asset_id']:a for a in assets}
    mapping={'C01':'AMB_JUNGLE_CANOPY','C02':'AMB_RUIN_DRAFT','C03':'AMB_BRIDGE_GORGE',
        'C04':'AMB_PRO_CAVE_ROOMTONE','C05':'AMB_MERIDIAN_POWER','C06':'AMB_DROWNED_TEMPLE',
        'C07':'AMB_LOST_CITY_AIRFLOW','C08':'AMB_RUIN_DRAFT','C09':'AMB_HEART_ROAD_RUMBLE',
        'C10':'AMB_HEART_VAULT_RESONANCE','FIN':'AMB_DAYLIGHT_RIDGE_WIND','EPI':'AMB_DAYLIGHT_RIDGE_WIND'}
    scene_maps={}
    for chapter,asset_id in mapping.items():
        path=by_id[asset_id]['path'] if asset_id in by_id else 'res://audio/ambience/cave/AMB_PRO_CAVE_ROOMTONE.wav' if asset_id=='AMB_PRO_CAVE_ROOMTONE' else ''
        if path:scene_maps[chapter]=[{'path':path,'gain_db':-23.0,'position':[0,3,-12]}]
    (ROOT/'audio/campaign_soundscapes.json').write_text(json.dumps(scene_maps,indent=2),encoding='utf-8')
    (ROOT/'production/campaign_soundscape_batch.json').write_text(json.dumps({'assets':assets,'errors':errors,'qa':'PENDING_LISTENING'},indent=2),encoding='utf-8')
    print(json.dumps({'assets':len(assets),'errors':errors}),flush=True)

if __name__=='__main__':main()
