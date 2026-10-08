# AUDIO REPORT: AAA pass (2026-10-07)

## 1. Quota (ElevenLabs free tier, 10,000 credits per month, resets about 2026-11-07)
| | credits |
|---|---|
| Used before this pass | 6,412 |
| Spent this pass (sum of per-request `character-cost` headers, production/elevenlabs_requests.jsonl) | **2,593** |
| **True remaining** | **995** (the `/v1/user/subscription` counter lags and still showed 1,639) |
Generation was staged by chapter (PRO first, measured, then C01-C05, a QA check, then C06-FIN) under a 250-credit reserve guard (`scripts/produce_aaa_audio_pass.py`). Zero failed or duplicate requests. The license is **non-commercial with attribution** (free tier); upgrade before a commercial release.

## 2. Generated this pass (34 assets)
- **12 chapter-transition recaps** (REC_PRO ... REC_FIN), narrated by Mara (same pinned voice), 6.2-9.6 s each.
- **7 re-voiced lines** (take R2), where the dialogue was weak or gamey: C04_NADIYA_001, C05_MARA_001, C06_MARA_003, C07_MARA_001, C07_MARA_003 (removed "optional challenge chamber"), C09_MARA_001, C10_DRAKE_001.
- **15 SFX/loops**: wading water steps x4, mud steps x4, jungle birds and insects bed (15 s loop), stone counterweight grind, water-rising loop, water-draining loop, water-exit splash, resonant waterfall loop (Lost City), harmonic node pulse (Heart Vault).

## 3. Audit of existing audio (before, then after)
- No clipping found. All files were ≤ -2.9 dBTP before the pass.
- **Dialogue was peak-normalized, not loudness-normalized.** 68 lines spanned -15.9 to -22.9 LUFS (7 LU), so Elias, Tomas and radio lines were noticeably quieter. **Now all 80 lines (incl. recaps) sit at -17.1 to -15.9 LUFS, true peak ≤ -1.0 dBTP**, with edge silence trimmed.
- **Ambience spanned 19 LU** (AMB_RUIN_DRAFT at -37 LUFS was nearly inaudible). Now every bed is mastered to **-26 LUFS (±1)**, stereo OGG for runtime, and the legacy mono WAV paths were re-rendered so Waterfall.gd and the QA scripts keep working.
- **SFX** were re-mastered: footsteps to -26 LUFS (variants now consistent; before they varied up to 8 LU within a set) and other one-shots to -22 LUFS / -1.5 dBTP. A bug found and fixed in mastering: stereo-to-mono summing phase-cancelled some ElevenLabs SFX, so one channel is now taken instead.
- Measured per-file values: `production/audio_master_report.json` and AUDIO_ASSET_REGISTRY.md.

## 4. Voice cast (pinned; unchanged from the prior batches)
Mara = Sarah `EXAVITQu4vr4xnSDxMaL` (also the recap narrator) · Elias Voss = George `JBFqnCBsd6RMkjVDRZzb` · Nadiya Rahman = Matilda `XrExE9yKIg1WjnnlVkGX` · Tomas Reyes = Chris `iP95p4xoKVk53GoZ742B` · Adrian Kell = Eric `cjVigY5qzO86Huf0OWal` · Lucian Drake = Daniel `onwK4e9ZLuTAKqWW03F9` · Meridian soldier = Roger `CwhRBWXzGAHq8TQ4Fs17` · Radio = the speaker's own voice with a baked 350-3200 Hz band-pass and compression, routed to the `Radio` bus (light clip distortion, sends to Dialogue).

## 5. Story and dialogue
- COMPLETE_SCREENPLAY.md: the 7 lines above were rewritten; the repeated boilerplate stage directions became `[Trigger: event]`; key parentheticals were made specific; the broken C02 quote was fixed; and a **"CHAPTER TRANSITION RECAPS"** section was added (keyed by the chapter that just ended, 2-3 sentences each, with audio paths).
- STORY_BIBLE.md was **rewritten to match the voiced canon.** The old bible contradicted the game: it cast Elias "Vance" as the villain and used "Mateo Cruz" and the "Obsidian Syndicate". Canon is Elias Voss as mentor, Adrian Kell as the betrayer, and Meridian / Lucian Drake as the antagonists.
- Levels were not touched. Levels still pass their literal (old) strings to `AudioManager.play_story_line()`; the `aliases` in campaign_events.json map them to IDs, and the manifest supplies the **new text and audio**. Subtitles therefore show the revised lines.

## 6. Runtime integration (systems/audio/)
- **AudioBuses.gd** (idempotent): Master [HardLimiter -1 dB]; Music, SFX [Reverb], Ambience [Reverb], Dialogue [Reverb at 40% wet, Compressor], UI → Master; Radio [Distortion] → Dialogue; Underwater [LowPass] → SFX. `apply_reverb(preset)` takes outdoor, ruin, cave, temple, vast, vault or tunnel; `set_underwater(bool)`.
- **ReverbZone.gd**: an Area3D box that applies a reverb preset while the Player is inside (the innermost zone wins) and restores the chapter default on exit.
- **Soundscape.gd**: the per-chapter soundscape from `audio/campaign_soundscapes.json` (v2 presets: beds, emitters, random one-shots around the listener, surface type, chapter reverb, C06 water loops). CampaignDialogue now attaches it automatically for C01-C10, FIN and EPI. The Prologue keeps PrologueSoundscape (gains rebalanced, cave reverb added).
- **ChapterRecap.gd**, for the QA transition screens: `ChapterRecap.get_recap("C03")` returns `{id, text, path, duration, cues}`, and `ChapterRecap.play("C03", hud)` returns the duration.
- Every dialogue manifest entry now has **`cues`** (sentence-level subtitle timing, weighted by characters) plus `lufs`, `true_peak_db` and `take`.

### How level agents attach soundscapes (call from the level's `_ready`, after CampaignDialogue.configure)
```gdscript
const SC := preload("res://systems/audio/Soundscape.gd")
var sc = SC.attach(self, "C06")   # returns the same instance CampaignDialogue created
sc.add_emitter("res://audio/ambience/lost_city/AMB_WATERFALL_RESONANT_LOOP.ogg", $Waterfall.global_position, 0.0, 40.0)
sc.add_reverb_zone(Vector3(0, 2, -20), Vector3(12, 6, 30), "cave")
sc.set_water_state("rising", basin_pos)    # or "draining" / "idle" (1.5 s crossfade)
sc.play_oneshot("res://audio/vaelor/SFX_STONE_MECHANISM_GRIND.wav", lever_pos, -6.0)
sc.footstep(player.global_position, "water")   # mud | water | wet_rock | stone | grass
sc.set_underwater(player_head_below_surface)
```
(`Soundscape`/`ChapterRecap` class_names also work once the editor's class cache has refreshed; preload paths always work.)

## 7. Evidence
- `scripts/qa_audio_aaa.gd` (headless): all audio scripts compile; 80/80 manifest streams load via ResourceLoader with the imported length matching the measured duration (±0.1 s); all preset paths and 68 aliases resolve; the runtime exercise played soundscapes for PRO/C01/C06/C07/C10/EPI, water crossfades, footsteps, a zone, underwater, and a recap on the Dialogue bus. Result: **fails=0**.
- `scripts/qa_audio_references.gd` (existing QA): **PASS, 128 resources**.
- The Prologue samples were checked first: REC_PRO 8.3 s at -16.9 LUFS / -1.2 dBTP, no dropouts; all chapter batches were then measured (`production/aaa_audio_batches.json`).

## 8. Requests for the QA agent (owner of systems/AudioManager.gd)
1. **Surface footsteps:** AudioManager's `footstep_stone` picks folders by scene name. Route it to `Soundscape.footstep(pos)` when a `Soundscape` child exists. That enables mud steps (C01) and water steps (C04/C06) and adds ±6% pitch variation.
2. **Splash out:** map a new `"splash_exit"` event to `res://audio/water/SFX_WATER_EXIT_SPLASH.wav`.
3. **Mix gains:** SFX one-shots are now hotter (+3 to +12 dB for the previously quiet takedown, impact and UI files) and dialogue is about 2.5 dB louder. Re-check `play_sfx` gains (-14 dB) and `dialogue_player.volume_db = -3` by ear. Suggested ducking is -6 dB music / -4 dB ambience instead of -3/-2.
4. **Recap playback across scene changes:** `_process` stops dialogue when `current_scene` changes. If the transition screen is its own scene, call `ChapterRecap.play` after the new scene is current, or exempt narration (`entry.narration == true`).

## 9. Remaining gaps (honest)
- **No human listening pass.** QA is measured only (loudness, peak, duration, silence). Pronunciation, performance and AI artifacts still need ears. All entries are marked `MEASURED_PENDING_LISTENING`.
- The SFX_PRO_CAVE_DRIP and SFX_COMBAT_TAKEDOWN masters were extremely quiet at source and hit the +36 dB gain clamp, so the noise floor may be audible. These are retake candidates (about 25 credits).
- 61 of the 68 original lines were kept as recorded. Many are serviceable but expository (e.g., C01 Elias telemetry). Re-voicing more is limited by the remaining 995 credits.
- No music was generated (the ElevenLabs music API is not on the free tier). The Music bus has no content from this pass.
- No combat or Meridian-chatter barks beyond the one patrol line; no water lap/underwater bed; nothing new for C03/C05/C08.
- Levels must call the Soundscape API for positional emitters, water states and zones; until they do, only the chapter beds, one-shots and default reverb run.
- Stale generators: `scripts/produce_campaign_soundscapes.py` (old JSON format) and `scripts/author_campaign_screenplay.py` (not mine; rewrites the screenplay and events) would overwrite this pass if re-run. Don't re-run them.
- Old dialogue WAVs were moved (not deleted) to `production/legacy_dialogue_wav/` (gdignored).
