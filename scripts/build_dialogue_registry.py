"""Master all runtime audio and build the dialogue registry with subtitle timing.

Sources: production/audio_masters/*.mp3 (never modified).
Outputs:
  audio/dialogue/<speaker>/VO_<ID>.ogg, audio/dialogue/recaps/REC_<CH>.ogg  (-16 LUFS, -1.5 dBTP)
  audio/ambience/**.ogg  (-26 LUFS beds, -3 dBTP), legacy ambience .wav re-rendered in place
  audio/** one-shot SFX .wav  (footsteps -26 LUFS, other SFX -22 LUFS, -1.5 dBTP)
  audio/dialogue_manifest.json, audio/campaign_events.json (recaps + aliases), DIALOGUE_PRODUCTION.csv
  production/audio_master_report.json  (measured loudness of every runtime file)
Run: python scripts/build_dialogue_registry.py
"""
import csv
import json
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MASTERS = ROOT / "production" / "audio_masters"
PLAN = json.loads((ROOT / "audio" / "aaa_production_plan.json").read_text(encoding="utf-8"))
LEGACY_DIR = ROOT / "production" / "legacy_dialogue_wav"
DIALOGUE_LUFS, AMB_LUFS, STEP_LUFS, SFX_LUFS = -16.0, -26.0, -26.0, -22.0
RADIO_EQ = "highpass=f=350,lowpass=f=3200,acompressor=threshold=0.15:ratio=3"


def run(args):
    r = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-y", *args], capture_output=True, text=True)
    if r.returncode:
        raise RuntimeError(r.stderr[-400:])
    return r.stderr


def measure(path, pre=""):
    chain = (pre + "," if pre else "") + "ebur128=peak=true"
    out = run(["-i", str(path), "-af", chain, "-f", "null", "-"])
    i = float(re.findall(r"I:\s+(-?[\d.]+|-inf) LUFS", out)[-1].replace("-inf", "-70"))
    p = float(re.findall(r"Peak:\s+(-?[\d.]+|-inf) dBFS", out)[-1].replace("-inf", "-70"))
    return i, p


def duration(path):
    r = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(path)],
                       capture_output=True, text=True)
    return float(r.stdout.strip())


def master(src, dst, target, tp, pre="", trim=False, codec="ogg", channels=1):
    """Linear gain to target LUFS, then a 4x-oversampled limiter for true-peak safety (loop-safe)."""
    chain = []
    if trim:  # strip leading/trailing silence, keep a short natural pad
        chain += ["silenceremove=start_periods=1:start_threshold=-50dB:start_silence=0.08",
                  "areverse", "silenceremove=start_periods=1:start_threshold=-50dB:start_silence=0.15", "areverse"]
    if channels == 1:  # take one channel: summing wide stereo phase-cancels and drops ~3 dB
        chain.insert(0, "pan=mono|c0=c0")
    chain += ["highpass=f=70"] + ([pre] if pre else [])
    base = ",".join(chain)
    loud, _ = measure(src, base)
    gain = max(-36.0, min(36.0, target - loud))
    limit = 10 ** (tp / 20)
    full = f"{base},volume={gain:.2f}dB,aresample=176400,alimiter=limit={limit:.4f}:level=false:attack=1:release=60,aresample=44100"
    dst.parent.mkdir(parents=True, exist_ok=True)
    enc = ["-c:a", "libvorbis", "-q:a", "6"] if codec == "ogg" else ["-c:a", "pcm_s16le"]
    run(["-i", str(src), "-af", full, "-ac", str(channels), "-ar", "44100", *enc, str(dst)])
    i, p = measure(dst)
    return {"lufs": round(i, 1), "true_peak_db": round(p, 1), "duration": round(duration(dst), 3), "gain_db": round(gain, 2)}


def subtitle_cues(text, total):
    """Sentence cues weighted by character count; the short pad at the end is excluded."""
    parts = [s.strip() for s in re.split(r"(?<=[.!?])\s+", text) if s.strip()]
    speak = max(0.5, total - 0.15)
    weights = [len(p) + 6 for p in parts]
    t, cues = 0.08, []
    for p, w in zip(parts, weights):
        d = (speak - 0.08) * w / sum(weights)
        cues.append({"start": round(t, 2), "end": round(t + d, 2), "text": p})
        t += d
    return cues


def master_source(asset_id):
    for suffix in ("_R2", "_V2", ""):
        p = MASTERS / f"{asset_id}{suffix}.mp3"
        if p.exists():
            return p, suffix
    raise FileNotFoundError(asset_id)


def main():
    report = {"dialogue": {}, "ambience": {}, "sfx": {}}
    manifest_path = ROOT / "audio" / "dialogue_manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    rows = list(csv.DictReader((ROOT / "DIALOGUE_PRODUCTION.csv").open(encoding="utf-8")))
    fields = list(rows[0].keys())
    revised = {i["dialogue_id"]: i for i in PLAN["items"] if i["kind"] == "vo"}
    recaps = [i for i in PLAN["items"] if i["kind"] == "recap"]

    # ---- Dialogue: every line re-mastered from its provider master to OGG ----
    for row in rows:
        did = row["Dialogue ID"]
        if did.startswith("REC_"):
            continue
        entry = manifest[did]
        if did in revised:
            row["Text"] = revised[did]["text"]
            entry["text"] = revised[did]["text"]
        src, suffix = master_source("VO_" + did)
        speaker_dir = row["Character"].lower()
        dst = ROOT / "audio" / "dialogue" / speaker_dir / f"VO_{did}.ogg"
        stats = master(src, dst, DIALOGUE_LUFS, -1.5, pre=RADIO_EQ if entry.get("radio") else "", trim=True)
        old = ROOT / entry["path"].removeprefix("res://")
        if old.suffix == ".wav" and old.exists():  # keep legacy renders out of the runtime tree
            LEGACY_DIR.mkdir(parents=True, exist_ok=True)
            shutil.move(str(old), LEGACY_DIR / old.name)
            imp = old.with_suffix(".wav.import")
            if imp.exists():
                shutil.move(str(imp), LEGACY_DIR / imp.name)
        res = "res://" + dst.relative_to(ROOT).as_posix()
        entry.update({"path": res, "duration": stats["duration"], "sample_rate": 44100, "channels": 1,
                      "lufs": stats["lufs"], "true_peak_db": stats["true_peak_db"],
                      "take": "R2" if suffix == "_R2" else ("V2" if suffix == "_V2" else "R1"),
                      "cues": subtitle_cues(entry["text"], stats["duration"]), "qa": "MEASURED_PENDING_LISTENING"})
        row["Generated File"], row["Status"] = res, "MASTERED"
        report["dialogue"][did] = stats

    # ---- Chapter transition recaps (Mara, field-journal narration) ----
    recap_events = {}
    for item in recaps:
        did = item["dialogue_id"]
        dst = ROOT / "audio" / "dialogue" / "recaps" / f"{did}.ogg"
        stats = master(MASTERS / f"{item['asset_id']}.mp3", dst, DIALOGUE_LUFS, -1.5, trim=True)
        res = "res://" + dst.relative_to(ROOT).as_posix()
        manifest[did] = {"path": res, "text": item["text"], "speaker": "Mara", "radio": False, "narration": True,
                         "voice_id": manifest["PRO_MARA_001"]["voice_id"], "duration": stats["duration"],
                         "sample_rate": 44100, "channels": 1, "lufs": stats["lufs"],
                         "true_peak_db": stats["true_peak_db"], "take": "R1",
                         "cues": subtitle_cues(item["text"], stats["duration"]), "qa": "MEASURED_PENDING_LISTENING"}
        recap_events[item["chapter"]] = did
        if not any(r["Dialogue ID"] == did for r in rows):
            rows.append({f: "" for f in fields})
        r = next(r for r in rows if r["Dialogue ID"] == did or r["Dialogue ID"] == "")
        r.update({"Dialogue ID": did, "Chapter": item["chapter"], "Scene": f"{item['chapter']}-RECAP", "Character": "MARA",
                  "Text": item["text"], "Emotion": "reflective", "Intensity": "low", "Delivery": "field-journal narration",
                  "Radio?": "No", "Cinematic?": "Yes", "Gameplay?": "No", "Interruptible?": "Yes", "Priority": "high",
                  "Generated File": res, "Status": "MASTERED"})
        report["dialogue"][did] = stats

    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    with (ROOT / "DIALOGUE_PRODUCTION.csv").open("w", newline="", encoding="utf-8") as h:
        w = csv.DictWriter(h, fieldnames=fields)
        w.writeheader()
        w.writerows(rows)
    events_path = ROOT / "audio" / "campaign_events.json"
    events = json.loads(events_path.read_text(encoding="utf-8"))
    events["recaps"] = recap_events  # chapter that just ended -> recap dialogue id
    events_path.write_text(json.dumps(events, indent=2), encoding="utf-8")

    # ---- Ambience beds: OGG for runtime soundscapes; legacy WAV paths kept valid ----
    for wav in sorted((ROOT / "audio" / "ambience").rglob("*.wav")):
        src = MASTERS / f"{wav.stem}.mp3"
        if src.exists():
            report["ambience"][wav.stem + ".wav"] = master(src, wav, AMB_LUFS, -3.0, codec="wav")
            report["ambience"][wav.stem + ".ogg"] = master(src, wav.with_suffix(".ogg"), AMB_LUFS, -3.0, channels=2)
    for item in [i for i in PLAN["items"] if i["kind"] == "sfx"]:
        src = MASTERS / f"{item['asset_id']}.mp3"
        if item["category"].startswith("ambience"):
            dst = ROOT / "audio" / item["category"] / f"{item['asset_id']}.ogg"
            report["ambience"][dst.name] = master(src, dst, AMB_LUFS, -3.0, channels=2)

    # ---- One-shot SFX (WAV: low-latency, AudioManager hardcodes these paths) ----
    for folder in ["footsteps", "combat", "destruction", "movement", "ui", "vaelor", "water"]:
        for wav in sorted((ROOT / "audio" / folder).rglob("*.wav")):
            src = MASTERS / f"{wav.stem}.mp3"
            if src.exists():
                report["sfx"][wav.name] = master(src, wav, STEP_LUFS if folder == "footsteps" else SFX_LUFS, -1.5, codec="wav")
    for item in [i for i in PLAN["items"] if i["kind"] == "sfx" and not i["category"].startswith("ambience")]:
        dst = ROOT / "audio" / item["category"] / f"{item['asset_id']}.wav"
        report["sfx"][dst.name] = master(MASTERS / f"{item['asset_id']}.mp3", dst,
                                         STEP_LUFS if item["category"].startswith("footsteps") else SFX_LUFS, -1.5, codec="wav")

    (ROOT / "production" / "audio_master_report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    d = [v["lufs"] for v in report["dialogue"].values()]
    print(f"dialogue {len(d)} files, LUFS {min(d)}..{max(d)}; ambience {len(report['ambience'])}; sfx {len(report['sfx'])}")


if __name__ == "__main__":
    main()
