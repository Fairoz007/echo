# Campaign Audio Production Report

Status: generated campaign audio integrated into reusable runtime systems; listening acceptance is pending.

Latest source coverage audit: 68 screenplay lines retain matching generated text and files; all existing story-line aliases resolve. Water entry is mapped to splash, and moving Chapter 6 swimming now emits a restrained stroke every 0.9 seconds. Collapse cues follow Chapter 3 bridge failure, Chapter 9 tremor, Chapter 10 fourth-node overload and the Finale escape. Configuration guards prevent duplicate ambience sources; short event cooldowns limit overlapping splash, swimming and collapse repeats. This source change was checked by read-only analysis while the root's isolated route test was active; no import, GPU test or generation was performed. Dedicated sluice mechanisms, underwater treatment and complete natural Foley coverage remain open. Commercial release rights and perceptual listening acceptance remain unresolved.

| Metric | Result |
|---|---:|
| Original screenplay spoken lines | 68 |
| Runtime voice assets | 68 |
| Dialogue duration | 289.831 seconds |
| Ambience loops | 11 |
| SFX / Foley | 26 |
| Footstep variants (wet rock / jungle / stone) | 12 |
| Vaelor sounds | 1 |
| UI sounds | 1 |
| Music tracks | 0 |
| Runtime WAV assets | 105 |
| Historical successful generations | 106 |
| Rejected generation requests | 0 |
| Superseded sources retained | 1 |
| Latest provider character usage | 6412 / 10000 |
| Latest provider remaining quota | 3588 |

Provider usage readings lagged and sometimes moved backwards; the preserved request ledger and independent character reservation controlled generation. No plan purchase or automatic quota extension was made. The new campaign dialogue reserved 4562 characters; nine new ambience loops total 158 seconds.

The account reports the free tier. Assets remain noncommercial prototypes. [ElevenLabs TTS documentation](https://elevenlabs.io/docs/overview/capabilities/text-to-speech) describes commercial use for paid subscriptions. [Speech API](https://elevenlabs.io/docs/api-reference/text-to-speech/convert) and [Sound Effects API](https://elevenlabs.io/docs/api-reference/text-to-sound-effects/convert) were checked. No real-person voice clone or celebrity imitation was requested.

The original screenplay now covers the complete campaign, with Elias Voss as mentor, Adrian Kell as the betrayer and Lucian Drake as the antagonist. Retired Mateo references were removed. The Prologue opening was regenerated with Nadiya while preserving its old source.

## Character voices

| Character | Stable provider premade voice ID | Status |
|---|---|---|
| MARA | EXAVITQu4vr4xnSDxMaL | GENERATED; consistency listening pending |
| ELIAS | JBFqnCBsd6RMkjVDRZzb | GENERATED; consistency listening pending |
| NADIYA | XrExE9yKIg1WjnnlVkGX | GENERATED; consistency listening pending |
| TOMAS | iP95p4xoKVk53GoZ742B | GENERATED; consistency listening pending |
| ADRIAN | cjVigY5qzO86Huf0OWal | GENERATED; consistency listening pending |
| DRAKE | onwK4e9ZLuTAKqWW03F9 | GENERATED; consistency listening pending |
| MERIDIAN | CwhRBWXzGAHq8TQ4Fs17 | GENERATED; consistency listening pending |

## Chapter coverage

| Chapter | Generated spoken lines | Listening acceptance |
|---|---:|---|
| PRO | 4 | PENDING |
| C01 | 12 | PENDING |
| C02 | 5 | PENDING |
| C03 | 4 | PENDING |
| C04 | 4 | PENDING |
| C05 | 5 | PENDING |
| C06 | 4 | PENDING |
| C07 | 5 | PENDING |
| C08 | 6 | PENDING |
| C09 | 4 | PENDING |
| C10 | 8 | PENDING |
| FIN | 4 | PENDING |
| EPI | 3 | PENDING |

## Integration and verification

AudioManager resolves legacy subtitle text through canonical aliases, plays stable dialogue IDs and uses the generated stream duration for subtitle timing. Dedicated audio buses provide scene-safe dialogue cancellation, ambience/music ducking and bounded spatial one-shots. CampaignDialogue sequences additional team, patrol, journal, confrontation and ending beats with duration-derived waits; it provides a subtitle overlay for the epilogue. Scene-owned spatial ambience distinguishes jungle, ruins, gorge, caves, Meridian machinery, drowned temple, Lost City, Heart Road and Heart Vault. Ridge dawn ambience accompanies the finale and epilogue. Combat fire/reload/impact/takedown, water entry/swimming, running breath and collapse map to gameplay event IDs. Footstep families vary by scene terrain (coarse chapter mapping, not per-contact material detection), with four non-consecutive variants per family.

Signal audit: PASS; 105 WAVs have nonzero durations and no full-scale PCM clipping. Dialogue peaks target -3 dBFS; effects target -6 dBFS. Radio uses the same actor voice with 350–3200 Hz band limiting and compression. New loops include boundary smoothing; measurements do not establish perceived seamlessness. Godot parser/runtime/save regression is recorded separately by the technical QA agent.

Listening QA has not been performed by this production agent. Acting, pronunciation, unintended noises, voice consistency, headphone positioning, low-volume intelligibility, action mix and all campaign/export listening gates remain pending. No chapter is labelled a listening PASS.

P1: required listening and commercial-license gates remain open. P2: this production does not yet cover every combat cue, every footstep surface, full breathing/effort variant coverage, puzzle families, underwater treatment, radio static, or the complete UI family. Music remains unproduced. Campaign mandatory story VO, gameplay event families and distinct ambience are available; complete audio acceptance is not claimed.
