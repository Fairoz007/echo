# PERFORMANCE BUDGET & PLATFORM TARGETS

---

## Target System Specification
- **Engine:** Godot 4.7.2 Forward+ (D3D12)
- **Target Framerate:** 60 FPS locked (16.6ms frame time)
- **Target Resolution:** 1080p - 1440p Native with FSR 2.2 scaling support

---

## Resource Budgets & Guardrails

| Metric | Target Budget | Max Cap | Optimization Technique |
| :--- | :--- | :--- | :--- |
| **Draw Calls** | < 1,200 | 1,800 | MultiMesh instancing, occlusion culling |
| **Polygon Count (Scene)**| 800,000 - 1,500,000 | 2,200,000 | Automatic LOD generation (LOD0, LOD1, LOD2) |
| **Character Triangles** | 25,000 - 40,000 | 50,000 | Dedicated hero mesh budget |
| **VRAM Usage** | < 3.5 GB | 5.5 GB | BC7 texture compression, mipmapping |
| **Foliage Density** | 10,000 blades/chunk | 25,000 blades | MultiMesh chunking (32x32m), distance fade |
| **Physics Step Time** | < 3.0 ms | 5.0 ms | Jolt Physics 3D with primitive & convex collision |
| **Audio Channels** | 32 active voices | 64 active voices | Polyphony limiting, distance attenuation |
