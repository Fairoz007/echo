"""Build traceable registries from production evidence, with explicit QA limits."""
import csv
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]

def main():
    if (ROOT/'production/campaign_dialogue_batch.json').exists():
        from write_campaign_audio_reports import main as write_campaign
        return write_campaign()
    voice=json.loads((ROOT/'production/prologue_audio_batch.json').read_text())
    sound=json.loads((ROOT/'production/prologue_soundscape_batch.json').read_text())
    audit=json.loads((ROOT/'production/audio_signal_audit.json').read_text())
    rows=list(csv.DictReader((ROOT/'DIALOGUE_PRODUCTION.csv').open(encoding='utf-8')))
    dialogue={row['Dialogue ID']:row for row in rows}
    log=[json.loads(line) for line in (ROOT/'production/elevenlabs_requests.jsonl').read_text().splitlines()]
    generated=[entry for entry in log if entry.get('status')=='GENERATED']
    registry=['# Audio Asset Registry', '', 'Prologue prototype only. Every entry remains pending listening review. Source masters and API evidence live in `production/`, excluded from Godot import. No actor cloning was used.', '',
        '| ID | Type | Character | Chapter / scene | Duration | Format | Sample rate / channels | Loop / spatial | Godot path | Status | QA |',
        '|---|---|---|---|---:|---|---|---|---|---|---|']
    for asset in voice['assets']+sound['assets']:
        asset_id=asset['asset_id']
        row=dialogue.get(asset_id.removeprefix('VO_'),{})
        kind='Dialogue' if row else 'Ambience' if asset_id.startswith('AMB_') else 'Footstep' if 'STEP_' in asset_id else 'Foley' if asset_id.startswith('FOL_') else 'SFX'
        spatial=asset.get('spatial',False) and asset_id!='AMB_PRO_CAVE_ROOMTONE'
        registry.append(f"| {asset_id} | {kind} | {row.get('Character','—')} | PRO / {row.get('Scene','cave')} | {asset['duration']:.3f}s | PCM WAV | 44100 / mono | {asset.get('loop',False)} / {spatial} | `{asset['path']}` | INTEGRATED (prototype) | PENDING_LISTENING |")
    registry += ['', '## Generation direction and traceability', '']
    for asset in voice['assets']+sound['assets']:
        row=dialogue.get(asset['asset_id'].removeprefix('VO_'),{})
        registry += [f"### {asset['asset_id']}", '',
            f"Text / prompt: {row.get('Text',asset.get('prompt',''))}", '',
            f"Voice reference: {asset.get('voice_id','none; sound-effects model eleven_text_to_sound_v2')}", '',
            f"Direction: {row.get('Delivery','restrained grounded environmental effect')}; original source preserved.", '']
    registry += ['## Unproduced required scope','',
        'Chapter 1 remains PLANNED. Later chapters have runtime subtitle dialogue but no complete screenplay sections. The supplied audio directive includes a different ten-line Prologue with Elias radio, collapse/escape and additional characters absent from the canonical opening. Those additions remain unproduced rather than silently rewriting the story. Breathing variants, surface coverage, collapse/escape, radio, remaining UI family, music and the full campaign remain incomplete.']
    (ROOT/'AUDIO_ASSET_REGISTRY.md').write_text('\n'.join(registry)+'\n',encoding='utf-8')
    total_duration=sum(a['duration'] for a in voice['assets'])
    report=f'''# Audio Production Report

Status: PROLOGUE PROTOTYPE; listening acceptance incomplete. Full campaign audio is not complete.

Canonical screenplay spoken lines: {len(rows)} (4 Prologue, 6 Chapter 1). Four Prologue voice assets and twelve environmental/Foley assets generated; {total_duration:.3f} seconds of dialogue. Environmental batch: 2 ambience layers, 4 wet-rock footstep variants, 1 breath recovery, 1 cloth shift, 1 water drip, 1 rock shift, 1 Vaelor activation, 1 objective UI cue. Music: 0. Elias and other character voices: not generated.

Generation ledger records {len(generated)} successful generated assets, no generation errors or rejected generations. Latest provider subscription reading: {voice['characters_after']} used / {voice['character_limit']}, {voice['remaining_characters']} remaining. Immediate usage readings lagged; no zero-cost claim is made. Processing reruns reuse masters and do not regenerate assets.

The account reports the free tier. These assets are labelled noncommercial prototypes. [ElevenLabs TTS documentation](https://elevenlabs.io/docs/overview/capabilities/text-to-speech) describes commercial usage for paid subscriptions. [Sound effects API](https://elevenlabs.io/docs/api-reference/text-to-sound-effects/convert) documents loop generation and duration limits. [Speech API](https://elevenlabs.io/docs/api-reference/text-to-speech/convert) provides the generation endpoint.

Processing: source MP3 preserved; high-pass filter and limiter with automatic output boost disabled; mono PCM16 WAV at 44.1 kHz; dialogue peaks normalized to -3 dBFS and sound effects to -6 dBFS. Signal audit: {'PASS' if audit['sample_integrity_pass'] else 'FAIL'}, {audit['total_assets']} assets with nonzero duration and zero full-scale clipped samples after repair. This does not verify speech accuracy, performance, undesirable noises, perceived loop seams or the in-game mix.

Integration: canonical dialogue IDs drive matching subtitle text and stream-derived timing. Prologue ambience/water sources are scene-owned; droplets and geological movement use spatial playback. Footstep variants avoid consecutive repetition, only on the supported Prologue rock surface. Vaelor activation, cloth and objective cues attach to relic interaction. AudioManager uses dedicated buses, dialogue ducking, scene cancellation and a limit of 24 spatial voices. Save restore prevents stale opening speech and duplicate relic acquisition.

Mara voice consistency: PENDING LISTENING. Elias/Nadiya/Tomas/Adrian/Drake/Meridian: NOT PRODUCED. Prologue: NOT ACCEPTED. Chapter 1 through Epilogue: NOT PRODUCED / NOT ACCEPTED. No headphone test, low-volume listening test, high-action mix evaluation, full campaign listening pass or Windows export listening pass has been performed by this production agent.

P1: Prologue listening review still required; screenplay covers only the opening and Chapter 1; cast/story and opening conflict with supplied directive; full-game generation cannot advance until Prologue acceptance. P2: radio treatment, reverb zones, surface mapping beyond Prologue rock, all breathing variants, collapse/escape cues and music remain unimplemented. Technical Godot import/runtime/save checks are owned by the project QA report and must be evaluated separately.
'''
    (ROOT/'FINAL_AUDIO_PRODUCTION_REPORT.md').write_text(report,encoding='utf-8')
    print(f'Registry/report written: {len(generated)} historical generated assets')

if __name__=='__main__':main()
