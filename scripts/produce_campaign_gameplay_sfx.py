"""Small quota-capped gameplay family, using isolated controllable events."""
import json
from elevenlabs_client import ElevenLabsClient,ElevenLabsError,ROOT
from produce_prologue_audio import process

ASSETS=[
 ('SFX_COMBAT_FIRE','combat',1,'One isolated modern semi automatic pistol shot, realistic crisp dry close report, short tail, no multiple shots, voice or music.'),
 ('SFX_COMBAT_RELOAD','combat',2,'One short realistic pistol magazine reload: release, insert, slide action, close restrained clean mechanical movement, no firing, voices or music.'),
 ('SFX_COMBAT_IMPACT','combat',1,'One isolated bullet striking thick old stone, short sharp chip and tiny debris, realistic clean game impact, no firing, voices or music.'),
 ('SFX_COMBAT_TAKEDOWN','combat',1.5,'One restrained close combat body shove and fabric impact, realistic blunt contact without gore or exaggerated punch, no words, voices or music.'),
 ('SFX_WATER_ENTRY','water',2,'One person entering a calm shallow pool, natural medium splash and short water movement, isolated realistic clean event, no voices or music.'),
 ('SFX_SWIM_STROKE','water',1.5,'One restrained arm swimming stroke at a calm water surface, close water movement and small splash, isolated clean event, no voices or music.'),
 ('FOL_BREATH_RUNNING','movement',4,'A physically exerted adult woman taking two controlled breaths after running, nonverbal grounded restrained effort, no words, theatrical sounds, sexualized sounds or music.'),
 ('SFX_ROCK_COLLAPSE','destruction',6,'Heavy natural limestone ceiling collapse: initial deep stone crack, falling large rocks and gravel settling, substantial grounded geological weight, isolated event, no voices, music, guns or explosive blast.'),
]
for family,folder,surface in [('JUNGLE','footsteps/grass','damp forest soil with scattered leaves'),('STONE','footsteps/stone','ancient dry rough stone slab')]:
    for variant in range(1,5):
        ASSETS.append((f'FOL_{family}_STEP_{variant:02d}',folder,1,
            f'Single realistic rugged hiking boot footstep on {surface}, variant {variant}, short clean isolated contact with natural small surface texture. One step only, no voices, music or multiple footsteps.'))

def main():
    client=ElevenLabsClient();assets=[];errors=[]
    if sum(a[2] for a in ASSETS)*10>500:raise RuntimeError('Small gameplay batch budget exceeded')
    for asset_id,folder,duration,prompt in ASSETS:
        source=ROOT/'production/audio_masters'/f'{asset_id}.mp3';target=ROOT/'audio'/folder/f'{asset_id}.wav'
        if not source.exists():
            try:client.generate_sound_effect(asset_id,prompt,source,duration)
            except ElevenLabsError as error:errors.append({'asset_id':asset_id,'reason':str(error)});break
        details=process(source,target)
        assets.append({'asset_id':asset_id,'path':'res://'+target.relative_to(ROOT).as_posix(),
            'prompt':prompt,'loop':False,'spatial':True,'qa':'PENDING_LISTENING',**details})
        print(asset_id+' ready',flush=True)
    (ROOT/'production/campaign_gameplay_sfx_batch.json').write_text(json.dumps({'assets':assets,'errors':errors,'qa':'PENDING_LISTENING'},indent=2),encoding='utf-8')
    print(json.dumps({'assets':len(assets),'errors':errors}),flush=True)

if __name__=='__main__':main()
