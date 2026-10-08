# API CAPABILITY MATRIX: ECHOES BENEATH

**Project:** ECHOES BENEATH  
**Generation Engine:** Tripo3D AI V2 REST API  

---

## Tripo3D Multi-Key Pipeline Configuration

Three credentials are loaded from environment variables or Windows user-bound encrypted storage outside this repository. Credentials are never included in runtime assets.

Live balance check on 2026-10-07:

| Key index | Available balance | Frozen balance |
| --- | ---: | ---: |
| 1 | 0 | 0 |
| 2 | 60 | 0 |
| 3 | 100 | 0 |

This production pass spent 920 credits: 14 model requests (560), 12 rig requests (300), and six successful legacy idle retargets (60). Seven rejected v2.5 retarget requests cost zero. All submitted jobs are terminal; 160 credits remain and none are frozen. See ASSET_REGISTRY.md for source provenance and the limits of visual acceptance. Account balances alone do not establish asset quality.

### Tripo3D API Specifications
- **Base URL:** `https://api.tripo3d.ai/v2/openapi`
- **Authentication:** `Bearer <TRIPO_API_KEY>`
- **Key Endpoints:**
  - `GET /user/balance` - Check active credit balance
  - `POST /task` - Submit text-to-3d, image-to-3d, animation/rigging tasks
  - `GET /task/{task_id}` - Poll task generation status and download GLTF/GLB models
- **Target Formats:** `.glb` (Binary glTF 2.0 with PBR textures and embedded animations)
- **Retry & Failover Architecture:** Managed through autonomous Python wrapper `scripts/tripo_client.py` with bounded request timeouts, sequential key rotation on authentication/quota errors, and bounded generation polling. Mesh optimization and gameplay QA are separate stages.

---

## Auxiliary Systems & APIs
- **Godot 4.7 Command Line / Headless Tooling:** Asset import, scene cooking, test automation.
- **Python 3.13 Runtime:** Pipeline automation, Tripo asset generation, conversion, and validation.
- **Git VCS:** Version control, milestone tagging, and regression tracking.
