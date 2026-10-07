# CHARACTER ASSET REGISTRY — ECHOES BENEATH
**Game Title:** ECHOES BENEATH  
**Engine:** Godot 4.7.2 Forward+ (D3D12, Jolt Physics 3D)  
**Art Pipeline:** Tripo3D PBR v2.5 -> GLTF 2.0 -> Godot Scene Node Architecture  

---

## 1. Character Asset Directory Structure
```
assets/
  characters/
    mara/
      source/       (Raw approved Tripo GLB download)
      optimized/    (Scale-calibrated, rig/mesh validated)
      textures/     (PBR Albedo, NormalGL, ORM)
      materials/    (Godot StandardMaterial3D)
    elias/
    nadiya/
    tomas/
    adrian/
    drake/
    meridian/
      base/
      scout/
      rifleman/
      heavy/
      commander/
      scientist/
```

---

## 2. Character Specification & Production Matrix

| Character ID | Name | Role | Story Role | Chapters | Height | Color Palette | Tripo Status | Approval Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `CHR_MARA_001` | **Mara Vale** | Protagonist | Archaeological Explorer & Specialist | All (P, 1-10, F, E) | 1.70 m | Olive green, Charcoal, Earth brown | In Progress | GENERATING |
| `CHR_ELIAS_001` | **Dr. Elias Voss** | Mentor | Senior Expedition Leader | 1, 2, 3, 8, E | 1.80 m | Weathered tan, Grey, Neutral linen | Planned | PLANNED |
| `CHR_NADIYA_001` | **Nadiya Rahman** | Specialist | Comms & Systems Engineer | 1, 4, 6, 7, 8, F | 1.67 m | Utility slate, Navy, Orange trim | Planned | PLANNED |
| `CHR_TOMAS_001` | **Tomas Reyes** | Specialist | Climber & Field Medic | 1, 2, 3, 8, F | 1.84 m | Forest green, Khaki, Leather | Planned | PLANNED |
| `CHR_ADRIAN_001` | **Adrian Kell** | Coordinator | Logistics / Betrayer | 1, 8 | 1.78 m | Neutral grey, Black, Gunmetal | Planned | PLANNED |
| `CHR_DRAKE_001` | **Lucian Drake** | Antagonist | Meridian Director / Expedition Exec | 5, 8, 9, 10 | 1.86 m | Dark graphite, Obsidian, Titanium | Planned | PLANNED |
| `CHR_MERIDIAN_BASE_001` | **Meridian Base** | Enemy | Private Archaeological Security | 5, 7, 8, 9, 10 | 1.78-1.85 m | Charcoal, Matte black, Khaki drab | Planned | PLANNED |

---

## 3. Character Detail Records

### `CHR_MARA_001` — Mara Vale (Hero Protagonist)
- **Role:** Main playable protagonist.
- **Physical Traits:** Age 30-34, 1.70m, athletic functional build, dark brown hair in compact low ponytail, intelligent determined facial features.
- **Costume:** Weathered dark olive expedition shirt, durable charcoal climbing trousers, rugged hiking boots, compact utility belt, lightweight harness, compact 20L backpack.
- **Pose Requirement:** Neutral A-pose / standing symmetrical pose, arms separated from torso, 5 fingers per hand, legs separated, straight spine.
- **Scale:** 1.70 Godot units (meters) high.
- **Target File:** `assets/characters/mara/source/CHR_Mara_Base.glb`
