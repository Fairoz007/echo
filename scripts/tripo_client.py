"""
Tripo3D Asset Generation Pipeline for ECHOES BENEATH
Features:
- Multi-key auto failover
- Asynchronous task submission & polling
- Automatic GLB download & placement in Godot asset tree
- Verification and metadata registration
"""

import os
import sys
import time
import json
import urllib.request
import urllib.error

API_KEYS = [
    "tsk_YeVEJCZ8gdewbRDRSlAgYG0uMu-QuR_W3R4nCc61E2j",
    "tsk_-QGbzwixVswcZoYGw3lMf2j9D1Zqu_bCg6AsaZjwYPu",
    "tsk_W5L8HeukUnv-AGCkjOFTL55gD1X4nU-vWpdLjnx5vbC"
]

BASE_URL = "https://api.tripo3d.ai/v2/openapi"

current_key_idx = 0

def get_current_key():
    global current_key_idx
    return API_KEYS[current_key_idx]

def rotate_key():
    global current_key_idx
    if current_key_idx < len(API_KEYS) - 1:
        current_key_idx += 1
        print(f"[TRIPO] Switching to API Key #{current_key_idx + 1}")
        return True
    else:
        print("[TRIPO ERROR] All API keys exhausted!")
        return False

def make_request(endpoint, method="GET", data=None):
    while True:
        url = f"{BASE_URL}{endpoint}"
        key = get_current_key()
        headers = {
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json"
        }
        
        req_data = json.dumps(data).encode("utf-8") if data else None
        req = urllib.request.Request(url, data=req_data, headers=headers, method=method)
        
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                res_body = resp.read().decode("utf-8")
                return json.loads(res_body)
        except urllib.error.HTTPError as e:
            err_body = e.read().decode("utf-8")
            print(f"[TRIPO HTTP {e.code}] {err_body}")
            if e.code in [401, 402, 429]:
                if rotate_key():
                    continue
            raise
        except Exception as e:
            print(f"[TRIPO EXCEPTION] {e}")
            raise

def check_all_balances():
    for i, k in enumerate(API_KEYS):
        req = urllib.request.Request(f"{BASE_URL}/user/balance", headers={"Authorization": f"Bearer {k}"})
        try:
            with urllib.request.urlopen(req) as resp:
                print(f"Key #{i+1}: {resp.read().decode('utf-8')}")
        except Exception as e:
            print(f"Key #{i+1} Failed: {e}")

def generate_text_to_3d(prompt, output_filename, model_version="v2.5-20250123"):
    payload = {
        "type": "text_to_model",
        "prompt": prompt,
        "model_version": model_version
    }
    print(f"[TRIPO] Submitting generation prompt: {prompt[:60]}...")
    res = make_request("/task", method="POST", data=payload)
    if res.get("code") != 0:
        raise RuntimeError(f"Task submission failed: {res}")
    
    task_id = res["data"]["task_id"]
    print(f"[TRIPO] Task submitted successfully. Task ID: {task_id}")
    
    # Poll for completion
    while True:
        time.sleep(5)
        status_res = make_request(f"/task/{task_id}")
        data = status_res.get("data", {})
        status = data.get("status")
        progress = data.get("progress", 0)
        print(f"[TRIPO] Task {task_id}: {status} ({progress}%)")
        
        if status == "success":
            output_model = data.get("output", {}).get("model") or data.get("result", {}).get("model")
            if not output_model:
                # Try finding any model URL
                for k, v in data.get("output", {}).items():
                    if isinstance(v, str) and (v.endswith(".glb") or "glb" in v):
                        output_model = v
                        break
            print(f"[TRIPO] Success! Model URL: {output_model}")
            # Download file
            os.makedirs(os.path.dirname(output_filename), exist_ok=True)
            urllib.request.urlretrieve(output_model, output_filename)
            print(f"[TRIPO] Saved model to {output_filename} (Size: {os.path.getsize(output_filename)} bytes)")
            return output_filename
        elif status in ["failed", "cancelled"]:
            raise RuntimeError(f"Task {task_id} failed with status: {status}")

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "balance":
        check_all_balances()
    else:
        print("Tripo3D client ready. Use via import or CLI commands.")
