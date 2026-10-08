"""Bounded ElevenLabs production client. Credentials never enter assets or logs."""
from __future__ import annotations
import json
import re
import time
import urllib.error
import urllib.request
from pathlib import Path
from production_credentials import get_secret

ROOT = Path(__file__).resolve().parents[1]

class ElevenLabsError(RuntimeError):
    pass

class ElevenLabsClient:
    def __init__(self, timeout=90):
        self._key = get_secret("ELEVENLABS_API_KEY")
        self.timeout = timeout
        self.log = ROOT / "production" / "elevenlabs_requests.jsonl"

    def _record(self, **values):
        self.log.parent.mkdir(parents=True, exist_ok=True)
        with self.log.open("a", encoding="utf-8") as handle:
            handle.write(json.dumps({"time_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()), **values}) + "\n")

    def _request(self, path, payload=None):
        method = "GET" if payload is None else "POST"
        request = urllib.request.Request("https://api.elevenlabs.io" + path,
            data=None if payload is None else json.dumps(payload).encode(),
            headers={"xi-api-key": self._key, "Content-Type": "application/json"}, method=method)
        # Retrying ambiguous paid POST failures can spend quota twice. Only retry explicit 429s.
        for attempt in range(3):
            try:
                with urllib.request.urlopen(request, timeout=self.timeout) as response:
                    return response.read(), {k.lower(): v for k, v in response.headers.items()}
            except urllib.error.HTTPError as error:
                code = error.code
                reason = "http_error"
                try:
                    detail = json.loads(error.read()).get("detail", {})
                    if isinstance(detail, dict):
                        reason = str(detail.get("status", reason))
                except (ValueError, AttributeError):
                    pass
                # Provider error messages may echo inputs; only retain restricted status codes.
                reason = re.sub(r"[^A-Za-z0-9_-]", "", reason)[:80]
                self._record(endpoint=path.split("?")[0], method=method, status=code, reason=reason)
                if code == 429 and attempt < 2:
                    delay = error.headers.get("Retry-After", "2")
                    time.sleep(min(float(delay) if delay.isdigit() else 2 ** (attempt + 1), 20))
                    continue
                raise ElevenLabsError(f"ElevenLabs HTTP {code}: {reason}") from None
            except (urllib.error.URLError, TimeoutError):
                self._record(endpoint=path.split("?")[0], method=method, status="network_failure", recovery="inspect_history_before_retry")
                raise ElevenLabsError("Network failure; inspect provider history before retrying generation") from None
        raise ElevenLabsError("Rate limit retry budget exhausted")

    def read(self, path):
        if path not in ("/v1/user/subscription", "/v1/voices", "/v1/models"):
            raise ValueError("Unsupported capability endpoint")
        content, _ = self._request(path)
        return json.loads(content)

    def _generate(self, asset_id, path, payload, destination):
        if not re.fullmatch(r"[A-Z0-9_]{3,90}", asset_id):
            raise ValueError("Invalid stable asset ID")
        destination = Path(destination).resolve()
        if ROOT not in destination.parents or destination.suffix != ".mp3":
            raise ValueError("Output must be a project-local MP3")
        if destination.exists():
            raise FileExistsError("Existing asset preserved; explicit review required before replacement")
        content, headers = self._request(path, payload)
        if len(content) < 128 or not (content[:3] == b"ID3" or content[0] == 255):
            raise ElevenLabsError("Invalid MP3 response; asset not saved")
        destination.parent.mkdir(parents=True, exist_ok=True)
        temporary = destination.with_suffix(".mp3.partial")
        temporary.write_bytes(content)
        temporary.replace(destination)
        self._record(asset_id=asset_id, endpoint=path.split("?")[0], status="GENERATED",
            bytes=len(content), file=str(destination.relative_to(ROOT)),
            request_id=headers.get("request-id"), character_cost=headers.get("character-cost"),
            qa="PENDING_LISTENING")
        return destination

    def generate_dialogue(self, asset_id, text, voice_id, destination, model_id="eleven_multilingual_v2", settings=None):
        if not text.strip() or len(text) > 10000 or not re.fullmatch(r"[A-Za-z0-9_-]+", voice_id):
            raise ValueError("Invalid dialogue request")
        return self._generate(asset_id, f"/v1/text-to-speech/{voice_id}?output_format=mp3_44100_128",
            {"text": text, "model_id": model_id, "voice_settings": settings or
             {"stability": 0.55, "similarity_boost": 0.8, "style": 0.15, "use_speaker_boost": True}}, destination)

    def generate_sound_effect(self, asset_id, prompt, destination, duration=4, loop=False):
        if not prompt.strip() or len(prompt) > 1000 or not 0.5 <= duration <= 30:
            raise ValueError("Invalid sound effect request")
        return self._generate(asset_id, "/v1/sound-generation?output_format=mp3_44100_128",
            {"text": prompt, "duration_seconds": duration, "prompt_influence": 0.3,
             "model_id": "eleven_text_to_sound_v2", "loop": bool(loop)}, destination)

    def generate_ambience(self, asset_id, prompt, destination, duration=20):
        return self.generate_sound_effect(asset_id, prompt, destination, duration, loop=True)

    def generate_radio_dialogue(self, *args, **kwargs):
        # Preserve the actor identity; band limiting belongs to offline processing / Radio bus.
        return self.generate_dialogue(*args, **kwargs)

    def generate_voice_variant(self, *args, settings=None, **kwargs):
        return self.generate_dialogue(*args, settings=settings, **kwargs)
