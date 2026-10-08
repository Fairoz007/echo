"""Measure audio integrity without substituting measurements for listening."""
import array
import json
import math
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def main():
    assets=[]
    for path in sorted((ROOT/'audio').rglob('*.wav')):
        with wave.open(str(path)) as source:
            samples=array.array('h',source.readframes(source.getnframes()))
            peak=max(abs(v) for v in samples)/32768 if samples else 0
            rms=math.sqrt(sum(v*v for v in samples)/len(samples))/32768 if samples else 0
            assets.append({'asset':path.stem,'path':str(path.relative_to(ROOT)),
                'duration':source.getnframes()/source.getframerate(),
                'sample_rate':source.getframerate(),'channels':source.getnchannels(),
                'peak_dbfs':20*math.log10(peak) if peak else None,
                'rms_dbfs':20*math.log10(rms) if rms else None,
                'clipped_samples':sum(abs(v)>=32767 for v in samples),
                'loop_boundary_delta':abs(samples[-1]-samples[0])/32768 if samples else None,
                'listening_qa':'NOT_PERFORMED'})
    report={'assets':assets,'total_assets':len(assets),'sample_integrity_pass':all(a['clipped_samples']==0 and a['duration']>0 for a in assets),
        'limitations':'Measurements do not assess words, acting, unwanted voices, perceived loop seams or in-game mix.'}
    (ROOT/'production/audio_signal_audit.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print(json.dumps(report))

if __name__=='__main__':main()
