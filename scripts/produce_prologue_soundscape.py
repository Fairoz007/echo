"""Bounded layered Prologue soundscape; all assets require listening review."""
import json
from elevenlabs_client import ElevenLabsClient, ElevenLabsError, ROOT
from produce_prologue_audio import process

ASSETS = [
 ('AMB_PRO_CAVE_ROOMTONE','ambience/cave',20,True,'Deep underground limestone cave room tone. Very subtle low air movement and natural cavern resonance. No distinct drops, music, speech, voices, monsters or dramatic events. Seamless restrained quiet background.'),
 ('AMB_PRO_CAVE_WATER','ambience/cave',12,True,'Quiet underground trickling water flowing between rocks, close isolated stream perspective, natural cave reflections, subtle realistic seamless continuous water, no music or voices.'),
 ('SFX_PRO_CAVE_DRIP','water',1,False,'One isolated water droplet falling into a shallow limestone pool, short realistic cave reflection. Single clear drop only. No voices or music.'),
 ('SFX_PRO_ROCK_SHIFT','destruction',3,False,'Small limestone rocks shifting and a little gravel falling nearby underground. Natural restrained geological creak. Clean isolated event, no explosions, no speech or music.'),
 ('SFX_PRO_VAELOR_KEY_ACTIVATE','vaelor',4,False,'Ancient acoustic stone key waking: a struck dark stone harmonic, resonant mineral ring rising gently into three pure intertwined overtones, subtle geological vibration fading away. Grounded archaeological mechanism, no electronic beep, music or voices.'),
 ('SFX_PRO_UI_OBJECTIVE','ui',1,False,'Subtle interface objective update: one delicate rounded stone tap with a very short airy harmonic tail. Quiet archaeological mystery game cue, no arcade reward, voices or music.'),
 ('FOL_PRO_CLOTH_SHIFT','movement',2,False,'One subtle canvas expedition jacket and backpack strap rustle during a small movement, restrained close dry isolated sound, no metal jangling, footsteps, voices or music.'),
 ('FOL_PRO_WET_ROCK_STEP_01','footsteps/rock',1,False,'Single realistic rugged hiking boot footstep on damp limestone cave floor, medium body weight, short clean transient and tiny gravel shift. One footstep only, no voice or music.'),
 ('FOL_PRO_WET_ROCK_STEP_02','footsteps/rock',1,False,'Single firm hiking boot heel and sole contact on damp rough limestone, subtle wet stone scrape, clean close isolated transient. One step only, no voices or music.'),
 ('FOL_PRO_WET_ROCK_STEP_03','footsteps/rock',1,False,'Single lighter rugged hiking boot contact on uneven damp limestone with a few grit grains, short restrained cave reflection. One isolated footstep only, no voices or music.'),
 ('FOL_PRO_WET_ROCK_STEP_04','footsteps/rock',1,False,'Single cautious hiking boot landing on wet limestone rock, soft heavy sole thud and brief sole friction. One isolated footstep only, no voices or music.'),
 ('FOL_PRO_BREATH_RECOVERY','movement',4,False,'One adult woman recovering from a fall, two restrained mildly strained breaths, realistic nonverbal breathing, grounded physical effort, not theatrical or sexualized, no words or music.'),
]

def main():
    client=ElevenLabsClient()
    report={'requested':0,'generated':0,'accepted':0,'rejected':0,'qa':'PENDING_LISTENING','assets':[],'errors':[]}
    for asset_id,folder,duration,loop,prompt in ASSETS:
        source=ROOT/'production/audio_masters'/f'{asset_id}.mp3'
        target=ROOT/'audio'/folder/f'{asset_id}.wav'
        if not source.exists():
            report['requested']+=1
            try:
                client.generate_sound_effect(asset_id,prompt,source,duration,loop)
                report['generated']+=1
            except ElevenLabsError as error:
                report['errors'].append({'asset_id':asset_id,'reason':str(error)})
                break
        details=process(source,target)
        report['assets'].append({'asset_id':asset_id,'path':'res://'+target.relative_to(ROOT).as_posix(),
            'prompt':prompt,'loop':loop,'spatial':folder not in ['ui','movement'],**details})
    subscription=client.read('/v1/user/subscription')
    report['remaining_characters_reported']=subscription['character_limit']-subscription['character_count']
    (ROOT/'production/prologue_soundscape_batch.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print(json.dumps(report))

if __name__=='__main__':main()
