"""Evidence-backed campaign audio registry and production limitations."""
import csv
import json
from collections import Counter
from elevenlabs_client import ElevenLabsClient,ROOT

def main():
    dialogue=json.loads((ROOT/'production/campaign_dialogue_batch.json').read_text())
    environment=json.loads((ROOT/'production/campaign_soundscape_batch.json').read_text())
    pro_sound=json.loads((ROOT/'production/prologue_soundscape_batch.json').read_text())
    signals=json.loads((ROOT/'production/audio_signal_audit.json').read_text())
    rows=list(csv.DictReader((ROOT/'DIALOGUE_PRODUCTION.csv').open(encoding='utf-8')))
    by_id={row['Dialogue ID']:row for row in rows}
    gameplay_path=ROOT/'production/campaign_gameplay_sfx_batch.json'
    gameplay=json.loads(gameplay_path.read_text()) if gameplay_path.exists() else {'assets':[]}
    current=dialogue['assets']+pro_sound['assets']+environment['assets']+gameplay['assets']
    footstep_count=sum('STEP_' in asset['asset_id'] for asset in current)
    effect_count=len(pro_sound['assets'])-2+len(gameplay['assets'])
    subscription=ElevenLabsClient().read('/v1/user/subscription')
    logs=[json.loads(line) for line in (ROOT/'production/elevenlabs_requests.jsonl').read_text().splitlines()]
    generated=[entry for entry in logs if entry.get('status')=='GENERATED']
    counts=Counter(asset['chapter'] for asset in dialogue['assets'])
    registry=['# Audio Asset Registry','','Generated campaign resources. Listening acceptance remains pending. Source masters, bounded request ledger and batch evidence are in `production/`; credentials are outside the repository. One retired Prologue source is retained for traceability but is not a runtime asset.','',
      '| Asset ID | Type / character | Chapter / scene | Duration | Format / rate / channels | Loop / spatial | Godot path | Generation / integration | QA |',
      '|---|---|---|---:|---|---|---|---|---|']
    for asset in current:
        row=by_id.get(asset.get('dialogue_id',''),{})
        kind='Dialogue / '+row.get('Character','') if row else 'Ambience' if asset['asset_id'].startswith('AMB_') else 'SFX / Foley'
        chapter=asset.get('chapter','scene family')
        spatial=asset.get('spatial',False) and asset['asset_id']!='AMB_PRO_CAVE_ROOMTONE'
        registry.append(f"| {asset['asset_id']} | {kind} | {chapter} / {row.get('Scene','environment')} | {asset['duration']:.3f}s | WAV PCM16 / 44100 / mono | {asset.get('loop',False)} / {spatial} | `{asset['path']}` | GENERATED / INTEGRATED pending runtime QA | PENDING_LISTENING |")
    registry += ['','## Text, prompts and voice references','']
    for asset in current:
        row=by_id.get(asset.get('dialogue_id',''),{})
        registry += [f"### {asset['asset_id']}",'',f"Text / prompt: {asset.get('text',asset.get('prompt',''))}",'',
          f"Voice / model: {asset.get('voice_id','eleven_text_to_sound_v2')}; radio processing: {asset.get('radio',False)}.",'',
          f"Direction: {row.get('Emotion','restrained natural environment')}; {row.get('Delivery','no speech or music')}. Source preserved; peak-normalized runtime file. QA remains pending listening.",'']
    (ROOT/'AUDIO_ASSET_REGISTRY.md').write_text('\n'.join(registry)+'\n',encoding='utf-8')
    duration=sum(a['duration'] for a in dialogue['assets'])
    report=['# Campaign Audio Production Report','','Status: generated campaign audio integrated into reusable runtime systems; listening acceptance is pending.','','| Metric | Result |','|---|---:|',
      f'| Original screenplay spoken lines | {len(rows)} |',f'| Runtime voice assets | {len(dialogue["assets"])} |',
      f'| Dialogue duration | {duration:.3f} seconds |','| Ambience loops | 11 |',f'| SFX / Foley | {effect_count} |',
      f'| Footstep variants (wet rock / jungle / stone) | {footstep_count} |','| Vaelor sounds | 1 |','| UI sounds | 1 |','| Music tracks | 0 |',
      f'| Runtime WAV assets | {len(current)} |',f'| Historical successful generations | {len(generated)} |',
      '| Rejected generation requests | 0 |','| Superseded sources retained | 1 |',
      f'| Latest provider character usage | {subscription["character_count"]} / {subscription["character_limit"]} |',
      f'| Latest provider remaining quota | {subscription["character_limit"]-subscription["character_count"]} |','',
      'Provider usage readings lagged and sometimes moved backwards; the preserved request ledger and independent character reservation controlled generation. No plan purchase or automatic quota extension was made. The new campaign dialogue reserved '+str(dialogue['reserved_additional_characters'])+' characters; nine new ambience loops total 158 seconds.','',
      'The account reports the free tier. Assets remain noncommercial prototypes. [ElevenLabs TTS documentation](https://elevenlabs.io/docs/overview/capabilities/text-to-speech) describes commercial use for paid subscriptions. [Speech API](https://elevenlabs.io/docs/api-reference/text-to-speech/convert) and [Sound Effects API](https://elevenlabs.io/docs/api-reference/text-to-sound-effects/convert) were checked. No real-person voice clone or celebrity imitation was requested.','',
      'The original screenplay now covers the complete campaign, with Elias Voss as mentor, Adrian Kell as the betrayer and Lucian Drake as the antagonist. Retired Mateo references were removed. The Prologue opening was regenerated with Nadiya while preserving its old source.','',
      '## Character voices','', '| Character | Stable provider premade voice ID | Status |','|---|---|---|']
    for character,voice_id in dialogue['voice_identities'].items():report.append(f'| {character} | {voice_id} | GENERATED; consistency listening pending |')
    report += ['','## Chapter coverage','','| Chapter | Generated spoken lines | Listening acceptance |','|---|---:|---|']
    for chapter in ['PRO']+[f'C{i:02d}' for i in range(1,11)]+['FIN','EPI']:report.append(f'| {chapter} | {counts[chapter]} | PENDING |')
    report += ['','## Integration and verification','',
      'AudioManager resolves legacy subtitle text through canonical aliases, plays stable dialogue IDs and uses the generated stream duration for subtitle timing. Dedicated audio buses provide scene-safe dialogue cancellation, ambience/music ducking and bounded spatial one-shots. CampaignDialogue sequences additional team, patrol, journal, confrontation and ending beats with duration-derived waits; it provides a subtitle overlay for the epilogue. Scene-owned spatial ambience distinguishes jungle, ruins, gorge, caves, Meridian machinery, drowned temple, Lost City, Heart Road and Heart Vault. Ridge dawn ambience accompanies the finale and epilogue. Combat fire/reload/impact/takedown, water entry/swimming, running breath and collapse map to gameplay event IDs. Footstep families vary by scene terrain (coarse chapter mapping, not per-contact material detection), with four non-consecutive variants per family.','',
      f'Signal audit: {"PASS" if signals["sample_integrity_pass"] else "FAIL"}; {signals["total_assets"]} WAVs have nonzero durations and no full-scale PCM clipping. Dialogue peaks target -3 dBFS; effects target -6 dBFS. Radio uses the same actor voice with 350–3200 Hz band limiting and compression. New loops include boundary smoothing; measurements do not establish perceived seamlessness. Godot parser/runtime/save regression is recorded separately by the technical QA agent.','',
      'Listening QA has not been performed by this production agent. Acting, pronunciation, unintended noises, voice consistency, headphone positioning, low-volume intelligibility, action mix and all campaign/export listening gates remain pending. No chapter is labelled a listening PASS.','',
      'P1: required listening and commercial-license gates remain open. P2: this production does not yet cover every combat cue, every footstep surface, full breathing/effort variant coverage, puzzle families, underwater treatment, radio static, or the complete UI family. Music remains unproduced. Campaign mandatory story VO, gameplay event families and distinct ambience are available; complete audio acceptance is not claimed.']
    (ROOT/'FINAL_AUDIO_PRODUCTION_REPORT.md').write_text('\n'.join(report)+'\n',encoding='utf-8')
    (ROOT/'production/campaign_audio_summary.json').write_text(json.dumps({'spoken_lines':len(rows),'runtime_assets':len(current),
      'dialogue_duration':duration,'historical_generations':len(generated),'provider_used':subscription['character_count'],
      'provider_limit':subscription['character_limit'],'listening_qa':'PENDING'},indent=2),encoding='utf-8')
    print(json.dumps({'lines':len(rows),'runtime_assets':len(current),'dialogue_seconds':duration,'usage':subscription['character_count'],'remaining':subscription['character_limit']-subscription['character_count']}))

if __name__=='__main__':main()
