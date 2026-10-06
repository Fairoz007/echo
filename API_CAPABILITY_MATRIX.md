# API CAPABILITY MATRIX: ECHOES BENEATH

**Project:** ECHOES BENEATH  
**Generation Engine:** Tripo3D AI V2 REST API  

---

## Tripo3D Multi-Key Pipeline Configuration

Three production API keys have been provided and verified for 3D asset generation with full credit balances:

| Key Index | Key Prefix | Tested Balance | Status | Failover Strategy |
| :--- | :--- | :--- | :--- | :--- |
| **Key 1** | `tsk_YeVEJC...` | 600 Credits | Active Primary | Use first until balance low/exhausted |
| **Key 2** | `tsk_-QGbzw...` | 600 Credits | Secondary Backup | Automatic rollover when Key 1 depleted |
| **Key 3** | `tsk_W5L8He...` | 600 Credits | Tertiary Backup | Rollover when Key 2 depleted |

### Tripo3D API Specifications
- **Base URL:** `https://api.tripo3d.ai/v2/openapi`
- **Authentication:** `Bearer <TRIPO_API_KEY>`
- **Key Endpoints:**
  - `GET /user/balance` - Check active credit balance
  - `POST /task` - Submit text-to-3d, image-to-3d, animation/rigging tasks
  - `GET /task/{task_id}` - Poll task generation status and download GLTF/GLB models
- **Target Formats:** `.glb` (Binary glTF 2.0 with PBR textures and embedded animations)
- **Retry & Failover Architecture:** Managed through autonomous Python wrapper `scripts/tripo_client.py` with automatic error handling, exponential backoff, key rotation, and mesh optimization checks.

---

## Auxiliary Systems & APIs
- **Godot 4.7 Command Line / Headless Tooling:** Asset import, scene cooking, test automation.
- **Python 3.13 Runtime:** Pipeline automation, Tripo asset generation, conversion, and validation.
- **Git VCS:** Version control, milestone tagging, and regression tracking.
