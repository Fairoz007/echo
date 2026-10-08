"""Generate a bounded Prologue batch; never advance to Chapter 1 automatically."""
import argparse
import array
import csv
import json
import subprocess
import wave
from pathlib import Path
from elevenlabs_client import ElevenLabsClient, ElevenLabsError, ROOT

VOICE_MARA = 'EXAVITQu4vr4xnSDxMaL' # Provider premade Sarah; no cloning.

def process(source, target, radio=False):
    target.parent.mkdir(parents=True, exist_ok=True)
    filters = 'highpass=f=75,alimiter=limit=0.89:level=false'
    if radio:
        filters = 'highpass=f=350,lowpass=f=3200,acompressor=threshold=0.15:ratio=3,alimiter=limit=0.89:level=false'
    result = subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-i',str(source),
        '-af',filters,'-ar','44100','-ac','1','-c:a','pcm_s16le',str(target)],capture_output=True)
    if result.returncode:
        raise RuntimeError('FFmpeg processing failed; source preserved')
    with wave.open(str(target),'rb') as audio:
        params=audio.getparams()
        samples=array.array('h',audio.readframes(audio.getnframes()))
    peak=max(abs(v) for v in samples) if samples else 0
    if not peak:
        raise RuntimeError('Silent generated asset rejected; source preserved')
    # Uniform family headroom; dynamic/gameplay loudness still requires listening.
    target_peak=23197 if target.stem.startswith('VO_') else 16422
    gain=target_peak/peak
    normalized=array.array('h',(round(v*gain) for v in samples))
    with wave.open(str(target),'wb') as audio:
        audio.setparams(params)
        audio.writeframes(normalized.tobytes())
    with wave.open(str(target)) as audio:
        return {'duration':audio.getnframes()/audio.getframerate(),'sample_rate':audio.getframerate(),'channels':audio.getnchannels()}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--generate',action='store_true',help='Explicitly perform paid/provider generation')
    args = parser.parse_args()
    rows = list(csv.DictReader((ROOT/'DIALOGUE_PRODUCTION.csv').open(encoding='utf-8')))
    manifest = {}
    client = ElevenLabsClient()
    subscription = client.read('/v1/user/subscription')
    report = {'chapter':'PRO','requested':0,'generated':0,'accepted':0,'rejected':0,
        'listening_qa':'NOT_PERFORMED','tier':subscription['tier'],
        'characters_before':subscription['character_count'],'character_limit':subscription['character_limit'],
        'license':'prototype_noncommercial' if subscription['tier']=='free' else 'requires_project_rights',
        'assets':[],'errors':[]}
    for row in rows:
        if row['Chapter'] != 'PRO':
            continue
        asset_id = 'VO_'+row['Dialogue ID']
        source = ROOT/'production/audio_masters'/f'{asset_id}.mp3'
        target = ROOT/row['Generated File'].removeprefix('res://')
        settings = {'stability':0.45 if row['Dialogue ID']=='PRO_MARA_001' else 0.6,
            'similarity_boost':0.85,'style':0.2 if row['Dialogue ID']=='PRO_MARA_004' else 0.1,'use_speaker_boost':True}
        if not source.exists() and args.generate:
            report['requested'] += 1
            try:
                client.generate_dialogue(asset_id,row['Text'],VOICE_MARA,source,settings=settings)
                report['generated'] += 1
            except ElevenLabsError as error:
                report['errors'].append({'asset_id':asset_id,'reason':str(error)})
                row['Status']='REJECTED'
                # Stop a batch on entitlement/quota/authentication failures; no quota loops.
                break
        if source.exists():
            details = process(source,target)
            manifest[row['Dialogue ID']]={'path':row['Generated File'],'text':row['Text'],'speaker':row['Character'],
                'radio':False,'qa':'PENDING_LISTENING',**details}
            row['Status']='PROCESSED'
            report['assets'].append({'asset_id':asset_id,'path':row['Generated File'],'voice_id':VOICE_MARA,**details})
    (ROOT/'audio').mkdir(exist_ok=True)
    (ROOT/'audio/dialogue_manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    with (ROOT/'DIALOGUE_PRODUCTION.csv').open('w',newline='',encoding='utf-8') as handle:
        writer=csv.DictWriter(handle,fieldnames=rows[0].keys());writer.writeheader();writer.writerows(rows)
    after=client.read('/v1/user/subscription')
    report['characters_after']=after['character_count']
    report['remaining_characters']=max(0,after['character_limit']-after['character_count'])
    (ROOT/'production/prologue_audio_batch.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print(json.dumps(report))

if __name__=='__main__':
    main()
