"""Production-only secrets: environment first, Windows user-bound storage second.

Never import this module from shipped game code. No credentials live in the repo.
"""
import os
import subprocess


def get_secret(name: str) -> str:
    if name not in {"TRIPO_API_KEYS", "ELEVENLABS_API_KEY"}:
        raise ValueError("Unsupported production credential")
    value = os.environ.get(name, "").strip()
    if value:
        return value
    if os.name == "nt":
        command = (
            "$p = Join-Path $env:USERPROFILE '.codex/secrets/echoes-beneath/" + name + ".dpapi'; "
            "if (Test-Path -LiteralPath $p) { "
            "$s = (Get-Content -LiteralPath $p -Raw).Trim() | ConvertTo-SecureString; "
            "[System.Net.NetworkCredential]::new('', $s).Password }"
        )
        result = subprocess.run(
            ["powershell.exe", "-NoProfile", "-NonInteractive", "-Command", command],
            capture_output=True, text=True, timeout=15,
            creationflags=subprocess.CREATE_NO_WINDOW,
        )
        if result.returncode == 0 and result.stdout.strip():
            return result.stdout.strip()
    raise RuntimeError(f"Missing production credential: {name}")
